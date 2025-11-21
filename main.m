clear all
close all
clc

%to do, brak rysowania przy poj iteracji uczenia

format long

%% Initialization

m_inicjalizacja
m_inicjalizacja_buforow
Te = Ti;

% Generate state and action spaces
[stany, akcje_sr, ilosc_stanow, ile_akcji, nr_stanu_doc, nr_akcji_doc] = ...
    f_generuj_stany_v2(dokladnosc_gen_stanu, oczekiwana_ilosc_stanow, ograniczenie_sterowania_gora, Te, Kp, dt);

% Initialize Q-learning matrix
[Q_2d, Q_2d_old] = f_generuj_macierz_Q_2d(ilosc_stanow+1, ile_akcji, nagroda, gamma);
Q_2d_save = Q_2d;

m_rysuj_mac_Q

if poj_iteracja_uczenia == 1
    zapis_logi = 1;
    m_reset
else
    % Run initial verification to establish baseline (logi_before_learning)
    m_eksperyment_weryfikacyjny
    % Note: Plots generated only at the end for final comparison
    m_reset
end

tic
eps = eps_ini;
uczenie = 1;
iter_wskazniki = 1;

%% Learning process
while epoka <= max_epoki
    m_regulator_Q
    m_zapis_logow
    m_realizacja_trajektorii_v2  % Calculate trajectory realization metrics
    iteracja_uczenia = iteracja_uczenia + 1;
    m_warunek_stopu
    iter = iter + 1;

    % Adaptive Te adjustment based on learning performance
    if mean(a_mnk_mean) > 0.2 && mean(b_mnk_mean) > -0.05 && mean(b_mnk_mean) < 0.05 && ...
            flaga_zmiana_Te == 1 && epoka ~= 0 && Te > Te_bazowe

        Te = Te - 0.1;
        filtr_mnk_mean = [0 0 0];
        a_mnk_mean = [0 0 0 0 0 0 0 0];
        b_mnk_mean = [100 100 100 100 100 100 100 100];
        flaga_zmiana_Te = 0;

        [stany, akcje_sr, ilosc_stanow, ile_akcji, nr_stanu_doc, nr_akcji_doc] = ...
            f_generuj_stany_v2(dokladnosc_gen_stanu, oczekiwana_ilosc_stanow, ograniczenie_sterowania_gora, Te, Kp, dt);
    end
end

fprintf("\n Uczenie zakonczono na %d epokach, osiągnieto Te=%f\n\n", epoka, Te);

%% Trim preallocated history arrays to actual used size
% Remove unused preallocated space to save memory and improve plot performance
wylosowany_SP = wylosowany_SP(1:idx_wylosowany);
wylosowane_d = wylosowane_d(1:idx_wylosowany);
czas_uczenia_wek = czas_uczenia_wek(1:idx_raport);
proc_stab_wek = proc_stab_wek(1:idx_raport);
max_macierzy_Q = max_macierzy_Q(1:idx_max_Q);

% Trim preallocated log arrays to actual used size before visualization
trim_logi = 1;
m_zapis_logow;

% Single iteration mode: show training plots
if poj_iteracja_uczenia == 1
    m_rysuj_wykresy
end

% Verification mode: run final verification and generate comparison plots
if poj_iteracja_uczenia == 0
    m_eksperyment_weryfikacyjny
    m_rysuj_wykresy  % Show all comparison plots (before vs after learning)
    figure()
    mesh(Q_2d)
end
