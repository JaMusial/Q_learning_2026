%sprawdzanie uchybu
if abs(e) <= abs(dopuszczalny_uchyb)
    stan_ustalony_probka=stan_ustalony_probka+1;
else
    stan_ustalony_probka=0;
end

%sprawdzanie warunku zakonczenia epoki uczenia
if iteracja_uczenia>maksymalna_ilosc_iteracji_uczenia
    if stan_ustalony_probka>oczekiwana_ilosc_probek_stabulizacji
        inf_zakonczono_epoke_stabil=inf_zakonczono_epoke_stabil+1;
    else
    inf_zakonczono_epoke_max_iter=inf_zakonczono_epoke_max_iter+1;
    end
    warunek_stopu=1;
    iteracja_uczenia=0;

else
    warunek_stopu=0;
end

%rozpoczecie kolejnej epoki uczenia
if warunek_stopu==1

   
    Q_2d_save=Q_2d;


    if mod(epoka,probkowanie_norma_macierzy)==0 && epoka ~= 0
        m_norma_macierzy

        if gif_on==1
            m_rysuj_mac_Q
            gif
        end

        max_macierzy_Q(end+1)=max(max(Q_2d));

        if poj_iteracja_uczenia==0
            licz_wskazniki=1;
            m_eksperyment_weryfikacyjny
            [IAE_wek(iter_wskazniki,:), IAE_traj_wek(iter_wskazniki,:), maks_przereg_wek(iter_wskazniki,:), czas_regulacji_wek(iter_wskazniki,:), max_delta_u_wek(iter_wskazniki,:)]=f_licz_wskazniki(logi.Q_y,logi.Q_u,SP,dokladnosc_gen_stanu,logi.Ref_y,dt,ilosc_probek_sterowanie_reczne,czas_eksp_wer);

            iter=1;
            iter_wskazniki=iter_wskazniki+1;
            m_reset
            licz_wskazniki=0;
        end

    end

    if max_epoki<=10000 && mod(epoka,100)==0
        czas_uczenia=toc;
        czas_uczenia_calkowity=czas_uczenia_calkowity+czas_uczenia;
        inf_proc_zak_epoke_stab=(inf_zakonczono_epoke_stabil-inf_zakonczono_epoke_stabil_old)/...
            (inf_zakonczono_epoke_max_iter-inf_zakonczono_epoke_max_iter_old+inf_zakonczono_epoke_stabil-inf_zakonczono_epoke_stabil_old);
        inf_zakonczono_epoke_stabil_old=inf_zakonczono_epoke_stabil;
        inf_zakonczono_epoke_max_iter_old=inf_zakonczono_epoke_max_iter;
        fprintf('Wykonano %5.0d epok, Czas uczenia 100 epok: %.2f [s]   %.1f%%   pozostalo jeszcze %5.0d epok, %3.0f%% zakończono stabilizacją, Te = %.1f\n',epoka, czas_uczenia, epoka*100/max_epoki, max_epoki-epoka,inf_proc_zak_epoke_stab*100, Te);
        tic

        czas_uczenia_wek(end+1)=czas_uczenia;
        proc_stab_wek(end+1)=inf_proc_zak_epoke_stab;
        probkowanie_dane_symulacji=100;

    elseif max_epoki<=15000 && mod(epoka,500)==0
        czas_uczenia=toc;
        czas_uczenia_calkowity=czas_uczenia_calkowity+czas_uczenia;
        inf_proc_zak_epoke_stab=(inf_zakonczono_epoke_stabil-inf_zakonczono_epoke_stabil_old)/...
            (inf_zakonczono_epoke_max_iter-inf_zakonczono_epoke_max_iter_old+inf_zakonczono_epoke_stabil-inf_zakonczono_epoke_stabil_old);
        inf_zakonczono_epoke_stabil_old=inf_zakonczono_epoke_stabil;
        inf_zakonczono_epoke_max_iter_old=inf_zakonczono_epoke_max_iter;
        fprintf('Wykonano %5.0d epok, Czas uczenia 500 epok: %.2f [s]   %.1f%%   pozostalo jeszcze %5.0d epok, %3.0f%% zakończono stabilizacją, Te = %.1f \n',epoka, czas_uczenia, epoka*100/max_epoki, max_epoki-epoka,inf_proc_zak_epoke_stab*100,Te);
        tic

        czas_uczenia_wek(end+1)=czas_uczenia;
        proc_stab_wek(end+1)=inf_proc_zak_epoke_stab;
        probkowanie_dane_symulacji=500;

    elseif mod(epoka,1000)==0
        czas_uczenia=toc;
        czas_uczenia_calkowity=czas_uczenia_calkowity+czas_uczenia;
        inf_proc_zak_epoke_stab=(inf_zakonczono_epoke_stabil-inf_zakonczono_epoke_stabil_old)/...
            (inf_zakonczono_epoke_max_iter-inf_zakonczono_epoke_max_iter_old+inf_zakonczono_epoke_stabil-inf_zakonczono_epoke_stabil_old);
        inf_zakonczono_epoke_stabil_old=inf_zakonczono_epoke_stabil;
        inf_zakonczono_epoke_max_iter_old=inf_zakonczono_epoke_max_iter;
        fprintf('Wykonano %5.0d epok, Czas uczenia 1000 epok: %.2f [s]   %.1f%%   pozostalo jeszcze %5.0d epok, %3.0f%% zakończono stabilizacją, Te = %.1f \n',epoka, czas_uczenia, epoka*100/max_epoki, max_epoki-epoka,inf_proc_zak_epoke_stab*100,Te);
        tic

        czas_uczenia_wek(end+1)=czas_uczenia;
        proc_stab_wek(end+1)=inf_proc_zak_epoke_stab;
        probkowanie_dane_symulacji=1000;

    end

    epoka=epoka+1;
    stan_ustalony_probka=0;

    m_reset

    wylosowany_SP(end+1)=SP;
    wylosowane_d(end+1)=d;

end
