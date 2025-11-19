function [y_n,y1_n,y2_n,y3_n] = f_obiekt(typ,dt,k,T,y,y1,y2,y3,u)
%funkcja odpowiadajaca za symulacje modelu matematycznego
%
% DEAD TIME HANDLING:
% Dead time (T0) is implemented EXTERNALLY in m_regulator_Q.m by buffering
% the control signal before it enters this function. Set T0 > 0 in
% m_inicjalizacja.m to add dead time to any model.
%
% MODEL COMPATIBILITY NOTES:
% - Models 2 and 4 are ALIASES for models 1 and 3 (kept for backward compatibility)
% - Use T0 parameter instead of selecting "with delay" model variants
% - All models support dead time via external T0 setting

switch typ
    case 1
        %inercja I rzedu
        y1_n=y1+dt/T(1)*(-y1+k*u);
        y_n=y1_n;
        y2_n=0;
        y3_n=0;
    case 2
        % DEPRECATED: Use model 1 with T0 > 0 instead
        % This case is an alias for model 1 (kept for backward compatibility)
        y1_n=y1+dt/T(1)*(-y1+k*u);
        y_n=y1_n;
        y2_n=0;
        y3_n=0;
    case 3
        %inercja II rzedu
        y1_n=y1+dt/T(1)*(-y1+1*u);
        y2_n=y2+dt/T(2)*(-y2+k*y1_n);
        y_n=y2_n;
        y3_n=0;
    case 4
        % DEPRECATED: Use model 3 with T0 > 0 instead
        % This case is an alias for model 3 (kept for backward compatibility)
        y1_n=y1+dt/T(1)*(-y1+1*u);
        y2_n=y2+dt/T(2)*(-y2+k*y1_n);
        y_n=y2_n;
        y3_n=0;
    case 5
        %obiekt wieloinercyjny
        y1_n=y1+dt/T(1)*(-y1+1*u);      %y1_n=y1+dt/T(1)*(-y1+k1*u);
        y2_n=y2+dt/T(2)*(-y2+1*y1_n);   %y2_n=y2+dt/T(2)*(-y2+k2*y1_n);
        y3_n=y3+dt/T(3)*(-y3+k*y2_n);   %y3_n=y3+dt/T(3)*(-y3+k3*y2_n);
        y_n=y3_n;
    case 6
        Rp1=1.1751; Rp2=7.5332; Rp3=24.6028; n1=1.6006; n2=1.4107; n3=0.9816;
        cp1=6; cp2=1;

        n1=2;n2=2;n3=2;
        y1_n=y1+dt/cp1*(((u-y1)/Rp1)^(1/n1)-((y1-y2)/Rp2)^(1/n2));
        y2_n=y2+dt/cp2*(((y1_n-y2)/Rp2)^(1/n2)-((y2)/Rp3)^(1/n3));
        y_n=y2_n;
        y3_n=0;
    case 7
        %https://apmonitor.com/pdc/index.php/Main/SecondOrderSystems
%         Obiekt oscylacyjny testowany dla T=[5 2 1]
        T_s=sqrt(T(1));
        dzeta=T(2)/(2*T_s);

        y1_n=y1+dt*y2;
        y2_n=y2+dt*(-1/T_s^2*y1-(2*dzeta)/T_s*y2+k/T_s^2*u);
        y_n=y1_n;
        y3_n=0;

    case 8
        k1=0.994;
        k2=0.972;
        %obiekt wieloinercyjny
        y1_n=y1+dt/T(1)*(-y1+k1*u);
        y2_n=y2+dt/T(2)*(-y2+k2*y1_n);
        y3_n=y3+dt/T(3)*(-y3+(0.081*y2_n^2+0.4*y2_n));   %nieliniowy
        % y3_n=y3+dt/T(3)*(-y3+(0.4*y2_n));   %liniowy
        y_n=y3_n;

end


end

