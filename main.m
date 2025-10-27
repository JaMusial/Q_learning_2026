clear all
close all
clc

format long

%% inicjalizacja

m_inicjalizacja
m_inicjalizacja_buforow
Te=Ti;
% Te=Te_bazowe;
% Ti=5;Te=5;

[stany, akcje_sr, ilosc_stanow, ile_akcji, nr_stanu_doc, nr_akcji_doc] = ...
    f_generuj_stany_v2(dokladnosc_gen_stanu, oczekiwana_ilosc_stanow,ograniczenie_sterowania_gora, Te, Kp, dt);

[Q_2d, Q_2d_old] = f_generuj_macierz_Q_2d(ilosc_stanow+1,ile_akcji, nagroda, gamma);
    Q_2d_save=Q_2d;

m_rysuj_mac_Q

if poj_iteracja_uczenia == 1
    zapis_logi=1;
    m_reset
else
    m_eksperyment_weryfikacyjny
    m_rysuj_wykresy
    m_reset
    
end

tic
eps=eps_ini;
uczenie=1;
iter_wskazniki=1;

pause(2);
% return

%% proces uczenia
while epoka<=max_epoki
    m_regulator_Q
    m_zapis_logow
    % m_area_index   %bada indexy
    m_realizacja_trajektorii_v2 %liczenie indexow po okreslonej ilosci probek
    iteracja_uczenia=iteracja_uczenia+1;
    m_warunek_stopu
    iter=iter+1;



    % if mean(filtr_mnk_mean) > 0.05 && flaga_zmiana_Te==1 && epoka ~= 0 && Te>Te_bazowe
    if mean(a_mnk_mean) > 0.2 && mean(b_mnk_mean) > -0.05 && mean(b_mnk_mean) < 0.05  && flaga_zmiana_Te==1 && epoka ~= 0 && Te>Te_bazowe
        % if mod(epoka,50)==0 && flaga_zmiana_Te==1 && epoka ~= 0 && Te>Te_bazowe

        % if length(srednia_okno_proc_realizacji)>=2 && srednia_okno_proc_realizacji(end)>=0.5 && srednia_okno_proc_realizacji(end-1)>=0.5 && flaga_zmiana_Te==1 && epoka ~= 0 && Te>Te_bazowe
        %     if mod(epoka,100)==0 && flaga_zmiana_Te==1 && epoka ~= 0 && Te<Te_bazowe && koszt_sterowania_flaga==0
        %         epoka
        %         if Te<5
        %             ttttt=1;
        %             figure(4)
        %             plot(proc_realizacji_traj)
        %             ylim([80 100])
        %         end

        Te=Te-0.1;
        filtr_mnk_mean=[0 0 0];
        a_mnk_mean=[0 0 0 0 0 0 0 0];
        b_mnk_mean=[100 100 100 100 100 100 100 100];
        flaga_zmiana_Te=0;

        [stany, akcje_sr, ilosc_stanow, ile_akcji, nr_stanu_doc, nr_akcji_doc] = ...
            f_generuj_stany_v2(dokladnosc_gen_stanu, oczekiwana_ilosc_stanow,ograniczenie_sterowania_gora, Te, Kp, dt);

        % wek_okno_realizacji(1)=0;wek_okno_realizacji(2)=0;wek_okno_realizacji(3)=0;wek_okno_realizacji(4)=0;wek_okno_realizacji(5)=0;
        % elseif mod(epoka,50)~=0
        % else
        % flaga_zmiana_Te=1;
    end

end

fprintf("\n Uczenie zakonczono na %d epokach, osiągnieto Te=%f, okno normy wynosi: ",epoka,Te);
% okno_norma
fprintf("\n\n");
m_rysuj_wykresy

if poj_iteracja_uczenia == 0

    m_eksperyment_weryfikacyjny
    figure()
    mesh(Q_2d)
    figure(300)

end
