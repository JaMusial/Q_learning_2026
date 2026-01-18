%% analyze_debug_logs.m
% Comprehensive analysis of Q-learning debug logs
%
% PURPOSE: Analyze logi.DEBUG_* fields to identify Q-learning issues
%
% REQUIREMENTS:
%   - debug_logging = 1 in config.m
%   - Run after training (logi structure must exist in workspace)
%
% USAGE:
%   main  % Run training with debug_logging enabled
%   analyze_debug_logs  % Analyze the debug logs

if ~exist('logi', 'var') || ~isfield(logi, 'DEBUG_old_state')
    error('Debug logs not found! Set debug_logging=1 in config.m and re-run training.');
end

fprintf('\n=== Q-LEARNING DEBUG LOG ANALYSIS ===\n\n');

%% ========================================================================
%% 1. Configuration Summary
%% ========================================================================
fprintf('1. CONFIGURATION\n');
fprintf('   Total iterations logged: %d\n', length(logi.Q_t));
fprintf('   T0_controller: %s\n', num2str(T0_controller));
fprintf('   T0 (plant dead time): %s\n', num2str(T0));
fprintf('   Goal state: %d, Goal action: %d\n', nr_stanu_doc, nr_akcji_doc);
fprintf('   Learning rate (alfa): %.3f\n', alfa);
fprintf('   Discount factor (gamma): %.3f\n', gamma);
fprintf('   Theoretical max Q: %.2f\n\n', 1/(1-gamma));

%% ========================================================================
%% 2. State-Action Pairing Validation
%% ========================================================================
fprintf('2. STATE-ACTION PAIRING VALIDATION\n');

% Check if old_state matches old_stan_T0 (for T0=0)
if T0_controller == 0
    % For T0=0, old_stan_T0 should equal old_state
    mismatches = sum(logi.DEBUG_old_stan_T0 ~= logi.DEBUG_old_state & logi.DEBUG_old_state > 0);
    if mismatches > 0
        fprintf('   ❌ PROBLEM: %d cases where old_stan_T0 ≠ old_state (T0=0)\n', mismatches);
        fprintf('      This indicates state buffering bug\n');
    else
        fprintf('   ✓ OK: old_stan_T0 correctly matches old_state\n');
    end

    % Check if wyb_akcja_T0 matches old_action
    action_mismatches = sum(logi.DEBUG_wyb_akcja_T0 ~= logi.DEBUG_old_action & logi.DEBUG_old_action > 0);
    if action_mismatches > 0
        fprintf('   ❌ PROBLEM: %d cases where wyb_akcja_T0 ≠ old_action (T0=0)\n', action_mismatches);
        fprintf('      This indicates action buffering bug\n');
    else
        fprintf('   ✓ OK: wyb_akcja_T0 correctly matches old_action\n');
    end

    % Check if R_buffered matches old_R
    R_mismatches = sum(abs(logi.DEBUG_R_buffered - logi.DEBUG_old_R) > 0.01 & logi.DEBUG_old_R >= 0);
    if R_mismatches > 0
        fprintf('   ❌ PROBLEM: %d cases where R_buffered ≠ old_R (T0=0)\n', R_mismatches);
        fprintf('      This indicates reward buffering bug (CRITICAL!)\n');
    else
        fprintf('   ✓ OK: R_buffered correctly matches old_R\n');
    end
else
    fprintf('   T0_controller > 0: Buffering logic active\n');
    fprintf('   Buffer size: %d iterations\n', round(T0_controller / dt));
end

fprintf('\n');

%% ========================================================================
%% 3. Goal State Q-Value Analysis
%% ========================================================================
fprintf('3. GOAL STATE Q-VALUE EVOLUTION\n');

% Find iterations where goal state Q-value was updated
goal_updates = find(logi.DEBUG_is_updating_goal == 1);
if ~isempty(goal_updates)
    fprintf('   Total goal state updates: %d\n', length(goal_updates));

    % Evolution of Q(goal, goal_action)
    final_goal_Q = logi.DEBUG_goal_Q(end);
    theoretical_max = 1 / (1 - gamma);
    fprintf('   Final Q(goal, goal_action): %.4f\n', final_goal_Q);
    fprintf('   Theoretical maximum: %.4f\n', theoretical_max);
    fprintf('   Difference: %.4f (%.1f%%)\n', theoretical_max - final_goal_Q, ...
        100*(theoretical_max - final_goal_Q)/theoretical_max);

    if final_goal_Q < theoretical_max - 5
        fprintf('   ⚠️  WARNING: Goal Q-value significantly below theoretical max\n');
    else
        fprintf('   ✓ OK: Goal Q-value converged near theoretical maximum\n');
    end

    % Check rewards during goal state updates
    goal_update_rewards = logi.DEBUG_R_buffered(goal_updates);
    R_zero_count = sum(goal_update_rewards == 0);
    R_one_count = sum(goal_update_rewards == 1);

    fprintf('\n   Goal state update rewards:\n');
    fprintf('      R=1: %d times (%.1f%%)\n', R_one_count, 100*R_one_count/length(goal_updates));
    fprintf('      R=0: %d times (%.1f%%)\n', R_zero_count, 100*R_zero_count/length(goal_updates));

    if R_zero_count > R_one_count
        fprintf('      ❌ PROBLEM: Goal state getting R=0 more often than R=1!\n');
        fprintf('         This indicates reward temporal mismatch bug\n');
    else
        fprintf('      ✓ OK: Goal state predominantly receives R=1\n');
    end
else
    fprintf('   ⚠️  No goal state updates found in logs\n');
end

fprintf('\n');

%% ========================================================================
%% 4. Global Maximum Tracking
%% ========================================================================
fprintf('4. GLOBAL MAXIMUM Q-VALUE TRACKING\n');

% Track where global maximum is located over time
final_max_state = logi.DEBUG_global_max_state(end);
final_max_action = logi.DEBUG_global_max_action(end);
final_max_Q = logi.DEBUG_global_max_Q(end);

fprintf('   Final global maximum:\n');
fprintf('      Q(%d, %d) = %.4f\n', final_max_state, final_max_action, final_max_Q);

if final_max_state == nr_stanu_doc && final_max_action == nr_akcji_doc
    fprintf('      ✓ OK: Global maximum is at goal state\n');
else
    fprintf('      ❌ PROBLEM: Global maximum NOT at goal state!\n');
    fprintf('         Expected: Q(%d, %d)\n', nr_stanu_doc, nr_akcji_doc);
    fprintf('         Actual: Q(%d, %d)\n', final_max_state, final_max_action);
end

% Check how often maximum moved away from goal state
sample_interval = max(1, floor(length(logi.Q_t) / 100));  % Sample 100 points
sample_points = 1:sample_interval:length(logi.Q_t);
max_not_at_goal = sum(logi.DEBUG_global_max_state(sample_points) ~= nr_stanu_doc | ...
                      logi.DEBUG_global_max_action(sample_points) ~= nr_akcji_doc);
fprintf('   Sampled %d points: maximum NOT at goal state in %d cases (%.1f%%)\n', ...
    length(sample_points), max_not_at_goal, 100*max_not_at_goal/length(sample_points));

fprintf('\n');

%% ========================================================================
%% 5. Reward Distribution Analysis
%% ========================================================================
fprintf('5. REWARD DISTRIBUTION\n');

% Count R=1 occurrences
R_one_indices = find(logi.DEBUG_R_buffered == 1);
fprintf('   Total R=1 rewards: %d (%.2f%% of iterations)\n', ...
    length(R_one_indices), 100*length(R_one_indices)/length(logi.Q_t));

if ~isempty(R_one_indices)
    % Which states received R=1?
    states_with_R1 = unique(logi.DEBUG_old_stan_T0(R_one_indices));
    fprintf('   States that received R=1: [');
    fprintf('%d ', states_with_R1);
    fprintf(']\n');

    % Check if only goal state should receive R=1
    non_goal_R1 = sum(logi.DEBUG_old_stan_T0(R_one_indices) ~= nr_stanu_doc);
    if non_goal_R1 > 0
        fprintf('   ⚠️  WARNING: R=1 given to non-goal states %d times\n', non_goal_R1);
        fprintf('      This may be correct if states transition TO goal state\n');
    else
        fprintf('   ✓ OK: R=1 only given when in goal state\n');
    end

    % Check invalid rewards (not 0 or 1)
    invalid_rewards = sum(logi.DEBUG_R_buffered ~= 0 & logi.DEBUG_R_buffered ~= 1);
    if invalid_rewards > 0
        fprintf('   ❌ PROBLEM: %d cases with invalid R (not 0 or 1)\n', invalid_rewards);
    end
end

fprintf('\n');

%% ========================================================================
%% 6. Bootstrap Value Analysis
%% ========================================================================
fprintf('6. BOOTSTRAP VALUE (γ·max(Q(s'',·))) ANALYSIS\n');

% Find non-zero bootstrap values
non_zero_bootstrap = logi.DEBUG_bootstrap(logi.DEBUG_bootstrap > 0.01);
if ~isempty(non_zero_bootstrap)
    fprintf('   Mean bootstrap value: %.4f\n', mean(non_zero_bootstrap));
    fprintf('   Max bootstrap value: %.4f\n', max(non_zero_bootstrap));
    fprintf('   Min bootstrap value: %.4f\n', min(non_zero_bootstrap));

    % Check for bootstrap values exceeding theoretical maximum
    theoretical_max_bootstrap = gamma * theoretical_max;
    excessive_bootstrap = sum(logi.DEBUG_bootstrap > theoretical_max_bootstrap + 1);
    if excessive_bootstrap > 0
        fprintf('   ❌ PROBLEM: %d cases where bootstrap > γ·theoretical_max (%.2f)\n', ...
            excessive_bootstrap, theoretical_max_bootstrap);
    else
        fprintf('   ✓ OK: No bootstrap values exceed theoretical bounds\n');
    end
end

fprintf('\n');

%% ========================================================================
%% 7. Q-Value Update Statistics
%% ========================================================================
fprintf('7. Q-VALUE UPDATE STATISTICS\n');

% Find updates where Q-value changed
Q_changed = find(abs(logi.DEBUG_Q_new_value - logi.DEBUG_Q_old_value) > 1e-6);
fprintf('   Total Q-updates: %d\n', length(Q_changed));

if ~isempty(Q_changed)
    % Calculate update magnitudes
    update_deltas = logi.DEBUG_Q_new_value(Q_changed) - logi.DEBUG_Q_old_value(Q_changed);

    fprintf('   Mean Q-update magnitude: %.6f\n', mean(abs(update_deltas)));
    fprintf('   Max Q-increase: %.6f\n', max(update_deltas));
    fprintf('   Max Q-decrease: %.6f\n', min(update_deltas));

    % Check for updates that violated theoretical bounds
    exceeded_max = sum(logi.DEBUG_Q_new_value > theoretical_max + 1);
    if exceeded_max > 0
        fprintf('   ❌ PROBLEM: %d Q-values exceed theoretical maximum!\n', exceeded_max);
        % Find first violation
        first_violation = find(logi.DEBUG_Q_new_value > theoretical_max + 1, 1);
        fprintf('      First violation at iteration %d:\n', first_violation);
        fprintf('         Q(%d, %d) = %.4f\n', logi.DEBUG_old_stan_T0(first_violation), ...
            logi.DEBUG_wyb_akcja_T0(first_violation), logi.DEBUG_Q_new_value(first_violation));
    else
        fprintf('   ✓ OK: All Q-values within theoretical bounds\n');
    end
end

fprintf('\n');

%% ========================================================================
%% 8. TD Error Analysis
%% ========================================================================
fprintf('8. TEMPORAL DIFFERENCE (TD) ERROR ANALYSIS\n');

% Find non-zero TD errors
non_zero_TD = logi.DEBUG_TD_error(abs(logi.DEBUG_TD_error) > 1e-6);
if ~isempty(non_zero_TD)
    fprintf('   Mean TD error: %.6f\n', mean(non_zero_TD));
    fprintf('   TD error std dev: %.6f\n', std(non_zero_TD));
    fprintf('   Max positive TD error: %.6f\n', max(non_zero_TD));
    fprintf('   Max negative TD error: %.6f\n', min(non_zero_TD));

    % TD error should decrease over time (convergence)
    first_half = non_zero_TD(1:floor(end/2));
    second_half = non_zero_TD(floor(end/2)+1:end);
    fprintf('   TD error first half: mean=%.6f, std=%.6f\n', mean(abs(first_half)), std(abs(first_half)));
    fprintf('   TD error second half: mean=%.6f, std=%.6f\n', mean(abs(second_half)), std(abs(second_half)));

    if mean(abs(second_half)) < mean(abs(first_half))
        fprintf('   ✓ OK: TD error decreasing (learning converging)\n');
    else
        fprintf('   ⚠️  WARNING: TD error not decreasing (poor convergence)\n');
    end
end

fprintf('\n');

%% ========================================================================
%% 9. Visualization (Optional)
%% ========================================================================
if exist('generate_debug_plots', 'var') && generate_debug_plots == 1
    fprintf('9. GENERATING DEBUG PLOTS\n\n');

    figure('Name', 'Q-Learning Debug Analysis', 'Position', [100 100 1200 800]);

    % Plot 1: Goal Q-value evolution
    subplot(3, 3, 1);
    plot(logi.Q_t, logi.DEBUG_goal_Q, 'b-', 'LineWidth', 1.5);
    hold on;
    yline(theoretical_max, 'r--', 'Theoretical Max', 'LineWidth', 2);
    xlabel('Time [s]');
    ylabel('Q(goal, goal\_action)');
    title('Goal State Q-Value Evolution');
    grid on;

    % Plot 2: Global max Q-value
    subplot(3, 3, 2);
    plot(logi.Q_t, logi.DEBUG_global_max_Q, 'g-', 'LineWidth', 1.5);
    hold on;
    plot(logi.Q_t, logi.DEBUG_goal_Q, 'b--', 'LineWidth', 1);
    yline(theoretical_max, 'r--', 'LineWidth', 1);
    xlabel('Time [s]');
    ylabel('Q-value');
    title('Global Max vs Goal Q-value');
    legend('Global Max', 'Goal Q', 'Theoretical Max', 'Location', 'best');
    grid on;

    % Plot 3: Reward distribution over time
    subplot(3, 3, 3);
    plot(logi.Q_t, logi.DEBUG_R_buffered, 'r.', 'MarkerSize', 2);
    xlabel('Time [s]');
    ylabel('R\_buffered');
    title('Reward Distribution');
    ylim([-0.1 1.1]);
    grid on;

    % Plot 4: Bootstrap values
    subplot(3, 3, 4);
    plot(logi.Q_t, logi.DEBUG_bootstrap, 'c-', 'LineWidth', 0.5);
    hold on;
    yline(theoretical_max_bootstrap, 'r--', 'γ·Theoretical Max', 'LineWidth', 2);
    xlabel('Time [s]');
    ylabel('γ·max(Q(s'',·))');
    title('Bootstrap Value Evolution');
    grid on;

    % Plot 5: TD error
    subplot(3, 3, 5);
    plot(logi.Q_t, logi.DEBUG_TD_error, 'k-', 'LineWidth', 0.5);
    xlabel('Time [s]');
    ylabel('TD Error');
    title('Temporal Difference Error');
    grid on;

    % Plot 6: Q-update magnitudes
    subplot(3, 3, 6);
    Q_deltas = logi.DEBUG_Q_new_value - logi.DEBUG_Q_old_value;
    plot(logi.Q_t, Q_deltas, 'm-', 'LineWidth', 0.5);
    xlabel('Time [s]');
    ylabel('ΔQ');
    title('Q-Value Update Magnitudes');
    grid on;

    % Plot 7: State tracking
    subplot(3, 3, 7);
    plot(logi.Q_t, logi.Q_stan_nr, 'b-', 'LineWidth', 0.5);
    hold on;
    plot(logi.Q_t, logi.DEBUG_old_stan_T0, 'r--', 'LineWidth', 0.5);
    yline(nr_stanu_doc, 'g--', 'Goal State', 'LineWidth', 2);
    xlabel('Time [s]');
    ylabel('State');
    title('Current vs Update State');
    legend('Current State', 'Update State', 'Goal', 'Location', 'best');
    grid on;

    % Plot 8: Global max location
    subplot(3, 3, 8);
    plot(logi.Q_t, logi.DEBUG_global_max_state, 'b.', 'MarkerSize', 2);
    hold on;
    yline(nr_stanu_doc, 'r--', 'Goal State', 'LineWidth', 2);
    xlabel('Time [s]');
    ylabel('State with Max Q');
    title('Global Maximum Location');
    grid on;

    % Plot 9: Goal state activity
    subplot(3, 3, 9);
    plot(logi.Q_t, logi.DEBUG_is_goal_state, 'b-', 'LineWidth', 1);
    hold on;
    plot(logi.Q_t, logi.DEBUG_is_updating_goal, 'r-', 'LineWidth', 1);
    xlabel('Time [s]');
    ylabel('Flag');
    title('Goal State Activity');
    legend('In Goal State', 'Updating Goal', 'Location', 'best');
    grid on;

    fprintf('   Debug plots generated\n\n');
end

fprintf('=== END DEBUG LOG ANALYSIS ===\n\n');
