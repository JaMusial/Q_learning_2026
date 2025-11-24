function [stany, akcje, no_of_states, no_of_actions, state_doc, action_doc] =...
    f_generuj_stany_v2(precision, oczekiwana_ilosc_stanow, gorne_ograniczenie, Te, Kp, dt)
% ============================================================================
% f_generuj_stany_v2 - Generate state and action spaces for Q2d controller
% ============================================================================
%
% PURPOSE:
%   Generates discretized state and action spaces with geometric distribution
%   for Q-learning controller. Actions are distributed geometrically from
%   fine resolution near zero (goal action) to coarse resolution at limits.
%   States are placed at midpoints between consecutive actions.
%
% INPUTS:
%   precision                - Steady-state accuracy parameter
%   oczekiwana_ilosc_stanow  - Expected number of states (actual = 2*this - 1)
%   gorne_ograniczenie       - Upper control limit (before scaling)
%   Te                       - Current time constant [s]
%   Kp                       - Controller gain
%   dt                       - Sampling time [s]
%
% OUTPUTS:
%   stany                    - State space vector (symmetric around 0)
%   akcje                    - Action space vector (symmetric around 0)
%   no_of_states             - Number of states
%   no_of_actions            - Number of actions
%   state_doc                - Goal state index (center)
%   action_doc               - Goal action index (center, zero increment)
%
% ALGORITHM:
%   1. Scale upper limit by controller dynamics: gorne_ograniczenie/(Kp*dt)
%   2. Generate positive half of action space geometrically:
%      - Start: [0, precision*2/Te]
%      - Geometric ratio q from scaled limit and number of actions
%      - akcje(i) = (precision*2/Te) * q^(i-1)
%   3. Generate states as midpoints between consecutive actions
%   4. Create symmetric negative half for both states and actions
%
% NOTES:
%   - Uses geometric distribution for better resolution near goal
%   - State space has 2*N-1 elements, action space has 2*N-1 elements
%   - Goal state/action at center index (zero error/increment)
%   - Preallocated arrays for performance
%
% SIDE EFFECTS:
%   - Sets global format to 'long' for numerical precision
%
% ============================================================================

format long

% ============================================================================
% Scale upper limit by controller dynamics
% ============================================================================
gorne_ograniczenie = gorne_ograniczenie / (Kp * dt);

% ============================================================================
% Calculate action space size and geometric ratio
% ============================================================================
% Divide by 2: User specifies total state count, but we generate positive half
% then mirror to negative half for symmetry
ilosc_akcji = floor(oczekiwana_ilosc_stanow / 2);

% Smallest action = precision * 2 / Te
% Why *2? States are midpoints between actions, so smallest_state = smallest_action/2
% Goal: In steady state (de=0), stan_value = e/Te
%       Goal state should capture: -precision/Te < e/Te <= +precision/Te
%       Which gives: -precision < e <= +precision (Te cancels!)
%       Since smallest_state = (precision*2/Te)/2 = precision/Te, this works perfectly
%       and maintains ±precision error tolerance regardless of Te during staged learning
smallest_action = precision * 2 / Te;

% Geometric ratio: maps from smallest action to upper limit over ilosc_akcji steps
% Formula ensures akcje(ilosc_akcji) = gorne_ograniczenie
q = (gorne_ograniczenie / smallest_action)^(1 / (ilosc_akcji - 1));

% ============================================================================
% Generate positive half of action space (geometric distribution)
% ============================================================================
% Preallocate for performance
akcje_positive = zeros(1, ilosc_akcji);

% First two actions: zero (goal action) and smallest non-zero action
akcje_positive(1) = 0;
akcje_positive(2) = smallest_action;

% Remaining actions: geometric progression
for i = 3:ilosc_akcji
    akcje_positive(i) = smallest_action * q^(i - 1);
end

% ============================================================================
% Generate positive half of state space (midpoints between actions)
% ============================================================================
% Preallocate for performance
stany_positive = zeros(1, ilosc_akcji - 1);

for i = 1:(ilosc_akcji - 1)
    stany_positive(i) = (akcje_positive(i + 1) + akcje_positive(i)) / 2;
end

% ============================================================================
% Create symmetric full state and action spaces
% ============================================================================
% States: [negative half, positive half] - symmetric around 0
stany = [flip(stany_positive), -stany_positive];

% Actions: [negative half, 0, positive half] - symmetric around 0
% Note: exclude zero from negative half to avoid duplication
akcje = [flip(akcje_positive), -akcje_positive(2:end)];

% ============================================================================
% Calculate output parameters
% ============================================================================
no_of_states = length(stany);
no_of_actions = length(akcje);

% Goal state/action indices: Center of symmetric arrays
% For odd-length arrays (which ours always are), floor(n/2)+1 gives exact center
% Example: [a, b, c, d, e] has 5 elements, center is floor(5/2)+1 = 3
% This corresponds to zero error (goal state) and zero control increment (goal action)
state_doc = floor(no_of_states / 2) + 1;
action_doc = floor(no_of_actions / 2) + 1;

end
