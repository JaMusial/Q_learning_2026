%% Quick Test: Verify Projection Function Fix
% This script runs a short experiment to verify the sign fix works
% Expected: Controller should reach setpoint after learning

clear all
close all
clc

fprintf('=== TESTING PROJECTION FUNCTION FIX ===\n\n');

%% Verify configuration
fprintf('Checking config.m settings...\n');
config;

% Verify projection is enabled
if f_rzutujaca_on ~= 1
    fprintf('⚠️  WARNING: f_rzutujaca_on = %d, should be 1\n', f_rzutujaca_on);
    fprintf('   Edit config.m and set: f_rzutujaca_on = 1\n');
    error('Projection function must be enabled for this test');
end

fprintf('✓ Projection function enabled (f_rzutujaca_on = 1)\n');
fprintf('  Te_bazowe = %g\n', Te_bazowe);
fprintf('  Ti = %g\n', Ti);
fprintf('  Te-Ti mismatch: %g (coefficient: %g)\n\n', ...
        abs(Te_bazowe - Ti), abs(1/Te_bazowe - 1/Ti));

%% Run short training
fprintf('Running 100 epoch training...\n');
fprintf('(This will take ~3-5 minutes)\n\n');

% Save original max_epoki
original_max_epoki = max_epoki;

% Override for quick test
max_epoki = 100;

% Run main training
tic
main
training_time = toc;

fprintf('\n✓ Training completed in %.1f seconds\n\n', training_time);

%% Analyze results

fprintf('=== VERIFICATION RESULTS ===\n\n');

% Check if verification was run
if exist('logi', 'var') && isfield(logi, 'Q_y')

    % Phase 1: Setpoint step response
    total_samples = length(logi.Q_y);
    phase1_end = round(total_samples / 3);

    % Take last 30% of phase 1 as steady-state
    ss_start = round(0.7 * phase1_end);
    ss_end = phase1_end;

    % Calculate metrics
    y_ss = logi.Q_y(ss_start:ss_end);
    e_ss = logi.Q_e(ss_start:ss_end);
    SP_ss = logi.Q_SP(ss_start);

    y_mean = mean(y_ss);
    e_mean = mean(e_ss);
    y_std = std(y_ss);

    fprintf('Phase 1 Steady-State Performance:\n');
    fprintf('  Setpoint:          %6.2f%%\n', SP_ss);
    fprintf('  Output (mean):     %6.2f%% (target: ~%.0f%%)\n', y_mean, SP_ss);
    fprintf('  Output (std):      %6.3f%%\n', y_std);
    fprintf('  Error (mean):      %6.2f%% (target: ~0%%)\n', e_mean);
    fprintf('\n');

    % Check success criteria
    success = true;

    % Criterion 1: Output within 10% of setpoint
    output_error = abs(y_mean - SP_ss);
    if output_error < 10
        fprintf('✓ Output tracking: PASS (error: %.2f%%)\n', output_error);
    else
        fprintf('✗ Output tracking: FAIL (error: %.2f%%, should be <10%%)\n', output_error);
        success = false;
    end

    % Criterion 2: Steady-state error < 2%
    if abs(e_mean) < 2.0
        fprintf('✓ Steady-state error: PASS (%.2f%%)\n', abs(e_mean));
    else
        fprintf('✗ Steady-state error: FAIL (%.2f%%, should be <2%%)\n', abs(e_mean));
        success = false;
    end

    % Criterion 3: Multiple states visited (no limit cycle)
    states_visited = logi.Q_stan_nr(ss_start:ss_end);
    unique_states = length(unique(states_visited));
    if unique_states > 3
        fprintf('✓ State diversity: PASS (%d unique states)\n', unique_states);
    else
        fprintf('⚠️  State diversity: MARGINAL (%d unique states, may still be converging)\n', unique_states);
        if unique_states <= 2
            fprintf('   WARNING: Limit cycle behavior detected!\n');
            success = false;
        end
    end

    % Criterion 4: Control direction check
    u_inc = logi.Q_u_increment(ss_start:ss_end);
    u_inc_mean = mean(u_inc);

    % When output below setpoint, need positive increments
    if SP_ss - y_mean > 1  % Significant deficit
        if u_inc_mean > 0
            fprintf('✓ Control direction: CORRECT (mean increment: %+.4f)\n', u_inc_mean);
        else
            fprintf('✗ Control direction: WRONG (mean increment: %+.4f, should be positive)\n', u_inc_mean);
            success = false;
        end
    else
        fprintf('✓ Control direction: Near setpoint (mean increment: %+.4f)\n', u_inc_mean);
    end

    fprintf('\n');

    % Overall verdict
    if success
        fprintf('========================================\n');
        fprintf('✓✓✓ FIX SUCCESSFUL ✓✓✓\n');
        fprintf('========================================\n');
        fprintf('Projection function now works correctly.\n');
        fprintf('Controller reaches setpoint and regulates properly.\n');
        fprintf('\nRecommended: Run full training (1000 epochs) for complete evaluation.\n');
    else
        fprintf('========================================\n');
        fprintf('⚠️  ISSUES DETECTED ⚠️\n');
        fprintf('========================================\n');
        fprintf('Fix may be incomplete or requires longer training.\n');
        fprintf('Check criteria above for specific failures.\n');
    end

    fprintf('\n');

    % Show sample sequence
    fprintf('Sample control sequence (first 10 steady-state samples):\n');
    fprintf('  #  | State | Action | Error  | Projection | Net Action | u_inc\n');
    fprintf('-----|-------|--------|--------|------------|------------|---------\n');
    for i = 1:min(10, length(states_visited))
        idx = ss_start + i - 1;
        fprintf(' %3d | %5.0f | %6.0f | %6.2f | %10.3f | %10.3f | %7.4f\n', ...
                i, ...
                logi.Q_stan_nr(idx), ...
                logi.Q_akcja_nr(idx), ...
                logi.Q_e(idx), ...
                logi.Q_funkcja_rzut(idx), ...
                logi.Q_akcja_value(idx), ...
                logi.Q_u_increment(idx));
    end

else
    fprintf('⚠️  No verification data available\n');
    fprintf('   Make sure poj_iteracja_uczenia = 0 in config.m\n');
end

fprintf('\n=== TEST COMPLETE ===\n');

%% Cleanup
% Restore original max_epoki if needed
% (Not necessary since config.m will reload on next run)
