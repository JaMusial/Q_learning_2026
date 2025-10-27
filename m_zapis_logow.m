if reset_logi==1 || exist('logi','var') == 0
    logi.Q_e=[];
    logi.Q_de=[];
    logi.Q_de2=[];
    logi.Q_stan_value=[];
    logi.Q_stan_nr=[];
    logi.Q_akcja_value=[];
    logi.Q_akcja_value_bez_f_rzutujacej=[];
    logi.Q_akcja_nr=[];
    logi.Q_funkcja_rzut=[];
    logi.Q_R=[];
    logi.Q_losowanie=[];
    logi.Q_y=[];
    logi.Q_delta_y=[];
    logi.Q_u=[];
    logi.Q_u_increment=[];
    logi.Q_u_increment_bez_f_rzutujacej=[];
    logi.Q_t=[];
    logi.Q_d=[];
    logi.Q_czas_zaklocenia=[];

    logi.Q_maxS=[];
    logi.Q_table_update=[];

    logi.Ref_e=[];
    logi.Ref_y=[];
    logi.Ref_de=[];
    logi.Ref_de2=[];
    logi.Ref_stan_value=[];
    logi.Ref_stan_nr=[];

    logi.PID_e=[];
    logi.PID_de=[];
    logi.PID_de2=[];
    logi.PID_u=[];
    logi.PID_u_increment=[];
    logi.PID_stan_value=[];
    logi.PID_stan_nr=[];
    logi.PID_akcja_value=[];
    logi.PID_akcja_nr=[];
    logi.PID_t=[];
    logi.PID_y=[];
end

if zapis_logi==1
    
    reset_logi=0;

    logi.Q_e(end+1)=f_skalowanie(wart_max_e,wart_min_e,proc_max_e,proc_min_e,e);
    logi.Q_de(end+1)=de;
    logi.Q_de2(end+1)=de2;
    logi.Q_stan_value(end+1)=stan_value;
    logi.Q_stan_nr(end+1)=stan;
    logi.Q_akcja_value(end+1)=wart_akcji;
    logi.Q_akcja_value_bez_f_rzutujacej(end+1)=wart_akcji_bez_f_rzutujacej;
    logi.Q_akcja_nr(end+1)=wyb_akcja;
    logi.Q_funkcja_rzut(end+1)=funkcja_rzutujaca;
    logi.Q_R(end+1)=R;
    logi.Q_losowanie(end+1)=czy_losowanie;
    logi.Q_y(end+1)=f_skalowanie(wart_max_y,wart_min_y,proc_max_y,proc_min_y,y);
    logi.Q_delta_y(end+1)=delta_y;
    logi.Q_u(end+1)=f_skalowanie(wart_max_u,wart_min_u,proc_max_u,proc_min_u,u);
    logi.Q_u_increment(end+1)=u_increment;
    logi.Q_u_increment_bez_f_rzutujacej(end+1)=u_increment_bez_f_rzutujacej;
    logi.Q_t(end+1)=t;
    logi.Q_d(end+1)=d;
    logi.Q_czas_zaklocenia(end+1)=maksymalna_ilosc_iteracji_uczenia;

    logi.Q_maxS(end+1)=maxS;
    logi.Q_table_update(end+1)=Q_update;

    logi.Ref_e(end+1)=e_ref;
    logi.Ref_y(end+1)=y_ref;
    logi.Ref_de(end+1)=de_ref;
    logi.Ref_de2(end+1)=de2_ref;
    logi.Ref_stan_value(end+1)=stan_value_ref;
    logi.Ref_stan_nr(end+1)=stan_nr_ref;

    if zapis_logi_PID==1
        logi.PID_e(end+1)=f_skalowanie(wart_max_e,wart_min_e,proc_max_e,proc_min_e,e_PID);
        logi.PID_de(end+1)=de_PID;
        logi.PID_de2(end+1)=de2_PID;
        logi.PID_u(end+1)=f_skalowanie(wart_max_u,wart_min_u,proc_max_u,proc_min_u,u_PID);
        logi.PID_u_increment(end+1)=u_increment_PID;
        logi.PID_stan_value(end+1)=stan_value_PID;
        logi.PID_stan_nr(end+1)=stan_PID;
        logi.PID_akcja_value(end+1)=wart_akcji_PID;
        logi.PID_akcja_nr(end+1)=akcja_nr_PID;
        logi.PID_t(end+1)=t_PID;
        logi.PID_y(end+1)=f_skalowanie(wart_max_y,wart_min_y,proc_max_y,proc_min_y,y_PID);
    end
end