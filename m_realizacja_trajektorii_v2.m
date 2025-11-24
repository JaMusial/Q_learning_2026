%% m_realizacja_trajektorii_v2.m - Trajectory Realization Tracking
%
% PURPOSE:
%   Tracks percentage of time the controller maintains the goal state during
%   active error correction. Used to determine when learning performance has
%   stabilized enough to reduce the time constant Te (staged learning).
%
% ALGORITHM:
%   1. Accumulate rewards (R) when |e| >= threshold (sliding window)
%   2. When window full (500 samples): calculate realization percentage
%   3. Apply recursive least-squares filter (MNK) with time constant T
%   4. Track trend coefficients (a=level, b=slope) for convergence detection
%   5. Set flag to enable Te reduction check in main.m
%
% INPUTS (from workspace):
%   okno_procent_realizacji          - Accumulator: R values during active correction
%   ilosc_probek_procent_realizacjii - Window size [iterations] (500 at dt=0.1)
%   R                                - Reward: 1 if in goal state, 0 otherwise
%   e                                - Current control error
%   dopuszczalny_uchyb               - Acceptable error threshold (scaled precision)
%   dt                               - Sampling time [s]
%   Te                               - Current time constant [s]
%   mnk_filter_time_constant         - MNK filter time constant [s] (from config.m)
%   mnk_mean_window_size             - Sliding window size for filtered values (from config.m)
%   mnk_coeff_a_window_size          - Sliding window size for coefficient 'a' (from config.m)
%   mnk_coeff_b_window_size          - Sliding window size for coefficient 'b' (from config.m)
%
% OUTPUTS (to workspace):
%   proc_realizacji                  - Current realization percentage (0-100%)
%   wek_proc_realizacji              - History of realization percentages (preallocated)
%   filtr_mnk                        - MNK filtered realization values (preallocated)
%   wsp_mnk                          - MNK coefficients [a; b; c] (preallocated matrix)
%   wek_Te                           - Te values when metrics computed (preallocated)
%   filtr_mnk_mean                   - Last N filtered values (sliding window)
%   a_mnk_mean                       - Last N values of coefficient 'a' (sliding window)
%   b_mnk_mean                       - Last N values of coefficient 'b' (sliding window)
%   flaga_zmiana_Te                  - Flag: 1=enable Te reduction check
%   idx_realizacja                   - Index counter for preallocated arrays
%
% CONVERGENCE DETECTION (in main.m):
%   Te reduction triggered when:
%   - mean(a_mnk_mean) > te_reduction_threshold_a      (upward trend)
%   - |mean(b_mnk_mean)| < te_reduction_threshold_b    (stable, not accelerating)
%   - flaga_zmiana_Te == 1                             (window processing complete)
%   - Te > Te_bazowe                                   (haven't reached goal)
%
% NOTES:
%   - Only accumulates R when OUTSIDE acceptable error (focuses on transient performance)
%   - Window is RESET (not sliding) when full - commented code suggests sliding was intended
%   - Uses indexed array access for performance (avoids end+1 reallocation)
%   - Arrays preallocated in m_inicjalizacja_buforov.m
%
% SIDE EFFECTS:
%   - Modifies persistent state in f_rec_mnk (recursive filter)
%   - Resets okno_procent_realizacji when full
%
% CALLED BY:
%   main.m (every iteration during learning loop)
%
% CALLS:
%   f_rec_mnk - Recursive least-squares filter

%% ========================================================================
%  TRAJECTORY REALIZATION TRACKING
%  ========================================================================

% Check if window is full (ready for processing)
if length(okno_procent_realizacji) >= ilosc_probek_procent_realizacjii

    %% --- Window Full: Process Metrics ---

    % Calculate realization percentage (% of time in goal state)
    proc_realizacji = sum(okno_procent_realizacji) / ilosc_probek_procent_realizacjii;

    % Reset window for next accumulation period
    % NOTE: Commented code below suggests sliding window was originally intended,
    %       but current implementation uses reset (tumbling) window
    % okno_procent_realizacji = okno_procent_realizacji(przesuniecie_okno_procent_realizacji : end);
    okno_procent_realizacji = [];

    % Store realization percentage (indexed access for performance)
    idx_realizacja = idx_realizacja + 1;
    wek_proc_realizacji(idx_realizacja) = proc_realizacji;

    % Apply recursive least-squares filter to smooth realization metric
    % Returns: filtered value and coefficients [a; b; c] where:
    %   a = current level estimate
    %   b = linear trend (rate of change)
    %   c = acceleration (curvature)
    [filtr_mnk(idx_realizacja), wsp_mnk(:, idx_realizacja)] = ...
        f_rec_mnk(proc_realizacji, dt, mnk_filter_time_constant);

    % Record current Te value for this metric window
    wek_Te(idx_realizacja) = Te;

    % Set flag to enable Te reduction check in main.m
    flaga_zmiana_Te = 1;

    % Update sliding windows for convergence detection
    % Shift left and append new value (maintains fixed window size)
    filtr_mnk_mean = [filtr_mnk_mean(2:end), filtr_mnk(idx_realizacja)];
    a_mnk_mean = [a_mnk_mean(2:end), wsp_mnk(1, idx_realizacja)];
    b_mnk_mean = [b_mnk_mean(2:end), wsp_mnk(2, idx_realizacja)];

else

    %% --- Window Not Full: Accumulate Samples ---

    % Accumulate reward ONLY when outside acceptable error range
    % This focuses metric on transient performance (active correction)
    % rather than steady-state dwelling
    if abs(e) >= abs(dopuszczalny_uchyb)
        okno_procent_realizacji(end+1) = R;
    end

end
