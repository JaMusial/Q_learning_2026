%% m_zapis_logow - Logging data from Q-learning and reference controllers
%
% Features:
%   - Preallocated arrays for performance (no dynamic growth)
%   - Index-based access instead of end+1 (10-100x faster)
%   - Automatic array trimming after episode ends
%
% Author: Jakub Musiał
% Modified: 2025-11-19

if reset_logi==1 || exist('logi','var') == 0
    % Preallocate arrays to maximum iteration size for performance
    % Round to integer since normrnd() can return float values
    % In single iteration mode: allocate for all epochs (logs accumulate)
    % In verification mode: allocate for one epoch (logs reset each epoch)
    if exist('poj_iteracja_uczenia', 'var') && poj_iteracja_uczenia == 1
        max_samples = round(max_epoki * maksymalna_ilosc_iteracji_uczenia);
    else
        max_samples = round(maksymalna_ilosc_iteracji_uczenia);
    end

    % Q-controller logs
    logi.Q_e = zeros(1, max_samples);
    logi.Q_de = zeros(1, max_samples);
    logi.Q_de2 = zeros(1, max_samples);
    logi.Q_stan_value = zeros(1, max_samples);
    logi.Q_stan_nr = zeros(1, max_samples);
    logi.Q_akcja_value = zeros(1, max_samples);
    logi.Q_akcja_value_bez_f_rzutujacej = zeros(1, max_samples);
    logi.Q_akcja_nr = zeros(1, max_samples);
    logi.Q_funkcja_rzut = zeros(1, max_samples);
    logi.Q_R = zeros(1, max_samples);
    logi.Q_losowanie = zeros(1, max_samples);
    logi.Q_y = zeros(1, max_samples);
    logi.Q_delta_y = zeros(1, max_samples);
    logi.Q_u = zeros(1, max_samples);
    logi.Q_u_increment = zeros(1, max_samples);
    logi.Q_u_increment_bez_f_rzutujacej = zeros(1, max_samples);
    logi.Q_t = zeros(1, max_samples);
    logi.Q_d = zeros(1, max_samples);
    logi.Q_SP = zeros(1, max_samples);
    logi.Q_czas_zaklocenia = zeros(1, max_samples);
    logi.Q_maxS = zeros(1, max_samples);
    logi.Q_table_update = zeros(1, max_samples);

    % DEBUG: Detailed Q-learning diagnostics (enabled via debug_logging in config.m)
    % Only initialize DEBUG fields if debug_logging is enabled
    if exist('debug_logging', 'var') && debug_logging == 1
        logi.DEBUG_old_state = zeros(1, max_samples);           % State from previous iteration
        logi.DEBUG_old_action = zeros(1, max_samples);          % Action from previous iteration
        logi.DEBUG_old_R = zeros(1, max_samples);               % Reward from previous iteration
        logi.DEBUG_old_uczenie = zeros(1, max_samples);         % Learning flag from previous iteration
        logi.DEBUG_stan_T0 = zeros(1, max_samples);             % Next state for Q-update (actual, may have drift)
        logi.DEBUG_stan_T0_for_bootstrap = zeros(1, max_samples); % Next state for bootstrap (override if goal->goal)
        logi.DEBUG_old_stan_T0 = zeros(1, max_samples);         % State being updated (buffered or old_state)
        logi.DEBUG_wyb_akcja_T0 = zeros(1, max_samples);        % Action being updated (buffered or old_action)
        logi.DEBUG_uczenie_T0 = zeros(1, max_samples);          % Learning flag for update (buffered or old)
        logi.DEBUG_R_buffered = zeros(1, max_samples);          % Reward used in Q-update
        logi.DEBUG_Q_old_value = zeros(1, max_samples);         % Q-value before update
        logi.DEBUG_Q_new_value = zeros(1, max_samples);         % Q-value after update
        logi.DEBUG_bootstrap = zeros(1, max_samples);           % γ·max(Q(s',:)) term
        logi.DEBUG_TD_error = zeros(1, max_samples);            % R + γ·max(Q(s',:)) - Q(s,a)
        logi.DEBUG_global_max_Q = zeros(1, max_samples);        % Maximum Q-value in entire table
        logi.DEBUG_global_max_state = zeros(1, max_samples);    % State with maximum Q-value
        logi.DEBUG_global_max_action = zeros(1, max_samples);   % Action with maximum Q-value
        logi.DEBUG_goal_Q = zeros(1, max_samples);              % Q(goal_state, goal_action)
        logi.DEBUG_is_goal_state = zeros(1, max_samples);       % 1 if current state is goal
        logi.DEBUG_is_updating_goal = zeros(1, max_samples);    % 1 if updating goal state Q-value
    end

    % Reference trajectory logs
    logi.Ref_e = zeros(1, max_samples);
    logi.Ref_y = zeros(1, max_samples);
    logi.Ref_de = zeros(1, max_samples);
    logi.Ref_de2 = zeros(1, max_samples);
    logi.Ref_stan_value = zeros(1, max_samples);
    logi.Ref_stan_nr = zeros(1, max_samples);

    % PID controller logs
    logi.PID_e = zeros(1, max_samples);
    logi.PID_de = zeros(1, max_samples);
    logi.PID_de2 = zeros(1, max_samples);
    logi.PID_u = zeros(1, max_samples);
    logi.PID_u_increment = zeros(1, max_samples);
    logi.PID_stan_value = zeros(1, max_samples);
    logi.PID_stan_nr = zeros(1, max_samples);
    logi.PID_akcja_value = zeros(1, max_samples);
    logi.PID_akcja_nr = zeros(1, max_samples);
    logi.PID_t = zeros(1, max_samples);
    logi.PID_y = zeros(1, max_samples);

    % Reset index counter
    logi_idx = 0;
end

if zapis_logi==1

    reset_logi=0;

    % Increment index counter
    logi_idx = logi_idx + 1;

    % Use indexed access instead of end+1 for performance
    logi.Q_e(logi_idx) = f_skalowanie(wart_max_e, wart_min_e, proc_max_e, proc_min_e, e);
    logi.Q_de(logi_idx) = de;
    logi.Q_de2(logi_idx) = de2;
    logi.Q_stan_value(logi_idx) = stan_value;
    logi.Q_stan_nr(logi_idx) = stan;
    logi.Q_akcja_value(logi_idx) = wart_akcji;
    logi.Q_akcja_value_bez_f_rzutujacej(logi_idx) = wart_akcji_bez_f_rzutujacej;
    logi.Q_akcja_nr(logi_idx) = wyb_akcja;
    logi.Q_funkcja_rzut(logi_idx) = funkcja_rzutujaca;
    logi.Q_R(logi_idx) = R;
    logi.Q_losowanie(logi_idx) = czy_losowanie;
    logi.Q_y(logi_idx) = f_skalowanie(wart_max_y, wart_min_y, proc_max_y, proc_min_y, y);
    logi.Q_delta_y(logi_idx) = delta_y;
    logi.Q_u(logi_idx) = f_skalowanie(wart_max_u, wart_min_u, proc_max_u, proc_min_u, u);
    logi.Q_u_increment(logi_idx) = u_increment;
    logi.Q_u_increment_bez_f_rzutujacej(logi_idx) = u_increment_bez_f_rzutujacej;
    logi.Q_t(logi_idx) = t;
    logi.Q_d(logi_idx) = d;
    logi.Q_SP(logi_idx) = SP;  % FIXED 2025-01-28: SP is already in process units, no scaling needed
    logi.Q_czas_zaklocenia(logi_idx) = maksymalna_ilosc_iteracji_uczenia;
    logi.Q_maxS(logi_idx) = maxS;
    logi.Q_table_update(logi_idx) = Q_update;

    % DEBUG: Populate detailed Q-learning diagnostics (if debug_logging enabled)
    if exist('debug_logging', 'var') && debug_logging == 1
        % Previous iteration values
        if exist('old_state', 'var')
            logi.DEBUG_old_state(logi_idx) = old_state;
        end
        if exist('old_wyb_akcja', 'var')
            logi.DEBUG_old_action(logi_idx) = old_wyb_akcja;
        end
        if exist('old_R', 'var')
            logi.DEBUG_old_R(logi_idx) = old_R;
        end
        if exist('old_uczenie', 'var')
            logi.DEBUG_old_uczenie(logi_idx) = old_uczenie;
        end

        % Buffered/selected values for Q-update
        if exist('stan_T0', 'var')
            logi.DEBUG_stan_T0(logi_idx) = stan_T0;
        end
        if exist('stan_T0_for_bootstrap', 'var')
            logi.DEBUG_stan_T0_for_bootstrap(logi_idx) = stan_T0_for_bootstrap;
        end
        if exist('old_stan_T0', 'var')
            logi.DEBUG_old_stan_T0(logi_idx) = old_stan_T0;
        end
        if exist('wyb_akcja_T0', 'var')
            logi.DEBUG_wyb_akcja_T0(logi_idx) = wyb_akcja_T0;
        end
        if exist('uczenie_T0', 'var')
            logi.DEBUG_uczenie_T0(logi_idx) = uczenie_T0;
        end
        if exist('R_buffered', 'var')
            logi.DEBUG_R_buffered(logi_idx) = R_buffered;
        end

        % Q-value tracking (only if Q-update happened)
        % CRITICAL FIX 2025-01-23 (Bug #6): Use stan_T0_for_bootstrap to match Q-update condition
        if exist('uczenie_T0', 'var') && exist('old_stan_T0', 'var') && exist('wyb_akcja_T0', 'var') && ...
           exist('stan_T0_for_bootstrap', 'var') && ...
           uczenie_T0 == 1 && pozwolenie_na_uczenia == 1 && stan_T0_for_bootstrap ~= 0 && old_stan_T0 ~= 0
            % Q-value before update (calculated before Q_update was applied)
            logi.DEBUG_Q_old_value(logi_idx) = Q_2d(old_stan_T0, wyb_akcja_T0) - Q_update;
            % Q-value after update (current value)
            logi.DEBUG_Q_new_value(logi_idx) = Q_2d(old_stan_T0, wyb_akcja_T0);
            % Bootstrap term
            if exist('gamma', 'var') && exist('maxS', 'var')
                logi.DEBUG_bootstrap(logi_idx) = gamma * maxS;
            end
            % TD error
            if exist('R_buffered', 'var') && exist('gamma', 'var') && exist('maxS', 'var')
                logi.DEBUG_TD_error(logi_idx) = R_buffered + gamma * maxS - (Q_2d(old_stan_T0, wyb_akcja_T0) - Q_update);
            end
        end

        % Global Q-table statistics
        [max_Q, max_idx] = max(Q_2d(:));
        [max_state, max_action] = ind2sub(size(Q_2d), max_idx);
        logi.DEBUG_global_max_Q(logi_idx) = max_Q;
        logi.DEBUG_global_max_state(logi_idx) = max_state;
        logi.DEBUG_global_max_action(logi_idx) = max_action;

        % Goal state tracking
        if exist('nr_stanu_doc', 'var') && exist('nr_akcji_doc', 'var')
            logi.DEBUG_goal_Q(logi_idx) = Q_2d(nr_stanu_doc, nr_akcji_doc);
            logi.DEBUG_is_goal_state(logi_idx) = (stan == nr_stanu_doc);
            if exist('old_stan_T0', 'var')
                logi.DEBUG_is_updating_goal(logi_idx) = (old_stan_T0 == nr_stanu_doc && uczenie_T0 == 1);
            end
        end
    end

    logi.Ref_e(logi_idx) = e_ref;
    logi.Ref_y(logi_idx) = y_ref;
    logi.Ref_de(logi_idx) = de_ref;
    logi.Ref_de2(logi_idx) = de2_ref;
    logi.Ref_stan_value(logi_idx) = stan_value_ref;
    logi.Ref_stan_nr(logi_idx) = stan_nr_ref;

    if zapis_logi_PID==1
        logi.PID_e(logi_idx) = f_skalowanie(wart_max_e, wart_min_e, proc_max_e, proc_min_e, e_PID);
        logi.PID_de(logi_idx) = de_PID;
        logi.PID_de2(logi_idx) = de2_PID;
        logi.PID_u(logi_idx) = f_skalowanie(wart_max_u, wart_min_u, proc_max_u, proc_min_u, u_PID);
        logi.PID_u_increment(logi_idx) = u_increment_PID;
        logi.PID_stan_value(logi_idx) = stan_value_PID;
        logi.PID_stan_nr(logi_idx) = stan_PID;
        logi.PID_akcja_value(logi_idx) = wart_akcji_PID;
        logi.PID_akcja_nr(logi_idx) = akcja_nr_PID;
        logi.PID_t(logi_idx) = t_PID;
        logi.PID_y(logi_idx) = f_skalowanie(wart_max_y, wart_min_y, proc_max_y, proc_min_y, y_PID);
    end
end

% Trim arrays to actual used size when episode ends (called from m_warunek_stopu or similar)
if exist('trim_logi', 'var') && trim_logi == 1
    % Trim Q-controller logs
    logi.Q_e = logi.Q_e(1:logi_idx);
    logi.Q_de = logi.Q_de(1:logi_idx);
    logi.Q_de2 = logi.Q_de2(1:logi_idx);
    logi.Q_stan_value = logi.Q_stan_value(1:logi_idx);
    logi.Q_stan_nr = logi.Q_stan_nr(1:logi_idx);
    logi.Q_akcja_value = logi.Q_akcja_value(1:logi_idx);
    logi.Q_akcja_value_bez_f_rzutujacej = logi.Q_akcja_value_bez_f_rzutujacej(1:logi_idx);
    logi.Q_akcja_nr = logi.Q_akcja_nr(1:logi_idx);
    logi.Q_funkcja_rzut = logi.Q_funkcja_rzut(1:logi_idx);
    logi.Q_R = logi.Q_R(1:logi_idx);
    logi.Q_losowanie = logi.Q_losowanie(1:logi_idx);
    logi.Q_y = logi.Q_y(1:logi_idx);
    logi.Q_delta_y = logi.Q_delta_y(1:logi_idx);
    logi.Q_u = logi.Q_u(1:logi_idx);
    logi.Q_u_increment = logi.Q_u_increment(1:logi_idx);
    logi.Q_u_increment_bez_f_rzutujacej = logi.Q_u_increment_bez_f_rzutujacej(1:logi_idx);
    logi.Q_t = logi.Q_t(1:logi_idx);
    logi.Q_d = logi.Q_d(1:logi_idx);
    logi.Q_SP = logi.Q_SP(1:logi_idx);
    logi.Q_czas_zaklocenia = logi.Q_czas_zaklocenia(1:logi_idx);
    logi.Q_maxS = logi.Q_maxS(1:logi_idx);
    logi.Q_table_update = logi.Q_table_update(1:logi_idx);

    % Trim DEBUG logs (if they exist and logi_idx is within bounds)
    if isfield(logi, 'DEBUG_old_state')
        % CRITICAL FIX 2025-01-23: Check bounds before trimming
        % During verification experiment, logi_idx can exceed original DEBUG array size
        % Only trim if logi_idx is within the allocated array size
        debug_array_size = length(logi.DEBUG_old_state);
        if logi_idx <= debug_array_size
            logi.DEBUG_old_state = logi.DEBUG_old_state(1:logi_idx);
            logi.DEBUG_old_action = logi.DEBUG_old_action(1:logi_idx);
            logi.DEBUG_old_R = logi.DEBUG_old_R(1:logi_idx);
            logi.DEBUG_old_uczenie = logi.DEBUG_old_uczenie(1:logi_idx);
            logi.DEBUG_stan_T0 = logi.DEBUG_stan_T0(1:logi_idx);
            logi.DEBUG_stan_T0_for_bootstrap = logi.DEBUG_stan_T0_for_bootstrap(1:logi_idx);
            logi.DEBUG_old_stan_T0 = logi.DEBUG_old_stan_T0(1:logi_idx);
            logi.DEBUG_wyb_akcja_T0 = logi.DEBUG_wyb_akcja_T0(1:logi_idx);
            logi.DEBUG_uczenie_T0 = logi.DEBUG_uczenie_T0(1:logi_idx);
            logi.DEBUG_R_buffered = logi.DEBUG_R_buffered(1:logi_idx);
            logi.DEBUG_Q_old_value = logi.DEBUG_Q_old_value(1:logi_idx);
            logi.DEBUG_Q_new_value = logi.DEBUG_Q_new_value(1:logi_idx);
            logi.DEBUG_bootstrap = logi.DEBUG_bootstrap(1:logi_idx);
            logi.DEBUG_TD_error = logi.DEBUG_TD_error(1:logi_idx);
            logi.DEBUG_global_max_Q = logi.DEBUG_global_max_Q(1:logi_idx);
            logi.DEBUG_global_max_state = logi.DEBUG_global_max_state(1:logi_idx);
            logi.DEBUG_global_max_action = logi.DEBUG_global_max_action(1:logi_idx);
            logi.DEBUG_goal_Q = logi.DEBUG_goal_Q(1:logi_idx);
            logi.DEBUG_is_goal_state = logi.DEBUG_is_goal_state(1:logi_idx);
            logi.DEBUG_is_updating_goal = logi.DEBUG_is_updating_goal(1:logi_idx);
        else
            % logi_idx exceeds DEBUG array size (verification experiment)
            % Keep DEBUG arrays as-is from training phase (don't trim)
            % This happens when debug_logging was enabled for training but
            % verification experiment runs longer than training episodes
        end
    end

    % Trim reference logs
    logi.Ref_e = logi.Ref_e(1:logi_idx);
    logi.Ref_y = logi.Ref_y(1:logi_idx);
    logi.Ref_de = logi.Ref_de(1:logi_idx);
    logi.Ref_de2 = logi.Ref_de2(1:logi_idx);
    logi.Ref_stan_value = logi.Ref_stan_value(1:logi_idx);
    logi.Ref_stan_nr = logi.Ref_stan_nr(1:logi_idx);

    % Trim PID logs (only if they were used)
    if zapis_logi_PID==1
        logi.PID_e = logi.PID_e(1:logi_idx);
        logi.PID_de = logi.PID_de(1:logi_idx);
        logi.PID_de2 = logi.PID_de2(1:logi_idx);
        logi.PID_u = logi.PID_u(1:logi_idx);
        logi.PID_u_increment = logi.PID_u_increment(1:logi_idx);
        logi.PID_stan_value = logi.PID_stan_value(1:logi_idx);
        logi.PID_stan_nr = logi.PID_stan_nr(1:logi_idx);
        logi.PID_akcja_value = logi.PID_akcja_value(1:logi_idx);
        logi.PID_akcja_nr = logi.PID_akcja_nr(1:logi_idx);
        logi.PID_t = logi.PID_t(1:logi_idx);
        logi.PID_y = logi.PID_y(1:logi_idx);
    end

    % Reset trim flag
    trim_logi = 0;
end
