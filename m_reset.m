%LOSOWANIE WARTOŚCXI ZMIANYsP LUB ZAKŁUCENIA OBCIAZENIOWEGO
if uczenie_obciazeniowe==1 && uczenie_zmiana_SP==0

    SP=SP_ini;
    zakres_losowania=0.5;
    mu=0;
    sigma=zakres_losowania/3;
    d = normrnd(mu,sigma);
    %mu=2000;
    zakres_losowania_czas=300;
    mu=300;
    mu=3000;
    % sigma=zakres_losowania_czas/3;
    sigma=zakres_losowania_czas/2;

    maksymalna_ilosc_iteracji_uczenia=normrnd(mu,sigma);
    if maksymalna_ilosc_iteracji_uczenia<10
        maksymalna_ilosc_iteracji_uczenia=10;
    end
    iteracja_uczenia=1;

    % if eks_wer==0
    %     war_okno_iterator=war_okno_iterator+1;
    %     if war_okno_iterator == okno_war_rozmiar
    %         war_okno_iterator=0;
    %         war_wek(end+1)=var(war_okno);
    %         war_wek_u(end+1)=var(war_okno_u);
    %         war_wek_delta_u(end+1)=var(war_okno_delta_u);
    %         war_okno=[];
    %         war_okno_u=[];
    %         war_okno_delta_u=[];
    %     end
    % end

elseif uczenie_obciazeniowe==0 && uczenie_zmiana_SP==1

    d=0;
    if zakres_losowania_zmian_SP<0.09
        dzielnik=10000;
        zakres_losowania=zakres_losowania_zmian_SP*dzielnik;
    elseif zakres_losowania_zmian_SP < 0.9
        dzielnik=1000;
        zakres_losowania=zakres_losowania_zmian_SP*dzielnik;
    elseif zakres_losowania_zmian_SP < 9
        dzielnik=100;
        zakres_losowania=zakres_losowania_zmian_SP*dzielnik;
    elseif zakres_losowania_zmian_SP < 99
        dzielnik=10;
        zakres_losowania=zakres_losowania_zmian_SP*dzielnik;
    end

    SP = randi([0 zakres_losowania],1,1)/dzielnik;
    iteracja_uczenia=1;

else

    fprintf('\n Nie Wybrano sposobu uczenia\n')
    quit
end

if iter==1
    y=f_skalowanie(proc_max_y,proc_min_y,wart_max_y,wart_min_y,SP);
end
