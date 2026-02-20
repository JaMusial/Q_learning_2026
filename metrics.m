%% metrics.m - Performance Metrics Calculator
%
% PURPOSE:
%   Calculates IAE, maximum overshoot, and maximum control increment
%   for multiple experiment files across different T0 and compensation levels.
%   Reimplements metric calculations for educational purposes.
%
% OUTPUTS:
%   - Console table: Performance metrics for all configurations
%   - CSV file: Exported metrics for further analysis
%
% INPUTS (none - standalone script):
%   Configure T0_wek and file paths below.
%
% NOTES:
%   - Processes PI, Q before learning, and Q after learning
%   - Calculates metrics for 3 phases: SP change, disturbance on, disturbance off
%   - Uses trapezoidal integration for IAE calculation

%% =====================================================================
%% CONFIGURATION
%% =====================================================================

clc;
close all;

% T0 values to process
T0_wek = [0.5, 2, 4];

fprintf('==========================================================\n');
fprintf('PERFORMANCE METRICS CALCULATOR\n');
fprintf('==========================================================\n\n');

%% =====================================================================
%% DATA STORAGE INITIALIZATION
%% =====================================================================

% Storage structure: (controller, scenario, T0_index, compensation_level)
% Controllers: 1=PI, 2=Q before learning, 3=Q after learning
% Scenarios: 1=SP change, 2=disturbance
% Compensation: 1=Full, 2=Under, 3=Over

NUM_CONTROLLERS = 3;
NUM_SCENARIOS = 2;  % Only using phases 1 and 2 (SP change and disturbance)
NUM_T0 = length(T0_wek);
NUM_COMP = 3;

% Metric storage arrays
IAE_storage = zeros(NUM_CONTROLLERS, NUM_SCENARIOS, NUM_T0, NUM_COMP);
max_overshoot_storage = zeros(NUM_CONTROLLERS, NUM_SCENARIOS, NUM_T0, NUM_COMP);
max_delta_u_storage = zeros(NUM_CONTROLLERS, NUM_SCENARIOS, NUM_T0, NUM_COMP);

% Labels for output
controller_labels = {'PI', 'Q before learning', 'Q after learning'};
scenario_labels = {'SP change', 'Disturbance'};
T0_labels = arrayfun(@(x) sprintf('T0=%.1f', x), T0_wek, 'UniformOutput', false);
comp_labels = {'Full', 'Under', 'Over'};  % Order: Full (T0c=T0), Under (T0c<T0), Over (T0c>T0)

fprintf('Initialized storage for %d configurations...\n', NUM_T0 * NUM_COMP);
fprintf('Controllers: %s\n', strjoin(controller_labels, ', '));
fprintf('Scenarios: %s\n\n', strjoin(scenario_labels, ', '));

%% =====================================================================
%% MAIN PROCESSING LOOP
%% =====================================================================

for T0_idx = 1:NUM_T0
    T0 = T0_wek(T0_idx);

    % Define file paths for this T0 value
    if T0 == 4
        file_paths = { ...
            fullfile('Saved_data', 'T0 4 T0controller 4 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 4 T0controller 3.2 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 4 T0controller 4.8 epoki 3000.mat') ...
        };
        T0_controller_values = [4, 3.2, 4.8];
    elseif T0 == 2
        file_paths = { ...
            fullfile('Saved_data', 'T0 2 T0controller 2 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 2 T0controller 1.6 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 2 T0controller 2.4 epoki 3000.mat') ...
        };
        T0_controller_values = [2, 1.6, 2.4];
    elseif T0 == 0.5
        file_paths = { ...
            fullfile('Saved_data', 'T0 0.5 T0controller 0.5 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 0.5 T0controller 0.4 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 0.5 T0controller 0.6 epoki 3000.mat') ...
        };
        T0_controller_values = [0.5, 0.4, 0.6];
    end

    fprintf('Processing T0 = %.1f...\n', T0);

    % Process each compensation level
    for comp_idx = 1:NUM_COMP
        file_path = file_paths{comp_idx};
        T0_controller = T0_controller_values(comp_idx);

        fprintf('  Loading: %s\n', file_path);

        % Check if file exists
        if exist(file_path, 'file') ~= 2
            warning('File not found: %s. Skipping...', file_path);
            continue;
        end

        % Load workspace
        ws = load(file_path);

        % Validate required variables
        required_vars = {'logi', 'logi_before_learning', 'dt', 'SP_ini', ...
                         'ilosc_probek_sterowanie_reczne', 'czas_eksp_wer'};
        missing_vars = {};
        for i = 1:length(required_vars)
            if ~isfield(ws, required_vars{i})
                missing_vars{end+1} = required_vars{i};
            end
        end

        if ~isempty(missing_vars)
            warning('Missing variables in %s: %s. Skipping...', ...
                    file_path, strjoin(missing_vars, ', '));
            continue;
        end

        % Extract common parameters
        dt = ws.dt;
        SP = ws.SP_ini;
        manual_samples = ws.ilosc_probek_sterowanie_reczne;
        exp_duration = ws.czas_eksp_wer;
        simulation_length = round(exp_duration / dt);

        % Calculate phase boundaries (only phases 1 and 2)
        % Phase 1: SP change (first third)
        phase1_start = manual_samples + 1;
        phase1_end = manual_samples + round(simulation_length / 3);

        % Phase 2: Disturbance applied (second third)
        phase2_start = manual_samples + round(simulation_length / 3) + 1;
        phase2_end = manual_samples + round(2 * simulation_length / 3);

        %% ---------------------------------------------------------------
        %% PI Controller Metrics
        %% ---------------------------------------------------------------
        if isfield(ws.logi, 'PID_y') && isfield(ws.logi, 'PID_u')
            y_PI = ws.logi.PID_y;
            u_PI = ws.logi.PID_u;

            % Phase 1: SP change
            [IAE_storage(1, 1, T0_idx, comp_idx), ...
             max_overshoot_storage(1, 1, T0_idx, comp_idx), ...
             max_delta_u_storage(1, 1, T0_idx, comp_idx)] = ...
                calculate_metrics_for_phase(y_PI, u_PI, SP, dt, phase1_start, phase1_end, true);

            % Phase 2: Disturbance
            [IAE_storage(1, 2, T0_idx, comp_idx), ...
             max_overshoot_storage(1, 2, T0_idx, comp_idx), ...
             max_delta_u_storage(1, 2, T0_idx, comp_idx)] = ...
                calculate_metrics_for_phase(y_PI, u_PI, SP, dt, phase2_start, phase2_end, false);
        end

        %% ---------------------------------------------------------------
        %% Q Before Learning Metrics
        %% ---------------------------------------------------------------
        if isfield(ws.logi_before_learning, 'Q_y') && isfield(ws.logi_before_learning, 'Q_u')
            y_Q_before = ws.logi_before_learning.Q_y;
            u_Q_before = ws.logi_before_learning.Q_u;

            % Phase 1: SP change
            [IAE_storage(2, 1, T0_idx, comp_idx), ...
             max_overshoot_storage(2, 1, T0_idx, comp_idx), ...
             max_delta_u_storage(2, 1, T0_idx, comp_idx)] = ...
                calculate_metrics_for_phase(y_Q_before, u_Q_before, SP, dt, phase1_start, phase1_end, true);

            % Phase 2: Disturbance
            [IAE_storage(2, 2, T0_idx, comp_idx), ...
             max_overshoot_storage(2, 2, T0_idx, comp_idx), ...
             max_delta_u_storage(2, 2, T0_idx, comp_idx)] = ...
                calculate_metrics_for_phase(y_Q_before, u_Q_before, SP, dt, phase2_start, phase2_end, false);
        end

        %% ---------------------------------------------------------------
        %% Q After Learning Metrics
        %% ---------------------------------------------------------------
        if isfield(ws.logi, 'Q_y') && isfield(ws.logi, 'Q_u')
            y_Q_after = ws.logi.Q_y;
            u_Q_after = ws.logi.Q_u;

            % Phase 1: SP change
            [IAE_storage(3, 1, T0_idx, comp_idx), ...
             max_overshoot_storage(3, 1, T0_idx, comp_idx), ...
             max_delta_u_storage(3, 1, T0_idx, comp_idx)] = ...
                calculate_metrics_for_phase(y_Q_after, u_Q_after, SP, dt, phase1_start, phase1_end, true);

            % Phase 2: Disturbance
            [IAE_storage(3, 2, T0_idx, comp_idx), ...
             max_overshoot_storage(3, 2, T0_idx, comp_idx), ...
             max_delta_u_storage(3, 2, T0_idx, comp_idx)] = ...
                calculate_metrics_for_phase(y_Q_after, u_Q_after, SP, dt, phase2_start, phase2_end, false);
        end

        fprintf('    T0_controller = %.1f: Metrics calculated\n', T0_controller);
    end

    fprintf('  T0 = %.1f complete.\n\n', T0);
end

fprintf('==========================================================\n');
fprintf('All files processed successfully.\n');
fprintf('==========================================================\n\n');

%% =====================================================================
%% CONSOLE OUTPUT - SUMMARY TABLES
%% =====================================================================

fprintf('==========================================================\n');
fprintf('PERFORMANCE METRICS SUMMARY\n');
fprintf('==========================================================\n\n');

% Display table for each controller
for ctrl_idx = 1:NUM_CONTROLLERS
    fprintf('----------------------------------------------------------\n');
    fprintf('%s\n', controller_labels{ctrl_idx});
    fprintf('----------------------------------------------------------\n\n');

    for metric_idx = 1:3
        if metric_idx == 1
            metric_name = 'IAE';
            data = squeeze(IAE_storage(ctrl_idx, :, :, :));
        elseif metric_idx == 2
            metric_name = 'Max Overshoot';
            data = squeeze(max_overshoot_storage(ctrl_idx, :, :, :));
        else
            metric_name = 'Max Delta U';
            data = squeeze(max_delta_u_storage(ctrl_idx, :, :, :));
        end

        fprintf('--- %s ---\n', metric_name);
        fprintf('%-15s', 'Scenario');
        for T0_idx = 1:NUM_T0
            fprintf('| %-12s %-12s %-12s', ...
                    [T0_labels{T0_idx} '-Full'], ...
                    [T0_labels{T0_idx} '-Over'], ...
                    [T0_labels{T0_idx} '-Under']);
        end
        fprintf('|\n');
        fprintf('%s\n', repmat('-', 1, 15 + NUM_T0 * 40));

        for scenario_idx = 1:NUM_SCENARIOS
            fprintf('%-15s', scenario_labels{scenario_idx});
            for T0_idx = 1:NUM_T0
                fprintf('| %12.3f %12.3f %12.3f', ...
                        data(scenario_idx, T0_idx, 1), ...
                        data(scenario_idx, T0_idx, 2), ...
                        data(scenario_idx, T0_idx, 3));
            end
            fprintf('|\n');
        end
        fprintf('\n');
    end
    fprintf('\n');
end

%% =====================================================================
%% CSV EXPORT - tabela.csv (matching rys_wyk_papier_reduced.m structure)
%% =====================================================================

fprintf('==========================================================\n');
fprintf('Exporting to CSV: tabela.csv\n');
fprintf('==========================================================\n\n');

tabela_file = fullfile('Saved_data', 'tabela.csv');

% Open file for writing
fid = fopen(tabela_file, 'w');
if fid == -1
    error('Cannot open file for writing: %s', tabela_file);
end

% Write header row 1: T0 groups
fprintf(fid, 'Scenario,Metric,');
for T0_idx = 1:NUM_T0
    fprintf(fid, '%s,,,,', T0_labels{T0_idx});
    if T0_idx < NUM_T0
        fprintf(fid, ',');
    end
end
fprintf(fid, '\n');

% Write header row 2: Controller types (PI and QaL only)
fprintf(fid, ',,');
for T0_idx = 1:NUM_T0
    fprintf(fid, 'PI,QaL-Full,QaL-Under,QaL-Over');
    if T0_idx < NUM_T0
        fprintf(fid, ',');
    end
end
fprintf(fid, '\n');

% Metric names for CSV
metric_names_csv = {'IAE', 'Max u', 'Max overshoot'};

% Write data rows (only PI and Q after learning)
for scenario_idx = 1:NUM_SCENARIOS
    for metric_idx = 1:3
        % Scenario label (only on first metric of each scenario)
        if metric_idx == 1
            fprintf(fid, '%s,', scenario_labels{scenario_idx});
        else
            fprintf(fid, ',');
        end

        % Metric label
        fprintf(fid, '%s', metric_names_csv{metric_idx});

        % Data for all T0 values
        for T0_idx = 1:NUM_T0
            % Get data values
            if metric_idx == 1  % IAE
                pi_val = IAE_storage(1, scenario_idx, T0_idx, 1);  % PI, Full compensation only
                q_vals = squeeze(IAE_storage(3, scenario_idx, T0_idx, :));  % Q after learning
            elseif metric_idx == 2  % Max Delta U
                pi_val = max_delta_u_storage(1, scenario_idx, T0_idx, 1);
                q_vals = squeeze(max_delta_u_storage(3, scenario_idx, T0_idx, :));
            else  % Max overshoot
                pi_val = max_overshoot_storage(1, scenario_idx, T0_idx, 1);
                q_vals = squeeze(max_overshoot_storage(3, scenario_idx, T0_idx, :));
            end

            % Print: PI, QaL-Full, QaL-Under, QaL-Over
            fprintf(fid, ',%.6f,%.6f,%.6f,%.6f', pi_val, q_vals(1), q_vals(2), q_vals(3));
        end

        fprintf(fid, '\n');
    end
end

fclose(fid);

fprintf('CSV file created: %s\n', tabela_file);
fprintf('Table structure: 8 rows (2 header + 6 data) x 14 columns\n');
fprintf('  Rows: 2 scenarios x 3 metrics\n');
fprintf('  Columns: Scenario, Metric, + 3xT0 (PI, QaL-Full, QaL-Under, QaL-Over)\n\n');

fprintf('==========================================================\n');
fprintf('Script complete!\n');
fprintf('==========================================================\n');

%% =====================================================================
%% HELPER FUNCTIONS
%% =====================================================================

function IAE = calculate_IAE(y, SP, dt, start_idx, end_idx)
% calculate_IAE - Integral of Absolute Error using trapezoidal integration
%
% INPUTS:
%   y         - Process output vector [process units]
%   SP        - Setpoint value [process units]
%   dt        - Sampling time [s]
%   start_idx - Phase start index
%   end_idx   - Phase end index
%
% OUTPUT:
%   IAE - Integral Absolute Error [process units * seconds]
%
% FORMULA:
%   IAE = integral of |SP - y(t)| dt
%   Uses MATLAB trapz() for trapezoidal numerical integration

    % Extract phase data
    y_phase = y(start_idx:end_idx);

    % Calculate absolute error
    error_abs = abs(SP - y_phase);

    % Integrate using trapezoidal rule
    % trapz(dt, signal) computes integral with spacing dt
    IAE = trapz(dt, error_abs);
end

function max_overshoot = calculate_max_overshoot(y, SP, start_idx, end_idx, is_SP_change_phase)
% calculate_max_overshoot - Maximum overshoot or deviation from setpoint
%
% INPUTS:
%   y                  - Process output vector [process units]
%   SP                 - Setpoint value [process units]
%   start_idx          - Phase start index
%   end_idx            - Phase end index
%   is_SP_change_phase - true for SP step phase, false for disturbance phase
%
% OUTPUT:
%   max_overshoot - Maximum deviation [process units]
%
% NOTES:
%   - For SP change phase: measures true overshoot past setpoint
%     (only positive deviation in step direction counts)
%   - For disturbance phases: measures maximum absolute deviation
%     (any deviation from SP counts)

    % Extract phase data
    y_phase = y(start_idx:end_idx);

    if is_SP_change_phase
        % SP change phase: calculate directional overshoot
        y_initial = y(start_idx);

        if y_initial < SP
            % Positive step: overshoot = max(y) above SP
            max_overshoot = max(0, max(y_phase) - SP);
        else
            % Negative step: overshoot = min(y) below SP
            max_overshoot = max(0, SP - min(y_phase));
        end
    else
        % Disturbance phase: maximum absolute deviation
        max_overshoot = max(abs(SP - y_phase));
    end
end

function max_delta_u = calculate_max_delta_u(u, start_idx, end_idx)
% calculate_max_delta_u - Maximum control signal increment
%
% INPUTS:
%   u         - Control signal vector [process units]
%   start_idx - Phase start index
%   end_idx   - Phase end index
%
% OUTPUT:
%   max_delta_u - Maximum control increment [process units]
%
% FORMULA:
%   max_delta_u = max(|u(k) - u(k-1)|)
%   Measures aggressiveness of control action

    % Extract phase data
    u_phase = u(start_idx:end_idx);

    if length(u_phase) > 1
        % Calculate absolute differences between consecutive samples
        % diff(u) computes u(k) - u(k-1)
        control_increments = abs(diff(u_phase));

        % Find maximum
        max_delta_u = max(control_increments);
    else
        % Not enough data
        max_delta_u = 0;
    end
end

function [IAE, max_overshoot, max_delta_u] = calculate_metrics_for_phase(y, u, SP, dt, start_idx, end_idx, is_SP_change_phase)
% calculate_metrics_for_phase - Wrapper to compute all three metrics
%
% INPUTS:
%   y                  - Process output vector [process units]
%   u                  - Control signal vector [process units]
%   SP                 - Setpoint value [process units]
%   dt                 - Sampling time [s]
%   start_idx          - Phase start index
%   end_idx            - Phase end index
%   is_SP_change_phase - true for SP change, false for disturbance
%
% OUTPUTS:
%   IAE           - Integral Absolute Error
%   max_overshoot - Maximum overshoot/deviation
%   max_delta_u   - Maximum control increment

    IAE = calculate_IAE(y, SP, dt, start_idx, end_idx);
    max_overshoot = calculate_max_overshoot(y, SP, start_idx, end_idx, is_SP_change_phase);
    max_delta_u = calculate_max_delta_u(u, start_idx, end_idx);
end
