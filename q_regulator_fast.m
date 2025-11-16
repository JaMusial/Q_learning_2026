% m_regulator_Q_fast.m  -- optimized regulator for inner loop
% Make sure main calls this file instead of m_regulator_Q

% --- Copy globals (or pass them in) for speed-critical access
% (if these are already in workspace as globals / from m_inicjalizacja, keep consistent)
global Q_2d stany akcje_sr ilosc_stanow ile_akcji nr_stanu_doc nr_akcji_doc
global SP dt Te Te_bazowe Ti Kp kQ k alfa gamma d T0 bufor_T0
global ograniczenie_sterowania_dol ograniczenie_sterowania_gora
global proc_max_e proc_min_e wart_max_e wart_min_e
global proc_max_u proc_min_u wart_max_u wart_min_u
global proc_max_y proc_min_y wart_max_y wart_min_y
global sterowanie_reczne iter ilosc_probek_sterowanie_reczne
global f_rzutujaca_on dokladnosc_gen_stanu eks_wer realizacja_traj_epoka

% Local copies for speed
Qlocal = Q_2d;
akcje = akcje_sr;
nr_doc = nr_stanu_doc;
ileA = ile_akcji;
iloscS = ilosc_stanow;

% Inline scaling (avoid repeated f_skalowanie calls)
scale_to_proc = @(procMax,procMin,wartMax,wartMin,x) ( (x - wartMin) .* (procMax - procMin) ./ (wartMax - wartMin) + procMin );

% scale incoming variables once (original used three scalings; do them together)
e = scale_to_proc(proc_max_e, proc_min_e, wart_max_e, wart_min_e, e);
u = scale_to_proc(proc_max_u, proc_min_u, wart_max_u, wart_min_u, u);
y = scale_to_proc(proc_max_y, proc_min_y, wart_max_y, wart_min_y, y);

% random a only once (vectorize if many draws needed)
a = randi([0,100],1,1)/100;
u_old = u;

%% sterowanie reczne (unchanged logic but fewer function calls)
if iter <= ilosc_probek_sterowanie_reczne
    u = y / k;
    e = SP - y;
    de = 0;
    de2 = 0;
    % keep bufor_T0 updating but avoid calling f_skalowanie again
    if T0 > 0 && all(bufor_T0 == 0)
        bufor_T0 = bufor_T0 + scale_to_proc(proc_max_u, proc_min_u, wart_max_u, wart_min_u, u);
    end

    e_ref = e;
    de_ref = de;
    de2_ref = de2;
    y_ref = y;
    d_ref_s = d*100;
    d_ref = 0;
    if iter == 1
        t = 0;
        y1_n = scale_to_proc(proc_max_y, proc_min_y, wart_max_y, wart_min_y, y);
        y2_n = y1_n;
        y3_n = y1_n;
    end
    sterowanie_reczne = 1;
    u_increment_bez_f_rzutujacej = 0;
    u_increment = 0;

    stan_value = de + 1/Te * e;
    stan = f_find_state(stan_value, stany); % leave this as-is (depends on stany structure)
    wyb_akcja = nr_akcji_doc;
    wart_akcji = akcje(wyb_akcja);
    uczenie = 0;
    czy_losowanie = 0;

    if reakcja_na_T0 == 1 && T0 > 0
        [stan, bufor_state] = f_bufor(stan, bufor_state);
        [wyb_akcja, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja);
    end

    stan_value_ref = de_ref + 1/Te * e_ref;
    stan_nr_ref = f_find_state(stan_value_ref, stany);

    t = t + dt;
else
    % --- non-manual branch
    e_s = e;
    e = SP - y;
    de_s = de;
    de = (e - e_s)/dt;
    de2 = (de - de_s)/dt;

    d_ref_s = d_ref;
    d_ref = d*100;
    e_ref_s = e_ref;

    if d_ref_s ~= d_ref
        e_ref = SP - y_ref - (d_ref - d_ref_s) / 2;
    else
        e_ref = SP - y_ref;
    end

    e_ref = (Te_bazowe - dt) / Te_bazowe * e_ref;
    de_ref_s = de_ref;
    de_ref = (e_ref - e_ref_s)/dt;
    de2_ref = (de_ref - de_ref_s)/dt;
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
        if old_stan_T0 == nr_doc
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

    % Use direct row max instead of extra function calls
    if stan_T0 >= 1 && stan_T0 <= size(Qlocal,1)
        rowOld = Qlocal(stan_T0, :);
        maxS = max(rowOld);
    else
        maxS = 0;
    end
    if stan_nr_ref >= 1 && stan_nr_ref <= size(Qlocal,1)
        rowRef = Qlocal(stan_nr_ref, :);
        maxS_ref = max(rowRef);
    else
        maxS_ref = 0;
    end

    if uczenie == 1 && pozwolenie_na_uczenia == 1 && stan_T0 ~= 0 && old_stan_T0 ~= 0
        % update Q using local copy and direct indices
        Qidx_old = old_stan_T0;
        Qidx_action = wyb_akcja_T0;
        % vectorized scalar update
        Qlocal(Qidx_old, Qidx_action) = Qlocal(Qidx_old, Qidx_action) + ...
            alfa_local * ( R + gamma_local * maxS - Qlocal(Qidx_old, Qidx_action) );
    end

end

%% wybor akcji (inline best-action search for neighbors)
% For performance: avoid calling f_best_action_in_state; use direct max on rows

% predefine safe function to pick best action index from Q row (ignore nr_doc)
pick_best = @(Qrow) max(1, find(Qrow==max(Qrow),1,'first'));

if stan+1 > iloscS
    wyb_akcja_above = wyb_akcja;
else
    rowAbove = Qlocal(stan+1, :);
    wyb_akcja_above = pick_best(rowAbove);
end

if stan-1 < 1
    wyb_akcja_under = wyb_akcja;
else
    rowUnder = Qlocal(stan-1, :);
    wyb_akcja_under = pick_best(rowUnder);
end

if (stan == nr_doc)
    wyb_akcja = nr_akcji_doc;
    R = nagroda;
    wart_akcji = akcje(wyb_akcja);
    uczenie = 1;
    czy_losowanie = 0;
else
    R = 0;
    if eps >= a
        % exploration branch : use your existing m_losowanie_nowe but avoid
        % repeated overhead by calling it once per decision (it may already be optimized)
        % keep same logic but avoid heavy re-evaluations
        ponowne_losowanie = 1;
        cnt_repeat = 0;
        while ponowne_losowanie > 0 && cnt_repeat <= max_powtorzen_losowania_RD
            m_losowanie_nowe; % keep this function; optimize it separately if it's hot
            cnt_repeat = cnt_repeat + 1;
            % m_losowanie_nowe should set ponowne_losowanie to 0 when done
        end
        if ponowne_losowanie >= max_powtorzen_losowania_RD
            % fallback to best action in current state
            rowCur = Qlocal(stan, :);
            [~, wyb_akcja] = max(rowCur);
        end
        wart_akcji = akcje(wyb_akcja);
        uczenie = 1;
        czy_losowanie = 1;
    elseif stan ~= 0
        rowCur = Qlocal(stan, :);
        [~, wyb_akcja] = max(rowCur);
        wart_akcji = akcje(wyb_akcja);
        uczenie = 0;
        czy_losowanie = 0;
    end
end

if eks_wer == 0
    % caller should write to preallocated array; we just ensure variable exists
    % realizacja_traj_epoka(iteration_index) = R;  % main writes this
end

wart_akcji_bez_f_rzutujacej = wart_akcji;

% apply rzutujaca function if enabled (kept logic, but computed inline)
if f_rzutujaca_on == 1 && (stan ~= nr_doc && stan ~= nr_doc+1 && stan ~= nr_doc-1 && abs(e) >= dokladnosc_gen_stanu)
    funkcja_rzutujaca = (e * (1/Te - 1/Ti));
    wart_akcji = wart_akcji - funkcja_rzutujaca;
else
    funkcja_rzutujaca = 0;
end

if sterowanie_reczne == 0
    u_increment_bez_f_rzutujacej = kQ * (wart_akcji_bez_f_rzutujacej) * dt;
    u_increment = kQ * wart_akcji * dt;
    u = u_increment + u;

    if u <= ograniczenie_sterowania_dol
        u = ograniczenie_sterowania_dol;
        uczenie = 0;
    end
    if u >= ograniczenie_sterowania_gora
        u = ograniczenie_sterowania_gora;
        uczenie = 0;
    end
end

if dist_on == 1
    z = -z_zakres + (z_zakres + z_zakres) * rand(1,1);
end

% scale back (use the inline inverse scaling)
inv_scale = @(procMax,procMin,wartMax,wartMin,x) ( (x - procMin) .* (wartMax - wartMin) ./ (procMax - procMin) + wartMin );
e = inv_scale(proc_max_e, proc_min_e, wart_max_e, wart_min_e, e);
u = inv_scale(proc_max_u, proc_min_u, wart_max_u, wart_min_u, u);
y = inv_scale(proc_max_y, proc_min_y, wart_max_y, wart_min_y, y);

% simulate object: reduce number of small-steps if possible
iteracje_petla_wew = round(dt / 0.01);
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

% Keep f_obiekt loop but avoid unnecessary repeated overhead inside it
for petla_wew_obiekt = 1:iteracje_petla_wew
    [y, y1_n, y2_n, y3_n, bufor_Q] = f_obiekt(nr_modelu, 0.01, k, T, y, y1_n, y2_n, y3_n, u_T0 + d_obiekt, bufor_Q);
    y = y + z;
end

delta_y = y - y_old;

% write local Q back to global (one write instead of many)
Q_2d = Qlocal;
