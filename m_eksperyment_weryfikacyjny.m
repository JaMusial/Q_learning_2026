SP=20;
y=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y_PID=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
% Initialize reference trajectory
y_ref = y;
e_ref = 0;
de_ref = 0;
de2_ref = 0;
d_ref = 0;
% Initialize Q controller state
e = 0;
de = 0;
de2 = 0;
u = SP / k;
% Initialize PID controller state
e_PID = 0;
de_PID = 0;
de2_PID = 0;
u_PID = SP / k;
% Initialize plant internal states for both controllers
y1_n = f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y2_n = f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y3_n = f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y1_n_PID = y1_n;
y2_n_PID = y2_n;
y3_n_PID = y3_n;
% Initialize time
t = 0;
eps=-1;
iter=1;
zapis_logi=1;
reset_logi=1;
zapis_logi_PID=1;
eks_wer=1;
d=0;
ilosc_probek_sterowanie_reczne = round(T0/dt) + dodatkowe_probki_reka;

% Reset plant delay buffers for clean verification test
% Pre-fill with steady-state value to prevent transient
if T0 ~= 0
    u_ss_scaled = f_skalowanie(proc_max_u, proc_min_u, wart_max_u, wart_min_u, SP/k);
    bufor_T0 = ones(1, round(T0/dt)) * u_ss_scaled;
    bufor_T0_PID = ones(1, round(T0/dt)) * u_ss_scaled;
end

% Reset controller compensation buffers for clean verification test
if T0_controller ~= 0
    bufor_state = zeros(1, round(T0_controller/dt));
    bufor_wyb_akcja = zeros(1, round(T0_controller/dt));
    bufor_uczenie = zeros(1, round(T0_controller/dt));
end

dlugosc_symulacji = round(czas_eksp_wer/dt) + ilosc_probek_sterowanie_reczne;
for iter_test=1:dlugosc_symulacji
    if iter_test==15+ilosc_probek_sterowanie_reczne
        SP=SP_ini;
    end
 
    m_regulator_Q;
    m_regulator_PID;
    m_zapis_logow

    if t>dlugosc_symulacji*dt/3+ilosc_probek_sterowanie_reczne && t<=2*dlugosc_symulacji*dt/3+ilosc_probek_sterowanie_reczne
        d=0.3;
    elseif t>dlugosc_symulacji*dt/3+ilosc_probek_sterowanie_reczne
        d=0;
    else
        d=0;
    end

    iter=iter+1;
end

% Trim preallocated log arrays to actual used size
trim_logi = 1;
m_zapis_logow;

eks_wer=0;

% Store data for comparison plots (handled in m_rysuj_wykresy.m)
if pierwszy_wykres_weryfikacyjny==0 && licz_wskazniki==0
    % First run (Q without learning) - store data
    logi_before_learning = logi;
    pierwszy_wykres_weryfikacyjny=1;
end

% Plotting is now handled in m_rysuj_wykresy.m

zapis_logi_PID=0;
zapis_logi=0;
eps=eps_ini;
