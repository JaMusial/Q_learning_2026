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
%
% Author: Jakub Musiał
% Modified: 2025-11-19

% Define theme-neutral colors
color_Q = 'b';                           % Blue (Q-controller)
color_Ref = [0.3010 0.7450 0.9330];     % Cyan (Reference trajectory)
color_PI = [0.1 0.6 0.1];               % Green (PI controller)
color_Reward = 'm';                      % Magenta (Reward markers)
color_Target = [0.5 0.5 0.5];           % Gray (Target lines)
color_Disturbance = [0.8500 0.3250 0.0980];  % Orange-Red (Disturbances)
color_Alt = [0.4660 0.6740 0.1880];     % Yellow-Green (Alternative plots)
color_Purple = [0.4940 0.1840 0.5560];  % Purple (Te normalized)
color_Q_before = [0.3010 0.7450 0.9330];  % Cyan (Q before learning)
color_Q_after = [1 0 0];                  % Red (Q after learning)

% Prepare reward markers (set zeros to NaN for cleaner visualization)
nagroda_y = logi.Q_y .* logi.Q_R;
nagroda_y(nagroda_y==0) = NaN;
nagroda_u = logi.Q_u .* logi.Q_R;
nagroda_u(nagroda_u==0) = NaN;
nagroda_e = logi.Q_e .* logi.Q_R;
nagroda_e(nagroda_e==0) = NaN;
nagroda_de = logi.Q_de .* logi.Q_R;
nagroda_de(nagroda_de==0) = NaN;
nagroda_de2 = logi.Q_de2 .* logi.Q_R;
nagroda_de2(nagroda_de2==0) = NaN;
nagroda_stan_val = logi.Q_stan_value .* logi.Q_R;
nagroda_stan_val(nagroda_stan_val==0) = NaN;
nagroda_stan_nr = logi.Q_stan_nr .* logi.Q_R;
nagroda_stan_nr(nagroda_stan_nr==0) = NaN;

%% ========================================================================
%%  SINGLE ITERATION MODE (Q-controller only)
%% ========================================================================

if poj_iteracja_uczenia == 1

    %% Figure 1: Output, Control, Disturbance, Control Increment
    figure()

    subplot(4,1,1)
    plot(logi.Q_t, logi.Q_y, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_y, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_y, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Output y [%]')
    title('Process Variable y')
    legend('Q-controller', 'Reference', 'Reward', 'Location', 'best')

    subplot(4,1,2)
    plot(logi.Q_t, logi.Q_u, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, nagroda_u, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Control Signal u [%]')
    title('Control Signal u')
    legend('Q-controller', 'Reward', 'Location', 'best')

    subplot(4,1,3)
    yyaxis left
    plot(logi.Q_t, logi.Q_czas_zaklocenia, 'Color', color_Q, 'LineWidth', 1.5);
    ylabel('Disturbance Duration [samples]')
    yyaxis right
    plot(logi.Q_t, logi.Q_d, 'Color', color_Disturbance, 'LineWidth', 1.5);
    ylabel('Load Disturbance d [%]')
    grid on
    xlabel('Time [s]')
    title('Disturbance Information')
    legend('Disturbance samples', 'Load disturbance d', 'Location', 'best')

    subplot(4,1,4)
    plot(logi.Q_t, logi.Q_u_increment, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    yline(0, 'Color', color_Target, 'LineWidth', 1);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('\Deltau [%]')
    title('Control Signal Increment \Deltau')

    %% Figure 2: State and Action Information
    figure()

    subplot(4,1,1)
    plot(logi.Q_t, logi.Q_stan_nr, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Ref_stan_nr, 'Color', color_Ref, 'LineWidth', 1.2);
    plot(logi.Q_t, nagroda_stan_nr, '|', 'Color', color_Reward, 'MarkerSize', 8);
    yline(nr_stanu_doc, 'Color', color_Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Index')
    title('Discrete State Index')
    legend('Q-controller', 'Reference', 'Reward', 'Target state', 'Location', 'best');

    subplot(4,1,2)
    plot(logi.Q_t, logi.Q_stan_value, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Ref_stan_value, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_stan_val, '|', 'Color', color_Reward, 'MarkerSize', 8);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Value')
    title('Continuous State Value (s = e + (1/T_e) \cdot de)')
    legend('Q-controller', 'Reference', 'Reward', 'Location', 'best')

    subplot(4,1,3)
    plot(logi.Q_t, logi.Q_akcja_nr, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    yline(nr_akcji_doc, 'Color', color_Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Index')
    title('Selected Action Index')
    legend('Q action', 'Target action', 'Location', 'best')

    subplot(4,1,4)
    plot(logi.Q_t, logi.Q_akcja_value, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Q_akcja_value_bez_f_rzutujacej, 'Color', color_Alt, 'LineWidth', 1.2);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Value')
    title('Action Value')
    legend('With projection function', 'Without projection function', 'Location', 'best')

    %% Figure 3: Error and Derivative Analysis
    figure()

    subplot(4,1,1)
    plot(logi.Q_t, logi.Q_y, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_y, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_y, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Output y [%]')
    title('Process Variable y')
    legend('Q-controller', 'Reference', 'Reward', 'Location', 'best')

    subplot(4,1,2)
    plot(logi.Q_t, logi.Q_e, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_e, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_e, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Error e [%]')
    title('Control Error e = SP - y')
    legend('Q-controller', 'Reference', 'Reward', 'Location', 'best')

    subplot(4,1,3)
    plot(logi.Q_t, logi.Q_de, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_de, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_de, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de [%/s]')
    title('Error Derivative de/dt')
    legend('Q-controller', 'Reference', 'Reward', 'Location', 'best')

    subplot(4,1,4)
    plot(logi.Q_t, logi.Q_de2, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_de2, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_de2, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de2')
    title('de2 (Alternative Error Derivative)')
    legend('Q-controller', 'Reference', 'Reward', 'Location', 'best')

    %% Figure 4: MNK Analysis (if available)
    if ~isempty(wsp_mnk)
        figure()

        subplot(4,1,1)
        plot(wek_proc_realizacji, 'Color', color_Q, 'LineWidth', 1.5)
        hold on
        plot(filtr_mnk, 'Color', color_Disturbance, 'LineWidth', 1.5)
        plot(wek_Te/max(wek_Te), 'Color', color_Purple, 'LineWidth', 1.5)
        hold off
        grid on
        xlabel('Epoch')
        ylabel('Normalized Value')
        title('Learning Progress Metrics')
        legend('Trajectory realization %', 'MNK filter', 'T_e normalized', 'Location', 'best');

        subplot(4,1,2)
        plot(wsp_mnk(1,:), 'Color', color_Q, 'LineWidth', 1.5);
        grid on
        xlabel('Epoch')
        ylabel('Coefficient a')
        title('MNK Coefficient a (Slope)')

        subplot(4,1,3)
        plot(wsp_mnk(2,:), 'Color', color_Disturbance, 'LineWidth', 1.5);
        grid on
        xlabel('Epoch')
        ylabel('Coefficient b')
        title('MNK Coefficient b (Intercept)')

        subplot(4,1,4)
        plot(wsp_mnk(3,:), 'Color', color_Alt, 'LineWidth', 1.5);
        grid on
        xlabel('Epoch')
        ylabel('Coefficient c')
        title('MNK Coefficient c')
    end

%% ========================================================================
%%  VERIFICATION MODE (Q-controller vs PI controller)
%% ========================================================================

else

    %% Figure 1: Output, Control, Disturbance (Q vs PI)
    figure()

    subplot(4,1,1)
    plot(logi.Q_t, logi.Q_y, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_y, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_y, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_y, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Output y [%]')
    title('Process Variable y - Q vs PI Comparison')
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    subplot(4,1,2)
    plot(logi.Q_t, logi.Q_u, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, nagroda_u, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_u, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Control Signal u [%]')
    title('Control Signal u - Q vs PI Comparison')
    legend('Q-controller', 'Reward', 'PI controller', 'Location', 'best')

    subplot(4,1,3)
    yyaxis left
    plot(logi.Q_t, logi.Q_u_increment, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.PID_t, logi.PID_u_increment, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    ylabel('Control Increment \Deltau [%]')
    yyaxis right
    plot(logi.Q_t, logi.Q_d, 'Color', color_Disturbance, 'LineWidth', 1.5);
    ylabel('Load Disturbance d [%]')
    grid on
    xlabel('Time [s]')
    title('Control Increment and Load Disturbance')
    legend('Q increment', 'PI increment', 'Disturbance d', 'Location', 'best')

    subplot(4,1,4)
    plot(logi.Q_t, logi.Q_funkcja_rzut, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    yline(0, 'Color', color_Target, 'LineWidth', 1);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Projection Function Value')
    title('Projection Function (Stability Enhancement)')

    %% Figure 2: State and Action (Q vs PI)
    figure()

    subplot(4,1,1)
    plot(logi.Q_t, logi.Q_stan_nr, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Ref_stan_nr, 'Color', color_Ref, 'LineWidth', 1.2);
    plot(logi.Q_t, nagroda_stan_nr, '|', 'Color', color_Reward, 'MarkerSize', 8);
    plot(logi.PID_t, logi.PID_stan_nr, 'Color', color_PI, 'LineWidth', 1.5)
    yline(nr_stanu_doc, 'Color', color_Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Index')
    title('Discrete State Index - Q vs PI')
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Target state', 'Location', 'best');

    subplot(4,1,2)
    plot(logi.Q_t, logi.Q_stan_value, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Ref_stan_value, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_stan_val, '|', 'Color', color_Reward, 'MarkerSize', 8);
    plot(logi.PID_t, logi.PID_akcja_value, 'Color', color_PI, 'LineWidth', 1.5);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Value')
    title('Continuous State Value - Q vs PI')
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    subplot(4,1,3)
    plot(logi.Q_t, logi.Q_akcja_nr, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.PID_t, logi.PID_akcja_nr, 'Color', color_PI, 'LineWidth', 1.5)
    yline(nr_akcji_doc, 'Color', color_Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Index')
    title('Selected Action Index - Q vs PI')
    legend('Q action', 'PI action', 'Target action', 'Location', 'best')

    subplot(4,1,4)
    plot(logi.Q_t, logi.Q_akcja_value, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.PID_t, logi.PID_akcja_value, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Value')
    title('Action Value - Q vs PI')
    legend('Q-controller', 'PI controller', 'Location', 'best')

    %% Figure 3: Error and Derivative (Q vs PI)
    figure()

    subplot(4,1,1)
    plot(logi.Q_t, logi.Q_y, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_y, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_y, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_y, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Output y [%]')
    title('Process Variable y')
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    subplot(4,1,2)
    plot(logi.Q_t, logi.Q_e, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_e, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_e, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_e, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Error e [%]')
    title('Control Error e = SP - y')
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    subplot(4,1,3)
    plot(logi.Q_t, logi.Q_de, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_de, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_de, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_de, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de [%/s]')
    title('Error Derivative de/dt')
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    subplot(4,1,4)
    plot(logi.Q_t, logi.Q_de2, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_de2, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_de2, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_de2, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de2')
    title('de2 (Alternative Error Derivative)')
    legend('Q-controller', 'Reference', 'Reward', 'PI controller', 'Location', 'best')

    %% Figure 4: MNK Analysis (if available)
    if ~isempty(wsp_mnk)
        figure()

        subplot(4,1,1)
        plot(wek_proc_realizacji, 'Color', color_Q, 'LineWidth', 1.5)
        hold on
        plot(filtr_mnk, 'Color', color_Disturbance, 'LineWidth', 1.5)
        plot(wek_Te/max(wek_Te), 'Color', color_Purple, 'LineWidth', 1.5)
        hold off
        grid on
        xlabel('Epoch')
        ylabel('Normalized Value')
        title('Learning Progress Metrics')
        legend('Trajectory realization %', 'MNK filter', 'T_e normalized', 'Location', 'best');

        subplot(4,1,2)
        plot(wsp_mnk(1,:), 'Color', color_Q, 'LineWidth', 1.5);
        grid on
        xlabel('Epoch')
        ylabel('Coefficient a')
        title('MNK Coefficient a (Slope)')

        subplot(4,1,3)
        plot(wsp_mnk(2,:), 'Color', color_Disturbance, 'LineWidth', 1.5);
        grid on
        xlabel('Epoch')
        ylabel('Coefficient b')
        title('MNK Coefficient b (Intercept)')

        subplot(4,1,4)
        plot(wsp_mnk(3,:), 'Color', color_Alt, 'LineWidth', 1.5);
        grid on
        xlabel('Epoch')
        ylabel('Coefficient c')
        title('MNK Coefficient c')
    end

    %% ====================================================================
    %%  VERIFICATION: Q-before vs PI vs Q-after Learning Comparison
    %% ====================================================================

    if exist('logi_before_learning', 'var') && licz_wskazniki == 0
        figure()

        subplot(2,1,1)
        plot(logi_before_learning.Q_t, logi_before_learning.Q_y, 'Color', color_Q_before, 'LineWidth', 1.5)
        hold on
        if isfield(logi, 'PID_t') && ~isempty(logi.PID_t) && sum(logi.PID_y) > 0
            plot(logi.PID_t, logi.PID_y, 'Color', color_PI, 'LineWidth', 1.5)
        end
        plot(logi.Q_t, logi.Q_y, 'Color', color_Q_after, 'LineWidth', 1.5)
        yline(SP_ini, '--', 'Color', color_Target, 'LineWidth', 1.5)
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

        subplot(2,1,2)
        plot(logi_before_learning.Q_t, logi_before_learning.Q_u, 'Color', color_Q_before, 'LineWidth', 1.5)
        hold on
        if isfield(logi, 'PID_t') && ~isempty(logi.PID_t) && sum(logi.PID_u) > 0
            plot(logi.PID_t, logi.PID_u, 'Color', color_PI, 'LineWidth', 1.5)
        end
        plot(logi.Q_t, logi.Q_u, 'Color', color_Q_after, 'LineWidth', 1.5)
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

        % Percent stabilization per epoch
        subplot(4,1,1)
        if exist('proc_stabil_per_epoch', 'var') && ~isempty(proc_stabil_per_epoch)
            plot(proc_stabil_per_epoch, 'Color', color_Q, 'LineWidth', 1.5)
            grid on
            xlabel('Epoch Group')
            ylabel('Stabilization [%]')
            title('Percentage of Epochs Ending in Stabilization')
        else
            % Calculate from available data if vector doesn't exist
            total_epochs = epoka - 1;
            if total_epochs > 0
                stabil_percent = (inf_zakonczono_epoke_stabil / total_epochs) * 100;
                bar(stabil_percent, 'FaceColor', color_Q)
                grid on
                ylabel('Stabilization [%]')
                title(sprintf('Stabilization: %.1f%% (%d/%d epochs)', ...
                    stabil_percent, inf_zakonczono_epoke_stabil, total_epochs))
            end
        end

        % Learning time per epoch
        subplot(4,1,2)
        if exist('learning_time_per_epoch', 'var') && ~isempty(learning_time_per_epoch)
            plot(learning_time_per_epoch, 'Color', color_Disturbance, 'LineWidth', 1.5)
            grid on
            xlabel('Epoch Group')
            ylabel('Time [s]')
            title('Learning Time per Epoch')
        else
            % Show total learning time
            bar(czas_uczenia_calkowity, 'FaceColor', color_Disturbance)
            grid on
            ylabel('Time [s]')
            title(sprintf('Total Learning Time: %.2f s', czas_uczenia_calkowity))
        end

        % Q-matrix norm differences
        subplot(4,1,3)
        if exist('max_macierzy_Q', 'var') && length(max_macierzy_Q) > 1
            % Plot differences between consecutive samples
            norm_diff = diff(max_macierzy_Q);
            plot(norm_diff, 'Color', color_Alt, 'LineWidth', 1.5)
            grid on
            xlabel('Sample')
            ylabel('\Delta||Q||')
            title('Q-matrix Norm Differences (Convergence Indicator)')
        end

        % Max Q-values over time
        subplot(4,1,4)
        if exist('max_macierzy_Q', 'var') && ~isempty(max_macierzy_Q)
            plot(max_macierzy_Q, 'Color', color_Purple, 'LineWidth', 1.5)
            grid on
            xlabel('Sample')
            ylabel('||Q||')
            title('Q-matrix Norm Evolution')
        end
    end

    %% ====================================================================
    %%  PERFORMANCE METRICS
    %% ====================================================================

    if exist('IAE_wek', 'var') && ~isempty(IAE_wek)
        figure()

        % IAE comparison
        subplot(5,1,1)
        if length(IAE_wek) >= 2
            bar_data = [IAE_wek(1), IAE_wek(2)];  % PI, Q-learning
            bar_colors = [color_PI; color_Q_after];
            b = bar(bar_data);
            b.FaceColor = 'flat';
            b.CData = bar_colors;
            grid on
            ylabel('IAE')
            title('Integral Absolute Error (IAE) Comparison')
            set(gca, 'XTickLabel', {'PI', 'Q-learning'})
        end

        % IAE trajectory (if available)
        subplot(5,1,2)
        if exist('IAE_traj_wek', 'var') && ~isempty(IAE_traj_wek)
            plot(IAE_traj_wek, 'Color', color_Q, 'LineWidth', 1.5)
            grid on
            xlabel('Sample')
            ylabel('IAE')
            title('IAE Trajectory Over Time')
        end

        % Overshoot comparison
        subplot(5,1,3)
        if exist('maks_przereg_wek', 'var') && length(maks_przereg_wek) >= 2
            bar_data = [maks_przereg_wek(1), maks_przereg_wek(2)];
            bar_colors = [color_PI; color_Q_after];
            b = bar(bar_data);
            b.FaceColor = 'flat';
            b.CData = bar_colors;
            grid on
            ylabel('Overshoot [%]')
            title('Maximum Overshoot Comparison')
            set(gca, 'XTickLabel', {'PI', 'Q-learning'})
        end

        % Settling time comparison
        subplot(5,1,4)
        if exist('czas_regulacji_wek', 'var') && length(czas_regulacji_wek) >= 2
            bar_data = [czas_regulacji_wek(1), czas_regulacji_wek(2)];
            bar_colors = [color_PI; color_Q_after];
            b = bar(bar_data);
            b.FaceColor = 'flat';
            b.CData = bar_colors;
            grid on
            ylabel('Settling Time [s]')
            title('Settling Time Comparison')
            set(gca, 'XTickLabel', {'PI', 'Q-learning'})
        end

        % Trajectory realization percentage
        subplot(5,1,5)
        if exist('proc_realizacji_traj', 'var') && ~isempty(proc_realizacji_traj)
            plot(proc_realizacji_traj, 'Color', color_Purple, 'LineWidth', 1.5)
            grid on
            xlabel('Sample')
            ylabel('Realization [%]')
            title('Trajectory Realization Percentage')
        end
    end

end
