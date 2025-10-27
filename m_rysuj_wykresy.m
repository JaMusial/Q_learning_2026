nagroda_y=logi.Q_y.*logi.Q_R;
nagroda_y(nagroda_y==0)=NaN;
nagroda_u=logi.Q_u.*logi.Q_R;
nagroda_u(nagroda_u==0)=NaN;
nagroda_e=logi.Q_e.*logi.Q_R;
nagroda_e(nagroda_e==0)=NaN;
nagroda_de=logi.Q_de.*logi.Q_R;
nagroda_de(nagroda_de==0)=NaN;
nagroda_de2=logi.Q_de2.*logi.Q_R;
nagroda_de2(nagroda_de2==0)=NaN;
nagroda_stan_val=logi.Q_stan_value.*logi.Q_R;
nagroda_stan_val(nagroda_stan_val==0)=NaN;
nagroda_stan_nr=logi.Q_stan_nr.*logi.Q_R;
nagroda_stan_nr(nagroda_stan_nr==0)=NaN;

if poj_iteracja_uczenia==1

    figure()

    subplot(4,1,1)
    plot(logi.Q_t,logi.Q_y,'b')
    hold on
    plot(logi.Q_t,logi.Ref_y,'w')
    plot(logi.Q_t,nagroda_y,'m|')
    grid on
    title('y')
    legend('Q','Ref','Nagroda')

    subplot(4,1,2)
    plot(logi.Q_t,logi.Q_u,'b')
    hold on
    plot(logi.Q_t,nagroda_u,'m|')
    title('u')
    grid on
    legend('Q','Nagroda')

    subplot(4,1,3)
    yyaxis left
    plot(logi.Q_t,logi.Q_czas_zaklocenia,'b');
    grid on
    title('ilosc probek zakl (lewo) i zakl obc d (prawo)')
    yyaxis right
    plot(logi.Q_t,logi.Q_d);
    legend('probki zakl','d')

    subplot(4,1,4)
    plot(logi.Q_t,logi.Q_u_increment,'b');
    hold on
    yline(0,'color',[0.3 0.3 0.3]);
    grid on
    title('delta u')


    figure()

    subplot(4,1,1)
    plot(logi.Q_t,logi.Q_stan_nr,'b');
    hold on
    plot(logi.Q_t,logi.Ref_stan_nr,'w');
    plot(logi.Q_t,nagroda_stan_nr,'m|');
    yline(nr_stanu_doc,'color',[0.3 0.3 0.3]);
    legend("Q","Ref",'nagroda','stan docelowy');
    grid on
    title('stan nr')

    subplot(4,1,2)
    plot(logi.Q_t,logi.Q_stan_value,'b');
    hold on
    plot(logi.Q_t,logi.Ref_stan_value,'k')
    plot(logi.Q_t,nagroda_stan_val,'m|');
    grid on
    title('stan value')

    subplot(4,1,3)
    plot(logi.Q_t,logi.Q_akcja_nr,'b');
    hold on
    yline(nr_akcji_doc);
    grid on
    title('akcja nr')
    legend('akcja Q','docelowa')

    subplot(4,1,4)
    plot(logi.Q_t,logi.Q_akcja_value,'b');
    hold on
    plot(logi.Q_t,logi.Q_akcja_value_bez_f_rzutujacej,'-g');
    grid on
    legend('wart akcji','wartosc akcji bez f rzutujacej')
    title('akcja value')

    figure()

    subplot(4,1,1)
    plot(logi.Q_t,logi.Q_y,'b')
    hold on
    plot(logi.Q_t,logi.Ref_y,'w')
    plot(logi.Q_t,nagroda_y,'m|')
    grid on
    title('y')
    legend('Q','Ref','Nagroda')

    subplot(4,1,2)
    plot(logi.Q_t,logi.Q_e,'b')
    hold on
    plot(logi.Q_t,logi.Ref_e,'k')
    plot(logi.Q_t,nagroda_e,'m|')
    grid on
    title('e')

    subplot(4,1,3)
    plot(logi.Q_t,logi.Q_de,'b')
    hold on
    plot(logi.Q_t,logi.Ref_de,'w')
    plot(logi.Q_t,nagroda_de,'m|')
    grid on
    title('de')

    subplot(4,1,4)
    plot(logi.Q_t,logi.Q_de2,'b')
    hold on
    plot(logi.Q_t,logi.Ref_de2,'w')
    plot(logi.Q_t,nagroda_de2,'m|')
    grid on
    title('de2')

    figure()
    subplot(4,1,1)
    plot(wek_proc_realizacji)
    hold on
    plot(filtr_mnk)
    plot(wek_Te/max(wek_Te))
    grid on
    legend('proc realizacji','filtr mnk','Te norm');
    subplot(4,1,2)
    plot(wsp_mnk(1,:));
    grid on
    hold on
    title('a')
    subplot(4,1,3)
    plot(wsp_mnk(2,:));
    grid on
    hold on
    title('b')
    subplot(4,1,4)
    plot(wsp_mnk(3,:));
    grid on
    hold on
    title('c')

else

    figure()

    subplot(4,1,1)
    plot(logi.Q_t,logi.Q_y,'b')
    hold on
    plot(logi.Q_t,logi.Ref_y,'w')
    plot(logi.Q_t,nagroda_y,'m|')
    plot(logi.PID_t,logi.PID_y,'color',[0.1 0.6 0.1])
    grid on
    title('y')
    legend('Q','Ref','Nagroda','PI')

    subplot(4,1,2)
    plot(logi.Q_t,logi.Q_u,'b')
    hold on
    plot(logi.Q_t,nagroda_u,'m|')
    plot(logi.PID_t,logi.PID_u,'color',[0.1 0.6 0.1])
    title('u')
    grid on
    legend('Q','Nagroda','PI')

    subplot(4,1,3)
    yyaxis left
    plot(logi.Q_t,logi.Q_u_increment,'b');
    hold on
    plot(logi.PID_t,logi.PID_u_increment,'color',[0.1 0.6 0.1])
    grid on
    title('przyrost u (lewo) i zakl obc d (prawo)')
    yyaxis right
    plot(logi.Q_t,logi.Q_d,'k');
    legend('Q','PI','d')

    subplot(4,1,4)
    plot(logi.Q_t,logi.Q_funkcja_rzut,'b');
    hold on
    yline(0,'color',[0.3 0.3 0.3]);
    grid on
    title('funkcja rzutujaca')


    figure()

    subplot(4,1,1)
    plot(logi.Q_t,logi.Q_stan_nr,'b');
    hold on
    plot(logi.Q_t,logi.Ref_stan_nr,'w');
    plot(logi.Q_t,nagroda_stan_nr,'m|');
    plot(logi.PID_t,logi.PID_stan_nr,'color',[0.1 0.6 0.1])
    yline(nr_stanu_doc,'color',[0.3 0.3 0.3]);
    legend("Q","Ref",'nagroda','PI','stan docelowy');
    grid on
    title('stan nr')

    subplot(4,1,2)
    plot(logi.Q_t,logi.Q_stan_value,'b');
    hold on
    plot(logi.Q_t,logi.Ref_stan_value,'w')
    plot(logi.Q_t,nagroda_stan_val,'m|');
    plot(logi.PID_t,logi.PID_akcja_value,'color',[0.1 0.6 0.1]);
    grid on
    title('stan value')

    subplot(4,1,3)
    plot(logi.Q_t,logi.Q_akcja_nr,'b');
    hold on
    plot(logi.PID_t,logi.PID_akcja_nr,'color',[0.1 0.6 0.1])
    yline(nr_akcji_doc,'color',[0.3 0.3 0.3]);
    grid on
    title('akcja nr')
    legend('akcja Q','akcja PI','docelowa')

    subplot(4,1,4)
    plot(logi.Q_t,logi.Q_akcja_value,'b');
    hold on
    plot(logi.PID_t,logi.PID_akcja_value,'color',[0.1 0.6 0.1])
    grid on
    title('akcja value')
    legend('Q','PI')

    figure()

    subplot(4,1,1)
    plot(logi.Q_t,logi.Q_y,'b')
    hold on
    plot(logi.Q_t,logi.Ref_y,'w')
    plot(logi.Q_t,nagroda_y,'m|')
    plot(logi.PID_t,logi.PID_y,'color',[0.1 0.6 0.1])
    grid on
    title('y')
    legend('Q','Ref','Nagroda','PI')

    subplot(4,1,2)
    plot(logi.Q_t,logi.Q_e,'b')
    hold on
    plot(logi.Q_t,logi.Ref_e,'w')
    plot(logi.Q_t,nagroda_e,'m|')
    plot(logi.PID_t,logi.PID_e,'color',[0.1 0.6 0.1])
    grid on
    title('e')

    subplot(4,1,3)
    plot(logi.Q_t,logi.Q_de,'b')
    hold on
    plot(logi.Q_t,logi.Ref_de,'w')
    plot(logi.Q_t,nagroda_de,'m|')
    plot(logi.PID_t,logi.PID_de,'color',[0.1 0.6 0.1])
    grid on
    title('de')

    subplot(4,1,4)
    plot(logi.Q_t,logi.Q_de2,'b')
    hold on
    plot(logi.Q_t,logi.Ref_de2,'w')
    plot(logi.Q_t,nagroda_de2,'m|')
    plot(logi.PID_t,logi.PID_de2,'color',[0.1 0.6 0.1])
    grid on
    title('de2')

    if ~isempty(wsp_mnk)
    figure()
    subplot(4,1,1)
    plot(wek_proc_realizacji)
    hold on
    plot(filtr_mnk)
    plot(wek_Te/max(wek_Te))
    grid on
    legend('proc realizacji','filtr mnk','Te norm');
    subplot(4,1,2)
    plot(wsp_mnk(1,:));
    grid on
    hold on
    title('a')
    subplot(4,1,3)
    plot(wsp_mnk(2,:));
    grid on
    hold on
    title('b')
    subplot(4,1,4)
    plot(wsp_mnk(3,:));
    grid on
    hold on
    title('c')
    end

end