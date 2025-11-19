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

%% Main plotting logic
if poj_iteracja_uczenia == 1
    % Single iteration mode (Q-controller only, no PI comparison)
    plot_single_iteration();
else
    % Verification mode (Q-controller vs PI controller)
    plot_with_pi_comparison();
end

%% Plot MNK filter coefficients (if available)
if ~isempty(wsp_mnk)
    plot_mnk_analysis();
end

%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function plot_single_iteration()
    % Plot results for single iteration learning mode

    %% Figure 1: Output, Control, Disturbance, Control Increment
    fig1 = figure('Position', [50, 50, 1000, 900]);

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
    plot(logi.Q_t, logi.Q_d, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
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
    fig2 = figure('Position', [100, 100, 1000, 900]);

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
    title('Continuous State Value (s = e + (1/T_e) \cdot \DeltaE)')
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
    plot(logi.Q_t, logi.Q_akcja_value_bez_f_rzutujacej, 'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.2);
    hold off
    grid on
    xlabel('Time [s]')
    ylabel('Action Value')
    title('Action Value')
    legend('With projection function', 'Without projection function', 'Location', 'best')

    %% Figure 3: Error and Derivative Analysis
    fig3 = figure('Position', [150, 150, 1000, 900]);

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
end

function plot_with_pi_comparison()
    % Plot results comparing Q-controller with PI controller

    %% Figure 1: Output, Control, Disturbance (Q vs PI)
    fig1 = figure('Position', [50, 50, 1000, 900]);

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
    plot(logi.Q_t, logi.Q_d, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
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
    fig2 = figure('Position', [100, 100, 1000, 900]);

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
    fig3 = figure('Position', [150, 150, 1000, 900]);

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
end

function plot_mnk_analysis()
    % Plot MNK (Least Mean Squares) filter analysis

    fig4 = figure('Position', [200, 200, 1000, 900]);

    subplot(4,1,1)
    plot(wek_proc_realizacji, 'Color', color_Q, 'LineWidth', 1.5)
    hold on
    plot(filtr_mnk, 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5)
    plot(wek_Te/max(wek_Te), 'Color', [0.4940 0.1840 0.5560], 'LineWidth', 1.5)
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
    plot(wsp_mnk(2,:), 'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.5);
    grid on
    xlabel('Epoch')
    ylabel('Coefficient b')
    title('MNK Coefficient b (Intercept)')

    subplot(4,1,4)
    plot(wsp_mnk(3,:), 'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.5);
    grid on
    xlabel('Epoch')
    ylabel('Coefficient c')
    title('MNK Coefficient c')
end

end
