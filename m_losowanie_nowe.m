%% ========================================================================
%% m_losowanie_nowe - Constrained random action selection for exploration
%% ========================================================================
% PURPOSE:
%   Select random action for exploration with constraints
%   TWO MODES:
%   - f_rzutujaca_on=0 (staged learning): Range from neighboring states + constraints
%   - f_rzutujaca_on=1 (projection): Range from best action ± RD + constraints
%
% INPUTS (from workspace):
%   f_rzutujaca_on - Projection mode flag
%   Q_2d - Q-matrix
%   stan - Current state number
%   wyb_akcja_above - Best action from state+1
%   wyb_akcja_under - Best action from state-1
%   nr_akcji_doc - Goal action index (typically 50)
%   nr_stanu_doc - Goal state index (typically 50)
%   RD - Random deviation range
%   ponowne_losowanie - Retry counter
%
% OUTPUTS (to workspace):
%   wyb_akcja - Selected action (either random or best if rejected)
%   wyb_akcja3 - Random action candidate
%   ponowne_losowanie - Updated retry counter (0=accepted, >0=rejected)
%
% CONSTRAINT LOGIC (f_rzutujaca_on=0):
%   State > goal (s < 0, below trajectory) → Need positive Du → Action < goal
%   State < goal (s > 0, above trajectory) → Need negative Du → Action > goal
%
% CONSTRAINT LOGIC (f_rzutujaca_on=1):
%   Draw from [best_action - RD, best_action + RD]
%   Reject if action == best_action (force exploration)
%   Reject if action == goal_action (not at goal state)
%   SAME-SIDE MATCHING: State > goal → Action > goal; State < goal → Action < goal
%
% NOTES:
%   - Called from m_regulator_Q.m during exploration phase
%   - Retry loop in m_regulator_Q.m falls back to exploitation after 10 failures
%% ========================================================================

[Q_value,wyb_akcja]=f_best_action_in_state(Q_2d, stan, nr_akcji_doc);

%% ========================================================================
%% PROJECTION MODE: Range-based exploration with directional constraints
%% ========================================================================
if f_rzutujaca_on == 1
    % Exploration: draw from [best_action - RD, best_action + RD]
    min_losowanie = max(1, wyb_akcja - RD);           % Clamp to valid range
    max_losowanie = min(ile_akcji, wyb_akcja + RD);   % Clamp to valid range

    % Sample random action
    wyb_akcja3 = randi([min_losowanie, max_losowanie], [1, 1]);

    % Apply constraints:
    % 1. Don't select same action as best (force exploration)
    % 2. Don't select goal action (unless at goal state)
    % 3. SAME-SIDE MATCHING: Action must be on same side as State
    %    State > goal (negative s) → Action > goal (negative Du)
    %    State < goal (positive s) → Action < goal (positive Du)
    if wyb_akcja3 ~= wyb_akcja && wyb_akcja3 ~= nr_akcji_doc %&& ...
           % ((wyb_akcja3 > nr_akcji_doc && stan > nr_stanu_doc) || ...
            % (wyb_akcja3 < nr_akcji_doc && stan < nr_stanu_doc))
        ponowne_losowanie = 0;  % Accept
        wyb_akcja = wyb_akcja3;
    else
        ponowne_losowanie = ponowne_losowanie + 1;  % Reject, retry
    end

    return;  % Exit early, skip complex logic below
end

%% ========================================================================
%% STAGED LEARNING MODE: Complex directional constraints
%% ========================================================================

% Construct sampling range from neighboring states' best actions ± RD
if wyb_akcja_above < wyb_akcja_under
    min_losowanie = wyb_akcja_under - RD;
    max_losowanie = wyb_akcja_above + RD;
else
    min_losowanie = wyb_akcja_above - RD;
    max_losowanie = wyb_akcja_under + RD;
end

% Sample random action from range
if max_losowanie > min_losowanie
    wyb_akcja3=randi([min_losowanie, max_losowanie], [1, 1]);
else
    wyb_akcja3=randi([max_losowanie, min_losowanie], [1, 1]);
end

% Apply directional constraint (SAME-SIDE MATCHING)
% FIXED 2025-01-23: Check RANDOM action (wyb_akcja3), not best action (wyb_akcja)
% State/action arrays both ordered: [positive descending, zero, negative descending]
% Constraint: Action must be on SAME SIDE as State
%   State > goal (negative s) → Action > goal (negative Du)
%   State < goal (positive s) → Action < goal (positive Du)
if wyb_akcja3~=nr_akcji_doc && wyb_akcja3 ~= wyb_akcja &&...
        ((wyb_akcja3 > nr_akcji_doc && stan > nr_stanu_doc) ||...
        (wyb_akcja3 < nr_akcji_doc && stan < nr_stanu_doc))
    ponowne_losowanie=0;
    wyb_akcja=wyb_akcja3;
else
    ponowne_losowanie=ponowne_losowanie+1;
end