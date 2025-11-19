%skalowanie
e_PID=f_skalowanie(wart_max_e,wart_min_e,proc_max_e,proc_min_e,e_PID);
u_PID=f_skalowanie(wart_max_u,wart_min_u,proc_max_u,proc_min_u,u_PID);
y_PID=f_skalowanie(wart_max_y,wart_min_y,proc_max_y,proc_min_y,y_PID);

%% sterowanie reczne
% if iter<=ilosc_probek_sterowanie_reczne + T0/dt + dodatkowe_probki_reka
 if iter<=ilosc_probek_sterowanie_reczne
    u_PID=y_PID/k;
    e_s_PID=e_PID;
    e_PID=SP-y_PID;
    de_PID=0;
    de2_PID=0;

    if T0 > 0 && all(bufor_T0_PID == 0)
        bufor_T0_PID=bufor_T0_PID+f_skalowanie(proc_max_u,proc_min_u,wart_max_u,wart_min_u,u_PID);
    end

    if iter==1
        t_PID=0;
        y1_n_PID=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,y_PID);
        y2_n_PID=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,y_PID);
        y3_n_PID=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,y_PID);
    end
    sterowanie_reczne=1;
    u_increment_PID=0;

    stan_value_PID=de_PID+1/Te*e_PID;
    stan_PID=f_find_state(stan_value_PID, stany);
    wart_akcji_PID=u_PID;
    t_PID=t_PID+dt_PID;

    %% standardowe działanie
else
    e_s_PID=e_PID;
    e_PID=SP-y_PID;
    de_s_PID=de_PID;
    de_PID=(e_PID-e_s_PID)/dt_PID;
    de2_PID=(de_PID-de_s_PID)/dt_PID;

    t_PID=t_PID+dt_PID;
    sterowanie_reczne=0;

    stan_value_PID=de_PID+1/Te*e_PID;
    old_state_PID=stan_PID;
    stan_PID=f_find_state(stan_value_PID, stany);

end

if sterowanie_reczne==0
    [u_PID,u_increment_PID,wart_akcji_PID] = f_dyskretny_PID('PI  ',e_PID,Kp,Ti,Td,Tn,Te,dt_PID,e_s_PID,u_PID);
    
    % if T0>0
    %     [u_increment_PID_T0,bufor_T0_PID]=f_bufor(u_increment_PID, bufor_T0_PID);
    % end

    u_PID = u_PID + u_increment_PID;

    if u_PID<=ograniczenie_sterowania_dol
        u_PID=ograniczenie_sterowania_dol;
    end
    if u_PID>=ograniczenie_sterowania_gora
        u_PID=ograniczenie_sterowania_gora;
    end

end

[~,akcja_nr_PID] = min(abs(akcje_sr-wart_akcji_PID));

%ponowne skalowanie na wyjsciu
e_PID=f_skalowanie(proc_max_e,proc_min_e,wart_max_e,wart_min_e,e_PID);
u_PID=f_skalowanie(proc_max_u,proc_min_u,wart_max_u,wart_min_u,u_PID);
y_PID=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,y_PID);

%obliczanie y(i+1) dla Q_learning
iteracje_petla_wew=dt_PID/0.01;
if T0 > 0
    [u_obiekt_PID,bufor_T0_PID]=f_bufor(u_PID, bufor_T0_PID);
else
    u_obiekt_PID = u_PID;
end
for petla_wew_obiekt=1:iteracje_petla_wew
    [y_PID,y1_n_PID,y2_n_PID,y3_n_PID]=f_obiekt(nr_modelu,0.01,k,T,y_PID,y1_n_PID,y2_n_PID,y3_n_PID,u_obiekt_PID+d);
    y_PID=y_PID+z;
end


