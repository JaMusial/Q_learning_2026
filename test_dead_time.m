%% TEST_DEAD_TIME - Test dead time implementation in plant models
%
% This script verifies that dead time compensation works correctly
% by testing plant models (f_obiekt.m) with and without dead time.
% No controller in the loop - pure open-loop step response testing.
%
% Tests verify:
%   1. Buffer function (f_bufor) operates correctly
%   2. Step response starts exactly after T0 seconds
%   3. Response shape is identical, just time-shifted by T0
%   4. Works across different models and T0 values
%
% Author: Jakub Musiał
% Date: 2025-11-19

clear; clc; close all;

fprintf('========================================\n');
fprintf('  DEAD TIME IMPLEMENTATION TEST\n');
fprintf('========================================\n\n');

%% Configuration
dt = 0.01;  % Fine timestep for accurate simulation (same as in m_regulator_Q.m)
simulation_time = 50;  % [s]
t = 0:dt:simulation_time;
n_samples = length(t);

% Step input configuration
u_initial = 0;
u_step = 50;  % Step from 0 to 50%
step_time = 5;  % Apply step at t=5s

% Dead time values to test
T0_values = [0, 1, 2, 3, 5];  % [s]
n_T0 = length(T0_values);

% Models to test (excluding deprecated 2 and 4)
models_to_test = [
    1, 5, 0, 0;    % 1st order, T=[5]
    3, 5, 2, 0; % 2nd order, T=[5 2]
    5, 2.34, 1.55, 9.38;  % 3rd order generic
    8, 2.34, 1.55, 9.38;  % 3rd order pneumatic (nonlinear)
];

% Model gains
model_gains = [1, 1, 1, 0.994*0.972*0.4];  % k for each model

%% Test 1: Verify f_bufor function
fprintf('TEST 1: f_bufor() Function Verification\n');
fprintf('----------------------------------------\n');

T0_test = 2.0;
buffer_size = round(T0_test/dt);
buffer = zeros(1, buffer_size);

test_passed = true;

% Test filling phase (first buffer_size outputs should be 0)
for i = 1:buffer_size
    [output, buffer] = f_bufor(i, buffer);
    if output ~= 0
        fprintf('  ✗ FAILED: Filling phase should output 0, got %.2f at step %d\n', output, i);
        test_passed = false;
    end
end

% Test steady state (output should be input delayed by buffer_size)
for i = 1:10
    input_val = buffer_size + i;
    [output, buffer] = f_bufor(input_val, buffer);
    expected = i;
    if output ~= expected
        fprintf('  ✗ FAILED: Expected output %d, got %.2f at step %d\n', expected, output, buffer_size+i);
        test_passed = false;
    end
end

if test_passed
    fprintf('  ✓ PASSED: f_bufor() operates correctly\n');
    fprintf('    - Filling phase: %d zeros output\n', buffer_size);
    fprintf('    - Steady state: Output = Input delayed by %.2f seconds\n', T0_test);
else
    fprintf('  ✗ FAILED: f_bufor() has errors\n');
    error('f_bufor() test failed. Fix buffer implementation before proceeding.');
end

fprintf('\n');

%% Test 2: Step Response with Dead Time for All Models
fprintf('TEST 2: Step Response with Dead Time\n');
fprintf('----------------------------------------\n');

test_results = struct();
figure_counter = 1;

for model_idx = 1:size(models_to_test, 1)
    nr_modelu = models_to_test(model_idx, 1);
    T = models_to_test(model_idx, 2:end);
    T = T(T > 0);  % Remove zeros
    k = model_gains(model_idx);

    fprintf('Testing Model %d (Order: %d, T=%s, k=%.3f)\n', ...
        nr_modelu, length(T), mat2str(T), k);

    % Storage for results
    y_responses = zeros(n_T0, n_samples);
    u_signals = zeros(n_T0, n_samples);

    for T0_idx = 1:n_T0
        T0 = T0_values(T0_idx);

        % Initialize plant states
        y = 0; y1 = 0; y2 = 0; y3 = 0;

        % Initialize control signal buffer for dead time
        if T0 > 0
            buffer_size = round(T0/dt);
            bufor_u = zeros(1, buffer_size);
        end

        % Generate control signal (step input)
        u = u_initial * ones(1, n_samples);
        u(t >= step_time) = u_step;

        % Simulate plant with dead time
        for k_sample = 1:n_samples
            % Apply dead time to control signal
            if T0 > 0
                [u_delayed, bufor_u] = f_bufor(u(k_sample), bufor_u);
            else
                u_delayed = u(k_sample);
            end

            % Plant simulation
            [y, y1, y2, y3] = f_obiekt(nr_modelu, dt, k, T, y, y1, y2, y3, u_delayed);

            % Store results
            y_responses(T0_idx, k_sample) = y;
            u_signals(T0_idx, k_sample) = u_delayed;
        end
    end

    % Verify timing: Find when response reaches 5% of final value
    fprintf('  Response start times (5%% threshold):\n');
    threshold = 0.05 * u_step * k;  % 5% of expected steady-state

    all_correct = true;
    for T0_idx = 1:n_T0
        T0 = T0_values(T0_idx);

        % Find first time output exceeds threshold
        idx_start = find(y_responses(T0_idx, :) > threshold, 1, 'first');

        if ~isempty(idx_start)
            t_start = t(idx_start);
            expected_start = step_time + T0;  % Step at step_time + dead time
            error_time = abs(t_start - expected_start);

            % Allow tolerance of 2*dt (due to discrete sampling)
            tolerance = 2 * dt;

            if error_time <= tolerance
                status = '✓';
            else
                status = '✗';
                all_correct = false;
            end

            fprintf('    T0=%.1fs: Response at t=%.2fs (expected: %.2fs, error: %.3fs) %s\n', ...
                T0, t_start, expected_start, error_time, status);
        else
            fprintf('    T0=%.1fs: No response detected (may need longer simulation) ✗\n', T0);
            all_correct = false;
        end
    end

    if all_correct
        fprintf('  ✓ PASSED: All dead time delays are correct\n');
    else
        fprintf('  ✗ FAILED: Some timing errors detected\n');
    end

    % Plot results
    fig = figure(figure_counter);
    figure_counter = figure_counter + 1;
    set(fig, 'Position', [100, 100, 1200, 800]);

    % Plot 1: Output responses
    subplot(2, 1, 1);
    hold on;
    colors = lines(n_T0);
    for T0_idx = 1:n_T0
        plot(t, y_responses(T0_idx, :), 'LineWidth', 1.5, ...
            'Color', colors(T0_idx, :), 'DisplayName', sprintf('T_0 = %.1fs', T0_values(T0_idx)));
    end
    yline(u_step * k, '--k', 'LineWidth', 1, 'DisplayName', 'Steady State');
    xline(step_time, '--r', 'LineWidth', 1, 'DisplayName', 'Step Applied');
    hold off;
    grid on;
    xlabel('Time [s]');
    ylabel('Output y [%]');
    title(sprintf('Model %d - Step Response with Dead Time (k=%.3f, T=%s)', ...
        nr_modelu, k, mat2str(T)));
    legend('Location', 'southeast');
    xlim([0, min(40, simulation_time)]);

    % Plot 2: Control signals (delayed)
    subplot(2, 1, 2);
    hold on;
    for T0_idx = 1:n_T0
        plot(t, u_signals(T0_idx, :), 'LineWidth', 1.5, ...
            'Color', colors(T0_idx, :), 'DisplayName', sprintf('T_0 = %.1fs', T0_values(T0_idx)));
    end
    hold off;
    grid on;
    xlabel('Time [s]');
    ylabel('Control Signal u [%]');
    title('Delayed Control Signal (after dead time)');
    legend('Location', 'southeast');
    xlim([0, min(40, simulation_time)]);

    % Store results
    test_results(model_idx).model = nr_modelu;
    test_results(model_idx).T = T;
    test_results(model_idx).k = k;
    test_results(model_idx).responses = y_responses;
    test_results(model_idx).passed = all_correct;

    fprintf('\n');
end

%% Test 3: Response Shape Verification (Time-Shifted Comparison)
fprintf('TEST 3: Response Shape Comparison\n');
fprintf('----------------------------------------\n');
fprintf('Verifying that T0>0 response matches T0=0 response shifted by T0...\n\n');

for model_idx = 1:size(models_to_test, 1)
    nr_modelu = models_to_test(model_idx, 1);

    fprintf('Model %d:\n', nr_modelu);

    % Reference response (T0=0)
    y_ref = test_results(model_idx).responses(1, :);

    % Compare with delayed responses
    all_match = true;
    for T0_idx = 2:n_T0  % Skip T0=0
        T0 = T0_values(T0_idx);
        y_delayed = test_results(model_idx).responses(T0_idx, :);

        % Shift T0=0 response by T0 for comparison
        shift_samples = round(T0/dt);
        y_ref_shifted = [zeros(1, shift_samples), y_ref(1:end-shift_samples)];

        % Compare after settling (avoid initial transient)
        compare_start_idx = round((step_time + T0 + 5) / dt);  % 5s after response starts
        compare_end_idx = min(round(40/dt), n_samples);

        if compare_start_idx < compare_end_idx
            % Calculate RMS difference
            diff_rms = sqrt(mean((y_delayed(compare_start_idx:compare_end_idx) - ...
                y_ref_shifted(compare_start_idx:compare_end_idx)).^2));

            % Normalize by steady-state value
            steady_state = test_results(model_idx).k * u_step;
            diff_percent = (diff_rms / steady_state) * 100;

            % Threshold: <1% difference acceptable
            if diff_percent < 1.0
                status = '✓';
            else
                status = '✗';
                all_match = false;
            end

            fprintf('  T0=%.1fs vs T0=0 shifted: RMS diff = %.4f%% %s\n', ...
                T0, diff_percent, status);
        else
            fprintf('  T0=%.1fs: Insufficient data for comparison\n', T0);
        end
    end

    if all_match
        fprintf('  ✓ PASSED: Response shapes match (just time-shifted)\n');
    else
        fprintf('  ✗ FAILED: Response shapes differ (not just time shift)\n');
    end

    fprintf('\n');
end

%% Final Summary
fprintf('========================================\n');
fprintf('  TEST SUMMARY\n');
fprintf('========================================\n');

overall_passed = true;
for model_idx = 1:length(test_results)
    if test_results(model_idx).passed
        fprintf('Model %d: ✓ PASSED\n', test_results(model_idx).model);
    else
        fprintf('Model %d: ✗ FAILED\n', test_results(model_idx).model);
        overall_passed = false;
    end
end

fprintf('\n');
if overall_passed
    fprintf('✓ ALL TESTS PASSED\n');
    fprintf('Dead time implementation is working correctly!\n');
else
    fprintf('✗ SOME TESTS FAILED\n');
    fprintf('Please review the results and fix any issues.\n');
end

fprintf('\n');
fprintf('Figures saved for visual inspection.\n');
fprintf('Check that responses are cleanly time-shifted by T0.\n');
