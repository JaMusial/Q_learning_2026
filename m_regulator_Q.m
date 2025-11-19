
% Scale variables to normalized ranges
e = f_skalowanie(wart_max_e, wart_min_e, proc_max_e, proc_min_e, e);
u = f_skalowanie(wart_max_u, wart_min_u, proc_max_u, proc_min_u, u);
y = f_skalowanie(wart_max_y, wart_min_y, proc_max_y, proc_min_y, y);

% Random coefficient for epsilon-greedy exploration
a = randi([0, 100], [1, 1]) / 100;
u_old = u;

%% Manual control (initial samples)
if iter <= ilosc_probek_sterowanie_reczne
    u = y / k;
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

    if reakcja_na_T0 == 1 && T0 > 0
        [stan, bufor_state] = f_bufor(stan, bufor_state);
        [wyb_akcja, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja);
    end

    stan_value_ref = de_ref + 1/Te * e_ref;
    stan_nr_ref = f_find_state(stan_value_ref, stany);

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

    if d_ref_s ~= d_ref
        e_ref = SP - y_ref - (d_ref - d_ref_s) / 2;
    else
        e_ref = SP - y_ref;
    end

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

    if reakcja_na_T0 == 1 && T0 > 0
        [stan_T0, bufor_state] = f_bufor(stan, bufor_state);
        [old_stan_T0, bufor_old_state] = f_bufor(old_state, bufor_old_state);
        [wyb_akcja_T0, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja);
        [uczenie_T0, bufor_uczenie] = f_bufor(uczenie, bufor_uczenie);

        if old_stan_T0 == nr_stanu_doc
            R = 1;
        else
            R = 0;
        end
    else
        stan_T0 = stan;
        old_stan_T0 = old_state;
        wyb_akcja_T0 = wyb_akcja;
        uczenie_T0 = uczenie;
    end

    stan_value_ref = de_ref + 1/Te * e_ref;
    stan_nr_ref = f_find_state(stan_value_ref, stany);

    maxS = max(Q_2d(stan_T0, :));
    maxS_ref = max(Q_2d(stan_nr_ref, :));

    % Q-learning update rule
    if uczenie == 1 && pozwolenie_na_uczenia == 1 && stan_T0 ~= 0 && old_stan_T0 ~= 0
        Q_update = alfa * (R + gamma * maxS - Q_2d(old_stan_T0, wyb_akcja_T0));
        Q_2d(old_stan_T0, wyb_akcja_T0) = Q_2d(old_stan_T0, wyb_akcja_T0) + Q_update;
    end
end

%% Action selection

% Get best actions from neighboring states
if stan + 1 > ilosc_stanow
    wyb_akcja_above = wyb_akcja;
else
    [Q_value_state_above, wyb_akcja_above] = f_best_action_in_state(Q_2d, stan+1, nr_stanu_doc);
end

if stan - 1 < 1
    wyb_akcja_under = wyb_akcja;
else
    [Q_value_state_under, wyb_akcja_under] = f_best_action_in_state(Q_2d, stan-1, nr_stanu_doc);
end

% If in target state, select target action
if (stan == nr_stanu_doc)
    wyb_akcja = nr_akcji_doc;
    R = nagroda;
    wart_akcji = akcje_sr(wyb_akcja);
    uczenie = 1;
    czy_losowanie = 0;

    % Otherwise, use epsilon-greedy policy
else
    R = 0;

    if eps >= a
        % Exploration: Random action selection with constraints
        ponowne_losowanie = 1;
        while ponowne_losowanie > 0 && ponowne_losowanie <= max_powtorzen_losowania_RD
            m_losowanie_nowe
        end

        if ponowne_losowanie >= max_powtorzen_losowania_RD
            [Q_value, wyb_akcja] = f_best_action_in_state(Q_2d, stan, nr_stanu_doc);
        end

        wart_akcji = akcje_sr(wyb_akcja);
        uczenie = 1;
        czy_losowanie = 1;

    elseif stan ~= 0
        % Exploitation: Select best action
        [Q_value, wyb_akcja] = f_best_action_in_state(Q_2d, stan, nr_stanu_doc);
        wart_akcji = akcje_sr(wyb_akcja);
        uczenie = 0;
        czy_losowanie = 0;
    end
end
% Store trajectory realization for analysis
if eks_wer == 0
    realizacja_traj_epoka_idx = realizacja_traj_epoka_idx + 1;
    realizacja_traj_epoka(realizacja_traj_epoka_idx) = R;
end

wart_akcji_bez_f_rzutujacej = wart_akcji;

% Apply projection function if enabled
if f_rzutujaca_on == 1 && (stan ~= nr_stanu_doc && stan ~= nr_stanu_doc+1 && ...
        stan ~= nr_stanu_doc-1 && abs(e) >= dokladnosc_gen_stanu)
    funkcja_rzutujaca = (e * (1/Te - 1/Ti));
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