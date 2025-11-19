% Random selection of setpoint change or load disturbance

if uczenie_obciazeniowe == 1 && uczenie_zmiana_SP == 0
    % Load disturbance learning mode
    SP = SP_ini;
    zakres_losowania = 0.5;
    mu = 0;
    sigma = zakres_losowania / 3;
    d = normrnd(mu, sigma);

    % Randomize episode length
    zakres_losowania_czas = 300;
    mu = 3000;
    sigma = zakres_losowania_czas / 2;

    maksymalna_ilosc_iteracji_uczenia = normrnd(mu, sigma);
    if maksymalna_ilosc_iteracji_uczenia < 10
        maksymalna_ilosc_iteracji_uczenia = 10;
    end
    iteracja_uczenia = 1;

elseif uczenie_obciazeniowe == 0 && uczenie_zmiana_SP == 1
    % Setpoint change learning mode
    d = 0;

    % Determine divisor based on range
    if zakres_losowania_zmian_SP < 0.09
        dzielnik = 10000;
        zakres_losowania = zakres_losowania_zmian_SP * dzielnik;
    elseif zakres_losowania_zmian_SP < 0.9
        dzielnik = 1000;
        zakres_losowania = zakres_losowania_zmian_SP * dzielnik;
    elseif zakres_losowania_zmian_SP < 9
        dzielnik = 100;
        zakres_losowania = zakres_losowania_zmian_SP * dzielnik;
    elseif zakres_losowania_zmian_SP < 99
        dzielnik = 10;
        zakres_losowania = zakres_losowania_zmian_SP * dzielnik;
    end

    SP = randi([0 zakres_losowania], 1, 1) / dzielnik;
    iteracja_uczenia = 1;

else
    fprintf('\n Nie Wybrano sposobu uczenia\n')
    quit
end

% Initialize output at first iteration
if iter == 1
    y = f_skalowanie(proc_max_y, proc_min_y, wart_max_y, wart_min_y, SP);
end

% Reset trajectory realization index for new epoch
if exist('realizacja_traj_epoka_idx', 'var')
    realizacja_traj_epoka_idx = 0;
end
