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
    max_samples = maksymalna_ilosc_iteracji_uczenia;

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
    logi.Q_czas_zaklocenia = zeros(1, max_samples);
    logi.Q_maxS = zeros(1, max_samples);
    logi.Q_table_update = zeros(1, max_samples);

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
    logi.Q_czas_zaklocenia(logi_idx) = maksymalna_ilosc_iteracji_uczenia;
    logi.Q_maxS(logi_idx) = maxS;
    logi.Q_table_update(logi_idx) = Q_update;

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
    logi.Q_czas_zaklocenia = logi.Q_czas_zaklocenia(1:logi_idx);
    logi.Q_maxS = logi.Q_maxS(1:logi_idx);
    logi.Q_table_update = logi.Q_table_update(1:logi_idx);

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
