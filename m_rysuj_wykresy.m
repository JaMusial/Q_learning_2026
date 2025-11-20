%% m_rysuj_wykresy - Visualization of Q-learning control results
%
% Generates comprehensive plots comparing Q-controller vs Reference trajectory
% (and vs PI controller in verification mode)
%
% Features:
%   - Theme-neutral colors (works on both light and dark MATLAB themes)
%   - Proper figure sizing for readability
%   - Axis labels with units
%   - Safety checks for empty variables
%   - Refactored with helper functions to reduce code duplication
%
% Author: Jakub Musiał
% Modified: 2025-11-20 - Refactored to reduce duplication

%% ========================================================================
%%  CONFIGURATION
%% ========================================================================

% Define theme-neutral colors
colors = struct();
colors.Q = 'b';                           % Blue (Q-controller)
colors.Ref = [0.3010 0.7450 0.9330];      % Cyan (Reference trajectory)
colors.PI = [0.1 0.6 0.1];                % Green (PI controller)
colors.Reward = 'm';                       % Magenta (Reward markers)
colors.Target = [0.5 0.5 0.5];            % Gray (Target lines)
colors.Disturbance = [0.8500 0.3250 0.0980];  % Orange-Red (Disturbances)
colors.Alt = [0.4660 0.6740 0.1880];      % Yellow-Green (Alternative plots)
colors.Purple = [0.4940 0.1840 0.5560];   % Purple (Te normalized)
colors.Q_before = [0.3010 0.7450 0.9330]; % Cyan (Q before learning)
colors.Q_after = [1 0 0];                 % Red (Q after learning)
colors.Total = [1 0 0];                   % Red (Total/Maximum aggregated metrics)

%% ========================================================================
%%  DATA PREPARATION
%% ========================================================================

% Prepare reward markers for current logi
rewards = prepare_reward_markers(logi);

%% ========================================================================
%%  SINGLE ITERATION MODE (Q-controller only)
%% ========================================================================

if poj_iteracja_uczenia == 1

    %% Figure 1: Output, Control, Disturbance, Control Increment
    figure()

    % Output y
    subplot(4,1,1)
    plot_comparison(logi.Q_t, logi.Q_y, logi.Q_t, logi.Ref_y, rewards.y, ...
        [], [], 'Time [s]', 'Output y [%]', 'Process Variable y', ...
        {'Q-controller', 'Reference', 'Reward'}, colors);

    % Control signal u
    subplot(4,1,2)
    plot_comparison(logi.Q_t, logi.Q_u, [], [], rewards.u, ...
        [], [], 'Time [s]', 'Control Signal u [%]', 'Control Signal u', ...
        {'Q-controller', 'Reward'}, colors);

    % Disturbance information
    subplot(4,1,3)
    yyaxis left
    plot(logi.Q_t, logi.Q_czas_zaklocenia, 'Color', colors.Q, 'LineWidth', 1.5);
    ylabel('Disturbance Duration [samples]')
    yyaxis right
    plot(logi.Q_t, logi.Q_d, 'Color', colors.Disturbance, 'LineWidth', 1.5);
    ylabel('Load Disturbance d [%]')
    grid on
    xlabel('Time [s]')
    title('Disturbance Information')
    legend('Disturbance samples', 'Load disturbance d', 'Location', 'best')

    % Control increment
    subplot(4,1,4)
    plot(logi.Q_t, logi.Q_u_increment, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    yline(0, 'Color', colors.Target, 'LineWidth', 1);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('\Deltau [%]')
    title('Control Signal Increment \Deltau')

    %% Figure 2: State and Action Information
    figure()

    % State index
    subplot(4,1,1)
    plot_comparison(logi.Q_t, logi.Q_stan_nr, logi.Q_t, logi.Ref_stan_nr, rewards.stan_nr, ...
        [], [], 'Time [s]', 'State Index', 'Discrete State Index', ...
        {'Q-controller', 'Reference', 'Reward', 'Target state'}, colors);
    hold on
    yline(nr_stanu_doc, 'Color', colors.Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off

    % State value
    subplot(4,1,2)
    plot_comparison(logi.Q_t, logi.Q_stan_value, logi.Q_t, logi.Ref_stan_value, rewards.stan_val, ...
        [], [], 'Time [s]', 'State Value', 'Continuous State Value (s = e + (1/T_e) \cdot de)', ...
        {'Q-controller', 'Reference', 'Reward'}, colors);

    % Action index
    subplot(4,1,3)
    plot(logi.Q_t, logi.Q_akcja_nr, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    yline(nr_akcji_doc, 'Color', colors.Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Index')
    title('Selected Action Index')
    legend('Q action', 'Target action', 'Location', 'best')

    % Action value
    subplot(4,1,4)
    plot(logi.Q_t, logi.Q_akcja_value, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Q_akcja_value_bez_f_rzutujacej, 'Color', colors.Alt, 'LineWidth', 1.2);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Value')
    title('Action Value')
    legend('With projection function', 'Without projection function', 'Location', 'best')

    %% Figure 3: Error and Derivative Analysis
    figure()

    % Output y (repeated for context)
    subplot(4,1,1)
    plot_comparison(logi.Q_t, logi.Q_y, logi.Q_t, logi.Ref_y, rewards.y, ...
        [], [], 'Time [s]', 'Output y [%]', 'Process Variable y', ...
        {'Q-controller', 'Reference', 'Reward'}, colors);

    % Error
    subplot(4,1,2)
    plot_comparison(logi.Q_t, logi.Q_e, logi.Q_t, logi.Ref_e, rewards.e, ...
        [], [], 'Time [s]', 'Error e [%]', 'Control Error e = SP - y', ...
        {'Q-controller', 'Reference', 'Reward'}, colors);

    % Error derivative
    subplot(4,1,3)
    plot_comparison(logi.Q_t, logi.Q_de, logi.Q_t, logi.Ref_de, rewards.de, ...
        [], [], 'Time [s]', 'de [%/s]', 'Error Derivative de/dt', ...
        {'Q-controller', 'Reference', 'Reward'}, colors);

    % Alternative derivative
    subplot(4,1,4)
    plot_comparison(logi.Q_t, logi.Q_de2, logi.Q_t, logi.Ref_de2, rewards.de2, ...
        [], [], 'Time [s]', 'de2', 'de2 (Alternative Error Derivative)', ...
        {'Q-controller', 'Reference', 'Reward'}, colors);

    %% Figure 4: MNK Analysis (if available)
    plot_mnk_analysis(colors);

%% ========================================================================
%%  VERIFICATION MODE (Q-controller vs PI controller)
%% ========================================================================

else

    %% ====================================================================
    %%  BEFORE LEARNING: Detailed Comparison (if data available)
    %% ====================================================================

    if exist('logi_before_learning', 'var') && licz_wskazniki == 0
        rewards_before = prepare_reward_markers(logi_before_learning);

        % Figure 1 (Before): Output, Control, Disturbance
        plot_verification_figure1(logi_before_learning, rewards_before, 'BEFORE LEARNING', colors);

        % Figure 2 (Before): State and Action
        plot_verification_figure2(logi_before_learning, rewards_before, 'BEFORE LEARNING', colors, nr_stanu_doc, nr_akcji_doc);

        % Figure 3 (Before): Error and Derivative
        plot_verification_figure3(logi_before_learning, rewards_before, 'BEFORE LEARNING', colors);
    end

    %% ====================================================================
    %%  AFTER LEARNING: Detailed Comparison
    %% ====================================================================

    % Figure 1 (After): Output, Control, Disturbance
    plot_verification_figure1(logi, rewards, 'AFTER LEARNING', colors);

    % Figure 2 (After): State and Action
    plot_verification_figure2(logi, rewards, 'AFTER LEARNING', colors, nr_stanu_doc, nr_akcji_doc);

    % Figure 3 (After): Error and Derivative
    plot_verification_figure3(logi, rewards, 'AFTER LEARNING', colors);

    % Figure 4: MNK Analysis (if available)
    plot_mnk_analysis(colors);

    %% ====================================================================
    %%  VERIFICATION: Q-before vs PI vs Q-after Learning Comparison
    %% ====================================================================

    if exist('logi_before_learning', 'var') && licz_wskazniki == 0
        figure()

        % Output comparison
        subplot(2,1,1)
        plot(logi_before_learning.Q_t, logi_before_learning.Q_y, 'Color', colors.Q_before, 'LineWidth', 1.5)
        hold on
        if isfield(logi, 'PID_t') && ~isempty(logi.PID_t) && sum(logi.PID_y) > 0
            plot(logi.PID_t, logi.PID_y, 'Color', colors.PI, 'LineWidth', 1.5)
        end
        plot(logi.Q_t, logi.Q_y, 'Color', colors.Q_after, 'LineWidth', 1.5)
        yline(SP_ini, '--', 'Color', colors.Target, 'LineWidth', 1.5)
        hold off
        grid on
        xlabel('Time [s]')
        ylabel('Output y [%]')
        title('Process Variable y - Comparison: Q-before vs PI vs Q-after Learning')
        if isfield(logi, 'PID_t') && ~isempty(logi.PID_t) && sum(logi.PID_y) > 0
            legend('Q-learning (before)', 'PI controller', 'Q-learning (after)', 'Setpoint', 'Location', 'best')
        else
            legend('Q-learning (before)', 'Q-learning (after)', 'Setpoint', 'Location', 'best')
        end

        % Control signal comparison
        subplot(2,1,2)
        plot(logi_before_learning.Q_t, logi_before_learning.Q_u, 'Color', colors.Q_before, 'LineWidth', 1.5)
        hold on
        if isfield(logi, 'PID_t') && ~isempty(logi.PID_t) && sum(logi.PID_u) > 0
            plot(logi.PID_t, logi.PID_u, 'Color', colors.PI, 'LineWidth', 1.5)
        end
        plot(logi.Q_t, logi.Q_u, 'Color', colors.Q_after, 'LineWidth', 1.5)
        hold off
        grid on
        xlabel('Time [s]')
        ylabel('Control Signal u [%]')
        title('Control Signal u - Comparison: Q-before vs PI vs Q-after Learning')
        if isfield(logi, 'PID_t') && ~isempty(logi.PID_t) && sum(logi.PID_u) > 0
            legend('Q-learning (before)', 'PI controller', 'Q-learning (after)', 'Location', 'best')
        else
            legend('Q-learning (before)', 'Q-learning (after)', 'Location', 'best')
        end
    end

    %% ====================================================================
    %%  LEARNING PROCESS PARAMETERS
    %% ====================================================================

    if exist('inf_zakonczono_epoke_stabil_old', 'var') && exist('czas_uczenia_calkowity', 'var')
        figure()

        % Stabilization percentage
        subplot(4,1,1)
        plot_learning_metric_simple('proc_stab_wek', probkowanie_dane_symulacji, ...
            'Epoch', 'Stabilization [%]', ...
            'Percentage of Epochs Ending in Stabilization (per 100-epoch group)', ...
            100, colors.Q, epoka, inf_zakonczono_epoke_stabil);

        % Learning time
        subplot(4,1,2)
        plot_learning_metric_simple('czas_uczenia_wek', probkowanie_dane_symulacji, ...
            'Epoch', 'Time [s]', ...
            sprintf('Learning Time per %d Epochs', probkowanie_dane_symulacji), ...
            1, colors.Disturbance, [], czas_uczenia_calkowity);

        % Q-matrix norm differences
        subplot(4,1,3)
        if exist('max_macierzy_Q', 'var') && length(max_macierzy_Q) > 1
            norm_diff = diff(max_macierzy_Q);
            plot(norm_diff, 'Color', colors.Alt, 'LineWidth', 1.5)
            grid on
            xlabel('Sample')
            ylabel('\Delta||Q||')
            title('Q-matrix Norm Differences (Convergence Indicator)')
        end

        % Q-matrix norm evolution
        subplot(4,1,4)
        if exist('max_macierzy_Q', 'var') && ~isempty(max_macierzy_Q)
            plot(max_macierzy_Q, 'Color', colors.Purple, 'LineWidth', 1.5)
            grid on
            xlabel('Sample')
            ylabel('||Q||')
            title('Q-matrix Norm Evolution')
        end
    end

    %% ====================================================================
    %%  PERFORMANCE METRICS (Evolution during Learning)
    %% ====================================================================

    if exist('IAE_wek', 'var') && ~isempty(IAE_wek) && size(IAE_wek, 1) > 1
        figure()

        % IAE evolution
        subplot(4,1,1)
        plot_metric_evolution(IAE_wek, probkowanie_norma_macierzy, ...
            'Epoch', 'IAE', 'Integral Absolute Error (IAE) Evolution During Learning', ...
            {'Total', 'Phase 1: Setpoint tracking', 'Phase 2: Disturbance rejection', 'Phase 3: Recovery'}, ...
            colors, 'sum');

        % Overshoot evolution
        subplot(4,1,2)
        if exist('maks_przereg_wek', 'var') && ~isempty(maks_przereg_wek)
            plot_metric_evolution(maks_przereg_wek, probkowanie_norma_macierzy, ...
                'Epoch', 'Overshoot [%]', 'Maximum Overshoot Evolution During Learning', ...
                {'Maximum', 'Phase 1', 'Phase 2', 'Phase 3'}, ...
                colors, 'max');
        end

        % Settling time evolution
        subplot(4,1,3)
        if exist('czas_regulacji_wek', 'var') && ~isempty(czas_regulacji_wek)
            plot_metric_evolution(czas_regulacji_wek, probkowanie_norma_macierzy, ...
                'Epoch', 'Settling Time [s]', 'Settling Time Evolution During Learning', ...
                {'Maximum', 'Phase 1', 'Phase 2', 'Phase 3'}, ...
                colors, 'max');
        end

        % Trajectory realization
        subplot(4,1,4)
        if exist('wek_proc_realizacji', 'var') && ~isempty(wek_proc_realizacji)
            plot(wek_proc_realizacji, 'Color', colors.Purple, 'LineWidth', 1.5)
            grid on
            xlabel('Epoch')
            ylabel('Realization [%]')
            title('Trajectory Realization Percentage Evolution')
        end
    end

end

%% ========================================================================
%%  HELPER FUNCTIONS
%% ========================================================================

function rewards = prepare_reward_markers(logi_data)
    % Prepare all reward markers by masking non-reward samples with NaN
    fields = {'y', 'u', 'e', 'de', 'de2', 'stan_val', 'stan_nr'};
    field_map = struct('y', 'Q_y', 'u', 'Q_u', 'e', 'Q_e', 'de', 'Q_de', ...
                       'de2', 'Q_de2', 'stan_val', 'Q_stan_value', 'stan_nr', 'Q_stan_nr');

    for i = 1:length(fields)
        fname = fields{i};
        data_field = field_map.(fname);
        if isfield(logi_data, data_field) && isfield(logi_data, 'Q_R')
            rewards.(fname) = logi_data.(data_field) .* logi_data.Q_R;
            rewards.(fname)(rewards.(fname) == 0) = NaN;
        else
            rewards.(fname) = [];
        end
    end
end

function plot_comparison(t_Q, data_Q, t_Ref, data_Ref, reward_data, ...
                        t_PI, data_PI, xlabel_str, ylabel_str, title_str, ...
                        legend_entries, colors)
    % Generic comparison plot with Q, Reference, Reward markers, and optional PI
    hold on

    % Plot Q data
    if ~isempty(data_Q)
        plot(t_Q, data_Q, 'Color', colors.Q, 'LineWidth', 1.5)
    end

    % Plot Reference data
    if ~isempty(data_Ref)
        plot(t_Ref, data_Ref, 'Color', colors.Ref, 'LineWidth', 1.2)
    end

    % Plot reward markers
    if ~isempty(reward_data)
        plot(t_Q, reward_data, '|', 'Color', colors.Reward, 'MarkerSize', 8)
    end

    % Plot PI data (optional)
    if ~isempty(t_PI) && ~isempty(data_PI)
        plot(t_PI, data_PI, 'Color', colors.PI, 'LineWidth', 1.5)
    end

    hold off
    grid on
    xlabel(xlabel_str)
    ylabel(ylabel_str)
    title(title_str)
    if ~isempty(legend_entries)
        legend(legend_entries, 'Location', 'best')
    end
end

function plot_verification_figure1(logi_data, rewards, phase_str, colors)
    % Figure 1: Output, Control, Disturbance - Verification mode
    figure()

    % Check if PI data exists
    has_PI = isfield(logi_data, 'PID_t') && ~isempty(logi_data.PID_t);

    % Output y
    subplot(4,1,1)
    plot(logi_data.Q_t, logi_data.Q_y, 'Color', colors.Q, 'LineWidth', 1.5)
    hold on
    plot(logi_data.Q_t, logi_data.Ref_y, 'Color', colors.Ref, 'LineWidth', 1.2)
    plot(logi_data.Q_t, rewards.y, '|', 'Color', colors.Reward, 'MarkerSize', 8)
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_y, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Output y [%]')
    title(sprintf('Process Variable y - Q vs PI (%s)', phase_str))
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    % Control signal u
    subplot(4,1,2)
    plot(logi_data.Q_t, logi_data.Q_u, 'Color', colors.Q, 'LineWidth', 1.5)
    hold on
    plot(logi_data.Q_t, rewards.u, '|', 'Color', colors.Reward, 'MarkerSize', 8)
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_u, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Control Signal u [%]')
    title(sprintf('Control Signal u - Q vs PI (%s)', phase_str))
    legend('Q-controller', 'Reward', 'PI controller', 'Location', 'best')

    % Control increment and disturbance
    subplot(4,1,3)
    yyaxis left
    plot(logi_data.Q_t, logi_data.Q_u_increment, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_u_increment, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    hold off
    ylabel('Control Increment \Deltau [%]')
    yyaxis right
    plot(logi_data.Q_t, logi_data.Q_d, 'Color', colors.Disturbance, 'LineWidth', 1.5);
    ylabel('Load Disturbance d [%]')
    grid on
    xlabel('Time [s]')
    title(sprintf('Control Increment and Load Disturbance (%s)', phase_str))
    legend('Q increment', 'PI increment', 'Disturbance d', 'Location', 'best')

    % Projection function
    subplot(4,1,4)
    plot(logi_data.Q_t, logi_data.Q_funkcja_rzut, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    yline(0, 'Color', colors.Target, 'LineWidth', 1);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Projection Function Value')
    title(sprintf('Projection Function (%s)', phase_str))
end

function plot_verification_figure2(logi_data, rewards, phase_str, colors, nr_stanu_doc, nr_akcji_doc)
    % Figure 2: State and Action - Verification mode
    figure()

    has_PI = isfield(logi_data, 'PID_t') && ~isempty(logi_data.PID_t);

    % State index
    subplot(4,1,1)
    plot(logi_data.Q_t, logi_data.Q_stan_nr, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    plot(logi_data.Q_t, logi_data.Ref_stan_nr, 'Color', colors.Ref, 'LineWidth', 1.2);
    plot(logi_data.Q_t, rewards.stan_nr, '|', 'Color', colors.Reward, 'MarkerSize', 8);
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_stan_nr, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    yline(nr_stanu_doc, 'Color', colors.Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Index')
    title(sprintf('Discrete State Index - Q vs PI (%s)', phase_str))
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Target state', 'Location', 'best');

    % State value
    subplot(4,1,2)
    plot(logi_data.Q_t, logi_data.Q_stan_value, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    plot(logi_data.Q_t, logi_data.Ref_stan_value, 'Color', colors.Ref, 'LineWidth', 1.2)
    plot(logi_data.Q_t, rewards.stan_val, '|', 'Color', colors.Reward, 'MarkerSize', 8);
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_stan_value, 'Color', colors.PI, 'LineWidth', 1.5);
    end
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Value')
    title(sprintf('Continuous State Value - Q vs PI (%s)', phase_str))
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    % Action index
    subplot(4,1,3)
    plot(logi_data.Q_t, logi_data.Q_akcja_nr, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_akcja_nr, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    yline(nr_akcji_doc, 'Color', colors.Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Index')
    title(sprintf('Selected Action Index - Q vs PI (%s)', phase_str))
    legend('Q action', 'PI action', 'Target action', 'Location', 'best')

    % Action value
    subplot(4,1,4)
    plot(logi_data.Q_t, logi_data.Q_akcja_value, 'Color', colors.Q, 'LineWidth', 1.5);
    hold on
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_akcja_value, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Value')
    title(sprintf('Action Value - Q vs PI (%s)', phase_str))
    legend('Q-controller', 'PI controller', 'Location', 'best')
end

function plot_verification_figure3(logi_data, rewards, phase_str, colors)
    % Figure 3: Error and Derivative - Verification mode
    figure()

    has_PI = isfield(logi_data, 'PID_t') && ~isempty(logi_data.PID_t);

    % Error
    subplot(4,1,1)
    plot(logi_data.Q_t, logi_data.Q_e, 'Color', colors.Q, 'LineWidth', 1.5)
    hold on
    plot(logi_data.Q_t, logi_data.Ref_e, 'Color', colors.Ref, 'LineWidth', 1.2)
    plot(logi_data.Q_t, rewards.e, '|', 'Color', colors.Reward, 'MarkerSize', 8)
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_e, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Error e [%]')
    title(sprintf('Control Error e = SP - y (%s)', phase_str))
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    % Setpoint
    subplot(4,1,2)
    if isfield(logi_data, 'Q_SP') && ~isempty(logi_data.Q_SP)
        plot(logi_data.Q_t, logi_data.Q_SP, 'Color', colors.Target, 'LineWidth', 1.5, 'LineStyle', '--')
    end
    grid on
    xlabel('Time [s]')
    ylabel('Setpoint SP [%]')
    title(sprintf('Setpoint Changes (%s)', phase_str))

    % Error derivative
    subplot(4,1,3)
    plot(logi_data.Q_t, logi_data.Q_de, 'Color', colors.Q, 'LineWidth', 1.5)
    hold on
    plot(logi_data.Q_t, logi_data.Ref_de, 'Color', colors.Ref, 'LineWidth', 1.2)
    plot(logi_data.Q_t, rewards.de, '|', 'Color', colors.Reward, 'MarkerSize', 8)
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_de, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de [%/s]')
    title(sprintf('Error Derivative de/dt (%s)', phase_str))
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    % Alternative derivative
    subplot(4,1,4)
    plot(logi_data.Q_t, logi_data.Q_de2, 'Color', colors.Q, 'LineWidth', 1.5)
    hold on
    plot(logi_data.Q_t, logi_data.Ref_de2, 'Color', colors.Ref, 'LineWidth', 1.2)
    plot(logi_data.Q_t, rewards.de2, '|', 'Color', colors.Reward, 'MarkerSize', 8)
    if has_PI
        plot(logi_data.PID_t, logi_data.PID_de2, 'Color', colors.PI, 'LineWidth', 1.5)
    end
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de2')
    title(sprintf('de2 (Alternative Error Derivative) (%s)', phase_str))
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')
end

function plot_mnk_analysis(colors)
    % MNK Analysis plots (if data available)
    % Access variables from base workspace
    if evalin('base', 'exist(''wsp_mnk'', ''var'')') == 0
        return;
    end

    wsp_mnk = evalin('base', 'wsp_mnk');
    if isempty(wsp_mnk)
        return;
    end

    figure()

    % Learning progress metrics
    subplot(4,1,1)
    wek_proc_realizacji = evalin('base', 'wek_proc_realizacji');
    filtr_mnk = evalin('base', 'filtr_mnk');
    wek_Te = evalin('base', 'wek_Te');

    plot(wek_proc_realizacji, 'Color', colors.Q, 'LineWidth', 1.5)
    hold on
    plot(filtr_mnk, 'Color', colors.Disturbance, 'LineWidth', 1.5)
    plot(wek_Te/max(wek_Te), 'Color', colors.Purple, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Epoch')
    ylabel('Normalized Value')
    title('Learning Progress Metrics')
    legend('Trajectory realization %', 'MNK filter', 'T_e normalized', 'Location', 'best');

    % MNK coefficient a
    subplot(4,1,2)
    plot(wsp_mnk(1,:), 'Color', colors.Q, 'LineWidth', 1.5);
    grid on
    xlabel('Epoch')
    ylabel('Coefficient a')
    title('MNK Coefficient a (Slope)')

    % MNK coefficient b
    subplot(4,1,3)
    plot(wsp_mnk(2,:), 'Color', colors.Disturbance, 'LineWidth', 1.5);
    grid on
    xlabel('Epoch')
    ylabel('Coefficient b')
    title('MNK Coefficient b (Intercept)')

    % MNK coefficient c
    subplot(4,1,4)
    plot(wsp_mnk(3,:), 'Color', colors.Alt, 'LineWidth', 1.5);
    grid on
    xlabel('Epoch')
    ylabel('Coefficient c')
    title('MNK Coefficient c')
end

function plot_learning_metric_simple(var_name, sampling_period, ...
        xlabel_str, ylabel_str, title_str, scale_factor, color, ...
        total_epochs, fallback_value)
    % Plot simple learning metric with fallback to bar chart
    if evalin('base', sprintf('exist(''%s'', ''var'')', var_name)) && ...
       evalin('base', sprintf('length(%s) > 1', var_name))
        data = evalin('base', var_name);
        x_epochs = (1:length(data)) * sampling_period;
        plot(x_epochs, data * scale_factor, 'Color', color, 'LineWidth', 1.5, 'Marker', 'o')
        grid on
        xlabel(xlabel_str)
        ylabel(ylabel_str)
        title(title_str)
    elseif ~isempty(total_epochs) && total_epochs > 0
        % Fallback for stabilization percentage
        stabil_percent = (fallback_value / (total_epochs - 1)) * 100;
        bar(stabil_percent, 'FaceColor', color)
        grid on
        ylabel(ylabel_str)
        title(sprintf('Stabilization: %.1f%% (%d/%d epochs)', ...
            stabil_percent, fallback_value, total_epochs - 1))
    elseif ~isempty(fallback_value)
        % Fallback for learning time
        bar(fallback_value, 'FaceColor', color)
        grid on
        ylabel(ylabel_str)
        title(sprintf('Total Learning Time: %.2f s', fallback_value))
    end
end

function plot_metric_evolution(metric_data, sampling_period, ...
        xlabel_str, ylabel_str, title_str, legend_entries, colors, aggregation)
    % Plot metric evolution with multi-phase breakdown
    x_epochs = (1:size(metric_data, 1)) * sampling_period;

    if size(metric_data, 2) >= 3
        % Compute aggregated metric (sum or max)
        if strcmp(aggregation, 'sum')
            metric_total = sum(metric_data, 2);
        else  % 'max'
            metric_total = max(metric_data, [], 2);
        end

        % Plot total/maximum
        plot(x_epochs, metric_total, 'Color', colors.Total, 'LineWidth', 2, ...
             'Marker', 'o', 'DisplayName', legend_entries{1})
        hold on

        % Plot individual phases
        plot(x_epochs, metric_data(:,1), 'Color', colors.Q, 'LineWidth', 1.2, ...
             'Marker', '^', 'LineStyle', '--', 'DisplayName', legend_entries{2})
        plot(x_epochs, metric_data(:,2), 'Color', colors.Disturbance, 'LineWidth', 1.2, ...
             'Marker', 's', 'LineStyle', '--', 'DisplayName', legend_entries{3})
        plot(x_epochs, metric_data(:,3), 'Color', colors.Alt, 'LineWidth', 1.2, ...
             'Marker', 'd', 'LineStyle', '--', 'DisplayName', legend_entries{4})
        hold off
    else
        % Single metric plot
        plot(x_epochs, metric_data, 'Color', colors.Q, 'LineWidth', 1.5, 'Marker', 'o')
    end

    grid on
    xlabel(xlabel_str)
    ylabel(ylabel_str)
    title(title_str)
    legend('Location', 'best')
end
