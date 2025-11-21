%% m_reset.m - Episode Reset and Initialization
%
% PURPOSE:
%   Prepares the system for a new learning episode by randomizing operating
%   conditions (setpoint or disturbance) and resetting iteration counters.
%   Called at the start of each epoch to ensure diverse training experiences.
%
% INPUTS (from workspace):
%   uczenie_obciazeniowe         - Flag: 1=learn with load disturbances
%   uczenie_zmiana_SP            - Flag: 1=learn with setpoint changes
%   SP_ini                       - Initial/nominal setpoint value
%   zakres_losowania_zmian_SP    - Range for random setpoint selection
%   iter                         - Global iteration counter
%   proc_max_y, proc_min_y       - Process output range (for scaling)
%   wart_max_y, wart_min_y       - Normalized output range (for scaling)
%
% OUTPUTS (to workspace):
%   SP                           - Setpoint for this episode
%   d                            - Load disturbance for this episode
%   maksymalna_ilosc_iteracji_uczenia - Episode length (iterations)
%   iteracja_uczenia             - Reset to 1 (start of episode)
%   y                            - Initial output (first iteration only)
%   realizacja_traj_epoka_idx    - Reset to 0
%   logi_idx                     - Reset to 0 (verification mode only)
%
% NOTES:
%   - Learning modes are mutually exclusive (only one should be enabled)
%   - In load disturbance mode: episode length is randomized ~N(3000, 150)
%   - In setpoint change mode: episode length remains unchanged
%   - Logging behavior differs between single iteration and verification modes

%% ========================================================================
%  LEARNING MODE SELECTION
%  ========================================================================

% Validate that exactly one learning mode is selected
if uczenie_obciazeniowe == 1 && uczenie_zmiana_SP == 1
    error('m_reset:BothModesEnabled', ...
          ['Both learning modes enabled simultaneously!\n', ...
           'Set EITHER uczenie_obciazeniowe=1 OR uczenie_zmiana_SP=1, not both.']);
end

if uczenie_obciazeniowe == 1 && uczenie_zmiana_SP == 0
    % =====================================================================
    % MODE 1: Load Disturbance Learning
    % =====================================================================
    % Controller learns to reject random disturbances at fixed setpoint.
    % Episode length randomized to expose controller to various transient
    % durations, preventing overfitting to specific time horizons.

    % Fixed setpoint (no SP changes in this mode)
    SP = SP_ini;

    % Generate random load disturbance: d ~ N(0, sigma)
    % Using 3-sigma rule: 99.7% of values within ±disturbance_range
    % disturbance_range from config.m (default: 0.5 for typical industrial disturbances)
    SIGMA_DIVISOR = 3;  % Statistical constant (3-sigma rule)
    disturbance_mean = 0;
    disturbance_sigma = disturbance_range / SIGMA_DIVISOR;
    d = normrnd(disturbance_mean, disturbance_sigma);

    % Randomize episode length: ~N(mean_episode_length, episode_length_variance/2)
    % Variation prevents overfitting to fixed episode duration
    % Parameters from config.m (defaults: mean=3000, variance=300)
    episode_length_sigma = episode_length_variance / 2;  % ~95% within ±300
    maksymalna_ilosc_iteracji_uczenia = round(normrnd(mean_episode_length, episode_length_sigma));

    % Enforce minimum episode length to ensure meaningful learning
    % min_episode_length from config.m (default: 10 iterations)
    if maksymalna_ilosc_iteracji_uczenia < min_episode_length
        maksymalna_ilosc_iteracji_uczenia = min_episode_length;
    end

    % Reset iteration counter for new episode
    iteracja_uczenia = 1;

elseif uczenie_obciazeniowe == 0 && uczenie_zmiana_SP == 1
    % =====================================================================
    % MODE 2: Setpoint Change Learning (Legacy Feature)
    % =====================================================================
    % Controller learns to track random setpoint changes without disturbances.
    %
    % DESIGN NOTE: Episode length is INTENTIONALLY FIXED (not randomized like Mode 1).
    % This legacy mode is rarely used and benefits from manual control over episode
    % count for specific testing scenarios. Uses maksymalna_ilosc_iteracji_uczenia
    % from config.m for predictable, controlled experiments.

    % No load disturbance in this mode
    d = 0;

    % Generate random setpoint using adaptive scaling
    % Calculate divisor to provide ~100 discrete random values for good granularity
    % Mathematical approach: dzielnik = 10^ceil(log10(100/range))
    %
    % Examples:
    %   range=0.05 → dzielnik=10000 → randi([0,500]) → 500 discrete values
    %   range=0.5  → dzielnik=1000  → randi([0,500]) → 500 discrete values
    %   range=5    → dzielnik=100   → randi([0,500]) → 500 discrete values
    %   range=50   → dzielnik=10    → randi([0,500]) → 500 discrete values

    % Validate positive range
    if zakres_losowania_zmian_SP <= 0
        error('m_reset:InvalidRange', ...
              'zakres_losowania_zmian_SP must be positive (current value: %.3f)', ...
              zakres_losowania_zmian_SP);
    end

    % Calculate divisor: ensure at least 100 discrete values
    dzielnik = 10^ceil(max(0, log10(100 / zakres_losowania_zmian_SP)));
    zakres_losowania = round(zakres_losowania_zmian_SP * dzielnik);

    % Generate random integer [0, zakres_losowania], then scale back to original range
    SP = randi([0 zakres_losowania], 1, 1) / dzielnik;

    % Reset iteration counter for new episode
    iteracja_uczenia = 1;

else
    % =====================================================================
    % ERROR: No valid learning mode selected
    % =====================================================================
    error('m_reset:NoModeSelected', ...
          ['No learning mode selected!\n', ...
           'Set either uczenie_obciazeniowe=1 OR uczenie_zmiana_SP=1.']);
end

%% ========================================================================
%  INITIALIZATION (First Iteration Only)
%  ========================================================================
% At the very first iteration of the entire simulation, initialize output
% to scaled setpoint value. This simulates starting near steady-state.
if iter == 1
    y = f_skalowanie(proc_max_y, proc_min_y, wart_max_y, wart_min_y, SP);
end

%% ========================================================================
%  RESET COUNTERS FOR NEW EPOCH
%  ========================================================================

% Reset trajectory realization index
% Tracks which sample we're at within trajectory logging for this epoch
if exist('realizacja_traj_epoka_idx', 'var')
    realizacja_traj_epoka_idx = 0;
end

% Reset logging index (verification mode only)
% NOTE: Logging behavior depends on mode:
%   - Single iteration mode (poj_iteracja_uczenia=1): logs accumulate
%     across ALL epochs to show full learning progression
%   - Verification mode (poj_iteracja_uczenia=0): logs reset each epoch
%     because only the final verification experiment matters
if exist('logi_idx', 'var') && exist('poj_iteracja_uczenia', 'var') && poj_iteracja_uczenia == 0
    logi_idx = 0;
end
