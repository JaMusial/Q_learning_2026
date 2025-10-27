function [Q_2d, Q_2d_old] = f_generuj_macierz_Q_2d(ile_stanow, ile_akcji, nagroda, gamma)

format long
w_max=nagroda/(1-gamma);
w_max=1;

Q_2d = eye(ile_stanow, ile_akcji)*w_max;
Q_2d_old=Q_2d;
end


