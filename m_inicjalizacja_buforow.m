%% m_inicjalizacja_buforow.m - Preallocate Training History Arrays
%
% PURPOSE:
%   Preallocates arrays that track training progress over epochs to avoid
%   expensive dynamic memory reallocation during training loop.
%
% PERFORMANCE OPTIMIZATION:
%   Preallocating to max_epoki size eliminates incremental (end+1) growth
%   which causes MATLAB to reallocate memory on each append. For long runs
%   (>10k epochs), this provides significant speedup.
%
% INPUTS (from workspace):
%   max_epoki                    - Total number of epochs to train
%   probkowanie_norma_macierzy   - Interval for Q-matrix analysis
%
% OUTPUTS (to workspace):
%   wylosowany_SP                - Preallocated: setpoint history per epoch
%   wylosowane_d                 - Preallocated: disturbance history per epoch
%   czas_uczenia_wek             - Preallocated: learning time per reporting interval
%   proc_stab_wek                - Preallocated: stabilization rate per interval
%   max_macierzy_Q               - Preallocated: max Q-value history
%   idx_wylosowany               - Index counter for wylosowany_SP/wylosowane_d
%   idx_raport                   - Index counter for czas_uczenia_wek/proc_stab_wek
%   idx_max_Q                    - Index counter for max_macierzy_Q

% Arrays that grow every epoch (max size = max_epoki)
wylosowany_SP = zeros(1, max_epoki);
wylosowane_d = zeros(1, max_epoki);
idx_wylosowany = 0;  % Index counter for both arrays

% Arrays that grow at reporting intervals
% Worst case: report every short_run_interval epochs (from config.m)
% Use short_run_interval as it's the smallest possible interval
SAFETY_MARGIN = 10;  % Extra elements to prevent overflow
max_raportow = ceil(max_epoki / short_run_interval) + SAFETY_MARGIN;
czas_uczenia_wek = zeros(1, max_raportow);
proc_stab_wek = zeros(1, max_raportow);
idx_raport = 0;  % Index counter for reporting arrays

% Array that grows every probkowanie_norma_macierzy epochs
max_zapisow_Q = ceil(max_epoki / probkowanie_norma_macierzy) + SAFETY_MARGIN;
max_macierzy_Q = zeros(1, max_zapisow_Q);
max_macierzy_Q(1) = 1;  % Initialize first value
idx_max_Q = 1;  % Start at 1 since first value already set

% Arrays for trajectory realization tracking (m_realizacja_trajektorii_v2)
% Window fills every ilosc_probek_procent_realizacjii iterations
% Max iterations = max_epoki * mean_episode_length
% Max windows = total_iterations / window_size
max_realizacja_windows = ceil((max_epoki * mean_episode_length) / ilosc_probek_procent_realizacjii) + SAFETY_MARGIN;
wek_proc_realizacji = zeros(1, max_realizacja_windows);  % Realization percentage history
filtr_mnk = zeros(1, max_realizacja_windows);             % MNK filtered values
wsp_mnk = zeros(3, max_realizacja_windows);               % MNK coefficients [a; b; c]
wek_Te = zeros(1, max_realizacja_windows);                % Te value at each window
idx_realizacja = 0;  % Index counter for trajectory realization arrays