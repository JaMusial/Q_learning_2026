
% Scale variables to normalized ranges
e = f_skalowanie(wart_max_e, wart_min_e, proc_max_e, proc_min_e, e);
u = f_skalowanie(wart_max_u, wart_min_u, proc_max_u, proc_min_u, u);
y = f_skalowanie(wart_max_y, wart_min_y, proc_max_y, proc_min_y, y);

% Random coefficient for epsilon-greedy exploration
a = randi([0, 100], [1, 1]) / 100;
u_old = u;


%% Manual control (initial samples)
if iter <= ilosc_probek_sterowanie_reczne
    u = SP / k;
    e = SP - y;
    de = 0;
    de2 = 0;

    if T0 > 0 && all(bufor_T0 == 0)
        bufor_T0 = bufor_T0 + f_skalowanie(proc_max_u, proc_min_u, wart_max_u, wart_min_u, u);
    end

    e_ref = e;
    de_ref = de;
    de2_ref = de2;
    y_ref = y;
    d_ref_s = d * 100;
    d_ref = 0;

    if iter == 1
        t = 0;
        y1_n = f_skalowanie(proc_max_y, proc_min_y, wart_max_y, wart_min_y, y);
        y2_n = f_skalowanie(proc_max_y, proc_min_y, wart_max_y, wart_min_y, y);
        y3_n = f_skalowanie(proc_max_y, proc_min_y, wart_max_y, wart_min_y, y);
    end

    sterowanie_reczne = 1;
    u_increment_bez_f_rzutujacej = 0;
    u_increment = 0;

    stan_value = de + 1/Te * e;
    stan = f_find_state(stan_value, stany);
    wyb_akcja = nr_akcji_doc;
    wart_akcji = akcje_sr(wyb_akcja);
    uczenie = 0;
    czy_losowanie = 0;
    R = 0;  % No reward during manual control phase

    % Initialize old_R for first iteration after manual control
    if ~exist('old_R', 'var')
        old_R = 0;
    end

    % Fill buffers during manual control but don't use buffered output (initially zeros)
    if T0_controller > 0
        [~, bufor_state] = f_bufor(stan, bufor_state);
        [~, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja);
        [~, bufor_uczenie] = f_bufor(uczenie, bufor_uczenie);
        [~, bufor_e] = f_bufor(e, bufor_e);  % Buffer error (not used currently but kept for consistency)
        [~, bufor_wart_akcji] = f_bufor(wart_akcji, bufor_wart_akcji);

    end

    stan_value_ref = de_ref + 1/Te * e_ref;
    stan_nr_ref = f_find_state(stan_value_ref, stany);

    % Initialize variables for projection function (no buffering during manual control)
    e_T0 = e;
    old_stan_T0 = stan;
    wyb_akcja_T0 = wyb_akcja;
    uczenie_T0 = uczenie;

    t = t + dt;

    %% Standard operation (Q-learning control)
else

    if iter == ilosc_probek_sterowanie_reczne + 1
        bufor_wart_akcji(:) = wart_akcji;
        bufor_e(:) = e;
        bufor_state(:) = stan;
        bufor_wyb_akcja(:) = wyb_akcja;
        bufor_uczenie(:) = 0;
        bufor_uczenie(:) = 0;
    end

    e_dec = e;   % error at decision time (before updating from new y)
    e_s = e;
    e = SP - y;
    de_s = de;
    de = (e - e_s) / dt;
    de2 = (de - de_s) / dt;

    d_ref_s = d_ref;
    d_ref = d * 100;
    e_ref_s = e_ref;

    % Reference trajectory follows ideal first-order dynamics toward setpoint
    % (disturbances are not modeled - they cause deviations that controllers must reject)
    e_ref = SP - y_ref;
    e_ref = (Te_bazowe - dt) / Te_bazowe * e_ref;
    de_ref_s = de_ref;
    de_ref = (e_ref - e_ref_s) / dt;
    de2_ref = (de_ref - de_ref_s) / dt;
    y_ref = SP - e_ref;

    t = t + dt;
    sterowanie_reczne = 0;

    stan_value = de + 1/Te * e;
    old_state = stan;
    stan = f_find_state(stan_value, stany);

    %% ========================================================================
    %% Save previous iteration's action, learning flag, and reward
    %% ========================================================================
    % CRITICAL FIX 2025-01-23: For T0_controller=0, we need to pair old_state
    % with the action AND reward that were ACTUALLY from that state (from previous iteration)
    old_wyb_akcja = wyb_akcja;
    old_uczenie = uczenie;
    old_R = R;

    %% ========================================================================
    %% Action selection for CURRENT state (BEFORE buffering)
    %% ========================================================================
    % CRITICAL FIX 2025-01-23: Action selection MUST happen before buffering
    % to ensure state-action pairs are correctly matched when buffered together.
    % Previous bug: wyb_akcja from iteration k-1 was buffered with stan from k.

    % Get best actions from neighboring states
    if stan + 1 > ilosc_stanow
        wyb_akcja_above = wyb_akcja;
    else
        [Q_value_state_above, wyb_akcja_above] = f_best_action_in_state(Q_2d, stan+1, nr_akcji_doc);
    end

    if stan - 1 < 1
        wyb_akcja_under = wyb_akcja;
    else
        [Q_value_state_under, wyb_akcja_under] = f_best_action_in_state(Q_2d, stan-1, nr_akcji_doc);
    end

    % If in target state, select target action
    if (stan == nr_stanu_doc)
        wyb_akcja = nr_akcji_doc;
        R = nagroda;  % Reward for current state (used for logging)
        wart_akcji = akcje_sr(wyb_akcja);
        uczenie = 1;
        czy_losowanie = 0;

        % Otherwise, use epsilon-greedy policy
    else
        R = 0;  % Reward for current state (used for logging)

        if eps >= a
            % Exploration: Random action selection with constraints
            ponowne_losowanie = 1;
            while ponowne_losowanie > 0 && ponowne_losowanie <= max_powtorzen_losowania_RD
                m_losowanie_nowe
            end

            % FIXED 2025-01-23: Don't update Q-values if exploration failed
            % If constraint rejected random actions 10 times, fallback to exploitation
            % but don't treat it as successful exploration for learning
            if ponowne_losowanie >= max_powtorzen_losowania_RD
                [Q_value, wyb_akcja] = f_best_action_in_state(Q_2d, stan, nr_akcji_doc);
                uczenie = 0;        % Don't update Q-values (failed exploration = exploitation)
                czy_losowanie = 0;  % Mark as exploitation for logging
            else
                uczenie = 1;        % Successful exploration - update Q-values
                czy_losowanie = 1;  % Mark as exploration for logging
            end

            wart_akcji = akcje_sr(wyb_akcja);

        else
            % Exploitation: Select best action
            [Q_value, wyb_akcja] = f_best_action_in_state(Q_2d, stan, nr_akcji_doc);
            wart_akcji = akcje_sr(wyb_akcja);
            uczenie = 0;
            czy_losowanie = 0;
        end
    end

    %% ========================================================================
    %% Delayed credit assignment (buffer state-action pairs)
    %% ========================================================================
    % Buffer the correctly matched (stan, wyb_akcja) pair
    %
    % NOTE 2026-01-15: For projection mode with T0>0, we DISABLE Q-learning
    % when projection significantly contributes to control. This avoids credit
    % assignment mismatch where Q-learning would credit Q-actions for outcomes
    % that were actually caused by the projection function.
    %
    % The problem: If we buffer raw action, Q learns wrong values (projection did the work)
    %              If we buffer effective action, it maps to action 50 (do nothing)
    % Solution: Don't update Q when projection dominates control

    if T0_controller > 0
        %% ============================================================
        %% DELAYED CREDIT ASSIGNMENT WITH PROJECTION (CORRECT VERSION)
        %% ============================================================
        % Key idea:
        % - Buffer EVERYTHING that influences the plant
        % - Projection must be evaluated in the SAME time frame as Q-action
        % - No dependence on future error allowed

        % ------------------------------------------------------------
        % 1. BUFFER STATE, RAW Q-ACTION, AND ERROR (DECISION TIME k)
        % ------------------------------------------------------------
        [old_stan_T0, bufor_state] = f_bufor(stan, bufor_state);
        [wyb_akcja_T0, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja);
        [uczenie_T0, bufor_uczenie] = f_bufor(uczenie, bufor_uczenie);
        [e_T0, bufor_e] = f_bufor(e_dec, bufor_e);   % <-- CRITICAL
        [wart_akcji_T0, bufor_wart_akcji] = f_bufor(wart_akcji, bufor_wart_akcji);


        % ------------------------------------------------------------
        % 2. DEFINE NEXT STATE (EFFECT IS VISIBLE NOW)
        % ------------------------------------------------------------
        stan_T0 = stan;

        % ------------------------------------------------------------
        % 3. BOOTSTRAP OVERRIDE (UNCHANGED)
        % ------------------------------------------------------------
        if old_stan_T0 == nr_stanu_doc && wyb_akcja_T0 == nr_akcji_doc
            stan_T0_for_bootstrap = nr_stanu_doc;
        else
            stan_T0_for_bootstrap = stan_T0;
        end

        % ------------------------------------------------------------
        % 4. REWARD LOGIC (UNCHANGED)
        % ------------------------------------------------------------
        if stan_T0 == nr_stanu_doc || ...
                (old_stan_T0 == nr_stanu_doc && wyb_akcja_T0 == nr_akcji_doc)
            R_buffered = 1;
        else
            R_buffered = 0;
        end

    else
        %% ============================================================
        %% STANDARD ONE-STEP Q-LEARNING (NO DEAD TIME)
        %% ============================================================
        stan_T0 = stan;
        stan_T0_for_bootstrap = stan_T0;
        old_stan_T0 = old_state;
        wyb_akcja_T0 = old_wyb_akcja;
        uczenie_T0 = old_uczenie;
        R_buffered = old_R;
        e_T0 = e;
        wart_akcji_T0=wart_akcji;
    end

    stan_value_ref = de_ref + 1/Te * e_ref;
    stan_nr_ref = f_find_state(stan_value_ref, stany);

    maxS_ref = max(Q_2d(stan_nr_ref, :));
    maxS = max(Q_2d(stan_T0_for_bootstrap, :));

    if uczenie_T0 == 1 && pozwolenie_na_uczenia == 1 && ...
            stan_T0_for_bootstrap ~= 0 && old_stan_T0 ~= 0

        Q_2d(old_stan_T0, wyb_akcja_T0) = ...
            Q_2d(old_stan_T0, wyb_akcja_T0) + ...
            alfa * (R_buffered + gamma * maxS - ...
            Q_2d(old_stan_T0, wyb_akcja_T0));
    end

end

% Store trajectory realization for analysis (uses current state reward)
if eks_wer == 0
    realizacja_traj_epoka_idx = realizacja_traj_epoka_idx + 1;
    realizacja_traj_epoka(realizacja_traj_epoka_idx) = R;
end

wart_akcji_bez_f_rzutujacej = wart_akcji;

%% ============================================================
%% APPLY PROJECTION (CAUSALLY CORRECT)
%% ============================================================

if f_rzutujaca_on == 1
    % Projection MUST use BUFFERED error
    funkcja_rzutujaca = e_T0 * (1/Te - 1/Ti);
else
    funkcja_rzutujaca = 0;
end

wart_akcji_eff = wart_akcji_T0 - funkcja_rzutujaca;

% Calculate control signal
if sterowanie_reczne == 0
    u_increment = kQ * wart_akcji_eff * dt;
    u = u + u_increment;

    if u <= ograniczenie_sterowania_dol
        u = ograniczenie_sterowania_dol;
        uczenie = 0;
        bufor_uczenie(end) = 0;   % <<< critical
    end

    if u >= ograniczenie_sterowania_gora
        u = ograniczenie_sterowania_gora;
        uczenie = 0;
        bufor_uczenie(end) = 0;   % <<< critical
    end

end

% Apply disturbance if enabled
if dist_on == 1
    z = -z_zakres + (z_zakres + z_zakres) * rand(1, 1);
end

% Scale back to process variable ranges
e = f_skalowanie(proc_max_e, proc_min_e, wart_max_e, wart_min_e, e);
u = f_skalowanie(proc_max_u, proc_min_u, wart_max_u, wart_min_u, u);
y = f_skalowanie(proc_max_y, proc_min_y, wart_max_y, wart_min_y, y);

% Calculate next plant output y(i+1)
iteracje_petla_wew = dt / 0.01;
if sterowanie_reczne == 1
    d_obiekt = 0;
else
    d_obiekt = d;
end
y_old = y;

if T0 > 0
    [u_T0, bufor_T0] = f_bufor(u, bufor_T0);
else
    u_T0 = u;
end

for petla_wew_obiekt = 1:iteracje_petla_wew
    [y, y1_n, y2_n, y3_n] = f_obiekt(nr_modelu, 0.01, k, T, y, y1_n, y2_n, y3_n, u_T0+d_obiekt);
    y = y + z;
end
delta_y = y - y_old;