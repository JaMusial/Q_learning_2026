%% ========================================================================
%% m_losowanie_nowe - Constrained random action selection for exploration
%% ========================================================================
% PURPOSE:
%   Select random action from neighboring states' best actions ± RD
%   Apply directional constraint to ensure action matches state direction
%
% INPUTS (from workspace):
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
% CONSTRAINT LOGIC:
%   State > goal (s < 0, below trajectory) → Need positive Du → Action < goal
%   State < goal (s > 0, above trajectory) → Need negative Du → Action > goal
%
% NOTES:
%   - Called from m_regulator_Q.m during exploration phase
%   - Retry loop in m_regulator_Q.m falls back to exploitation after 10 failures
%% ========================================================================

[Q_value,wyb_akcja]=f_best_action_in_state(Q_2d, stan, nr_akcji_doc);

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