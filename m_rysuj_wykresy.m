%% m_rysuj_wykresy - Visualization of Q-learning control results
%
% Generates comprehensive plots comparing Q-controller vs Reference trajectory
% (and vs PI controller in verification mode)
%
% Features:
%   - Theme-neutral colors (works on both light and dark MATLAB themes)
%   - Single figure window with organized subplots
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

    %% Create single large figure with all plots
    fig1 = figure('Position', [50, 50, 1600, 1200], 'Name', 'Q-Learning Results', 'NumberTitle', 'off');

    % Row 1: Output and Control
    subplot(4, 3, 1)
    plot(logi.Q_t, logi.Q_y, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_y, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_y, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Output y [%]')
    title('Process Variable y')
    legend('Q', 'Ref', 'Reward', 'Location', 'best')

    subplot(4, 3, 2)
    plot(logi.Q_t, logi.Q_u, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, nagroda_u, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Control u [%]')
    title('Control Signal u')
    legend('Q', 'Reward', 'Location', 'best')

    subplot(4, 3, 3)
    yyaxis left
    plot(logi.Q_t, logi.Q_czas_zaklocenia, 'Color', color_Q, 'LineWidth', 1.5);
    ylabel('Disturbance [samples]')
    yyaxis right
    plot(logi.Q_t, logi.Q_d, 'Color', color_Disturbance, 'LineWidth', 1.5);
    ylabel('Load d [%]')
    grid on
    xlabel('Time [s]')
    title('Disturbance')

    % Row 2: States
    subplot(4, 3, 4)
    plot(logi.Q_t, logi.Q_stan_nr, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Ref_stan_nr, 'Color', color_Ref, 'LineWidth', 1.2);
    plot(logi.Q_t, nagroda_stan_nr, '|', 'Color', color_Reward, 'MarkerSize', 8);
    yline(nr_stanu_doc, 'Color', color_Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Index')
    title('State Index')
    legend('Q', 'Ref', 'Reward', 'Target', 'Location', 'best');

    subplot(4, 3, 5)
    plot(logi.Q_t, logi.Q_stan_value, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Ref_stan_value, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_stan_val, '|', 'Color', color_Reward, 'MarkerSize', 8);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Value')
    title('State Value')
    legend('Q', 'Ref', 'Reward', 'Location', 'best')

    subplot(4, 3, 6)
    plot(logi.Q_t, logi.Q_u_increment, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    yline(0, 'Color', color_Target, 'LineWidth', 1);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('\Deltau [%]')
    title('Control Increment')

    % Row 3: Actions and Errors
    subplot(4, 3, 7)
    plot(logi.Q_t, logi.Q_akcja_nr, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    yline(nr_akcji_doc, 'Color', color_Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Index')
    title('Action Index')
    legend('Q', 'Target', 'Location', 'best')

    subplot(4, 3, 8)
    plot(logi.Q_t, logi.Q_akcja_value, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Q_akcja_value_bez_f_rzutujacej, 'Color', color_Alt, 'LineWidth', 1.2);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Value')
    title('Action Value')
    legend('With proj', 'Without proj', 'Location', 'best')

    subplot(4, 3, 9)
    plot(logi.Q_t, logi.Q_e, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_e, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_e, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Error e [%]')
    title('Error e')
    legend('Q', 'Ref', 'Reward', 'Location', 'best')

    % Row 4: Derivatives and MNK
    subplot(4, 3, 10)
    plot(logi.Q_t, logi.Q_de, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_de, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_de, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de [%/s]')
    title('Error Derivative')
    legend('Q', 'Ref', 'Reward', 'Location', 'best')

    subplot(4, 3, 11)
    plot(logi.Q_t, logi.Q_de2, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_de2, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_de2, '|', 'Color', color_Reward, 'MarkerSize', 8)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de2')
    title('de2')
    legend('Q', 'Ref', 'Reward', 'Location', 'best')

    % MNK Analysis (if available) - use last subplot
    if ~isempty(wsp_mnk)
        subplot(4, 3, 12)
        plot(wek_proc_realizacji, 'Color', color_Q, 'LineWidth', 1.5)
        hold on
        plot(filtr_mnk, 'Color', color_Disturbance, 'LineWidth', 1.5)
        plot(wek_Te/max(wek_Te), 'Color', color_Purple, 'LineWidth', 1.5)
        hold off
        grid on
        xlabel('Epoch')
        ylabel('Normalized')
        title('Learning Progress')
        legend('Traj %', 'MNK', 'Te', 'Location', 'best');
    end

%% ========================================================================
%%  VERIFICATION MODE (Q-controller vs PI controller)
%% ========================================================================

else

    %% Create single large figure with all plots
    fig1 = figure('Position', [50, 50, 1600, 1200], 'Name', 'Q vs PI Comparison', 'NumberTitle', 'off');

    % Row 1: Output and Control
    subplot(4, 3, 1)
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
    legend('Q', 'Ref', 'Reward', 'PI', 'Location', 'best')

    subplot(4, 3, 2)
    plot(logi.Q_t, logi.Q_u, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, nagroda_u, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_u, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Control u [%]')
    title('Control Signal u')
    legend('Q', 'Reward', 'PI', 'Location', 'best')

    subplot(4, 3, 3)
    yyaxis left
    plot(logi.Q_t, logi.Q_u_increment, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.PID_t, logi.PID_u_increment, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    ylabel('\Deltau [%]')
    yyaxis right
    plot(logi.Q_t, logi.Q_d, 'Color', color_Disturbance, 'LineWidth', 1.5);
    ylabel('Load d [%]')
    grid on
    xlabel('Time [s]')
    title('Increment & Disturbance')

    % Row 2: States
    subplot(4, 3, 4)
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
    title('State Index')
    legend('Q', 'Ref', 'Reward', 'PI', 'Target', 'Location', 'best');

    subplot(4, 3, 5)
    plot(logi.Q_t, logi.Q_stan_value, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.Q_t, logi.Ref_stan_value, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_stan_val, '|', 'Color', color_Reward, 'MarkerSize', 8);
    plot(logi.PID_t, logi.PID_akcja_value, 'Color', color_PI, 'LineWidth', 1.5);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('State Value')
    title('State Value')
    legend('Q', 'Ref', 'Reward', 'PI', 'Location', 'best')

    subplot(4, 3, 6)
    plot(logi.Q_t, logi.Q_funkcja_rzut, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    yline(0, 'Color', color_Target, 'LineWidth', 1);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Projection Fn')
    title('Projection Function')

    % Row 3: Actions and Errors
    subplot(4, 3, 7)
    plot(logi.Q_t, logi.Q_akcja_nr, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.PID_t, logi.PID_akcja_nr, 'Color', color_PI, 'LineWidth', 1.5)
    yline(nr_akcji_doc, 'Color', color_Target, 'LineWidth', 1, 'LineStyle', '--');
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Index')
    title('Action Index')
    legend('Q', 'PI', 'Target', 'Location', 'best')

    subplot(4, 3, 8)
    plot(logi.Q_t, logi.Q_akcja_value, 'Color', color_Q, 'LineWidth', 1.5);
    hold on
    plot(logi.PID_t, logi.PID_akcja_value, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Value')
    title('Action Value')
    legend('Q', 'PI', 'Location', 'best')

    subplot(4, 3, 9)
    plot(logi.Q_t, logi.Q_e, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_e, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_e, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_e, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Error e [%]')
    title('Error e')
    legend('Q', 'Ref', 'Reward', 'PI', 'Location', 'best')

    % Row 4: Derivatives and MNK
    subplot(4, 3, 10)
    plot(logi.Q_t, logi.Q_de, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_de, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_de, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_de, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de [%/s]')
    title('Error Derivative')
    legend('Q', 'Ref', 'Reward', 'PI', 'Location', 'best')

    subplot(4, 3, 11)
    plot(logi.Q_t, logi.Q_de2, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(logi.Q_t, logi.Ref_de2, 'Color', color_Ref, 'LineWidth', 1.2)
    plot(logi.Q_t, nagroda_de2, '|', 'Color', color_Reward, 'MarkerSize', 8)
    plot(logi.PID_t, logi.PID_de2, 'Color', color_PI, 'LineWidth', 1.5)
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('de2')
    title('de2')
    legend('Q', 'Ref', 'Reward', 'PI', 'Location', 'best')

    % MNK Analysis (if available) - use last subplot
    if ~isempty(wsp_mnk)
        subplot(4, 3, 12)
        plot(wek_proc_realizacji, 'Color', color_Q, 'LineWidth', 1.5)
        hold on
        plot(filtr_mnk, 'Color', color_Disturbance, 'LineWidth', 1.5)
        plot(wek_Te/max(wek_Te), 'Color', color_Purple, 'LineWidth', 1.5)
        hold off
        grid on
        xlabel('Epoch')
        ylabel('Normalized')
        title('Learning Progress')
        legend('Traj %', 'MNK', 'Te', 'Location', 'best');
    end

end
