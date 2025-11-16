function [val_action, num_action] = f_best_action_in_state(table, state, nr_stanu_doc)
% f_best_action_in_state  Finds best action in a given state.
% Identical to original logic but more compact and vectorized.

row = table(state, :);
[val_action, num_action] = max(row);

% Handle ties — pick the one closest to nr_stanu_doc
same_mask = (row == val_action);
same_count = nnz(same_mask);

if same_count > 1
    candidates = find(same_mask);
    [~, idx_min] = min(abs(candidates - nr_stanu_doc));
    num_action = candidates(idx_min);
end
end
