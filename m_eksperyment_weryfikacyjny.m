%% m_eksperyment_weryfikacyjny - Run verification experiment comparing Q vs PI
%
% PURPOSE:
%   Executes controlled verification experiment with both Q-learning and PI controllers
%   on same plant to enable performance comparison. Experiment consists of 3 phases:
%   1. SP tracking: Setpoint step change response
%   2. Disturbance rejection: Load disturbance d=0.3 applied
%   3. Recovery: Disturbance removed, return to setpoint
%
% INPUTS (from workspace):
%   Q_2d, stany, akcje   - Q-learning controller tables
%   Kp, Ti               - PI controller parameters
%   czas_eksp_wer        - Verification experiment duration [s]
%   T0, T0_controller    - Dead time parameters
%   Plant parameters     - k, T, nr_modelu, etc.
%
% OUTPUTS (to workspace):
%   logi                 - Logged data from current experiment
%   logi_before_learning - Logged data from first run (if applicable)
%
% NOTES:
%   - Called from main.m before and after learning
%   - First call (before learning): Stores logi_before_learning
%   - Second call (after learning): Uses logi for comparison
%   - Both controllers run in parallel on identical conditions
%   - Manual control phase (T0/dt + extra samples) precedes experiment
%   - Disturbance timing fixed at middle third of experiment (phase 2)
%   - All arrays pre-allocated and trimmed after simulation
%
% SIDE EFFECTS:
%   - Modifies: logi, logi_before_learning, eps, zapis_logi flags
%   - Resets: Plant states, controller states, buffers

%% =====================================================================
%% Initialize Controller States and Plant
%% =====================================================================

SP=20;
y=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y_PID=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);

% Initialize reference trajectory
y_ref = y;
e_ref = 0;
de_ref = 0;
de2_ref = 0;
d_ref = 0;

% Initialize Q controller state
e = 0;
de = 0;
de2 = 0;
u = SP / k;

% Initialize PID controller state
e_PID = 0;
de_PID = 0;
de2_PID = 0;
u_PID = SP / k;

% Initialize plant internal states for both controllers
y1_n = f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y2_n = f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y3_n = f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y1_n_PID = y1_n;
y2_n_PID = y2_n;
y3_n_PID = y3_n;

% Initialize time and flags
t = 0;
eps=-1;
iter=1;
zapis_logi=1;
reset_logi=1;
zapis_logi_PID=1;
eks_wer=1;
d=0;
ilosc_probek_sterowanie_reczne = round(T0/dt) + dodatkowe_probki_reka;

%% =====================================================================
%% Reset Buffers for Clean Test
%% =====================================================================

% Reset plant delay buffers for clean verification test
% Pre-fill with steady-state value to prevent transient
if T0 ~= 0
    u_ss_scaled = f_skalowanie(proc_max_u, proc_min_u, wart_max_u, wart_min_u, SP/k);
    bufor_T0 = ones(1, round(T0/dt)) * u_ss_scaled;
    bufor_T0_PID = ones(1, round(T0/dt)) * u_ss_scaled;
end

% Reset controller compensation buffers for clean verification test
if T0_controller ~= 0
    bufor_state = zeros(1, round(T0_controller/dt));
    bufor_wyb_akcja = zeros(1, round(T0_controller/dt));
    bufor_uczenie = zeros(1, round(T0_controller/dt));
    bufor_e = zeros(1, round(T0_controller/dt));  % Error buffer for projection temporal consistency
    bufor_credit = ones(1, round(T0_controller/dt));  % Credit ratio buffer (1.0 = full credit)
end

%% =====================================================================
%% Run Verification Experiment
%% =====================================================================

% Calculate phase boundaries (in time [seconds], not samples)
% Experiment divided into 3 equal phases AFTER manual control:
%   Phase 1: SP tracking (0 to T/3)
%   Phase 2: Disturbance rejection (T/3 to 2T/3, d=0.3)
%   Phase 3: Recovery (2T/3 to T)
manual_control_time = ilosc_probek_sterowanie_reczne * dt;
phase2_start_time = manual_control_time + czas_eksp_wer / 3;
phase2_end_time = manual_control_time + 2 * czas_eksp_wer / 3;

dlugosc_symulacji = round(czas_eksp_wer/dt) + ilosc_probek_sterowanie_reczne;
for iter_test=1:dlugosc_symulacji
    if iter_test==15+ilosc_probek_sterowanie_reczne
        SP=SP_ini;
    end

    m_regulator_Q;
    m_regulator_PID;
    m_zapis_logow

    % Apply disturbance during Phase 2 (middle third of experiment)
    if t > phase2_start_time && t <= phase2_end_time
        d = - 0.3;  % Phase 2: disturbance on
    else
        d = 0;    % Phase 1 or Phase 3: no disturbance
    end

    iter=iter+1;
end

%% =====================================================================
%% Post-Processing and Storage
%% =====================================================================

% Trim preallocated log arrays to actual used size
trim_logi = 1;
m_zapis_logow;

eks_wer=0;

% Store data for comparison plots (handled in m_rysuj_wykresy.m)
if pierwszy_wykres_weryfikacyjny==0 && licz_wskazniki==0
    % First run (Q without learning) - store data
    logi_before_learning = logi;
    pierwszy_wykres_weryfikacyjny=1;

    % Export debug data to JSON if debug logging enabled
    f_export_debug_json(logi_before_learning, 'logi_before_learning.json', debug_logging);
end

% Plotting is now handled in m_rysuj_wykresy.m

% Reset flags for normal operation
zapis_logi_PID=0;
zapis_logi=0;
eps=eps_ini;
