%% ========================================================================
%% CONFIGURATION FILE - User modifies parameters here
%% ========================================================================
% This file contains all user-configurable parameters for the Q2d Q-learning
% controller simulation. Modify these values to set up your experiment.
%
% Called by: m_inicjalizacja.m (do not run directly)
%% ========================================================================

%% --- Simulation Control ---
poj_iteracja_uczenia = 0;          % 1=single iteration mode, 0=full verification with metrics
max_epoki = 1500;                    % Training duration (500 for testing, 5000+ for full training)
maksymalna_ilosc_iteracji_uczenia = 4000;  % Max samples per epoch
czas_eksp_wer = 600;               % Verification experiment time [s]
gif_on = 0;                        % 1=generate GIF animation, 0=disabled

%% --- Debug Logging ---
% Enables detailed Q-learning diagnostics in logi.DEBUG_* fields
% WARNING: Adds computational overhead (~10-15%), use only for debugging
debug_logging = 0;                 % 1=enable detailed debug logs, 0=disabled (default: 0 for production)

%% --- Learning Mode ---
uczenie_obciazeniowe = 1;          % 1=learn with disturbances, 0=setpoint changes (mutually exclusive)
uczenie_zmiana_SP = 0;             % 1=learn with SP changes, 0=disabled (mutually exclusive)
zakres_losowania_zakl_obc = 0.5;   % Disturbance randomization range
zakres_losowania_zmian_SP = 1;     % SP change randomization range
dist_on = 0;                       % 1=external disturbance enabled, 0=disabled

%% --- Episode Configuration (Load Disturbance Mode) ---
% These parameters control randomization when uczenie_obciazeniowe = 1
disturbance_range = 0.5;           % Disturbance range: ±0.5 at 3-sigma covers typical industrial disturbances
mean_episode_length = 3000;        % Mean episode length [iterations]
episode_length_variance = 300;     % Episode length standard deviation [iterations]
min_episode_length = 10;           % Minimum episode length (safety limit for meaningful learning)

%% --- Progress Reporting Configuration ---
% Adaptive reporting thresholds based on total training duration
short_run_threshold = 10000;       % Max epochs for "short run" (reports every short_run_interval)
medium_run_threshold = 15000;      % Max epochs for "medium run" (reports every medium_run_interval)
                                   % Long runs (>medium_run_threshold) report every long_run_interval
short_run_interval = 100;          % Reporting interval for short runs [epochs]
medium_run_interval = 500;         % Reporting interval for medium runs [epochs]
long_run_interval = 1000;          % Reporting interval for long runs [epochs]

%% --- Plant Model Selection ---
% Available models:
%   1 - First order inertia              T: [scalar]
%   3 - Second order inertia             T: [T1, T2]
%   5 - Third order inertia              T: [T1, T2, T3]
%   6 - Pneumatic (nonlinear)            T: [T1, T2, T3]
%   7 - Second order oscillatory         T: [T1, T2, T3] (tested for T=[5 2 1])
%   8 - Third order pneumatic            T: [T1, T2, T3] (example: T=[2.34 1.55 9.38])

nr_modelu = 3;                     % Model selection (1, 3, 5, 6, 7, 8)
k = 1;                             % Process gain
% T = [2.34 1.55 9.38];              % Time constants [s] - adjust dimensions per model
T=[5 2];
T0 = 4;                            % Plant dead time (physical reality) [s]
T0_controller = 0;                % Controller compensation dead time [s] (0=no compensation)
SP_ini = 50;                       % Initial setpoint [%]

%% --- PI Controller Parameters ---
Kp = 1;                            % Proportional gain
Ti = 20;                           % Integral time [s]
Td = 0;                            % Derivative time [s]
Tn = 0;                            % Derivative filter time [s]
dt_PID = 0.1;                      % PI sampling time [s]

%% --- Q-Learning Controller Parameters ---
dt = 0.1;                          % Sampling time [s] (must equal dt_PID)
Te_bazowe = 10;                     % Goal time constant [s]
kQ = Kp;                           % Q-controller gain (set to Kp for bumpless transfer)

% Learning parameters
alfa = 0.1;                        % Learning rate (0 < alfa <= 1)
gamma = 0.99;                      % Discount factor (0 < gamma < 1)
eps_ini = 0.3;                     % Initial exploration rate [0, 1]
nagroda = 1;                       % Reward value (typically 1)

% State space generation
dokladnosc_gen_stanu = 0.5;        % Precision (steady-state accuracy)
oczekiwana_ilosc_stanow = 100;     % Expected number of states
f_rzutujaca_on = 0;                % Projection function: 1=enabled, 0=disabled

% Control constraints
ograniczenie_sterowania_dol = 0;   % Lower limit [%]
ograniczenie_sterowania_gora = 100;% Upper limit [%]

% Exploration
RD = 5;                            % Random deviation range
max_powtorzen_losowania = 10;      % Max randomization attempts
max_powtorzen_losowania_RD = 10;   % Max RD randomization attempts

%% --- Convergence & Trajectory Tracking ---
oczekiwana_ilosc_probek_stabulizacji = 20;  % Expected stabilization samples
probkowanie_norma_macierzy = 100;           % Q-matrix norm sampling interval (epochs)
ilosc_probek_procent_realizacjii = round(50 / dt);  % Trajectory realization window size [iterations]
przesuniecie_okno_procent_realizacji = round(ilosc_probek_procent_realizacjii / 4);  % Window shift (unused)
rozmiar_okna_sredniej_realizacji = 5;       % Moving average window size

%% --- Trajectory Realization & Te Reduction ---
% MNK (Least Squares) Filter Configuration
mnk_filter_time_constant = 10;     % Recursive least-squares filter time constant [s]
mnk_mean_window_size = 3;          % Sliding window size for filtered realization values
mnk_coeff_a_window_size = 8;       % Sliding window size for coefficient 'a' (level)
mnk_coeff_b_window_size = 8;       % Sliding window size for coefficient 'b' (trend)

% Te Reduction Convergence Criteria
% Te is reduced by 0.1s when learning performance stabilizes
te_reduction_threshold_a = 0.2;    % Min mean(a) for upward trend detection (0-1 scale)
te_reduction_threshold_b_min = -0.05;  % Min mean(b) for stable trend (near-zero derivative)
te_reduction_threshold_b_max = 0.05;   % Max mean(b) for stable trend (near-zero derivative)

%% --- Scaling Parameters ---
% Process variable ranges (engineering units / percentage)
proc_max_e = 100;    proc_min_e = -100;  % Error range [%]
proc_max_y = 100;    proc_min_y = 0;     % Output range [%]
proc_max_u = 100;    proc_min_u = 0;     % Control range [%]

% Normalized ranges (internal calculations)
% IMPORTANT: Keep (wart_max_u - wart_min_u) == (wart_max_y - wart_min_y) for correct steady-state
wart_max_e = 2;      wart_min_e = -2;    % Normalized error
wart_max_y = 2;      wart_min_y = 0;     % Normalized output
wart_max_u = 2;      wart_min_u = 0;     % Normalized control

%% --- Manual Control ---
ilosc_probek_sterowanie_reczne = 5;  % Manual control samples at start (u=SP/k)
dodatkowe_probki_reka = 5;           % Additional manual samples for buffer pre-filling
