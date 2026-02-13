function [IAE, IAE_traj, max_overshoot, settling_time, max_delta_u] = f_licz_wskazniki(y, u, SP, prec, traj, dt, manual_control_samples, experiment_duration)
% f_licz_wskazniki - Calculate performance metrics for verification experiments
%
% PURPOSE:
%   Computes 5 control performance metrics across 3 phases of verification experiment:
%   - Phase 1: SP change (setpoint step response)
%   - Phase 2: Disturbance rejection (load disturbance applied)
%   - Phase 3: Recovery (disturbance removed, return to setpoint)
%
% INPUTS:
%   y                     - Process output vector [process units]
%   u                     - Control signal vector [process units]
%   SP                    - Setpoint value [process units]
%   prec                  - Precision for settling time (steady-state tolerance) [process units]
%   traj                  - Reference trajectory vector [process units]
%   dt                    - Sampling time [s]
%   manual_control_samples - Number of initial manual control samples (excluded from metrics)
%   experiment_duration   - Total experiment duration [s]
%
% OUTPUTS:
%   IAE           - [1x3] Integral Absolute Error vs setpoint for each phase
%   IAE_traj      - [1x3] Integral Absolute Error vs reference trajectory for each phase
%   max_overshoot - [1x3] Maximum error magnitude for each phase [process units]
%   settling_time - [1x3] Time to settle within precision for each phase [s]
%   max_delta_u   - [1x3] Maximum control increment for each phase [process units]
%
% NOTES:
%   - Called from m_warunek_stopu.m during verification tests
%   - Experiment structure defined in m_eksperyment_weryfikacyjny.m:
%     * t=0 to t=T/3: Phase 1 (SP change at t=15*dt after manual control)
%     * t=T/3 to t=2T/3: Phase 2 (disturbance d=0.3 applied)
%     * t=2T/3 to t=T: Phase 3 (disturbance removed)
%   - Each phase has equal duration (T/3 samples)
%   - Settling time uses re-entry definition (last time within tolerance)
%
% SIDE EFFECTS:
%   None (pure function)

%% =====================================================================
%% Initialize
%% =====================================================================

NUM_PHASES = 3;  % Fixed: SP change, disturbance on, disturbance off

% Calculate simulation length in samples (experiment only, without manual control)
simulation_length = round(experiment_duration / dt);

% Calculate total data length (manual control + experiment)
total_samples = manual_control_samples + simulation_length;

% Preallocate output arrays
IAE = zeros(1, NUM_PHASES);
IAE_traj = zeros(1, NUM_PHASES);
max_overshoot = zeros(1, NUM_PHASES);
settling_time = zeros(1, NUM_PHASES);
max_delta_u = zeros(1, NUM_PHASES);

%% =====================================================================
%% Calculate metrics for each phase
%% =====================================================================

for phase = 1:NUM_PHASES

    % Determine phase boundaries
    % All phases start AFTER manual control samples and span equal durations
    if phase == 1
        % Phase 1: SP change (first third of experiment after manual control)
        start_idx = manual_control_samples + 1;
        end_idx = manual_control_samples + simulation_length / 3;
    elseif phase == 2
        % Phase 2: Disturbance on (second third of experiment)
        start_idx = manual_control_samples + simulation_length / 3 + 1;
        end_idx = manual_control_samples + 2 * simulation_length / 3;
    else
        % Phase 3: Disturbance off (final third of experiment)
        start_idx = manual_control_samples + 2 * simulation_length / 3 + 1;
        end_idx = manual_control_samples + simulation_length;
    end

    % Convert to integer indices
    start_idx = round(start_idx);
    end_idx = round(end_idx);

    %% -----------------------------------------------------------------
    %% IAE: Integral Absolute Error vs Setpoint
    %% -----------------------------------------------------------------
    error_vs_sp = SP - y(start_idx:end_idx);
    IAE(phase) = trapz(dt, abs(error_vs_sp));

    %% -----------------------------------------------------------------
    %% IAE_traj: Integral Absolute Error vs Reference Trajectory
    %% -----------------------------------------------------------------
    error_vs_traj = traj(start_idx:end_idx) - y(start_idx:end_idx);
    IAE_traj(phase) = trapz(dt, abs(error_vs_traj));

    %% -----------------------------------------------------------------
    %% max_delta_u: Maximum Control Increment
    %% -----------------------------------------------------------------
    % Vectorized: find maximum absolute difference between consecutive samples
    if end_idx > start_idx
        control_increments = abs(diff(u(start_idx:end_idx)));
        max_delta_u(phase) = max(control_increments);
    else
        max_delta_u(phase) = 0;
    end

    %% -----------------------------------------------------------------
    %% max_overshoot: Maximum Overshoot / Deviation
    %% -----------------------------------------------------------------
    if phase == 1
        % Phase 1 (SP step): measure true overshoot past setpoint
        % Determine step direction from initial output value
        y_initial = y(start_idx);
        if y_initial < SP
            % Positive step: overshoot = how much y exceeds SP
            max_overshoot(phase) = max(0, max(y(start_idx:end_idx)) - SP);
        else
            % Negative step: overshoot = how much y drops below SP
            max_overshoot(phase) = max(0, SP - min(y(start_idx:end_idx)));
        end
    else
        % Phases 2,3 (disturbance): max deviation from SP
        max_overshoot(phase) = max(abs(SP - y(start_idx:end_idx)));
    end

    %% -----------------------------------------------------------------
    %% settling_time: Time to Settle Within Precision
    %% -----------------------------------------------------------------
    % Re-entry definition: backward scan for last sample outside tolerance
    % If always within tolerance, settling_time = 0
    % If never settles, settling_time = phase duration
    settling_time(phase) = 0;
    for j = end_idx:-1:start_idx
        if abs(SP - y(j)) > prec
            settling_time(phase) = (j - start_idx + 1) * dt;
            break;
        end
    end

end

end
