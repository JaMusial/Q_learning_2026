%% main_fast.m  -- optimized version of your main.m
clearvars -except USE_PARFOR % keep optional flag if you set it earlier
close all
clc

de=0;

format long

%% --- user-tunable performance flags
USE_PARFOR = exist('USE_PARFOR','var') && USE_PARFOR; % set true in workspace to enable parfor
USE_SINGLE = false;   % if true, use single precision for Q matrix (saves memory / bandwidth)
PLOT_EVERY = 50;      % reduce plotting frequency (0 = never inside loop)

%% inicjalizacja (call your existing init scripts -- they should set initial variables)
m_inicjalizacja
m_inicjalizacja_buforow

Te = Ti;  % as before

% Generate states & actions (only once; we'll regenerate only if Te changes)
[stany, akcje_sr, ilosc_stanow, ile_akcji, nr_stanu_doc, nr_akcji_doc] = ...
    f_generuj_stany_v2(dokladnosc_gen_stanu, oczekiwana_ilosc_stanow, ograniczenie_sterowania_gora, Te, Kp, dt);

% Preallocate Q matrix (use single if desired)
if USE_SINGLE
    Q_2d = single(zeros(ilosc_stanow+1, ile_akcji));
else
    Q_2d = zeros(ilosc_stanow+1, ile_akcji);
end
Q_2d_old = Q_2d;
Q_2d_save = Q_2d;

m_rysuj_mac_Q

% Preallocate arrays that previously grew dynamically
maxEp = max_epoki + 10; % safe margin
realizacje_traj = zeros(maxEp,1);
rewards_per_episode = zeros(maxEp,1);
iteracja_log_index = 0;

if poj_iteracja_uczenia == 1
    zapis_logi = 1;
    m_reset
else
    m_eksperyment_weryfikacyjny
    m_rysuj_wykresy
    m_reset
end

tic
eps = eps_ini;
uczenie = 1;
iter_wskazniki = 1;

% If you had pause for manual inspection, remove or shorten for speed
% pause(2);

%% main learning loop (optimized)
ep = epoka; % local copy
iter_local = iter;
iteracja_uczenia_local = iteracja_uczenia;

% Pre-store frequently used constants locally for faster access
alfa_local = alfa;
gamma_local = gamma;
nr_akcji_doc_local = nr_akcji_doc;
ilosc_stanow_local = ilosc_stanow;
ile_akcji_local = ile_akcji;

while ep <= max_epoki
    % Call regulator (optimized version below)
    m_regulator_Q;  % <- use the optimized regulator file (below)
    
    % logging - avoid file writes inside loop; collect in memory
    iteracja_log_index = iteracja_log_index + 1;
    % store the reward for this episode (realizacje_traj_epoka replaced)
    if exist('R','var')
        realizacje_traj(iteracja_log_index) = R;
        rewards_per_episode(iteracja_log_index) = R;
    end
    
    % Do trajectory simulation (should be vectorized / optimized separately)
    m_realizacja_trajektorii_v2 % keep but consider optimizing that function too
    
    iteracja_uczenia_local = iteracja_uczenia_local + 1;
    m_warunek_stopu % unchanged
    
    iter_local = iter_local + 1;
    
    % ——— Te adaptation logic unchanged but avoid expensive allocations —
    if mean(a_mnk_mean) > 0.2 && mean(b_mnk_mean) > -0.05 && mean(b_mnk_mean) < 0.05 ...
            && flaga_zmiana_Te == 1 && ep ~= 0 && Te > Te_bazowe
        Te = Te - 0.1;
        filtr_mnk_mean = zeros(1,3);
        a_mnk_mean = zeros(1,8);
        b_mnk_mean = 100*ones(1,8);
        flaga_zmiana_Te = 0;
        % Regenerate states only if Te actually changed
        [stany, akcje_sr, ilosc_stanow, ile_akcji, nr_stanu_doc, nr_akcji_doc] = ...
            f_generuj_stany_v2(dokladnosc_gen_stanu, oczekiwana_ilosc_stanow, ograniczenie_sterowania_gora, Te, Kp, dt);
        % If ilosc_stanow/ile_akcji changed, resize Q matrix (preserve learned values where possible)
        newRows = ilosc_stanow + 1;
        if newRows ~= size(Q_2d,1) || ile_akcji ~= size(Q_2d,2)
            Qtmp = zeros(newRows, ile_akcji);
            mnRows = min(newRows, size(Q_2d,1));
            mnCols = min(ile_akcji, size(Q_2d,2));
            Qtmp(1:mnRows,1:mnCols) = Q_2d(1:mnRows,1:mnCols);
            Q_2d = Qtmp;
        end
    end

    % periodic plotting (reduce frequency inside training)
    if PLOT_EVERY > 0 && mod(ep, PLOT_EVERY) == 0
        if exist('m_rysuj_wykresy','file')
            m_rysuj_wykresy
        end
    end

    ep = ep + 1; % advance epoch counter
end

% finalize index counts & print
epoka = ep;
iter = iter_local;
iteracja_uczenia = iteracja_uczenia_local;

fprintf("\n Uczenie zakonczono na %d epokach, osiągnieto Te=%f\n", epoka, Te);
m_rysuj_wykresy

if poj_iteracja_uczenia == 0
    m_eksperyment_weryfikacyjny
    figure()
    mesh(Q_2d)
    figure(300)
end
