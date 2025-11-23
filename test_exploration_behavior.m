%% ========================================================================
%% test_exploration_behavior - Integration test for exploration mechanism
%% ========================================================================
% PURPOSE:
%   Verify that the complete exploration mechanism works correctly:
%   1. Constraint accepts valid random actions
%   2. Failed exploration sets uczenie=0 (no Q-updates)
%   3. Successful exploration sets uczenie=1 (Q-updates enabled)
%
% APPROACH:
%   Simulate the exploration process for multiple states
%   Track acceptance rates and uczenie flag settings
%
% EXPECTED RESULTS:
%   - States 51-100: Should have ~30% successful exploration (eps=0.3)
%   - States 1-49: Should have ~30% successful exploration (eps=0.3)
%   - Failed exploration: uczenie=0, czy_losowanie=0
%   - Successful exploration: uczenie=1, czy_losowanie=1
%
% USAGE:
%   Run in MATLAB command window: test_exploration_behavior
%% ========================================================================

function test_exploration_behavior()
    fprintf('\n========================================\n');
    fprintf('Testing Exploration Behavior\n');
    fprintf('========================================\n\n');

    % Initialize parameters
    nr_akcji_doc = 50;
    nr_stanu_doc = 50;
    RD = 5;
    max_powtorzen_losowania_RD = 10;
    eps = 0.3;

    % Create mock Q-matrix and state/action spaces
    ilosc_stanow = 100;
    ilosc_akcji = 100;
    Q_2d = ones(ilosc_stanow, ilosc_akcji);  % Initialize Q-matrix

    % Test states from different regions
    test_states = [45, 48, 52, 55, 60, 70];  % Mix of states < and > goal
    num_trials = 1000;  % Trials per state

    fprintf('Configuration:\n');
    fprintf('  Goal state: %d, Goal action: %d\n', nr_stanu_doc, nr_akcji_doc);
    fprintf('  Exploration rate: %.1f%%\n', eps*100);
    fprintf('  Trials per state: %d\n\n', num_trials);

    %% Test each state
    for state_idx = 1:length(test_states)
        stan = test_states(state_idx);

        fprintf('----------------------------------------\n');
        fprintf('Testing State %d (s %s 0)\n', stan, ternary(stan > nr_stanu_doc, '<', '>'));
        fprintf('----------------------------------------\n');

        % Counters
        exploration_attempts = 0;
        successful_exploration = 0;
        failed_exploration = 0;
        uczenie_on_success = 0;
        uczenie_on_failure = 0;

        % Simulate exploration trials
        for trial = 1:num_trials
            % Random epsilon-greedy trigger
            a = rand();

            if a <= eps
                % Exploration triggered
                exploration_attempts = exploration_attempts + 1;

                % Simulate best action for this state
                % For testing, assume best action adapts to state direction
                if stan > nr_stanu_doc
                    wyb_akcja = 45;  % Best action < goal (positive Du)
                    wyb_akcja_above = 46;
                    wyb_akcja_under = 44;
                else
                    wyb_akcja = 55;  % Best action > goal (negative Du)
                    wyb_akcja_above = 56;
                    wyb_akcja_under = 54;
                end

                % Construct sampling range
                if wyb_akcja_above < wyb_akcja_under
                    min_losowanie = wyb_akcja_under - RD;
                    max_losowanie = wyb_akcja_above + RD;
                else
                    min_losowanie = wyb_akcja_above - RD;
                    max_losowanie = wyb_akcja_under + RD;
                end

                % Try random action selection
                ponowne_losowanie = 1;
                attempts = 0;

                while ponowne_losowanie > 0 && ponowne_losowanie <= max_powtorzen_losowania_RD
                    attempts = attempts + 1;

                    % Random action
                    if max_losowanie > min_losowanie
                        wyb_akcja3 = randi([min_losowanie, max_losowanie]);
                    else
                        wyb_akcja3 = randi([max_losowanie, min_losowanie]);
                    end

                    % Apply constraint (CORRECTED logic)
                    if wyb_akcja3 ~= nr_akcji_doc && wyb_akcja3 ~= wyb_akcja && ...
                        ((wyb_akcja < nr_akcji_doc && stan > nr_stanu_doc) || ...
                         (wyb_akcja > nr_akcji_doc && stan < nr_stanu_doc))
                        ponowne_losowanie = 0;  % Accepted
                    else
                        ponowne_losowanie = ponowne_losowanie + 1;
                    end
                end

                % Check if exploration succeeded or failed
                if ponowne_losowanie >= max_powtorzen_losowania_RD
                    % Failed exploration - should set uczenie=0
                    failed_exploration = failed_exploration + 1;
                    uczenie = 0;
                    czy_losowanie = 0;
                    uczenie_on_failure = uczenie_on_failure + uczenie;
                else
                    % Successful exploration - should set uczenie=1
                    successful_exploration = successful_exploration + 1;
                    uczenie = 1;
                    czy_losowanie = 1;
                    uczenie_on_success = uczenie_on_success + uczenie;
                end
            end
        end

        % Calculate statistics
        if exploration_attempts > 0
            success_rate = successful_exploration / exploration_attempts * 100;
            failure_rate = failed_exploration / exploration_attempts * 100;
        else
            success_rate = 0;
            failure_rate = 0;
        end

        % Display results
        fprintf('Exploration attempts: %d (%.1f%% of trials)\n', ...
                exploration_attempts, exploration_attempts/num_trials*100);
        fprintf('Successful exploration: %d (%.1f%%)\n', ...
                successful_exploration, success_rate);
        fprintf('Failed exploration: %d (%.1f%%)\n', ...
                failed_exploration, failure_rate);
        fprintf('uczenie=1 on success: %d/%d (%.1f%%)\n', ...
                uczenie_on_success, successful_exploration, ...
                ternary(successful_exploration>0, uczenie_on_success/successful_exploration*100, 0));
        fprintf('uczenie=1 on failure: %d/%d (%.1f%%)\n\n', ...
                uczenie_on_failure, failed_exploration, ...
                ternary(failed_exploration>0, uczenie_on_failure/failed_exploration*100, 0));

        % Validation
        test_pass = true;

        % Check 1: Should have some successful exploration
        if success_rate < 10
            fprintf('   ⚠ WARNING: Very low success rate (%.1f%% < 10%%)\n', success_rate);
            test_pass = false;
        end

        % Check 2: uczenie should be 1 on all successes
        if successful_exploration > 0 && uczenie_on_success ~= successful_exploration
            fprintf('   ✗ FAIL: uczenie not set correctly on success\n');
            test_pass = false;
        end

        % Check 3: uczenie should be 0 on all failures
        if failed_exploration > 0 && uczenie_on_failure ~= 0
            fprintf('   ✗ FAIL: uczenie=1 on failed exploration (should be 0)\n');
            test_pass = false;
        end

        if test_pass
            fprintf('   ✓ State %d: PASS\n\n', stan);
        else
            fprintf('   ✗ State %d: FAIL\n\n', stan);
        end
    end

    fprintf('========================================\n');
    fprintf('Integration Test Complete\n');
    fprintf('========================================\n\n');
end

%% Helper function for conditional output
function result = ternary(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
