%% m_warunek_stopu.m - Stopping Condition and Epoch Management
%
% PURPOSE:
%   Monitors episode progress, detects completion conditions, manages epoch
%   transitions, triggers verification experiments, and reports training progress.
%   This is the main control script for the learning loop lifecycle.
%
% INPUTS (from workspace):
%   e                            - Current control error
%   dopuszczalny_uchyb           - Acceptable error threshold for steady-state
%   stan_ustalony_probka         - Counter: consecutive samples in steady-state
%   oczekiwana_ilosc_probek_stabulizacji - Required samples for convergence
%   iteracja_uczenia             - Current iteration within episode
%   maksymalna_ilosc_iteracji_uczenia - Maximum episode length
%   epoka                        - Current epoch number
%   max_epoki                    - Total epochs to run
%   Q_2d                         - Current Q-matrix
%   probkowanie_norma_macierzy   - Interval for detailed analysis
%   gif_on                       - Flag: 1=generate GIF frames
%   poj_iteracja_uczenia         - Mode: 0=verification, 1=single iteration
%   Te                           - Current time constant
%
% OUTPUTS (to workspace):
%   warunek_stopu                - Flag: 1=episode complete, 0=continue
%   inf_zakonczono_epoke_stabil  - Count: episodes ended by stabilization
%   inf_zakonczono_epoke_max_iter - Count: episodes ended by timeout
%   Q_2d_save                    - Saved copy of Q-matrix
%   max_macierzy_Q               - Vector: max Q-value history
%   epoka                        - Incremented epoch counter
%   wylosowany_SP                - Vector: setpoint history
%   wylosowane_d                 - Vector: disturbance history
%
% SIDE EFFECTS:
%   - Calls m_norma_macierzy, m_rysuj_mac_Q, gif, m_eksperyment_weryfikacyjny
%   - Calls m_reset (twice in verification mode)
%   - Prints progress reports to console
%   - Modifies iter, iter_wskazniki in verification mode

%% ========================================================================
%  STEADY-STATE DETECTION
%  ========================================================================
% Count consecutive samples within acceptable error bounds.
% Counter resets if error exceeds threshold (not yet converged).

if abs(e) <= abs(dopuszczalny_uchyb)
    stan_ustalony_probka = stan_ustalony_probka + 1;
else
    stan_ustalony_probka = 0;
end

%% ========================================================================
%  EPISODE TERMINATION CONDITION
%  ========================================================================
% Episode ends when maximum iteration count exceeded.
% Track termination reason: stabilization vs timeout.

if iteracja_uczenia > maksymalna_ilosc_iteracji_uczenia
    % Determine termination reason
    if stan_ustalony_probka > oczekiwana_ilosc_probek_stabulizacji
        % Episode ended due to stabilization (desired outcome)
        inf_zakonczono_epoke_stabil = inf_zakonczono_epoke_stabil + 1;
    else
        % Episode ended due to timeout (did not converge)
        inf_zakonczono_epoke_max_iter = inf_zakonczono_epoke_max_iter + 1;
    end

    % Signal episode completion
    warunek_stopu = 1;
    iteracja_uczenia = 0;
else
    % Episode still in progress
    warunek_stopu = 0;
end

%% ========================================================================
%  EPOCH COMPLETION PROCESSING
%  ========================================================================
% When episode completes (warunek_stopu==1), perform epoch-level tasks:
% save Q-matrix, run periodic analysis, report progress, start next epoch.

if warunek_stopu == 1

    % Save current Q-matrix for analysis/comparison
    Q_2d_save = Q_2d;


    % =====================================================================
    % PERIODIC ANALYSIS (every probkowanie_norma_macierzy epochs)
    % =====================================================================
    % Compute detailed metrics, optionally run verification experiment
    if mod(epoka, probkowanie_norma_macierzy) == 0 && epoka ~= 0

        % Compute Q-matrix convergence metrics
        m_norma_macierzy

        % Generate GIF animation frame (if enabled)
        if gif_on == 1
            m_rysuj_mac_Q
            gif
        end

        % Track maximum Q-value over training
        idx_max_Q = idx_max_Q + 1;
        max_macierzy_Q(idx_max_Q) = max(max(Q_2d));

        % Run verification experiment (verification mode only)
        % This temporarily interrupts main learning loop to test current
        % Q-matrix performance in controlled conditions
        if poj_iteracja_uczenia == 0
            licz_wskazniki = 1;

            % Run full test experiment with current Q-matrix
            m_eksperyment_weryfikacyjny

            % Compute performance metrics from test
            [IAE_wek(iter_wskazniki,:), ...
             IAE_traj_wek(iter_wskazniki,:), ...
             maks_przereg_wek(iter_wskazniki,:), ...
             czas_regulacji_wek(iter_wskazniki,:), ...
             max_delta_u_wek(iter_wskazniki,:)] = ...
                f_licz_wskazniki(logi.Q_y, logi.Q_u, SP, ...
                                 dokladnosc_gen_stanu, logi.Ref_y, dt, ...
                                 ilosc_probek_sterowanie_reczne, czas_eksp_wer);

            % Reset iteration counter and prepare for next episode
            % This second m_reset ensures clean state after verification test
            iter = 1;
            iter_wskazniki = iter_wskazniki + 1;
            m_reset
            licz_wskazniki = 0;
        end
    end

    % =====================================================================
    % PROGRESS REPORTING (adaptive intervals based on total epochs)
    % =====================================================================
    % Report training progress at intervals scaled to training duration.
    % Thresholds and intervals configured in config.m:
    %   - Short runs (≤short_run_threshold): report every short_run_interval epochs
    %   - Medium runs (≤medium_run_threshold): report every medium_run_interval epochs
    %   - Long runs (>medium_run_threshold): report every long_run_interval epochs

    % Determine reporting interval and check if this epoch should report
    raportuj_postep = false;
    if max_epoki <= short_run_threshold && mod(epoka, short_run_interval) == 0
        raportuj_postep = true;
        interval = short_run_interval;
    elseif max_epoki <= medium_run_threshold && mod(epoka, medium_run_interval) == 0
        raportuj_postep = true;
        interval = medium_run_interval;
    elseif mod(epoka, long_run_interval) == 0
        raportuj_postep = true;
        interval = long_run_interval;
    end

    % Generate and display progress report
    if raportuj_postep
        % Measure elapsed time since last report
        czas_uczenia = toc;
        czas_uczenia_calkowity = czas_uczenia_calkowity + czas_uczenia;

        % Calculate stabilization rate (% of episodes ending by convergence)
        % Ratio of stabilized episodes to total episodes since last report
        total_episodes_since_last = ...
            (inf_zakonczono_epoke_max_iter - inf_zakonczono_epoke_max_iter_old) + ...
            (inf_zakonczono_epoke_stabil - inf_zakonczono_epoke_stabil_old);
        stabilized_episodes_since_last = ...
            (inf_zakonczono_epoke_stabil - inf_zakonczono_epoke_stabil_old);

        if total_episodes_since_last > 0
            inf_proc_zak_epoke_stab = stabilized_episodes_since_last / total_episodes_since_last;
        else
            inf_proc_zak_epoke_stab = 0;
        end

        % Update counters for next interval
        inf_zakonczono_epoke_stabil_old = inf_zakonczono_epoke_stabil;
        inf_zakonczono_epoke_max_iter_old = inf_zakonczono_epoke_max_iter;

        % Display progress report
        fprintf('Completed %5.0d epochs, Time for %4.0d epochs: %.2f [s]   %.1f%%   ', ...
                epoka, interval, czas_uczenia, epoka*100/max_epoki);
        fprintf('Remaining: %5.0d epochs, %3.0f%% stabilized, Te = %.1f\n', ...
                max_epoki - epoka, inf_proc_zak_epoke_stab*100, Te);

        % Log timing and stabilization data
        idx_raport = idx_raport + 1;
        czas_uczenia_wek(idx_raport) = czas_uczenia;
        proc_stab_wek(idx_raport) = inf_proc_zak_epoke_stab;
        probkowanie_dane_symulacji = interval;

        % Restart timer for next interval
        tic
    end

    % =====================================================================
    % PREPARE FOR NEXT EPOCH
    % =====================================================================

    % Increment epoch counter
    epoka = epoka + 1;

    % Reset steady-state sample counter
    stan_ustalony_probka = 0;

    % Reset episode conditions (randomize SP/disturbance, reset counters)
    m_reset

    % Log randomized conditions for this epoch
    idx_wylosowany = idx_wylosowany + 1;
    wylosowany_SP(idx_wylosowany) = SP;
    wylosowane_d(idx_wylosowany) = d;

end
