%% diagnose_q_table.m
% Quick diagnostic script to identify Q-table anomalies
%
% PURPOSE: Analyze current Q-table to find why non-goal states have higher
%          Q-values than Q(goal_state, goal_action)
%
% USAGE: Run after loading Q_2d matrix from training

%% ========================================================================
%% Configuration
%% ========================================================================
goal_state = 50;
goal_action = 50;
theoretical_max = 1 / (1 - 0.99);  % Should be 100

fprintf('\n=== Q-TABLE DIAGNOSTIC ===\n\n');

%% ========================================================================
%% 1. Global Maximum Analysis
%% ========================================================================
fprintf('1. GLOBAL MAXIMUM ANALYSIS\n');
fprintf('   Theoretical maximum Q-value: %.2f\n', theoretical_max);

[max_Q, max_idx] = max(Q_2d(:));
[max_state, max_action] = ind2sub(size(Q_2d), max_idx);
goal_Q = Q_2d(goal_state, goal_action);

fprintf('   Global max Q-value: %.6f at Q(%d, %d)\n', max_Q, max_state, max_action);
fprintf('   Goal Q-value: %.6f at Q(%d, %d)\n', goal_Q, goal_state, goal_action);
fprintf('   Difference: %.6f (should be <= 0)\n', max_Q - goal_Q);

if max_Q > theoretical_max + 1
    fprintf('   ⚠️  WARNING: Max Q-value exceeds theoretical maximum!\n');
end

if max_state ~= goal_state || max_action ~= goal_action
    fprintf('   ❌ PROBLEM: Global maximum is NOT at goal state!\n');
else
    fprintf('   ✓ OK: Global maximum is at goal state\n');
end

%% ========================================================================
%% 2. Top 10 Highest Q-values
%% ========================================================================
fprintf('\n2. TOP 10 HIGHEST Q-VALUES\n');

Q_flat = Q_2d(:);
[sorted_Q, sorted_idx] = sort(Q_flat, 'descend');

fprintf('   Rank | State | Action | Q-value   | vs Goal\n');
fprintf('   -----|-------|--------|-----------|--------\n');
for i = 1:min(10, length(sorted_Q))
    if sorted_Q(i) < 1
        break;  % Skip near-zero values
    end
    [s, a] = ind2sub(size(Q_2d), sorted_idx(i));
    marker = '';
    if s == goal_state && a == goal_action
        marker = ' ← GOAL';
    end
    fprintf('   %4d | %5d | %6d | %9.4f | %+7.4f%s\n', ...
        i, s, a, sorted_Q(i), sorted_Q(i) - goal_Q, marker);
end

%% ========================================================================
%% 3. Goal State Row Analysis
%% ========================================================================
fprintf('\n3. GOAL STATE ROW ANALYSIS (State %d)\n', goal_state);

goal_row = Q_2d(goal_state, :);
non_zero_actions = find(goal_row > 0.1);  % Find actions with significant values

fprintf('   Actions with Q-value > 0.1: %d\n', length(non_zero_actions));
if length(non_zero_actions) == 1 && non_zero_actions(1) == goal_action
    fprintf('   ✓ OK: Only goal action has value in goal state\n');
else
    fprintf('   ❌ PROBLEM: Multiple actions have values in goal state\n');
    fprintf('   Action | Q-value   | Should be\n');
    fprintf('   -------|-----------|----------\n');
    for i = 1:length(non_zero_actions)
        a = non_zero_actions(i);
        if a == goal_action
            expected = '~100';
        else
            expected = '~0';
        end
        fprintf('   %6d | %9.4f | %s\n', a, goal_row(a), expected);
    end
end

%% ========================================================================
%% 4. Goal Column Analysis
%% ========================================================================
fprintf('\n4. GOAL ACTION COLUMN ANALYSIS (Action %d)\n', goal_action);

goal_col = Q_2d(:, goal_action);
non_zero_states = find(goal_col > 0.1);

fprintf('   States with Q(state, %d) > 0.1: %d\n', goal_action, length(non_zero_states));
fprintf('   Top 5 states for goal action:\n');
fprintf('   State | Q-value   | Distance from goal\n');
fprintf('   ------|-----------|-------------------\n');

[sorted_col, sorted_col_idx] = sort(goal_col, 'descend');
for i = 1:min(5, sum(goal_col > 0.1))
    s = sorted_col_idx(i);
    fprintf('   %5d | %9.4f | %+d\n', s, sorted_col(i), s - goal_state);
end

%% ========================================================================
%% 5. Value Gradient Analysis (neighbors of goal state)
%% ========================================================================
fprintf('\n5. VALUE GRADIENT AROUND GOAL STATE\n');
fprintf('   Distance | State | Best Action | Max Q-value\n');
fprintf('   ---------|-------|-------------|------------\n');

for dist = -5:5
    s = goal_state + dist;
    if s >= 1 && s <= size(Q_2d, 1)
        [max_Q_state, best_action] = max(Q_2d(s, :));
        if s == goal_state
            marker = ' <- GOAL';
        else
            marker = '';
        end
        fprintf('   %+8d | %5d | %11d | %9.4f%s\n', ...
            dist, s, best_action, max_Q_state, marker);
    end
end

%% ========================================================================
%% 6. Theoretical Consistency Check
%% ========================================================================
fprintf('\n6. THEORETICAL CONSISTENCY CHECKS\n');

% Check if any Q-value exceeds theoretical max
violations = sum(Q_2d(:) > theoretical_max + 1);
if violations > 0
    fprintf('   ❌ VIOLATION: %d Q-values exceed theoretical maximum (%.2f)\n', ...
        violations, theoretical_max);
    [viol_states, viol_actions] = find(Q_2d > theoretical_max + 1);
    fprintf('   First 5 violations:\n');
    for i = 1:min(5, length(viol_states))
        fprintf('      Q(%d, %d) = %.4f\n', ...
            viol_states(i), viol_actions(i), Q_2d(viol_states(i), viol_actions(i)));
    end
else
    fprintf('   ✓ OK: No Q-values exceed theoretical maximum\n');
end

% Check value propagation (goal state should bootstrap to ~100)
if goal_Q < theoretical_max - 5
    fprintf('   ⚠️  WARNING: Goal state Q-value (%.2f) is significantly below theoretical max (%.2f)\n', ...
        goal_Q, theoretical_max);
    fprintf('      This suggests insufficient training or incorrect reward structure\n');
else
    fprintf('   ✓ OK: Goal state Q-value is near theoretical maximum\n');
end

%% ========================================================================
%% 7. Hypothesis Generator
%% ========================================================================
fprintf('\n7. LIKELY ROOT CAUSES\n');

if max_state ~= goal_state || max_action ~= goal_action
    fprintf('   PRIMARY ISSUE: Global maximum not at goal state\n\n');

    % Hypothesis 1: State-action mismatch
    goal_row_nonzero = sum(Q_2d(goal_state, :) > 0.1);
    if goal_row_nonzero > 1
        fprintf('   Hypothesis #1: State-action temporal mismatch\n');
        fprintf('      - Goal state has %d actions with values (should be 1)\n', goal_row_nonzero);
        fprintf('      - Actions selected in other states are being credited to goal state\n');
        fprintf('      - FIX: Check old_wyb_akcja pairing in m_regulator_Q.m\n\n');
    end

    % Hypothesis 2: Reward structure
    if max_Q > goal_Q
        fprintf('   Hypothesis #2: Incorrect reward propagation\n');
        fprintf('      - State %d, action %d has higher value than goal\n', max_state, max_action);
        fprintf('      - Check if this state receives R=1 when it shouldn''t\n');
        fprintf('      - FIX: Verify reward assignment in m_regulator_Q.m lines 178-181\n\n');
    end

    % Hypothesis 3: Bootstrap inflation
    [max_row_val, ~] = max(Q_2d, [], 2);  % Max Q for each state
    problematic_states = find(max_row_val > goal_Q);
    if length(problematic_states) > 1
        fprintf('   Hypothesis #3: Bootstrap value inflation\n');
        fprintf('      - %d states have max Q-values > goal state\n', length(problematic_states));
        fprintf('      - These states propagate inflated values backward via γ·max(Q(s'',:))\n');
        fprintf('      - Problematic states: [');
        fprintf('%d ', problematic_states(1:min(10, length(problematic_states))));
        fprintf('...]\n');
        fprintf('      - FIX: Enable detailed logging to trace value propagation\n\n');
    end
end

fprintf('\n=== END DIAGNOSTIC ===\n\n');

%% ========================================================================
%% 8. Generate Visualization (if enabled)
%% ========================================================================
if exist('generate_plots', 'var') && generate_plots == 1
    figure('Name', 'Q-Table Diagnostics');

    % Plot 1: Q-value distribution
    subplot(2, 2, 1);
    histogram(Q_2d(:), 50);
    hold on;
    xline(theoretical_max, 'r--', 'Theoretical Max', 'LineWidth', 2);
    xline(goal_Q, 'g--', sprintf('Goal Q=%.2f', goal_Q), 'LineWidth', 2);
    xlabel('Q-value');
    ylabel('Frequency');
    title('Q-value Distribution');
    grid on;

    % Plot 2: Goal state row
    subplot(2, 2, 2);
    plot(Q_2d(goal_state, :), 'b.-');
    hold on;
    plot(goal_action, goal_Q, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    xlabel('Action');
    ylabel('Q-value');
    title(sprintf('Goal State (s=%d) Row', goal_state));
    grid on;

    % Plot 3: Max Q-value per state
    subplot(2, 2, 3);
    [max_per_state, ~] = max(Q_2d, [], 2);
    plot(max_per_state, 'b.-');
    hold on;
    plot(goal_state, goal_Q, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    yline(theoretical_max, 'r--', 'Theoretical Max');
    xlabel('State');
    ylabel('Max Q-value');
    title('Maximum Q-value per State');
    grid on;

    % Plot 4: Heatmap around goal state
    subplot(2, 2, 4);
    state_range = max(1, goal_state-10):min(size(Q_2d,1), goal_state+10);
    action_range = max(1, goal_action-10):min(size(Q_2d,2), goal_action+10);
    imagesc(action_range, state_range, Q_2d(state_range, action_range));
    colorbar;
    hold on;
    plot(goal_action, goal_state, 'rx', 'MarkerSize', 15, 'LineWidth', 3);
    xlabel('Action');
    ylabel('State');
    title('Q-table Heatmap (Goal State Vicinity)');
    axis xy;
end
