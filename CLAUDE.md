# CLAUDE.md

Guidance for Claude Code when working with this Q2d Q-learning controller repository.

**IMPORTANT CODING RULES**:
- **NEVER** use Polish special characters (ą, ć, ę, ł, ń, ó, ś, ź, ż) in variable names - MATLAB compatibility issue
- Use English names for NEW variables when possible
- Existing Polish variable names (e.g., `epoka`, `stan`, `uchyb`) are preserved for backward compatibility
- See Variable Glossary in "Coding Standards" section for translations

## Research Context

**Problem**: 60% of industrial PID loops perform poorly. Retuning requires expert knowledge and is impractical at scale.

**Solution**: Self-improving Q-learning controller that:
- Bumplessly replaces existing PI controllers
- Starts with similar performance (Te=Ti, K_Q=K_PI, Q-matrix as identity)
- Gradually improves online through reinforcement learning
- Requires no process model (only existing PI tunings)

### Q2d Breakthrough

**Key Innovation**: Merge error and derivative into single state based on first-order trajectory:
- **Target trajectory**: `ė + (1/Te)·e = 0` → `e(t) = e₀·exp(-t/Te)`
- **State definition**: `s = ė + (1/Te)·e` (when s≈0, system on trajectory)
- **Control law**: `U(t) = U(t-1) + K_Q·Ts·a(s)` where action `a(s)` from Q-matrix

**Staged Learning**: Te reduces from Ti (20s) → Te_goal (2s) in 0.1s steps
- Q-matrix preserved across Te changes
- Small steps allow gradual adaptation without catastrophic forgetting
- `precision*2/Te` scaling maintains steady-state accuracy

**Previous approach (Q3d)**: 3D Q-matrix with separate e and ė dimensions - too slow, abandoned.

**Future direction (Q2dPLC)**: PLC implementation with reversed generation, geometric action distribution, PTC metric.

## Quick Start

**Run**: `main.m` in MATLAB

**Configure** (`config.m`):
- `poj_iteracja_uczenia`: 1=single iteration mode, 0=full verification with metrics
- `max_epoki`: Training duration (500 for testing, 5000+ for full training)
- `nr_modelu`: Plant model 1-8 (1=1st order, 3=2nd order, 8=3rd order pneumatic)
- `f_rzutujaca_on`: 0=current approach (recommended), 1=paper version with projection (for comparison)

**Performance**: ~30-35 seconds per 100 epochs.

**Optimizations Applied**:
- Array preallocation (2025): Eliminated incremental growth bottleneck for history arrays
- Remaining bottleneck: f_skalowanie() called 9.75M times per 100 epochs

## Core Algorithm (m_regulator_Q.m)

**Manual Control** (first 5 samples): `u = SP/k` to initialize toward setpoint

**Q-Learning Phase**:
1. **State**: `s = ė + (1/Te)·e`, discretize to index
2. **Q-update**: `Q(s,a) += α·(R + γ·max(Q(s',·)) - Q(s,a))`
3. **Action**: ε-greedy (explore/exploit), always a=0 at target state
4. **Control**: `u += K_Q·a·dt` with saturation [0,100]%
5. **Simulate**: Plant at 0.01s timestep

**Key Features**:
- Projection function: `e·(1/Te - 1/Ti)` (optional, see below)
- Dead time: Decoupled plant delay (T0) and controller compensation (T0_controller)
- Reference trajectory: Uses Te_bazowe (goal) for consistent visualization
- Learning disabled when control saturates

**Projection Function** (2025-01-28 experimental validation):
- **Current approach** (`f_rzutujaca_on=0`, **RECOMMENDED**): Projection disabled, uses staged learning instead
  - Te starts at Ti (bumpless switching), reduces gradually to Te_bazowe in 0.1s steps
  - Better empirical performance, smoother convergence
  - **Proven to work correctly**
- **Paper version** (`f_rzutujaca_on=1`, **DO NOT USE**): Projection enabled with fixed Te
  - Te = Te_bazowe from start (immediate goal, large 10× Te-Ti mismatch)
  - Projection term: `wart_akcji -= e·(1/Te - 1/Ti)` applied to control
  - **EXPERIMENTAL FAILURE (1000 epochs)**: Output stuck at 44.89% (target: 100%), error 5.11%, limit cycle between 2 states
  - **Root cause**: Projection magnitude (e·0.45) overwhelms Q-learning, wrong control direction for large errors
  - **Conclusion**: Projection function fundamentally flawed for large Te-Ti mismatches

**Key Finding**: Staged learning eliminates need for projection by maintaining small Te-Ti difference. Projection cannot compensate for 10× mismatch and corrupts Q-learning process.

## Dead Time Compensation

**Design Philosophy**: Decouple physical plant delay from controller compensation strategy to enable robustness research.

### Two Independent Parameters

**T0** (Plant Dead Time):
- Physical dead time in the plant/process
- Control signal u(t) affects plant output at t+T0
- Always applied via `bufor_T0` before plant simulation
- Represents reality

**T0_controller** (Controller Compensation):
- Dead time value the controller uses for compensation
- Set to 0: No compensation (controller ignores dead time)
- Set to T0: Perfect matched compensation
- Set to ≠T0: Mismatched compensation (research scenarios)

### Delayed Credit Assignment (T0_controller > 0)

**Core Strategy**: Buffer state-action pairs and wait for action's effect to propagate before updating Q-values.

**Timing Logic** (at iteration k):
1. Observe state s(k) calculated from y(k)
2. Select action a(k) based on s(k)
3. Buffer s(k) and a(k) in FIFO buffers (size T0_controller/dt)
4. Retrieve s(k-T0_controller/dt) and a(k-T0_controller/dt) from buffers
5. Update: `Q(s(k-T0_controller/dt), a(k-T0_controller/dt))` using s(k) as next state

**Why this works when T0 = T0_controller**:
- Action a(k) generates u(k)
- u(k) enters plant delay buffer (T0)
- At k+T0/dt+1: y reflects u(k), therefore s(k+T0/dt+1) reflects a(k)
- Buffer retrieves (s(k), a(k)) at iteration k+T0/dt+1
- Q-update credits a(k) with consequence s(k+T0/dt+1) ✓

**Code Implementation** (m_regulator_Q.m:86-105):
```matlab
% Note: Variable names use Polish terms (stan=state, wyb_akcja=selected_action,
%       bufor=buffer, nr_stanu_doc=goal_state_number) for historical compatibility

if T0_controller > 0
    % Buffer current state/action for delayed credit assignment
    [old_stan_T0, bufor_state] = f_bufor(stan, bufor_state);
    [wyb_akcja_T0, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja);

    % Use CURRENT state as next state (effect visible now)
    stan_T0 = stan;

    % Reward buffered state if it was in goal state
    if old_stan_T0 == nr_stanu_doc
        R = 1;
    else
        R = 0;
    end
else
    % No compensation: standard one-step Q-learning
    old_stan_T0 = old_state;
    stan_T0 = stan;
    wyb_akcja_T0 = wyb_akcja;
end
```

### Sparse Reward Strategy

**Critical Design Choice**: R=1 **ONLY** at goal state (nr_stanu_doc)

**Rationale**:
- Goal state forces goal action (a=0, zero control increment)
- Q(goal_state, goal_action) receives direct reward
- All other Q-values learned via bootstrapping: γ·max(Q(s',·))
- Ensures Q(goal_state, goal_action) = highest value in Q-table
- Controller cannot select goal_action unless in goal_state

This sparse reward requires proper credit assignment - dead time compensation ensures actions are credited when their effects are actually observed.

### Buffer Pre-filling (Manual Control)

During manual control phase (first 5 samples):
- Plant buffers (`bufor_T0`, `bufor_T0_PID`) pre-filled with u=SP/k (steady-state)
- Controller buffers (`bufor_state`, `bufor_wyb_akcja`) filled but outputs discarded
- Prevents transient from zero-filled buffers
- Simulates system already at steady-state before controller engages

### Research Scenarios

**Matched Compensation** (T0=3, T0_controller=3):
- Optimal: controller waits full dead time before crediting actions

**No Compensation** (T0=3, T0_controller=0):
- Controller learns delayed policy without explicit compensation
- Tests if Q-learning can handle dead time implicitly

**Under-Compensation** (T0=3, T0_controller=2):
- Controller underestimates dead time
- Credits actions too early
- Tests robustness

**Over-Compensation** (T0=3, T0_controller=4):
- Controller overestimates dead time
- Credits actions too late
- Tests robustness

### Continuous Learning Mode

**Important**: Buffers are NOT reset between learning episodes:
- Episodes are artificial boundaries for convergence checking
- Buffers retain values to simulate continuous industrial operation
- Only reset at start of verification experiment (clean test)

## Architecture

**Main Loop** (`main.m`):
```
Init → Generate states/actions → Init Q-matrix →
  Loop: m_regulator_Q → m_zapis_logow → m_realizacja_trajektorii_v2 →
        m_warunek_stopu → m_reset → [Te adjustment] →
Verification → Visualization
```

**Staged Te Reduction**: When MNK filter shows convergence, Te decreases by 0.1s and state/action spaces regenerate.

## Key Parameters

All configurable parameters are defined in `config.m`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| **Q-Learning** | | |
| `alfa` | 0.1 | Learning rate |
| `gamma` | 0.99 | Discount factor |
| `eps_ini` | 0.3 | Initial exploration rate |
| `RD` | 5 | Random deviation range |
| **Trajectory** | | |
| `Te_bazowe` | 2 | Goal time constant [s] |
| `Te` | 20 | Initial (=Ti) [s] |
| `kQ` | 1 | Controller gain (=Kp) |
| **State Space** | | |
| `dokladnosc_gen_stanu` | 0.5 | Precision (steady-state accuracy) |
| `oczekiwana_ilosc_stanow` | 100 | Expected number of states |
| **Simulation** | | |
| `max_epoki` | 500 | Maximum training epochs |
| `dt` | 0.1 | Sampling time [s] |
| `uczenie_obciazeniowe` | 1 | Learn with disturbances (vs setpoint changes) |
| **Episode Configuration** | | |
| `disturbance_range` | 0.5 | Disturbance range: ±0.5 at 3-sigma |
| `mean_episode_length` | 3000 | Mean episode length [iterations] |
| `episode_length_variance` | 300 | Episode length std deviation [iterations] |
| `min_episode_length` | 10 | Minimum episode length (safety limit) |
| **Progress Reporting** | | |
| `short_run_threshold` | 10000 | Threshold for short runs (report every 100 epochs) |
| `medium_run_threshold` | 15000 | Threshold for medium runs (report every 500 epochs) |
| `short_run_interval` | 100 | Reporting interval for short runs [epochs] |
| `medium_run_interval` | 500 | Reporting interval for medium runs [epochs] |
| `long_run_interval` | 1000 | Reporting interval for long runs [epochs] |
| **PI (comparison)** | | |
| `Kp` | 1 | Proportional gain |
| `Ti` | 20 | Integral time [s] |
| **Plant** | | |
| `nr_modelu` | 1-8 | Model selection (1=1st order, 8=3rd order pneumatic) |
| `T` | varies | Time constant(s) [s] |
| `k` | varies | Process gain |
| `T0` | 0 | Plant dead time (physical reality) [s] |
| `T0_controller` | 0 | Controller compensation dead time [s] (0=no compensation) |

## Plant Models (f_obiekt.m)

| Model | Description | Transfer Function |
|-------|-------------|-------------------|
| 1 | 1st order | k/(T·s+1) |
| 3 | 2nd order | k/[(T₁·s+1)(T₂·s+1)] |
| 5 | 3rd order | k/[(T₁·s+1)(T₂·s+1)(T₃·s+1)] |
| 6 | Pneumatic (nonlinear) | Complex 3rd order |
| 7 | Oscillatory 2nd order | Tested for T=[5 2 1] |
| 8 | 3rd order pneumatic | T=[2.34 1.55 9.38], k=0.386 |

Models 2,4 deprecated. Dead time: Add T0 > 0 (external delay).

## File Organization

| Category | Files | Purpose |
|----------|-------|---------|
| **Main** | main.m | Entry point |
| **Controllers** | m_regulator_Q.m, m_regulator_PID.m | Q2d and PI implementations |
| **Init** | m_inicjalizacja.m, m_inicjalizacja_buforov.m, m_reset.m | Setup and episode reset |
| **State/Action** | f_generuj_stany_v2.m, f_find_state.m, f_best_action_in_state.m, f_generuj_macierz_Q_2d.m | Space generation and lookup |
| **Learning** | m_warunek_stopu.m, m_realizacja_trajektorii_v2.m, m_norma_macierzy.m, m_losowanie_nowe.m | Episode management and exploration |
| **Logging/Viz** | m_zapis_logow.m, m_rysuj_wykresy.m, m_rysuj_mac_Q.m | Data recording and plotting |
| **Verification** | m_eksperyment_weryfikacyjny.m, f_licz_wskazniki.m | Q vs PI comparison, metrics (IAE, overshoot, settling time) |
| **Utilities** | f_skalowanie.m, f_obiekt.m, f_bufor.m | Scaling, plant simulation, delay buffers |

**Recently Refactored** (2025):
- `config.m`: Added episode configuration and progress reporting parameters (eliminated magic numbers)
- `m_reset.m`: Comprehensive documentation, clear mode separation, mathematical divisor calculation (replaced 4-branch if-elseif, **fixed bug for range≥99**), mutual exclusivity validation, error() instead of quit, uses parameters from config.m
- `m_warunek_stopu.m`: Eliminated code duplication, unified progress reporting, English comments, indexed array access, uses parameters from config.m
- `m_inicjalizacja_buforov.m`: Array preallocation with proper sizing, index counters for performance, named constants
- `main.m`: Added array trimming after training loop
- `f_generuj_stany_v2.m`: Removed dead code (compensation model p=0), array preallocation for performance, comprehensive documentation explaining `precision*2/Te` formula and Te-invariant error tolerance, magic numbers explained
- `f_licz_wskazniki.m`: English variable names, comprehensive documentation with 3-phase experiment structure, vectorized calculations (time array, max_delta_u, max_overshoot), removed all dead code (25+ lines), replaced hardcoded timesteps with dt parameter, array preallocation, unified max overshoot logic, **fixed phase boundary bug** and time array length bug
- `m_eksperyment_weryfikacyjny.m`: Comprehensive header documentation (PURPOSE, INPUTS, OUTPUTS, NOTES, SIDE EFFECTS), section dividers, **fixed dimensional inconsistency bug** in disturbance timing (mixed time[s] with samples), phase boundaries now correctly calculated in time units
- `test_divisor_logic.m`: Verification script for divisor calculation (14 test cases, identifies 2 bug fixes)
- `DIVISOR_LOGIC_ANALYSIS.md`: Detailed explanation of bug fixes and formula derivation

## Workflows

**Standard Experiment**:
1. Edit `m_inicjalizacja.m`: Set parameters
   - `max_epoki` (max_epochs): Training duration (500 for testing, 5000+ for full training)
   - `uczenie_obciazeniowe` (disturbance_learning): 1=learn with load disturbances
   - `uczenie_zmiana_SP` (setpoint_learning): 1=learn with setpoint changes
   - `nr_modelu` (model_number): Plant model 1-8
   - `T`: Time constant(s), `k`: Process gain
2. Run `main.m`
3. Monitor: Epoch progress, stabilization %, current Te
4. View plots: Q vs PI vs Reference, trajectory realization, Q-matrix evolution

**Change Plant Model**:
```matlab
% Example: 2nd order plant
% Note: nr_modelu = model_number, adjust time constants T and gain k as needed
T = [5 2]; nr_modelu = 3; Ks = tf(1,[5 1])*tf(1,[2 1]);
% May adjust: Te_bazowe (goal time constant), Ti, Kp, maksymalna_ilosc_iteracji_uczenia (max episode length)
```

## Coding Standards

**Documentation**:
- All scripts should have file headers with: PURPOSE, INPUTS, OUTPUTS, NOTES, SIDE EFFECTS
- Use section dividers (`%% ======...`) to separate logical blocks
- Inline comments should explain WHY, not just WHAT
- Complex algorithms need step-by-step explanation
- See `m_reset.m` and `m_warunek_stopu.m` for reference style

**Magic Numbers**:
- **NEVER** hard-code numeric literals without explanation
- Two types of numbers:
  1. **Configurable parameters**: Move to `config.m` with descriptive names and comments
  2. **Mathematical/physical constants**: Use named constants with explanation
- Example of configurable parameters in `config.m`:
  ```matlab
  disturbance_range = 0.5;        % Disturbance range: ±0.5 at 3-sigma
  mean_episode_length = 3000;     % Mean episode length [iterations]
  short_run_interval = 100;       % Report every 100 epochs for short runs
  ```
- Example of mathematical constants in code:
  ```matlab
  SIGMA_DIVISOR = 3;              % Statistical constant (3-sigma rule)
  SAFETY_MARGIN = 10;             % Array preallocation buffer
  ```
- See refactored `m_reset.m`, `m_warunek_stopu.m`, `m_inicjalizacja_buforow.m` for examples

**Performance**:
- **CRITICAL**: Preallocate arrays to maximum expected size, use indexed access with counters
  - Example: `arr = zeros(1, max_size); idx = 0;` then `idx = idx + 1; arr(idx) = value;`
  - Avoid `arr(end+1) = value` which reallocates memory on each append
  - For long runs (>10k epochs), preallocation provides significant speedup
  - See `m_inicjalizacja_buforov.m` for reference implementation
- Trim arrays when done to actual used size: `arr = arr(1:idx);`
- Wrap size calculations in `round()` to avoid floating-point indices
- Avoid code duplication - extract repeated logic into variables/functions

**Variable Naming**:
- **CRITICAL**: Never use Polish special characters (ą, ć, ę, ł, ń, ó, ś, ź, ż) in variable names - MATLAB compatibility issue
- Use English names for new variables when possible
- Existing Polish names preserved for compatibility (documented below)
- Comments can be in English or Polish, but code must be ASCII-compatible

**Common Variable Glossary** (Polish → English meaning):
- `epoka` → epoch (training epoch number)
- `iteracja_uczenia` → learning_iteration (iteration within episode)
- `iter` → iteration (global iteration counter)
- `uchyb` / `dopuszczalny_uchyb` → error / acceptable_error
- `dokladnosc` / `dokladnosc_gen_stanu` → precision / state_generation_precision
- `stan` / `stan_ustalony` → state / steady_state
- `wyb_akcja` → selected_action
- `zakres_losowania` → sampling_range
- `maksymalna_ilosc_iteracji_uczenia` → max_episode_length
- `oczekiwana_ilosc_probek_stabulizacji` → expected_stabilization_samples (note: typo in original)
- `inf_zakonczono_epoke_stabil` → count_epochs_ended_by_stabilization
- `inf_zakonczono_epoke_max_iter` → count_epochs_ended_by_timeout
- `czas_uczenia` → learning_time
- `prob(k)a` → sample
- `bufor` → buffer
- `wylosowany_SP` / `wylosowane_d` → sampled_setpoint / sampled_disturbance (history arrays)
- `idx_wylosowany` / `idx_raport` / `idx_max_Q` → array index counters (for preallocation)

**Visualization**:
- Theme-neutral colors (RGB arrays, never 'w' or 'k')
- Use `figure()` without Position for tabbed interface
- Check variable existence: `exist()`, `isfield()`, `~isempty()`
- Dynamic sizing: `size()`, `length()` instead of hardcoded dimensions

**Mathematical Approaches**:
- Prefer mathematical formulas over multi-branch conditionals when possible
- Example: Divisor calculation in `m_reset.m` (lines 105-106)
  - Old: 4-branch if-elseif chain checking thresholds (0.09, 0.9, 9, 99)
  - New: `dzielnik = 10^ceil(max(0, log10(100/range)))`
  - Benefits: Self-documenting intent, handles edge cases, no magic numbers
  - **Bonus**: Fixed critical bug where range≥99 had no matching branch (undefined behavior)
- Use logarithms, power functions, and ceiling/floor for scaling operations
- Mathematical formulas often reveal edge case bugs in conditional logic
- See `DIVISOR_LOGIC_ANALYSIS.md` for detailed case study

**Error Handling**:
- Use `error('message')` instead of `quit` for validation failures
- Check variable existence with `exist()` before using optional features
- Validate mutually exclusive flags (e.g., learning modes)
- Validate input ranges (e.g., positive values where required)
- Provide helpful error messages indicating how to fix the issue
- Include current value in error messages for easier debugging

**Verification Flow**:
- First run (before learning): stores `logi_before_learning`
- Second run (after learning): uses `logi`
- Plots show Q-before vs PI vs Q-after comparison

## Scaling Convention

`f_skalowanie(max_in, min_in, max_out, min_out, value)` for bidirectional conversion:
- **Process ranges**: Error [-100,+100]%, Output [0,100]%, Control [0,100]%
- **Normalized**: Error [-1,+1], Output [0,1], Control [0,1]

**Important**: Plant gain `k` is defined in process units and used directly in f_obiekt (which operates in normalized space). This requires symmetric u/y scaling (wart_max_u = wart_max_y = 1) to maintain correct steady-state relationships. If asymmetric scaling is needed (e.g., wart_max_u=2 for 200% authority), gain must be adjusted: k_norm = k × (wart_max_y/wart_max_u).

## Design Insights

**Staged Learning**: Te reduction preserves Q-matrix while regenerating state/action spaces
- Small 0.1s steps prevent catastrophic forgetting
- `precision*2/Te` scaling maintains accuracy (see State Space Generation below)
- Continued learning adapts Q-values naturally

**State Space Generation**: Geometric distribution with Te-invariant precision
- **Smallest action**: `precision * 2 / Te`
- **States**: Midpoints between actions → smallest state = `precision / Te`
- **Mathematical proof of ±precision tolerance**:
  - State value: `s = de + (1/Te)·e`
  - In steady state (de=0): `s = e/Te`
  - Goal state boundaries: `(-precision/Te, +precision/Te]`
  - Condition: `-precision/Te < e/Te ≤ +precision/Te`
  - **Result**: `-precision < e ≤ +precision` (Te cancels!)
- **Key insight**: As Te changes during staged learning (20→2), state boundaries scale proportionally, but state value also scales by 1/Te, maintaining constant ±precision error tolerance
- **Performance**: Arrays preallocated for efficiency (avoid incremental growth)

**Reference Trajectory**: Always uses Te_bazowe (not current Te)
- Shows final performance goal consistently
- Enables meaningful before/after comparison
- Does NOT track disturbances (they show as deviations controllers must reject)

**Multi-Model**: 8 models share same Q2d implementation (1st→3rd order, nonlinear)

**Random Setpoint Generation**: Mathematical divisor calculation ensures consistent granularity
- Goal: Provide ~100 discrete random values regardless of range magnitude
- Formula: `dzielnik = 10^ceil(max(0, log10(100/range)))`
- Automatically adapts from tiny ranges (0.01) to large ranges (100+)
- Eliminates magic number thresholds and maintains code clarity

**Episode Length Strategy** (Intentional Asymmetry):
- **Load Disturbance Mode** (primary): Randomized episode length ~N(3000, 150)
  - Prevents overfitting to fixed episode duration
  - Improves robustness across different time horizons
  - Primary mode for industrial applications
- **Setpoint Change Mode** (legacy): Fixed episode length from config.m
  - Provides manual control for specific testing scenarios
  - Rarely used, benefits from predictable behavior
  - Intentional design choice, not a bug

**Exploration Logic** (m_losowanie_nowe.m):
- Dual-mode: Different range sources for f=0 vs f=1
- Mode 0 (staged learning): Range from neighboring states' best actions (adaptive)
- Mode 1 (projection): Range from current best action ± RD (fixed)
- Both modes enforce same-side matching: State > goal → Action > goal
- Constraints: Force exploration (≠best), protect goal action, directional (same-side)
- RD parameter (default 5) controls exploration width

## Critical Bug Fixes (2025-01-23/24)

**All experiments before 2025-01-23 must be re-run.** Five critical bugs were discovered and fixed:

### Bug #1: Exploration Constraint Inverted
**File**: m_losowanie_nowe.m
**Problem**: Used opposite-side logic instead of same-side matching
**Fix**: Changed to `(wyb_akcja3 > goal && state > goal) || (wyb_akcja3 < goal && state < goal)`
**Impact**: Enabled proper exploration in states 51-100 (previously blocked)

### Bug #2: Failed Exploration Q-Update
**File**: m_regulator_Q.m
**Problem**: When exploration failed 10 times, fell back to best action but still set `uczenie=1`
**Fix**: Set `uczenie=0` when falling back to exploitation
**Impact**: Broke positive feedback loop reinforcing wrong actions

### Bug #3: State-Action Temporal Mismatch
**Affects**: Both T0=0 and T0>0
**Problem**:
- T0>0: Action selection happened AFTER buffering → paired state(k) with action(k-1)
- T0=0: Used current action/reward with previous state → paired state(k-1) with action(k)
**Fix**:
- T0>0: Moved action selection BEFORE buffering (m_regulator_Q.m:86-147)
- T0=0: Save old_wyb_akcja, old_uczenie, old_R before selecting new (m_regulator_Q.m:87-94)
**Impact**: Now only Q(goal_state, goal_action) has high value

### Bug #4: Reward Temporal Mismatch
**Affects**: Both T0=0 and T0>0
**Problem**:
- T0>0: Reward for LEAVING goal instead of ARRIVING
- T0=0: Reward from iteration k used to update state-action from iteration k-1
**Fix**:
- T0>0: Reward if arrive OR (in goal with goal action) (m_regulator_Q.m:168-175)
- T0=0: Use old_R instead of current R (m_regulator_Q.m:95, 192)
**Impact**: Q(goal,goal) now converges toward 100

### Bug #5: Bootstrap Contamination (T0>0 only)
**Problem**: Q(goal,goal) DECREASED from 94.31 to 74.10 due to numerical drift causing next_state ≠ goal
**Fix**: Bootstrap override for goal→goal transitions (m_regulator_Q.m:178-187, 205, 217, 224)
```matlab
if old_stan_T0 == nr_stanu_doc && wyb_akcja_T0 == nr_akcji_doc
    stan_T0_for_bootstrap = nr_stanu_doc;  % Override to goal
else
    stan_T0_for_bootstrap = stan_T0;       % Use actual
end
```
**Impact**: Goal→Goal transitions: 100% (was 74.3%), Q(goal,goal) increases

### Bug #6: Same-Side Constraint Disabled in Projection Mode (2025-12-02)
**File**: m_losowanie_nowe.m
**Problem**: Lines 61-62 were commented out, disabling same-side matching constraint for f_rzutujaca_on=1
- Controller selected actions > 50 in states < 50 (wrong control direction)
- 9,007 constraint violations in 90k samples (10% violation rate)
- 2,949 violations during exploration (constraint should prevent)
- 6,058 violations during exploitation (Q-table corrupted by wrong explorations)
- **Result**: Controller stuck oscillating between states 45-47 with actions 47-51
**Fix**: Uncommented lines 61-62 to re-enable same-side matching (m_losowanie_nowe.m:60-62)
```matlab
if wyb_akcja3 ~= wyb_akcja && wyb_akcja3 ~= nr_akcji_doc && ...
       ((wyb_akcja3 > nr_akcji_doc && stan > nr_stanu_doc) || ...
        (wyb_akcja3 < nr_akcji_doc && stan < nr_stanu_doc))
```
**Impact**: Eliminates constraint violations, prevents oscillation around goal action

### Bug #7: Projection Threshold Disables Q-Learning (2025-12-02)
**File**: m_regulator_Q.m
**Problem**: Lines 257-270 disabled Q-learning when `abs(funkcja_rzutujaca) > 0.05`
- With Te=10, Ti=20: projection coefficient = 0.05
- Q-learning disabled when `abs(e) > 1%` (99% of training time)
- Controller operated almost entirely on projection term
- Minimal Q-learning refinement (only near setpoint)
**Fix**: Removed threshold check (m_regulator_Q.m:257-270 deleted)
**Impact**: Q-learning now active at all error levels
**Caveat**: Credit assignment mismatch remains with projection + dead time (see PROJECTION_FUNCTION.md)
- May cause Q-table corruption with large projection coefficients
- Recommend f_rzutujaca_on=0 (staged learning) for production use

### Results After Fixes
**T0=0, 50 epochs**:
- Q(50,50): 92.46 (converging to 100) ✓
- TD error: Decreasing ✓

**T0=4**: Expected to converge with Bug #5 fix

### Debug System
Enable in config.m: `debug_logging = 1`
**Tools**: diagnose_q_table.m, analyze_debug_logs.m (MATLAB)
**Fields**: DEBUG_old_state, DEBUG_old_action, DEBUG_R_buffered, DEBUG_stan_T0_for_bootstrap
**Performance**: ~600 MB for 2000 epochs, ~10-15% CPU overhead

## Publications

1. **2022**: "Implementation aspects..." - Introduces Q2d, validates on 2nd order
2. **ASC (Submitted)**: "Application of Self-Improving..." - Industrial focus, bumpless switching
3. **TIE (In prep)**: "PLC-based Implementation..." - Q2dPLC extensions, staged learning, PTC metric


## Contact

**Jakub Musiał** - Silesian University of Technology, Dept. of Automatic Control and Robotics
**Primary**: Prof. Jacek Czeczot (jacek.czeczot@polsl.pl)
