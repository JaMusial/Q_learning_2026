% Test if state/action dimensions change with Te
precision = 0.5;
oczekiwana_ilosc_stanow = 100;
gorne_ograniczenie = 100;
Kp = 1;
dt = 0.1;

fprintf('Testing state/action dimensions for different Te values:\n\n');

for Te = [20, 19.9, 10, 5, 2]
    [stany, akcje, no_of_states, no_of_actions, state_doc, action_doc] = ...
        f_generuj_stany_v2(precision, oczekiwana_ilosc_stanow, gorne_ograniczenie, Te, Kp, dt);
    
    fprintf('Te = %.1f: %d states, %d actions (goal state=%d, goal action=%d)\n', ...
        Te, no_of_states, no_of_actions, state_doc, action_doc);
end
