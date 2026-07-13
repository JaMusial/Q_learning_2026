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

% Path to saved workspace .mat file
mat_file_path = fullfile('Saved_data', 'T0 4 T0controller 4 epoki 3000.mat');

% Normalization factor: divide process units [0, 100]% by this to get [0, 1]
NORM_FACTOR = 100;

% Training epochs to include in the comparison table
table_epochs = [500, 1000, 2000, 3000];

% Phase labels for table columns
phase_labels_display = {'Y_SP', 'd=-2', 'd=0'};
phase_labels_latex = {'$Y_{SP}$', '$d=-2$', '$d=0$'};

% Metric names
metric_names_display = {'IAE', 'Max overshoot', 'Settling time [s]', 'Delta U max'};
metric_names_latex = {'IAE', 'Max overshoot', 'Settling time [s]', '$\Delta U_{max}$'};

%% =====================================================================
%% LOAD AND VALIDATE DATA
%% =====================================================================

fprintf('Loading data from: %s\n', mat_file_path);
if exist(mat_file_path, 'file') ~= 2
    error('File not found: %s', mat_file_path);
end
ws = load(mat_file_path);

% Validate required variables
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

fprintf('Data loaded successfully.\n');

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
%% COMPUTE PI AND QwL (EPOCH 0) METRICS
%% =====================================================================

% PI controller metrics (PI does not learn - same result from any verification run)
[IAE_PI, ~, overshoot_PI, settling_PI, delta_u_PI] = ...
    f_licz_wskazniki(ws.logi.PID_y, ws.logi.PID_u, ws.SP_ini, ...
                     ws.dokladnosc_gen_stanu, ws.logi.Ref_y, ws.dt, ...
                     ws.ilosc_probek_sterowanie_reczne, ws.czas_eksp_wer);

% Q without learning (epoch 0) metrics
[IAE_QwL, ~, overshoot_QwL, settling_QwL, delta_u_QwL] = ...
    f_licz_wskazniki(ws.logi_before_learning.Q_y, ...
                     ws.logi_before_learning.Q_u, ws.SP_ini, ...
                     ws.dokladnosc_gen_stanu, ws.logi_before_learning.Ref_y, ...
                     ws.dt, ws.ilosc_probek_sterowanie_reczne, ws.czas_eksp_wer);

%% =====================================================================
%% BUILD METRICS TABLE DATA
%% =====================================================================

NUM_PHASES = 3;
NUM_METRICS = 4;
num_rows = 2 + length(table_epochs);  % PI + QwL + one per epoch

% Preallocate: rows x 12 (4 metrics * 3 phases each)
table_data = zeros(num_rows, NUM_METRICS * NUM_PHASES);
row_labels = cell(1, num_rows);

% Row 1: PI
table_data(1, :) = [IAE_PI, overshoot_PI, settling_PI, delta_u_PI];
row_labels{1} = 'PI';

% Row 2: QwL (Q without learning, epoch 0)
table_data(2, :) = [IAE_QwL, overshoot_QwL, settling_QwL, delta_u_QwL];
row_labels{2} = 'QwL';

% Rows 3+: Training checkpoint epochs
if ~isfield(ws, 'IAE_wek')
    warning('IAE_wek not found. Training metrics will be NaN.');
end
for i = 1:length(table_epochs)
    epoch = table_epochs(i);
    row_idx = round(epoch / ws.probkowanie_norma_macierzy);

    if ~isfield(ws, 'IAE_wek') || row_idx < 1 || row_idx > size(ws.IAE_wek, 1)
        warning('Epoch %d metrics not available. Setting to NaN.', epoch);
        table_data(2 + i, :) = NaN(1, NUM_METRICS * NUM_PHASES);
    else
        table_data(2 + i, :) = [ws.IAE_wek(row_idx, :), ...
                                ws.maks_przereg_wek(row_idx, :), ...
                                ws.czas_regulacji_wek(row_idx, :), ...
                                ws.max_delta_u_wek(row_idx, :)];
    end
    row_labels{2 + i} = sprintf('%d', epoch);
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

plot(t_PI, y_PI, 'Color', [0.1 0.6 0.1], 'LineWidth', 2)
hold on
plot(t_before, y_before, 'Color', [0.3010 0.7450 0.9330], 'LineWidth', 2)
plot(t_after, y_after, 'Color', [1 0 0], 'LineWidth', 2)
yline(SP_norm, '--', 'Setpoint', 'Color', [0.5 0.5 0.5], 'LineWidth', 2, ...
      'LabelHorizontalAlignment', 'left', 'FontSize', 20)
hold off

grid on
set(gca, 'Color', 'w', 'FontSize', 20)
xlabel('time [s]', 'FontSize', 20)
ylabel('Y', 'FontSize', 20)
legend('PI', 'Q before learning', 'Q after learning', 'Location', 'best', 'FontSize', 20)

% Add disturbance change arrows (Y plot: first arrow starts at y=0.55)
add_disturbance_arrows(gca, t_d_on, t_d_off, d_value, 0.55);

%% =====================================================================
%% FIGURE 2: U (CONTROL SIGNAL) COMPARISON
%% =====================================================================

figure('Color', 'w');

% Normalized control data [0, 1]
u_PI = ws.logi.PID_u / NORM_FACTOR;
u_before = ws.logi_before_learning.Q_u / NORM_FACTOR;
u_after = ws.logi.Q_u / NORM_FACTOR;

plot(t_PI, u_PI, 'Color', [0.1 0.6 0.1], 'LineWidth', 2)
hold on
plot(t_before, u_before, 'Color', [0.3010 0.7450 0.9330], 'LineWidth', 2)
plot(t_after, u_after, 'Color', [1 0 0], 'LineWidth', 2)
hold off

grid on
set(gca, 'Color', 'w', 'FontSize', 20)
xlabel('time [s]', 'FontSize', 20)
ylabel('U', 'FontSize', 20)
legend('PI', 'Q before learning', 'Q after learning', 'Location', 'best', 'FontSize', 20)

% Add disturbance change arrows (U plot: first arrow starts at y=0.6)
add_disturbance_arrows(gca, t_d_on, t_d_off, d_value, 0.6);

%% =====================================================================
%% TABLE: CONSOLE OUTPUT
%% =====================================================================

fprintf('\n=== Performance Metrics Comparison ===\n');
fprintf('(Values in process units; settling time in seconds)\n\n');

% Compute column width for consistent formatting
col_w = 11;  % Width per data column
group_w = col_w * NUM_PHASES + NUM_PHASES;  % Width per metric group

% Header row 1: Metric group names
fprintf('%-6s', '');
for m = 1:NUM_METRICS
    label = metric_names_display{m};
    pad = group_w - length(label);
    left_pad = floor(pad / 2);
    fprintf('|%s%s%s', repmat(' ', 1, left_pad), label, repmat(' ', 1, pad - left_pad));
end
fprintf('|\n');

% Header row 2: Phase names
fprintf('%-6s', '');
for m = 1:NUM_METRICS
    for p = 1:NUM_PHASES
        fprintf('|%*s', col_w, phase_labels_display{p});
    end
end
fprintf('|\n');

% Separator
total_w = 6 + NUM_METRICS * (col_w * NUM_PHASES + NUM_PHASES) + 1;
fprintf('%s\n', repmat('-', 1, total_w));

% Data rows
for r = 1:num_rows
    fprintf('%-6s', row_labels{r});
    for col = 1:NUM_METRICS * NUM_PHASES
        if isnan(table_data(r, col))
            fprintf('|%*s', col_w, '---');
        else
            fprintf('|%*.3f', col_w, table_data(r, col));
        end
    end
    fprintf('|\n');
end
fprintf('\n');

%% =====================================================================
%% TABLE: LATEX OUTPUT
%% =====================================================================

fprintf('=== LaTeX Table Code ===\n\n');
fprintf('\\begin{table}[htbp]\n');
fprintf('\\centering\n');
fprintf('\\caption{Performance metrics comparison}\n');
fprintf('\\label{tab:metrics}\n');
fprintf('\\resizebox{\\textwidth}{!}{%%\n');

% Column specification: label + 4 groups of 3 columns with vertical separators
fprintf('\\begin{tabular}{l|');
for m = 1:NUM_METRICS
    fprintf('c c c');
    if m < NUM_METRICS
        fprintf('|');
    end
end
fprintf('}\n');
fprintf('\\hline\n');

% Header row 1: Metric group names with multicolumn
fprintf(' ');
for m = 1:NUM_METRICS
    separator = '|';
    if m == NUM_METRICS
        separator = '';
    end
    fprintf(' & \\multicolumn{3}{c%s}{%s}', separator, metric_names_latex{m});
end
fprintf(' \\\\\n');

% Header row 2: Phase names
fprintf(' ');
for m = 1:NUM_METRICS
    for p = 1:NUM_PHASES
        fprintf(' & %s', phase_labels_latex{p});
    end
end
fprintf(' \\\\\n');
fprintf('\\hline\n');

% Data rows
for r = 1:num_rows
    fprintf('%s', row_labels{r});
    for col = 1:NUM_METRICS * NUM_PHASES
        if isnan(table_data(r, col))
            fprintf(' & ---');
        else
            fprintf(' & %.3f', table_data(r, col));
        end
    end
    fprintf(' \\\\\n');
end

fprintf('\\hline\n');
fprintf('\\end{tabular}%%\n');
fprintf('}\n');
fprintf('\\end{table}\n\n');

fprintf('Done. Generated 2 figures and metrics table (console + LaTeX).\n');

%% =====================================================================
%% HELPER FUNCTIONS
%% =====================================================================

function add_disturbance_arrows(ax, t_on, t_off, d_val, y_start_first)
% add_disturbance_arrows - Add textarrow annotations at disturbance transitions
%
% INPUTS:
%   ax              - Axes handle
%   t_on            - Time when disturbance is applied [s]
%   t_off           - Time when disturbance is removed [s]
%   d_val           - Disturbance value
%   y_start_first   - Y-coordinate for first arrow start (0.55 for Y plot, 0.6 for U plot)
%
% Draws two diagonal arrows on the current figure:
%   1. From (t=150, y/u=y_start_first) to (t=200, y/u=0.5): disturbance applied
%   2. From (t=350, y/u=0.4) to (t=400, y/u=0.5): disturbance removed

    drawnow;  % Ensure axes layout is finalized before reading positions

    ax_pos = get(ax, 'Position');
    x_lim = get(ax, 'XLim');
    y_lim = get(ax, 'YLim');

    % Helper function to convert data coordinates to normalized figure coords
    data_to_fig = @(t_data, y_data) deal(...
        ax_pos(1) + ax_pos(3) * (t_data - x_lim(1)) / (x_lim(2) - x_lim(1)), ...
        ax_pos(2) + ax_pos(4) * (y_data - y_lim(1)) / (y_lim(2) - y_lim(1)));

    % Arrow 1: disturbance ON (from t=150, y=y_start_first to t=200, y=0.5)
    [x_on_tail, y_on_tail] = data_to_fig(150, y_start_first);
    [x_on_tip, y_on_tip] = data_to_fig(200, 0.5);

    % Round time down (subtract 1 second)
    t_on_display = floor(t_on - 1);

    annotation('textarrow', [x_on_tail, x_on_tip], [y_on_tail, y_on_tip], ...
        'String', sprintf('d = %.1f\nt = %d s', d_val, t_on_display), ...
        'FontSize', 20, 'Color', [0.3 0.3 0.3], 'TextColor', [0 0 0], ...
        'HeadWidth', 8, 'HeadLength', 6, 'HorizontalAlignment', 'center');

    % Arrow 2: disturbance OFF (from t=350, y=0.4 to t=400, y=0.5)
    [x_off_tail, y_off_tail] = data_to_fig(350, 0.4);
    [x_off_tip, y_off_tip] = data_to_fig(400, 0.5);

    % Round time down (subtract 1 second)
    t_off_display = floor(t_off - 1);

    annotation('textarrow', [x_off_tail, x_off_tip], [y_off_tail, y_off_tip], ...
        'String', sprintf('d = 0\nt = %d s', t_off_display), ...
        'FontSize', 20, 'Color', [0.3 0.3 0.3], 'TextColor', [0 0 0], ...
        'HeadWidth', 8, 'HeadLength', 6, 'HorizontalAlignment', 'center');
end
