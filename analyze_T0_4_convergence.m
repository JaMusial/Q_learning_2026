%% ========================================================================
%% ANALYZE T0=4 CONVERGENCE ISSUES
%% ========================================================================
% PURPOSE: Investigate why T0=4 shows poorer convergence than T0=0
%
% FINDINGS FROM tests_rusults.txt:
%   T0=0: Q(50,50)=92.46, TD error decreasing ✓
%   T0=4: Q(50,50)=74.10, TD error NOT decreasing ⚠️
%
% QUESTIONS TO ANSWER:
%   1. Why Q(50,50) only reaches 74.10 for T0=4 vs 92.46 for T0=0?
%   2. Why TD error increases instead of decreases?
%   3. When does global maximum leave goal state?
%   4. Are bootstrap values inflating?
%   5. How is R=1 distributed across 20 different states?
%% ========================================================================

clear; clc;

%% Load JSON debug logs
fprintf('Loading T0=4 debug logs...\n');
json_file = 'logi_T0=4_max_epoki=50.json';
data = jsondecode(fileread(json_file));
fprintf('Loaded %d iterations\n\n', length(data.DEBUG_goal_Q));

%% Configuration
T0_controller = 4;
goal_state = 50;
goal_action = 50;
alfa = 0.1;
gamma = 0.99;
theoretical_max = 1/(1-gamma);

%% ========================================================================
%% SECTION 1: GOAL Q-VALUE EVOLUTION
%% ========================================================================
fprintf('=== SECTION 1: GOAL Q-VALUE EVOLUTION ===\n\n');

% Find all goal state updates
goal_updates = find(data.DEBUG_is_updating_goal == 1);
n_goal_updates = length(goal_updates);
fprintf('Total goal state updates: %d\n', n_goal_updates);

% Analyze goal Q-value trajectory
goal_Q_values = data.DEBUG_goal_Q(goal_updates);
fprintf('Initial Q(50,50): %.4f\n', goal_Q_values(1));
fprintf('Final Q(50,50): %.4f\n', goal_Q_values(end));
fprintf('Theoretical max: %.4f\n', theoretical_max);
fprintf('Gap: %.4f (%.1f%%)\n\n', theoretical_max - goal_Q_values(end), ...
    100*(theoretical_max - goal_Q_values(end))/theoretical_max);

% Check if goal Q-value is still increasing at end
if n_goal_updates >= 100
    early_mean = mean(goal_Q_values(1:50));
    late_mean = mean(goal_Q_values(end-49:end));
    fprintf('Early average (first 50 updates): %.4f\n', early_mean);
    fprintf('Late average (last 50 updates): %.4f\n', late_mean);
    fprintf('Increase: %.4f (%.1f%%)\n', late_mean - early_mean, ...
        100*(late_mean - early_mean)/early_mean);

    if late_mean > early_mean
        fprintf('✓ Goal Q-value still increasing (needs more training)\n\n');
    else
        fprintf('⚠️  Goal Q-value plateaued or decreasing\n\n');
    end
end

%% ========================================================================
%% SECTION 2: REWARD DISTRIBUTION ANALYSIS
%% ========================================================================
fprintf('=== SECTION 2: REWARD DISTRIBUTION ANALYSIS ===\n\n');

% Overall reward statistics
total_updates = sum(data.DEBUG_uczenie_T0 == 1);
R1_updates = sum(data.DEBUG_R_buffered == 1 & data.DEBUG_uczenie_T0 == 1);
fprintf('Total Q-updates: %d\n', total_updates);
fprintf('R=1 updates: %d (%.1f%%)\n', R1_updates, 100*R1_updates/total_updates);
fprintf('R=0 updates: %d (%.1f%%)\n\n', total_updates - R1_updates, ...
    100*(total_updates - R1_updates)/total_updates);

% States that received R=1
states_with_R1 = unique(data.DEBUG_old_stan_T0(data.DEBUG_R_buffered == 1));
fprintf('States that received R=1: %d unique states\n', length(states_with_R1));
fprintf('States: [%s]\n\n', num2str(states_with_R1'));

% Goal state reward analysis
goal_R1 = sum(data.DEBUG_is_updating_goal == 1 & data.DEBUG_R_buffered == 1);
goal_R0 = sum(data.DEBUG_is_updating_goal == 1 & data.DEBUG_R_buffered == 0);
fprintf('Goal state updates:\n');
fprintf('  R=1: %d (%.1f%%)\n', goal_R1, 100*goal_R1/n_goal_updates);
fprintf('  R=0: %d (%.1f%%)\n', goal_R0, 100*goal_R0/n_goal_updates);

if goal_R0 > 0
    fprintf('  ⚠️  WARNING: Goal state received R=0 %d times!\n\n', goal_R0);
else
    fprintf('  ✓ OK: Goal state always receives R=1\n\n');
end

%% ========================================================================
%% SECTION 3: GLOBAL MAXIMUM TRACKING
%% ========================================================================
fprintf('=== SECTION 3: GLOBAL MAXIMUM TRACKING ===\n\n');

% When is global maximum at goal state?
max_at_goal = (data.DEBUG_global_max_state == goal_state) & ...
              (data.DEBUG_global_max_action == goal_action);
pct_max_at_goal = 100*sum(max_at_goal)/length(max_at_goal);
fprintf('Global max at goal state: %.1f%% of iterations\n', pct_max_at_goal);

% Find when maximum first leaves goal
if sum(~max_at_goal) > 0
    first_departure = find(~max_at_goal, 1);
    fprintf('First departure from goal: iteration %d\n', first_departure);
    fprintf('  Moved to: Q(%d, %d) = %.4f\n', ...
        data.DEBUG_global_max_state(first_departure), ...
        data.DEBUG_global_max_action(first_departure), ...
        data.DEBUG_global_max_Q(first_departure));

    % Where does maximum go when not at goal?
    non_goal_states = data.DEBUG_global_max_state(~max_at_goal);
    non_goal_actions = data.DEBUG_global_max_action(~max_at_goal);

    % Most common non-goal maximum location
    [unique_pairs, ~, idx] = unique([non_goal_states' non_goal_actions'], 'rows');
    counts = histc(idx, 1:size(unique_pairs,1));
    [max_count, max_idx] = max(counts);

    fprintf('\nMost common non-goal maximum:\n');
    fprintf('  Q(%d, %d) appears %d times\n', ...
        unique_pairs(max_idx,1), unique_pairs(max_idx,2), max_count);
else
    fprintf('✓ Global maximum always at goal state\n');
end
fprintf('\n');

%% ========================================================================
%% SECTION 4: BOOTSTRAP VALUE ANALYSIS
%% ========================================================================
fprintf('=== SECTION 4: BOOTSTRAP VALUE ANALYSIS ===\n\n');

% Bootstrap statistics for all updates
learning_idx = find(data.DEBUG_uczenie_T0 == 1);
bootstrap_values = data.DEBUG_bootstrap(learning_idx);

fprintf('Bootstrap value statistics:\n');
fprintf('  Mean: %.4f\n', mean(bootstrap_values));
fprintf('  Std: %.4f\n', std(bootstrap_values));
fprintf('  Max: %.4f\n', max(bootstrap_values));
fprintf('  Min: %.4f\n', min(bootstrap_values));
fprintf('  Theoretical limit (γ×100): %.4f\n', gamma * theoretical_max);

% Check for bootstrap inflation
inflated = bootstrap_values > (gamma * theoretical_max + 0.1);
if sum(inflated) > 0
    fprintf('  ⚠️  WARNING: %d bootstrap values exceed theoretical limit!\n', sum(inflated));

    % Find first inflated bootstrap
    inflated_idx = learning_idx(find(inflated, 1));
    fprintf('  First occurrence at iteration %d\n', inflated_idx);
    fprintf('    Next state: %d\n', data.DEBUG_stan_T0(inflated_idx));
    fprintf('    Bootstrap: %.4f\n', data.DEBUG_bootstrap(inflated_idx));
else
    fprintf('  ✓ OK: All bootstrap values within theoretical bounds\n');
end
fprintf('\n');

%% ========================================================================
%% SECTION 5: TD ERROR TRENDS
%% ========================================================================
fprintf('=== SECTION 5: TD ERROR TRENDS ===\n\n');

% TD error statistics
TD_errors = data.DEBUG_TD_error(learning_idx);
fprintf('TD error statistics:\n');
fprintf('  Mean: %.4f\n', mean(TD_errors));
fprintf('  Std: %.4f\n', std(TD_errors));
fprintf('  Max positive: %.4f\n', max(TD_errors));
fprintf('  Max negative: %.4f\n', min(TD_errors));

% Compare first half vs second half
mid_point = floor(length(TD_errors)/2);
first_half = TD_errors(1:mid_point);
second_half = TD_errors(mid_point+1:end);

fprintf('\nFirst half vs Second half:\n');
fprintf('  First half: mean=%.4f, std=%.4f\n', mean(first_half), std(first_half));
fprintf('  Second half: mean=%.4f, std=%.4f\n', mean(second_half), std(second_half));

if abs(mean(second_half)) < abs(mean(first_half))
    fprintf('  ✓ OK: TD error magnitude decreasing\n');
else
    fprintf('  ⚠️  WARNING: TD error magnitude NOT decreasing\n');
end

if std(second_half) < std(first_half)
    fprintf('  ✓ OK: TD error variance decreasing\n');
else
    fprintf('  ⚠️  WARNING: TD error variance NOT decreasing\n');
end
fprintf('\n');

%% ========================================================================
%% SECTION 6: GOAL STATE UPDATE QUALITY
%% ========================================================================
fprintf('=== SECTION 6: GOAL STATE UPDATE QUALITY ===\n\n');

% Analyze TD errors specifically for goal state updates
goal_TD_errors = data.DEBUG_TD_error(goal_updates);
fprintf('Goal state TD error statistics:\n');
fprintf('  Mean: %.4f\n', mean(goal_TD_errors));
fprintf('  Std: %.4f\n', std(goal_TD_errors));
fprintf('  Max: %.4f\n', max(goal_TD_errors));
fprintf('  Min: %.4f\n', min(goal_TD_errors));

% Expected TD error for goal state: R + γ·max(Q(s',:)) - Q(goal, goal)
% Since goal state forces action=goal_action which keeps system at goal:
% Expected: 1 + γ·Q(50,50) - Q(50,50) = 1 - (1-γ)·Q(50,50)
expected_goal_TD = 1 - (1-gamma)*goal_Q_values;
actual_goal_TD = goal_TD_errors;

fprintf('\nExpected vs Actual goal TD errors:\n');
fprintf('  Mean expected: %.4f\n', mean(expected_goal_TD));
fprintf('  Mean actual: %.4f\n', mean(actual_goal_TD));
fprintf('  Difference: %.4f\n', mean(actual_goal_TD) - mean(expected_goal_TD));

if abs(mean(actual_goal_TD) - mean(expected_goal_TD)) > 0.5
    fprintf('  ⚠️  WARNING: Actual goal TD deviates from expected!\n');
    fprintf('      This suggests next state after goal is NOT always goal\n');
else
    fprintf('  ✓ OK: Goal TD errors match expected pattern\n');
end
fprintf('\n');

%% ========================================================================
%% SECTION 7: DEAD TIME BUFFER ANALYSIS
%% ========================================================================
fprintf('=== SECTION 7: DEAD TIME BUFFER ANALYSIS ===\n\n');

% Check temporal alignment: does old_stan_T0 lag behind current state?
% For T0_controller=4, dt=0.1, buffer size = 40 samples
buffer_size = T0_controller / 0.1;
fprintf('Expected buffer size: %d samples\n', buffer_size);

% Find a sequence where we can verify buffering
% Look for when current state changes from goal to non-goal
state_transitions = find(diff([goal_state; data.DEBUG_old_state']) ~= 0);

if ~isempty(state_transitions) && length(state_transitions) >= 1
    trans_idx = state_transitions(1);
    fprintf('\nFirst state transition at iteration %d\n', trans_idx);
    fprintf('  Before: state=%d\n', data.DEBUG_old_state(max(1, trans_idx-1)));
    fprintf('  After: state=%d\n', data.DEBUG_old_state(trans_idx));

    % Check when this appears in old_stan_T0 (should be ~40 iterations later)
    if trans_idx + buffer_size <= length(data.DEBUG_old_stan_T0)
        fprintf('  Buffered state at iteration %d: %d\n', ...
            trans_idx + buffer_size, data.DEBUG_old_stan_T0(trans_idx + buffer_size));

        if data.DEBUG_old_stan_T0(trans_idx + buffer_size) == data.DEBUG_old_state(trans_idx)
            fprintf('  ✓ OK: Buffer delay matches T0_controller\n');
        else
            fprintf('  ⚠️  WARNING: Buffer delay does NOT match T0_controller\n');
        end
    end
end
fprintf('\n');

%% ========================================================================
%% SECTION 8: COMPARISON WITH T0=0 EXPECTATIONS
%% ========================================================================
fprintf('=== SECTION 8: COMPARISON WITH T0=0 ===\n\n');

fprintf('T0=0 results (from tests_rusults.txt):\n');
fprintf('  Final Q(50,50): 92.46\n');
fprintf('  Goal updates: 4134\n');
fprintf('  TD error trend: Decreasing ✓\n\n');

fprintf('T0=4 results (current analysis):\n');
fprintf('  Final Q(50,50): %.2f\n', goal_Q_values(end));
fprintf('  Goal updates: %d\n', n_goal_updates);
if std(second_half) < std(first_half)
    fprintf('  TD error trend: Decreasing ✓\n\n');
else
    fprintf('  TD error trend: NOT decreasing ⚠️\n\n');
end

fprintf('Key differences:\n');
fprintf('  Fewer goal updates: %d vs 4134 (%.1f%%)\n', ...
    n_goal_updates, 100*n_goal_updates/4134);
fprintf('  Lower final Q-value: %.2f vs 92.46 (%.1f%% gap)\n', ...
    goal_Q_values(end), 100*(92.46 - goal_Q_values(end))/92.46);

%% ========================================================================
%% SECTION 9: GENERATE DIAGNOSTIC PLOTS
%% ========================================================================
fprintf('=== SECTION 9: GENERATING DIAGNOSTIC PLOTS ===\n\n');

% Plot 1: Goal Q-value evolution
figure('Name', 'T0=4 Convergence Analysis');
subplot(3,2,1);
plot(goal_updates, goal_Q_values, 'b-', 'LineWidth', 1.5);
hold on;
yline(theoretical_max, 'r--', 'Theoretical Max', 'LineWidth', 1.5);
xlabel('Iteration');
ylabel('Q(50,50)');
title('Goal State Q-Value Evolution');
grid on;

% Plot 2: Global max Q over time
subplot(3,2,2);
plot(data.DEBUG_global_max_Q, 'Color', [0.8 0.4 0], 'LineWidth', 1);
hold on;
plot(data.DEBUG_goal_Q, 'b-', 'LineWidth', 1);
yline(theoretical_max, 'r--', 'LineWidth', 1.5);
xlabel('Iteration');
ylabel('Q-value');
title('Global Max vs Goal Q-Value');
legend('Global Max', 'Goal Q', 'Theoretical Max');
grid on;

% Plot 3: TD error over time
subplot(3,2,3);
plot(learning_idx, TD_errors, '.', 'Color', [0.5 0.5 0.5], 'MarkerSize', 2);
hold on;
% Add moving average
window = 100;
if length(TD_errors) > window
    TD_smooth = movmean(TD_errors, window);
    plot(learning_idx, TD_smooth, 'b-', 'LineWidth', 2);
end
yline(0, 'r--', 'LineWidth', 1);
xlabel('Iteration');
ylabel('TD Error');
title('TD Error Evolution');
grid on;

% Plot 4: Bootstrap values over time
subplot(3,2,4);
plot(learning_idx, bootstrap_values, '.', 'Color', [0.5 0.5 0.5], 'MarkerSize', 2);
hold on;
yline(gamma * theoretical_max, 'r--', 'Theoretical Limit', 'LineWidth', 1.5);
if length(bootstrap_values) > window
    bootstrap_smooth = movmean(bootstrap_values, window);
    plot(learning_idx, bootstrap_smooth, 'b-', 'LineWidth', 2);
end
xlabel('Iteration');
ylabel('Bootstrap Value');
title('Bootstrap Value Evolution');
grid on;

% Plot 5: Reward distribution over time
subplot(3,2,5);
R_values = data.DEBUG_R_buffered(learning_idx);
% Plot as running average
if length(R_values) > window
    R_smooth = movmean(R_values, window);
    plot(learning_idx, R_smooth, 'b-', 'LineWidth', 2);
end
xlabel('Iteration');
ylabel('Average R (moving window)');
title('Reward Distribution Over Time');
ylim([-0.1 1.1]);
grid on;

% Plot 6: State distribution histogram
subplot(3,2,6);
states_updated = data.DEBUG_old_stan_T0(learning_idx);
histogram(states_updated, 'BinEdges', 0.5:1:100.5, 'FaceColor', [0.3 0.5 0.8]);
hold on;
xline(goal_state, 'r--', 'Goal State', 'LineWidth', 2);
xlabel('State');
ylabel('Update Count');
title('State Update Distribution');
grid on;

fprintf('Plots generated.\n\n');

%% ========================================================================
%% FINAL DIAGNOSIS
%% ========================================================================
fprintf('=== FINAL DIAGNOSIS ===\n\n');

diagnosis = {};

% Check 1: Insufficient training
if goal_Q_values(end) < 0.9 * theoretical_max && late_mean > early_mean
    diagnosis{end+1} = 'LIKELY CAUSE: Insufficient training - Q-value still increasing';
    diagnosis{end+1} = sprintf('  Recommendation: Increase max_epoki to at least %d', ...
        ceil(50 * theoretical_max / goal_Q_values(end)));
end

% Check 2: Fewer goal updates
if n_goal_updates < 3000
    diagnosis{end+1} = sprintf('CONTRIBUTING FACTOR: Fewer goal state visits (%d vs 4134 for T0=0)', ...
        n_goal_updates);
    diagnosis{end+1} = '  Explanation: Dead time compensation delays learning, system spends less time at goal';
end

% Check 3: Bootstrap inflation
if sum(inflated) > 0
    diagnosis{end+1} = 'POTENTIAL BUG: Bootstrap value inflation detected';
    diagnosis{end+1} = '  Recommendation: Investigate state transitions leading to inflated bootstraps';
end

% Check 4: Goal state getting R=0
if goal_R0 > 0
    diagnosis{end+1} = 'CRITICAL BUG: Goal state receiving R=0';
    diagnosis{end+1} = '  Recommendation: Check reward logic for T0>0 case';
end

% Check 5: TD error not converging
if std(second_half) >= std(first_half)
    diagnosis{end+1} = 'CONCERN: TD error variance not decreasing';
    diagnosis{end+1} = '  Possible cause: Exploration rate too high or environment non-stationary';
end

if isempty(diagnosis)
    fprintf('✓ NO CRITICAL ISSUES DETECTED\n');
    fprintf('  T0=4 convergence is slower but progressing correctly\n');
    fprintf('  Recommendation: Increase training duration\n');
else
    for i = 1:length(diagnosis)
        fprintf('%s\n', diagnosis{i});
    end
end

fprintf('\n=== END ANALYSIS ===\n');
