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
ilosc_probek_sterowanie_reczne=T0/dt + dodatkowe_probki_reka;

dlugosc_symulacji=czas_eksp_wer/dt+ilosc_probek_sterowanie_reczne;
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


if pierwszy_wykres_weryfikacyjny==0 && licz_wskazniki==0

    figure(300)

    subplot(2,1,1)
    plot(logi.Q_t,logi.Q_y,'b',LineWidth=2)
    hold on
    plot(logi.Q_t,logi.Ref_y,'w',LineWidth=1)
    plot(logi.PID_t,logi.PID_y,'color',[0.1 0.6 0.1],LineWidth=2)

    subplot(2,1,2)
    plot(logi.Q_t,logi.Q_u,'b',LineWidth=2)
    hold on
    plot(logi.PID_t,logi.PID_u,'color',[0.1 0.6 0.1],LineWidth=2)

    pierwszy_wykres_weryfikacyjny=1;

elseif pierwszy_wykres_weryfikacyjny==1 && licz_wskazniki==0

    figure(300)

    subplot(2,1,1)
    plot(logi.Q_t,logi.Q_y,'r',LineWidth=2)
    hold on
    plot(logi.Q_t,logi.Ref_y,'w--',LineWidth=1)
    grid on
    title('y')
    legend('QwL','Ref','PID','QL', 'nowe Ref')

    subplot(2,1,2)
    plot(logi.Q_t,logi.Q_u,'r',LineWidth=2)
    grid on
    title('u')
    legend('QwL','PID','QL')

    figure(301)
    subplot(4,1,1)
    plot(proc_stab_wek,LineWidth=2)
    grid on
    tytol=['Procent stabilizacji na ',num2str(probkowanie_dane_symulacji),' epok [%]'];
    title(tytol)

    subplot(4,1,2)
    plot(czas_uczenia_wek,LineWidth=2)
    grid on
    tytol=['Czas uczenia na ',num2str(probkowanie_dane_symulacji),' epok [s]'];
    title(tytol)

    subplot(4,1,3)
    plot(norma_macierzy2_roznica,LineWidth=2)
    grid on
    tytol=['Norma roznic macierzy na ',num2str(probkowanie_dane_symulacji),' epok'];
    title(tytol)

    subplot(4,1,4)
    plot(max_macierzy_Q,LineWidth=2)
    grid on
    tytol=['Max Q-value na ',num2str(probkowanie_norma_macierzy),' epok'];
    title(tytol)

    figure()

    subplot(5,1,1)
    plot(IAE_wek,LineWidth=2)
    title('IAE')
    grid on
    legend('Zmiena SP','d=0.3','d=0')

    subplot(5,1,2)
    plot(IAE_traj_wek,LineWidth=2)
    title('IAE trajektoria')
    grid on

    subplot(5,1,3)
    plot(maks_przereg_wek,LineWidth=2)
    title('max przeregulowanie')
    grid on

    subplot(5,1,4)
    plot(czas_regulacji_wek,LineWidth=2)
    title('czas regulacji')
    grid on

    %     subplot(5,1,5)
    %     plot(max_delta_u_wek,LineWidth=2)
    %     title('max delta u')
    %     grid on

    %     subplot(5,1,5)
    %     plot(koszt_sterowania_wek,LineWidth=2)
    %     title('koszt sterowania')
    %     grid on

    subplot(5,1,5)
    yline(90,'color',[0.3 0.3 0.3],LineWidth=2);
    hold on
    plot(proc_realizacji_traj,LineWidth=2)
    title('Realizacja trajektorii w epokach [%]')
    grid on
    plot(proc_realizacji_w_oknie_wek,LineWidth=1)



end

zapis_logi_PID=0;
zapis_logi=0;
eps=eps_ini;
