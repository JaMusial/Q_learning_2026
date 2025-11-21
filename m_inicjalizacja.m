%% ========================================================================
%% INITIALIZATION SCRIPT
%% ========================================================================
% Loads configuration parameters, validates them, and initializes all
% internal state variables for the Q2d Q-learning controller simulation.
%
% Structure:
%   1. Load configuration from config.m
%   2. Validate parameter consistency
%   3. Compute derived parameters
%   4. Initialize internal state variables
%   5. Initialize buffers
%% ========================================================================

%% ========================================================================
%% 1. LOAD CONFIGURATION
%% ========================================================================
config;  % Execute configuration file

%% ========================================================================
%% 2. PARAMETER VALIDATION
%% ========================================================================

fprintf('=== Validating parameters ===\n');

% Model-T dimension consistency
expected_T_length = [1, 1, 2, 2, 3, 3, 3, 3];  % For models 1-8
if nr_modelu >= 1 && nr_modelu <= 8
    if length(T) ~= expected_T_length(nr_modelu)
        error('Model %d requires T with %d element(s), got %d', ...
              nr_modelu, expected_T_length(nr_modelu), length(T));
    end
else
    error('Invalid nr_modelu=%d. Valid range: 1-8 (excluding 2,4)', nr_modelu);
end

% Dead time buffer consistency
if T0 < 0 || T0_controller < 0
    error('Dead times must be non-negative: T0=%g, T0_controller=%g', T0, T0_controller);
end
if T0 > 0 && mod(T0, dt) > 1e-10
    warning('T0/dt = %g not integer, buffer size will be rounded to %d', ...
            T0/dt, round(T0/dt));
end
if T0_controller > 0 && mod(T0_controller, dt) > 1e-10
    warning('T0_controller/dt = %g not integer, buffer size will be rounded to %d', ...
            T0_controller/dt, round(T0_controller/dt));
end
if abs(T0_controller - T0) > 0.5 && T0_controller > 0
    fprintf('INFO: Dead time mismatch - T0=%g, T0_controller=%g (research scenario)\n', ...
            T0, T0_controller);
end

% Scaling symmetry (critical for steady-state per CLAUDE.md)
u_range = wart_max_u - wart_min_u;
y_range = wart_max_y - wart_min_y;
if abs(u_range - y_range) > 1e-10
    error(['Asymmetric u/y scaling detected! u_range=%g, y_range=%g\n' ...
           'This breaks steady-state. Either:\n' ...
           '  1. Make symmetric: set wart_max_u=%g, wart_min_u=%g\n' ...
           '  2. Adjust gain: k_norm = k * (y_range/u_range) = %g'], ...
          u_range, y_range, wart_min_y + u_range, wart_min_y, k * (y_range/u_range));
end

% Sampling time consistency
if abs(dt - dt_PID) > 1e-10
    error('Sampling times must match: dt=%g, dt_PID=%g', dt, dt_PID);
end
if dt <= 0
    error('Sampling time must be positive: dt=%g', dt);
end

% Q-learning parameter ranges
if alfa <= 0 || alfa > 1
    error('Learning rate must be in (0, 1]: alfa=%g', alfa);
end
if gamma <= 0 || gamma >= 1
    error('Discount factor must be in (0, 1): gamma=%g', gamma);
end
if eps_ini < 0 || eps_ini > 1
    error('Exploration rate must be in [0, 1]: eps_ini=%g', eps_ini);
end

% Bumpless transfer consistency (Te initialized to Ti in derived section)
if abs(kQ - Kp) > 1e-10
    warning('kQ=%g should equal Kp=%g for bumpless start. Setting kQ=Kp.', kQ, Kp);
    kQ = Kp;
end

% Learning mode exclusivity
if uczenie_obciazeniowe == 1 && uczenie_zmiana_SP == 1
    error('uczenie_obciazeniowe and uczenie_zmiana_SP cannot both be 1 (mutually exclusive)');
end

% Positive values
if max_epoki <= 0 || oczekiwana_ilosc_stanow <= 0 || dokladnosc_gen_stanu <= 0
    error('max_epoki, oczekiwana_ilosc_stanow, dokladnosc_gen_stanu must be positive');
end
if maksymalna_ilosc_iteracji_uczenia <= 0
    error('maksymalna_ilosc_iteracji_uczenia must be positive');
end

fprintf('    All validations passed\n');

%% ========================================================================
%% 3. DERIVED PARAMETERS (Computed from configuration)
%% ========================================================================

% Te initialization: Start at Ti for bumpless transfer
Te = Ti;

% PI controller type identifier
typ = 'PI  ';

% Scaled tolerance for state space generation
dopuszczalny_uchyb = f_skalowanie(proc_max_e, proc_min_e, wart_max_e, wart_min_e, dokladnosc_gen_stanu);

%% ========================================================================
%% 4. INTERNAL STATE INITIALIZATION (Auto-initialized, do not modify)
%% ========================================================================

fprintf('=== Initializing internal state ===\n');

%% --- Control & Learning State ---
pozwolenie_na_uczenia = 1;         % Learning enabled flag
epoka = 1;                         % Current epoch counter
iter = 1;                          % Iteration counter within epoch
z = 0;                             % Sample counter
flaga_zmiana_Te = 1;               % Flag for Te change event

%% --- Process Variables ---
e = 0;                             % Error (Q-controller)
y = 0;                             % Output (Q-controller)
delta_y = 0;                       % Output derivative
u = 0;                             % Control signal (Q-controller)
e_PID = 0;                         % Error (PI controller)
y_PID = 0;                         % Output (PI controller)
u_PID = 0;                         % Control signal (PI controller)

%% --- Logging Control ---
zapis_logi_PID = 0;                % PI logging flag
reset_logi = 0;                    % Reset logs flag
logi_idx = 0;                      % Log array index counter
trim_logi = 0;                     % Trim logs flag
flaga_rysuj_gif = 1;               % GIF drawing flag
pierwszy_wykres_weryfikacyjny = 0; % First verification plot flag
eks_wer = 0;                       % Verification experiment flag

%% --- Q-Learning State ---
maxS = 0;                          % Maximum state index
Q_update = 0;                      % Q-update counter
max_macierzy_Q = [1];              % Max Q-value per epoch

%% --- Convergence Tracking ---
stan_ustalony_probka = 0;          % Steady-state sample counter
okno_norma = [100 100 100 100];   % Q-matrix norm sliding window
realizacja_traj_epoka = zeros(1, 20000);  % Trajectory realization buffer
realizacja_traj_epoka_idx = 0;    % Trajectory buffer index
wek_okno_realizacji = zeros(1, 100);      % Realization window vector
proc_realizacji_w_oknie = 0;      % Realization percentage in window
probkowanie_var_iter = 0;          % Iteration sampling counter
proc_realizacji_w_oknie_wek = [];  % Realization percentage vector
okno_procent_realizacji = [];     % Percentage realization window
wek_proc_realizacji = [];          % Realization percentage vector
srednia_okno_proc_realizacji = []; % Average realization window
filtr_mnk = [];                    % Least squares filter
wsp_mnk = [];                      % Least squares coefficients
filtr_mnk_mean = [0 0 0];          % MNK filter mean
a_mnk_mean = [0 0 0 0 0 0 0 0];    % MNK coefficient a (mean)
b_mnk_mean = [100 100 100 100 100 100 100 100];  % MNK coefficient b (mean)

%% --- Trajectory & Performance Metrics ---
proc_realizacji_traj = [0];        % Trajectory realization percentage
pole_wek = [];                     % Area vector
pole = 0;                          % Current area
test_wek = [];                     % Test vector
t_pos = 0;                         % Positive time counter
t_neg = 0;                         % Negative time counter
licz_pole = 0;                     % Calculate area flag
idle_index_wek = [];               % Idle index vector (performance metric)
visioli_index_wek = [];            % Visioli index vector (performance metric)
area_index_wek = [];               % Area index vector (performance metric)
koszt_sterowania = 0;              % Control cost
koszt_sterowania_wek = [0];        % Control cost vector
koszt_sterowania_flaga = 0;        % Control cost calculation flag
licz_wskazniki = 0;                % Calculate metrics flag
pierwsze_zakl = 0;                 % First disturbance flag
wek_Te = [];                       % Te evolution vector

%% --- Diagnostic Counters ---
inf_zakonczono_epoke_max_iter = 0;     % Epoch ended by max iterations counter
inf_zakonczono_epoke_stabil = 0;       % Epoch ended by stabilization counter
czas_uczenia_calkowity = 0;            % Total learning time
inf_zakonczono_epoke_stabil_old = 0;   % Previous stabilization counter
inf_zakonczono_epoke_max_iter_old = 0; % Previous max iterations counter

fprintf('    Internal state initialized\n');

%% ========================================================================
%% 5. BUFFER INITIALIZATION
%% ========================================================================

fprintf('=== Initializing buffers ===\n');

% Plant dead time buffers (physical reality - applied to plant output)
if T0 ~= 0
    bufor_T0 = zeros(1, round(T0/dt));
    bufor_T0_PID = zeros(1, round(T0/dt));
    fprintf('    Plant buffers: T0=%g s, size=%d samples\n', T0, round(T0/dt));
end

% Controller compensation buffers (what controller thinks - for delayed credit assignment)
if T0_controller ~= 0
    bufor_state = zeros(1, round(T0_controller/dt));
    bufor_wyb_akcja = zeros(1, round(T0_controller/dt));
    bufor_uczenie = zeros(1, round(T0_controller/dt));
    fprintf('    Controller buffers: T0_controller=%g s, size=%d samples\n', ...
            T0_controller, round(T0_controller/dt));
end

fprintf('\n=== Initialization Complete ===\n');
fprintf('Model: %d, T=%s, k=%g, T0=%g, T0_controller=%g\n', ...
        nr_modelu, mat2str(T), k, T0, T0_controller);
fprintf('Q-learning: Te=%g->%g s, alfa=%g, gamma=%g, eps=%g\n', ...
        Te, Te_bazowe, alfa, gamma, eps_ini);
fprintf('Training: max_epoki=%d, mode=%s\n', ...
        max_epoki, iif(uczenie_obciazeniowe, 'disturbances', 'SP changes'));
fprintf('=========================================\n\n');

%% Helper function for conditional formatting
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end
