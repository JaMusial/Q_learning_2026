
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

        elseif stan ~= 0
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
    % NOW buffer the correctly matched (stan, wyb_akcja) pair

    if T0_controller > 0
        % Buffer current state, action for delayed credit assignment
        [old_stan_T0, bufor_state] = f_bufor(stan, bufor_state);
        [wyb_akcja_T0, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja);
        [uczenie_T0, bufor_uczenie] = f_bufor(uczenie, bufor_uczenie);
        [e_T0, bufor_e] = f_bufor(e, bufor_e);  % Buffer error (not used but kept for consistency)

        % Use CURRENT state as next state (effect is visible now)
        stan_T0 = stan;

        % CRITICAL FIX 2025-01-23 (Bug #6): Bootstrap override to prevent drift contamination
        % Problem: When goal state + goal action selected, next state SHOULD be goal (by design)
        % But numerical drift over T0_controller/dt iterations causes next state to be 49 or 51
        % This contaminates bootstrap with lower Q-values, pulling Q(50,50) DOWN instead of UP
        % Solution: Override next state to goal for bootstrap calculation when goal→goal intended
        if old_stan_T0 == nr_stanu_doc && wyb_akcja_T0 == nr_akcji_doc
            stan_T0_for_bootstrap = nr_stanu_doc;  % Override: goal action should keep at goal
        else
            stan_T0_for_bootstrap = stan_T0;  % Use actual next state
        end

        % Reward logic for goal-reaching with disturbances and dead time:
        % We need to ensure Q(goal_state, goal_action) remains the highest value!
        % Two cases for R=1:
        % 1. Arriving at goal state (stan_T0 == goal) - rewards transitions TO goal
        % 2. Being in goal WITH goal action (old_stan_T0 == goal AND wyb_akcja_T0 == goal_action)
        %    - ensures Q(goal,goal_action) stays maximum even with disturbances
        if stan_T0 == nr_stanu_doc || (old_stan_T0 == nr_stanu_doc && wyb_akcja_T0 == nr_akcji_doc)
            R_buffered = 1;
        else
            R_buffered = 0;
        end
    else
        % No dead time compensation: standard one-step Q-learning
        % CRITICAL FIX 2025-01-23: Pair old_state with old_wyb_akcja AND old_R (from same iteration)
        % to maintain correct Q-learning semantics: Q(s_k-1, a_k-1) updated with R_k-1 using s_k
        stan_T0 = stan;
        stan_T0_for_bootstrap = stan_T0;  % No override needed for T0=0 (minimal drift)
        old_stan_T0 = old_state;
        wyb_akcja_T0 = old_wyb_akcja;  % Action from SAME iteration as old_state
        uczenie_T0 = old_uczenie;      % Learning flag from SAME iteration as old_state
        R_buffered = old_R;            % Reward from SAME iteration as old_state (CRITICAL FIX!)
        e_T0 = e;                      % No buffering for error (use current)
    end

    stan_value_ref = de_ref + 1/Te * e_ref;
    stan_nr_ref = f_find_state(stan_value_ref, stany);

    % CRITICAL FIX 2025-01-23 (Bug #6): Use stan_T0_for_bootstrap (not stan_T0) for max calculation
    % This prevents bootstrap contamination when goal state drifts to adjacent states
    maxS = max(Q_2d(stan_T0_for_bootstrap, :));
    maxS_ref = max(Q_2d(stan_nr_ref, :));

    %% ========================================================================
    %% Q-learning update
    %% ========================================================================
    % Update Q-value for the BUFFERED state-action pair
    if uczenie_T0 == 1 && pozwolenie_na_uczenia == 1 && stan_T0_for_bootstrap ~= 0 && old_stan_T0 ~= 0
        Q_update = alfa * (R_buffered + gamma * maxS - Q_2d(old_stan_T0, wyb_akcja_T0));
        Q_2d(old_stan_T0, wyb_akcja_T0) = Q_2d(old_stan_T0, wyb_akcja_T0) + Q_update;
    end
end

% Store trajectory realization for analysis (uses current state reward)
if eks_wer == 0
    realizacja_traj_epoka_idx = realizacja_traj_epoka_idx + 1;
    realizacja_traj_epoka(realizacja_traj_epoka_idx) = R;
end

wart_akcji_bez_f_rzutujacej = wart_akcji;

% Apply projection function if enabled
% NOTE 2025-12-01: Projection ALWAYS uses CURRENT error/state (not buffered)
% Rationale: Projection modifies the control signal applied to plant RIGHT NOW
%
% FIX 2026-01-15: Changed condition from state-based to error-based exclusion
% OLD BUG: Excluded states {49,50,51} which disabled projection when system
%          was on target trajectory (state_value ≈ 0) even with large error.
%          This caused Q controller to do nothing while PI drove output.
% NEW: Only disable projection when error is truly small (< precision)
if f_rzutujaca_on == 1 && abs(e) >= dokladnosc_gen_stanu
    funkcja_rzutujaca = (e * (1/Te - 1/Ti));
    % NOTE 2025-01-28: SUBTRACTION is mathematically correct (Paper Eq. 7)
    % Required for initialization to match PI controller behavior
    %
    % FIX 2026-01-15: Always apply projection, removed sign check
    % OLD BUG: Sign check (wart_akcji<0 && ... || wart_akcji>0 && ...) failed
    %          when wart_akcji=0 (at goal state), preventing projection.
    % NEW: Always apply projection - the math is correct regardless of sign
    wart_akcji = wart_akcji - funkcja_rzutujaca;
else
    funkcja_rzutujaca = 0;
end

% Calculate control signal
if sterowanie_reczne == 0
    u_increment_bez_f_rzutujacej = kQ * (wart_akcji_bez_f_rzutujacej) * dt;
    u_increment = kQ * wart_akcji * dt;
    u = u_increment + u;

    % Apply control limits
    if u <= ograniczenie_sterowania_dol
        u = ograniczenie_sterowania_dol;
        uczenie = 0;
    end
    if u >= ograniczenie_sterowania_gora
        u = ograniczenie_sterowania_gora;
        uczenie = 0;
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