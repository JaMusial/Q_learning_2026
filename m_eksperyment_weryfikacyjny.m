SP=20;
y=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
y_PID=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
eps=-1;
iter=1;
zapis_logi=1;
reset_logi=1;
zapis_logi_PID=1;
eks_wer=1;
d=0;
ilosc_probek_sterowanie_reczne = round(T0/dt) + dodatkowe_probki_reka;

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
