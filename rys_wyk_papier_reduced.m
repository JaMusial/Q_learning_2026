clc
close all

%% generacja_wykresow_papier.m - Paper-quality plot and table generation
%
% PURPOSE:
%   Generates publication-ready figures and performance metrics table
%   comparing PI controller, Q-learning before learning, and Q-learning
%   after learning. Loads data from a saved .mat workspace file.
%
% OUTPUTS:
%   - Figure 1: Y (output) comparison, normalized to [0, 1]
%   - Figure 2: U (control signal) comparison, normalized to [0, 1]
%   - Console table: Performance metrics at key training epochs
%   - LaTeX table code: Ready for paper inclusion
%
% INPUTS (none - standalone script):
%   Configure mat_file_path and table_epochs below.
%
% NOTES:
%   - Requires f_licz_wskazniki.m in MATLAB path
%   - Loads workspace saved by main.m (Saved_data/*.mat)
%   - White theme, grid on all plots
%   - Table values in original process units (not normalized)

%% =====================================================================
%% CONFIGURATION
%% =====================================================================

T0_wek=[0.5 2 4];

% Normalization factor: divide process units [0, 100]% by this to get [0, 1]
NORM_FACTOR = 100;

%% =====================================================================
%% INITIALIZE DATA STORAGE FOR TABLES
%% =====================================================================

% Storage for Q-learning metrics: (scenario, T0_index, compensation_level)
% Scenarios: 1=SP change, 2=disturbance
% T0_index: 1=0.5, 2=2, 3=4
% Compensation: 1=Full, 2=Under, 3=Over
IAE_Q_data = zeros(2, 3, 3);
delta_u_Q_data = zeros(2, 3, 3);
overshoot_Q_data = zeros(2, 3, 3);

% Storage for PI baseline: (scenario, T0_index)
% PI only for Full compensation (T0_controller = T0)
IAE_PI_data = zeros(2, 3);
delta_u_PI_data = zeros(2, 3);
overshoot_PI_data = zeros(2, 3);

for aa = 1:numel(T0_wek)
    T0=T0_wek(aa);
    if T0==4
        sciezki = { ...
            fullfile('Saved_data', 'T0 4 T0controller 4 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 4 T0controller 3.2 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 4 T0controller 4.8 epoki 3000.mat') ...
            };
        T0controller=[4 3.2 4.8];
    elseif T0==2
        sciezki = { ...
            fullfile('Saved_data', 'T0 2 T0controller 2 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 2 T0controller 1.6 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 2 T0controller 2.4 epoki 3000.mat') ...
            };
        T0controller=[2 1.6 2.4];
    elseif T0==0.5
        sciezki = { ...
            fullfile('Saved_data', 'T0 0.5 T0controller 0.5 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 0.5 T0controller 0.4 epoki 3000.mat'), ...
            fullfile('Saved_data', 'T0 0.5 T0controller 0.6 epoki 3000.mat') ...
            };
        T0controller=[0.5 0.4 0.6];
    end

    % Path to saved workspace .mat file
    mat_file_path = fullfile('Saved_data', 'T0 4 T0controller 4 epoki 3000.mat');

    % Normalization factor: divide process units [0, 100]% by this to get [0, 1]
    NORM_FACTOR = 100;

    %% =====================================================================
    %% LOAD AND VALIDATE DATA AND COMPUTE METRICS
    %% =====================================================================

    % Loop through all three compensation levels
    for comp_idx = 1:3
        ws = load(sciezki{comp_idx});

        % Validate required variables (only on first iteration)
        if comp_idx == 1
            required_vars = {'logi', 'logi_before_learning', 'dt', 'SP_ini', ...
                'dokladnosc_gen_stanu', 'ilosc_probek_sterowanie_reczne', ...
                'czas_eksp_wer', 'probkowanie_norma_macierzy'};
            for i = 1:length(required_vars)
                if ~isfield(ws, required_vars{i})
                    error('Required variable "%s" not found in workspace file.', required_vars{i});
                end
            end

            % Validate PI data exists
            if ~isfield(ws.logi, 'PID_y') || isempty(ws.logi.PID_y)
                error('PI controller data (PID_y) not found in logi. Was verification mode used?');
            end

            fprintf('Data loaded successfully for T0=%.1f.\n', T0);
        end

        % Compute Q-learning metrics (after 3000 epochs)
        [IAE_Q, ~, overshoot_Q, ~, delta_u_Q] = ...
            f_licz_wskazniki(ws.logi.Q_y, ws.logi.Q_u, ws.SP_ini, ...
                             ws.dokladnosc_gen_stanu, ws.logi.Ref_y, ws.dt, ...
                             ws.ilosc_probek_sterowanie_reczne, ws.czas_eksp_wer);

        % Store Q metrics: Phase 1 = SP change, Phase 2 = disturbance
        IAE_Q_data(1, aa, comp_idx) = IAE_Q(1);
        IAE_Q_data(2, aa, comp_idx) = IAE_Q(2);
        delta_u_Q_data(1, aa, comp_idx) = delta_u_Q(1);
        delta_u_Q_data(2, aa, comp_idx) = delta_u_Q(2);
        overshoot_Q_data(1, aa, comp_idx) = overshoot_Q(1);
        overshoot_Q_data(2, aa, comp_idx) = overshoot_Q(2);

        % For Full compensation only, also compute and store PI metrics
        if comp_idx == 1
            [IAE_PI, ~, overshoot_PI, ~, delta_u_PI] = ...
                f_licz_wskazniki(ws.logi.PID_y, ws.logi.PID_u, ws.SP_ini, ...
                                 ws.dokladnosc_gen_stanu, ws.logi.Ref_y, ws.dt, ...
                                 ws.ilosc_probek_sterowanie_reczne, ws.czas_eksp_wer);

            IAE_PI_data(1, aa) = IAE_PI(1);
            IAE_PI_data(2, aa) = IAE_PI(2);
            delta_u_PI_data(1, aa) = delta_u_PI(1);
            delta_u_PI_data(2, aa) = delta_u_PI(2);
            overshoot_PI_data(1, aa) = overshoot_PI(1);
            overshoot_PI_data(2, aa) = overshoot_PI(2);
        end
    end

    % Reload first file for plotting
    ws = load(sciezki{1});

    %% =====================================================================
    %% COMPUTE DISTURBANCE TRANSITION TIMES
    %% =====================================================================

    manual_control_time = ws.ilosc_probek_sterowanie_reczne * ws.dt;
    t_d_on = manual_control_time + ws.czas_eksp_wer / 3;
    t_d_off = manual_control_time + 2 * ws.czas_eksp_wer / 3;

    % Extract actual disturbance value from logged data
    d_nonzero_idx = find(ws.logi.Q_d ~= 0, 1, 'first');
    if ~isempty(d_nonzero_idx)
        d_value = ws.logi.Q_d(d_nonzero_idx);
    else
        d_value = -0.3;
    end

    %% =====================================================================
    %% FIGURE 1: Y (OUTPUT) COMPARISON
    %% =====================================================================

    figure('Color', 'w');

    % Time vectors (seconds, based on sampling time)
    t_before = ws.logi_before_learning.Q_t;
    t_after = ws.logi.Q_t;
    t_PI = ws.logi.PID_t;

    % Normalized output data [0, 1]
    y_PI = ws.logi.PID_y / NORM_FACTOR;
    y_before = ws.logi_before_learning.Q_y / NORM_FACTOR;
    y_after = ws.logi.Q_y / NORM_FACTOR;
    SP_norm = ws.SP_ini / NORM_FACTOR;

    plot(t_PI, y_PI, 'Color', [0 0 0], 'LineWidth', 2)
    hold on
    % plot(t_before, y_before, 'Color', [0.3010 0.7450 0.9330], 'LineWidth', 2)
    plot(t_after, y_after, 'Color', [1 0 0], 'LineWidth', 2)

    load(sciezki{2});
    y_after = logi.Q_y / NORM_FACTOR;
    plot(t_after, y_after, 'Color', [0 0 1], 'LineWidth', 2)
    load(sciezki{3});
    y_after = logi.Q_y / NORM_FACTOR;
    plot(t_after, y_after, 'Color', [0 1 0], 'LineWidth', 2)
    yline(SP_norm, '--', 'Setpoint', 'Color', [0.5 0.5 0.5], 'LineWidth', 2, ...
        'LabelHorizontalAlignment', 'left', 'FontSize', 20)
    hold off

    grid on
    set(gca, 'Color', 'w', 'FontSize', 20)
    xlabel('time [s]', 'FontSize', 20)
    ylabel('Y', 'FontSize', 20)
    legend('PI = QwL','QaL full compensation', 'QaL under compensation', 'QaL over compensation', ...
        'Location', 'best', 'FontSize', 20, 'Position', [0.587965433632459,0.149053745281145,0.29442747205071,0.216968011126564])

    if T0==4
        xlim([0 400])
        ylim([0.35 0.55])
    else
        xlim([0 400])
        ylim([0.35 0.515])
    end

    annotation('textarrow', [0.4207,0.5104], [0.5214,0.6929], ...
        'String', sprintf('d = %.1f\nt = %d s', -0.3, 200), ...
        'FontSize', 20, 'Color', [0.3 0.3 0.3], 'TextColor', [0 0 0], ...
        'HeadWidth', 8, 'HeadLength', 6, 'HorizontalAlignment', 'center');

    %% =====================================================================
    %% FIGURE 2: U (CONTROL SIGNAL) COMPARISON
    %% =====================================================================

    figure('Color', 'w');
    load(sciezki{1});
    % Normalized control data [0, 1]
    u_PI = ws.logi.PID_u / NORM_FACTOR;
    u_before = ws.logi_before_learning.Q_u / NORM_FACTOR;
    u_after = ws.logi.Q_u / NORM_FACTOR;

    plot(t_PI, u_PI, 'Color', [0 0 0], 'LineWidth', 2)
    hold on
    % plot(t_before, u_before, 'Color', [0.3010 0.7450 0.9330], 'LineWidth', 2)
    plot(t_after, u_after, 'Color', [1 0 0], 'LineWidth', 2)
    load(sciezki{2})
    y_after = logi.Q_u / NORM_FACTOR;
    plot(t_after, y_after, 'Color', [0 0 1], 'LineWidth', 2)
    load(sciezki{3});
    y_after = logi.Q_u / NORM_FACTOR;
    plot(t_after, y_after, 'Color', [0 1 0], 'LineWidth', 2)
    hold off

    grid on
    set(gca, 'Color', 'w', 'FontSize', 20)
    xlabel('time [s]', 'FontSize', 20)
    ylabel('U', 'FontSize', 20)
    legend('PI = QwL', 'QaL full compensation', 'QaL under compensation', 'QaL over compensation', ...
        'Location', 'best', 'FontSize', 20, 'Position', [0.587965433632459,0.149053745281145,0.29442747205071,0.216968011126564])

    if T0==0.5
        xlim([0 400])
        ylim([0.35 0.7])
    else
        xlim([0 400])
        ylim([0.35 0.75])
    end


    annotation('textarrow', [0.4221,0.4961], [0.6167,0.4762], ...
        'String', sprintf('d = %.1f\nt = %d s', -0.3, 200), ...
        'FontSize', 20, 'Color', [0.3 0.3 0.3], 'TextColor', [0 0 0], ...
        'HeadWidth', 8, 'HeadLength', 6, 'HorizontalAlignment', 'center');

end

%% =====================================================================
%% GENERATE PERFORMANCE METRICS TABLES
%% =====================================================================

fprintf('\n========================================================\n');
fprintf('PERFORMANCE METRICS TABLE (3000 epochs)\n');
fprintf('========================================================\n\n');

% Table configuration
T0_labels = {'T0=0.5', 'T0=2', 'T0=4'};
comp_labels = {'Full', 'Under', 'Over'};  % Order: Full (T0c=T0), Under (T0c<T0), Over (T0c>T0)
comp_labels_latex = {'Full', 'Under', 'Over'};
scenario_labels = {'SP change', 'd=-0.3'};
metric_labels = {'IAE', 'Max u', 'Max overshoot'};
metric_labels_latex = {'IAE', '$\Delta U_{max}$', 'Max overshoot'};

%% =====================================================================
%% MATLAB CONSOLE TABLE
%% =====================================================================

% Build table data: 6 rows (2 scenarios × 3 metrics), 12 columns (3 T0 × 4 controllers)
% Controllers per T0: PI, QaL-Full, QaL-Over, QaL-Under
num_rows = 6;   % 2 scenarios × 3 metrics
num_cols = 12;  % 3 T0 values × 4 controllers each

table_data = zeros(num_rows, num_cols);
row_labels = cell(1, num_rows);

row_idx = 1;

% Build rows: 2 scenarios × 3 metrics
for scenario = 1:2
    for metric = 1:3
        row_labels{row_idx} = sprintf('%s - %s', scenario_labels{scenario}, metric_labels{metric});

        col_idx = 1;
        for T0_idx = 1:3
            % Get data for this scenario/metric/T0 combination
            if metric == 1  % IAE
                pi_val = IAE_PI_data(scenario, T0_idx);
                q_vals = squeeze(IAE_Q_data(scenario, T0_idx, :));
            elseif metric == 2  % Delta U max
                pi_val = delta_u_PI_data(scenario, T0_idx);
                q_vals = squeeze(delta_u_Q_data(scenario, T0_idx, :));
            else  % Max overshoot
                pi_val = overshoot_PI_data(scenario, T0_idx);
                q_vals = squeeze(overshoot_Q_data(scenario, T0_idx, :));
            end

            % Fill columns: PI, QaL-Full, QaL-Over, QaL-Under
            table_data(row_idx, col_idx) = pi_val;
            table_data(row_idx, col_idx + 1) = q_vals(1);  % Full
            table_data(row_idx, col_idx + 2) = q_vals(2);  % Over
            table_data(row_idx, col_idx + 3) = q_vals(3);  % Under

            col_idx = col_idx + 4;
        end

        row_idx = row_idx + 1;
    end
end

% Display console table
fprintf('%-30s', '');
for T0_idx = 1:3
    fprintf('| %-45s', T0_labels{T0_idx});
end
fprintf('|\n');

fprintf('%-30s', 'Scenario - Metric');
for T0_idx = 1:3
    fprintf('| %-10s %-10s %-10s %-10s', 'PI', 'QaL-Full', 'QaL-Over', 'QaL-Under');
end
fprintf('|\n');

fprintf('%s\n', repmat('-', 1, 172));

for r = 1:num_rows
    fprintf('%-30s', row_labels{r});
    for col = 1:num_cols
        fprintf('| %10.3f', table_data(r, col));
    end
    fprintf('|\n');
end

fprintf('\n');

%% =====================================================================
%% LATEX TABLE OUTPUT
%% =====================================================================

fprintf('========================================================\n');
fprintf('LATEX TABLE CODE\n');
fprintf('========================================================\n\n');

fprintf('\\begin{table}[htbp]\n');
fprintf('\\centering\n');
fprintf('\\caption{Performance metrics comparison for different dead time compensation strategies}\n');
fprintf('\\label{tab:dead_time_compensation}\n');
fprintf('\\resizebox{\\textwidth}{!}{%%\n');
fprintf('\\begin{tabular}{ll|cccc|cccc|cccc}\n');
fprintf('\\hline\n');

% Header row 1: T0 values
fprintf('& ');
for T0_idx = 1:3
    if T0_idx < 3
        fprintf('& \\multicolumn{4}{c|}{%s}', T0_labels{T0_idx});
    else
        fprintf('& \\multicolumn{4}{c}{%s}', T0_labels{T0_idx});
    end
end
fprintf(' \\\\\n');

% Header row 2: Controller types
fprintf('Scenario & Metric');
for T0_idx = 1:3
    fprintf(' & PI & QaL-Full & QaL-Over & QaL-Under');
end
fprintf(' \\\\\n');
fprintf('\\hline\n');

% Data rows
for scenario = 1:2
    for metric = 1:3
        % First metric of each scenario shows scenario label
        if metric == 1
            fprintf('\\multirow{3}{*}{%s}', scenario_labels{scenario});
        else
            fprintf('');  % Empty for multirow
        end

        fprintf(' & %s', metric_labels_latex{metric});

        % Data for all T0 values
        for T0_idx = 1:3
            % Get data values
            if metric == 1  % IAE
                pi_val = IAE_PI_data(scenario, T0_idx);
                q_vals = squeeze(IAE_Q_data(scenario, T0_idx, :));
            elseif metric == 2  % Delta U max
                pi_val = delta_u_PI_data(scenario, T0_idx);
                q_vals = squeeze(delta_u_Q_data(scenario, T0_idx, :));
            else  % Max overshoot
                pi_val = overshoot_PI_data(scenario, T0_idx);
                q_vals = squeeze(overshoot_Q_data(scenario, T0_idx, :));
            end

            % Print: PI, QaL-Full, QaL-Over, QaL-Under
            fprintf(' & %.3f & %.3f & %.3f & %.3f', pi_val, q_vals(1), q_vals(2), q_vals(3));
        end

        fprintf(' \\\\\n');
    end

    % Add line between scenarios
    if scenario == 1
        fprintf('\\hline\n');
    end
end

fprintf('\\hline\n');
fprintf('\\end{tabular}%%\n');
fprintf('}\n');
fprintf('\\end{table}\n\n');

fprintf('========================================================\n');
fprintf('Table generation complete.\n');
fprintf('========================================================\n');