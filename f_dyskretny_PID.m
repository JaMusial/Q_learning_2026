function [u,przyrost,wart_akcji] = f_dyskretny_PID(typ,e,Kp,Ti,Td,Tn,Te,dt,e_prev,u)

if typ=='P   '
    u=Kp*e;
elseif typ=='PI  '
%     calka=calka+e;
    dedt=(e-e_prev)/dt;
    wart_akcji=(1/Te*e+dedt);
    przyrost=Kp*dt*(1/Ti*e+dedt);
    % u=u+przyrost; dla opoznienia
elseif typ=='PID '
%     calka=calka+e;
%     u=Kp*(e+(1/Ti)*calka*dt+Td*((e-e_prev)/dt));
elseif typ=='I   '
%     calka=calka+e;
%     u=(1/Ti)*calka*dt;
elseif typ=='PIDn'
%     calka=calka+e;
%     u=Kp*(e+(1/Ti)*calka*dt+Td*((e-e_prev)/td));
end

end

