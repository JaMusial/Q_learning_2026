function [IAE, IAE_traj, maks_przereg, czas_regulacji, max_delta_u] = f_licz_wskazniki(y, u, SP, prec, traj, dt,ilosc_probek_sterowanie_reczne,czas_eksp_wer)

dlugosc_symulacji=czas_eksp_wer/dt;
time=[0];
pocz=ilosc_probek_sterowanie_reczne;
for kk=1:dlugosc_symulacji
    time(kk+1)=kk*0.1;
end

% y=Qini1228.y(1:10800);
% % time=datetime(Qini1228.Time(1:10800),'InputFormat','HH:mm:ss;S', 'Format', 'HH:mm:ss.SSS');
% u=Qini1228.u(1:10800);
% SP=892;
% prec=2;
% traj=Qini1228.y_ref(1:10800);

% figure()
% subplot(3,1,1)
% plot(time,y)
% grid on
% subplot(3,1,2)
% plot(time,u)
% grid on


for i=1:3

    if i==1
%         pocz=14;
        kon=dlugosc_symulacji/3;
    elseif i==2
        pocz=dlugosc_symulacji/3+1;
        kon=2*dlugosc_symulacji/3;
    else
        pocz=2*dlugosc_symulacji/3+1;
        kon=dlugosc_symulacji;
    end

    %WSKAŹNIK IAE
    delta_t=dt;
    uchyb=SP-y(pocz:kon);
    IAE(i) = trapz(delta_t,abs(uchyb));

    %WSKAŹNIK IAE REF
    uchyb_traj=traj(pocz:kon)-y(pocz:kon);
    IAE_traj(i) = trapz(delta_t,abs(uchyb_traj));

    %MAX DELTA U
    roznica_u=[];
    max_delta_u(i)=abs(u(pocz+1)-u(pocz));
    for j=pocz+1:kon-1
        roznica_u=abs(u(j+1)-u(j));
        if roznica_u>max_delta_u(i)
            max_delta_u(i)=roznica_u;
        end
    end

    %WSKAŹNIK MAX PRZEREGULOWANIE
    if i==1
        maks_przereg(i)=abs(min(SP-y(pocz:kon)));
    else
        maks_przereg(i)=abs(SP-y(pocz));
        for j=pocz+1:kon
            if abs(SP-y(j))>maks_przereg(i)
                maks_przereg(i)=abs(SP-y(j));
            end
        end
    end

%     subplot(3,1,3)
%     plot(time, SP-y)
%     grid on

    %WSKAŹNIK CZAS REGULACJI
    k=1;
    flaga=0;
    czas_regulacji(i)=(kon-pocz-1)*0.1;
    for j=pocz:kon
        if flaga==0 && abs(SP-y(j))<=prec
            %             czas_regulacji(i)=seconds(time(j)-time(pocz));
            czas_regulacji(i)=time(j)-time(pocz);
            flaga=1;
        elseif flaga==1 && abs(SP-y(j))>prec
            flaga=0;
        end

    end

end

end