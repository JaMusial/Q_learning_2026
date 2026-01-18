# CLAUDE.md

Guidance for Claude Code when working with this Q2d Q-learning controller repository.

**IMPORTANT CODING RULES**:
- **NEVER** use Polish special characters (ą, ć, ę, ł, ń, ó, ś, ź, ż) in variable names - MATLAB compatibility issue
- Use English names for NEW variables when possible
- Existing Polish variable names (e.g., `epoka`, `stan`, `uchyb`) preserved for backward compatibility
- See Variable Glossary below for translations

## Research Context

**Problem**: 60% of industrial PID loops perform poorly. Retuning requires expert knowledge and is impractical at scale.

**Solution**: Self-improving Q-learning controller that:
- Bumplessly replaces existing PI controllers
- Starts with similar performance (Te=Ti, K_Q=K_PI, Q-matrix as identity)
- Gradually improves online through reinforcement learning
- Requires no process model (only existing PI tunings)

### Q2d Innovation

**Key Insight**: Merge error and derivative into single state based on first-order trajectory:
- **Target trajectory**: `ė + (1/Te)·e = 0` → `e(t) = e₀·exp(-t/Te)`
- **State definition**: `s = ė + (1/Te)·e` (when s≈0, system on trajectory)
- **Control law**: `U(t) = U(t-1) + K_Q·Ts·a(s)` where action `a(s)` from Q-matrix

**Two Operating Modes**:

1. **Staged Learning** (`f_rzutujaca_on=0`) - **RECOMMENDED**
   - Te reduces from Ti (20s) → Te_bazowe (2s) in 0.1s steps
   - Q-matrix preserved across Te changes
   - Better long-term learning and Q-table refinement
   - Works correctly with dead time compensation

2. **Projection Mode** (`f_rzutujaca_on=1`) - For paper comparison only
   - Te = Te_bazowe from start (fixed)
   - Projection term: `wart_akcji = stan_value - e·(1/Te - 1/Ti)` converts Q2d to PI-equivalent
   - Mathematically: `(de + e/Te) - e·(1/Te - 1/Ti) = de + e/Ti` (matches PI)
   - **Limitation**: Q-learning only effective near setpoint (states 49-51)
   - **Caution**: Complex interaction with dead time - see bugs.md for history

**Previous approach (Q3d)**: 3D Q-matrix with separate e and ė - too slow, abandoned.

## Quick Start

**Run**: `main.m` in MATLAB

**Configure** (`config.m`):
- `poj_iteracja_uczenia`: 1=single iteration mode, 0=full verification with metrics
- `max_epoki`: Training duration (500 for testing, 5000+ for full training)
- `nr_modelu`: Plant model 1-8 (1=1st order, 3=2nd order, 8=3rd order pneumatic)
- `f_rzutujaca_on`: 0=staged learning (recommended), 1=projection mode (paper comparison)
- `T0`: Plant dead time [s] (physical reality)
- `T0_controller`: Controller compensation [s] (0=no compensation, T0=matched)

**Performance**: ~30-35 seconds per 100 epochs

**Debug Mode**: Set `debug_logging = 1` in config.m (auto-exports JSON logs)

## Core Algorithm (m_regulator_Q.m)

**Initialization** (first 5 samples): `u = SP/k` to pre-fill buffers

**Q-Learning Loop**:
1. **State**: `s = ė + (1/Te)·e`, discretize to index
2. **Action**: ε-greedy selection (explore/exploit), forced a=0 at goal state
3. **Control**: `u += K_Q·a·dt` with saturation [0,100]%
4. **Simulate**: Plant response (dt=0.01s)
5. **Q-update**: `Q(s,a) += α·(R + γ·max(Q(s',·)) - Q(s,a))`
   - Reward: R=1 only at goal state (sparse reward)
   - Learning disabled when control saturates

**Key Features**:
- Dead time: Decoupled T0 (plant) and T0_controller (compensation) for robustness research
- Reference trajectory: Uses Te_bazowe for consistent visualization
- Projection function: Optional (mode-dependent, see above)

## Dead Time Compensation

**Design Philosophy**: Separate physical delay from controller strategy to enable robustness research.

**T0** (Plant Dead Time): Physical reality, always applied via `bufor_T0`

**T0_controller** (Controller Compensation):
- 0: No compensation (controller ignores dead time)
- T0: Perfect matched compensation
- ≠T0: Mismatched compensation (research scenarios)

**Delayed Credit Assignment** (T0_controller > 0):
Buffer state-action pairs, wait for action's effect to propagate before Q-update.

```matlab
% At iteration k:
if T0_controller > 0
    [old_stan_T0, bufor_state] = f_bufor(stan, bufor_state);
    [wyb_akcja_T0, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja);
    stan_T0 = stan;  % Current state is next_state for buffered pair

    if old_stan_T0 == nr_stanu_doc
        R = 1;  % Reward buffered state if it was in goal
    else
        R = 0;
    end
else
    % Standard one-step Q-learning
    old_stan_T0 = old_state;
    stan_T0 = stan;
    wyb_akcja_T0 = wyb_akcja;
end
```

**Why this works**: Action at k enters T0 delay buffer → effect visible at k+T0/dt+1 → Q-update credits action with correct consequence.

**Buffers NOT reset** between episodes (continuous learning, industrial operation simulation).

## Architecture

```
main.m:
  Init → Generate states/actions → Init Q-matrix →
  Loop: m_regulator_Q → m_zapis_logow → m_realizacja_trajektorii_v2 →
        m_warunek_stopu → m_reset → [Te adjustment if converged] →
  Verification → Visualization
```

**Staged Te Reduction**: MNK filter detects convergence → Te decreases 0.1s → state/action spaces regenerate.

## Key Parameters (config.m)

| Category | Parameter | Default | Description |
|----------|-----------|---------|-------------|
| **Q-Learning** | `alfa` | 0.1 | Learning rate |
| | `gamma` | 0.99 | Discount factor |
| | `eps_ini` | 0.3 | Initial exploration rate |
| | `RD` | 5 | Random deviation range |
| **Trajectory** | `Te_bazowe` | 2 | Goal time constant [s] |
| | `Te` | 20 | Initial (=Ti) [s] |
| | `kQ` | 1 | Controller gain (=Kp) |
| **State Space** | `dokladnosc_gen_stanu` | 0.5 | Precision (steady-state accuracy) |
| | `oczekiwana_ilosc_stanow` | 100 | Expected number of states |
| **Simulation** | `max_epoki` | 500 | Maximum training epochs |
| | `dt` | 0.1 | Sampling time [s] |
| | `uczenie_obciazeniowe` | 1 | Learn with disturbances |
| **Episode** | `mean_episode_length` | 3000 | Mean episode length [iterations] |
| | `episode_length_variance` | 300 | Std deviation [iterations] |
| **PI Baseline** | `Kp` | 1 | Proportional gain |
| | `Ti` | 20 | Integral time [s] |
| **Plant** | `nr_modelu` | 1-8 | Model selection |
| | `T` | varies | Time constant(s) [s] |
| | `k` | varies | Process gain |
| | `T0` | 0 | Plant dead time [s] |
| | `T0_controller` | 0 | Controller compensation [s] |

## Plant Models (f_obiekt.m)

| Model | Description | Transfer Function |
|-------|-------------|-------------------|
| 1 | 1st order | k/(T·s+1) |
| 3 | 2nd order | k/[(T₁·s+1)(T₂·s+1)] |
| 5 | 3rd order | k/[(T₁·s+1)(T₂·s+1)(T₃·s+1)] |
| 8 | 3rd order pneumatic | T=[2.34 1.55 9.38], k=0.386 |

Models 2,4 deprecated. Add dead time via T0 parameter.

## File Organization

| Category | Files | Purpose |
|----------|-------|---------|
| **Main** | main.m, config.m | Entry point, configuration |
| **Controllers** | m_regulator_Q.m, m_regulator_PID.m | Q2d and PI implementations |
| **Init/Reset** | m_inicjalizacja.m, m_reset.m, m_inicjalizacja_buforov.m | Setup and episode management |
| **State/Action** | f_generuj_stany_v2.m, f_find_state.m, f_best_action_in_state.m, f_generuj_macierz_Q_2d.m | Space generation and lookup |
| **Learning** | m_warunek_stopu.m, m_realizacja_trajektorii_v2.m, m_losowanie_nowe.m | Episode management, exploration |
| **Logging/Viz** | m_zapis_logow.m, m_rysuj_wykresy.m, m_rysuj_mac_Q.m | Data recording and plotting |
| **Verification** | m_eksperyment_weryfikacyjny.m, f_licz_wskazniki.m | Q vs PI comparison, metrics |
| **Utilities** | f_skalowanie.m, f_obiekt.m, f_bufor.m | Scaling, plant simulation, buffers |
| **Debug** | diagnose_q_table.m, analyze_debug_logs.m | Q-table diagnostics |

## Coding Standards

### Documentation
- File headers: PURPOSE, INPUTS, OUTPUTS, NOTES, SIDE EFFECTS
- Section dividers: `%% ======...`
- Comments explain WHY, not just WHAT
- See `m_reset.m`, `m_warunek_stopu.m` for reference style

### Magic Numbers - NEVER hard-code!
**Configurable parameters** → Move to `config.m`:
```matlab
disturbance_range = 0.5;        % Disturbance range: ±0.5 at 3-sigma
mean_episode_length = 3000;     % Mean episode length [iterations]
```

**Mathematical constants** → Named with explanation:
```matlab
SIGMA_DIVISOR = 3;              % Statistical constant (3-sigma rule)
SAFETY_MARGIN = 10;             % Array preallocation buffer
```

### Performance - CRITICAL
**Array preallocation** (avoid incremental growth):
```matlab
% Good
arr = zeros(1, max_size); idx = 0;
idx = idx + 1; arr(idx) = value;

% Bad (reallocates memory each time)
arr(end+1) = value;
```

**Trim when done**: `arr = arr(1:idx);`

**Wrap calculations**: `round()` to avoid floating-point indices

### Variable Naming
**CRITICAL**: No Polish special characters in variable names!

**Common Variable Glossary** (Polish → English):
- `epoka` → epoch
- `stan` / `old_stan` → state / old_state
- `wyb_akcja` → selected_action
- `uchyb` → error
- `dokladnosc` → precision
- `bufor` → buffer
- `iteracja_uczenia` → learning_iteration
- `maksymalna_ilosc_iteracji_uczenia` → max_episode_length
- `idx_*` → array index counters (for preallocation)

### Mathematical Approaches
Prefer formulas over multi-branch conditionals:
```matlab
% Good: Self-documenting, handles edge cases
dzielnik = 10^ceil(max(0, log10(100/range)));

% Bad: Magic numbers, missed edge case (range≥99)
if range < 0.09
    dzielnik = 1000;
elseif range < 0.9
    dzielnik = 100;
...
```

### Error Handling
- Use `error('message')` not `quit`
- Validate mutually exclusive flags
- Check variable existence: `exist()`, `isfield()`
- Include current value in error messages

### Visualization
- Theme-neutral colors (RGB arrays, never 'w' or 'k')
- Use `figure()` without Position for tabbed interface
- Dynamic sizing: `size()`, `length()` instead of hardcoded dimensions

### Python Tools
**Before creating Python scripts**:
```bash
pip list | grep -iE "package1|package2"  # Check if installed
```
**If needed package is required ask user to install it and update this file.**

**Available packages**: numpy (1.26.4), pandas (2.1.4), matplotlib (3.6.3), scipy (1.11.4), seaborn (0.13.2), tqdm

## Design Insights

**Staged Learning**: Te reduction preserves Q-matrix while regenerating state/action spaces
- Small 0.1s steps prevent catastrophic forgetting
- `precision*2/Te` scaling maintains Te-invariant ±precision error tolerance
- Continued learning adapts Q-values naturally

**State Space Generation**: Geometric distribution
- **Smallest action**: `precision * 2 / Te`
- **States**: Midpoints between actions → smallest state = `precision / Te`
- **Te-invariant tolerance**: As Te changes, state boundaries scale proportionally, but state value `s = de + e/Te` also scales, maintaining constant ±precision error tolerance

**Reference Trajectory**: Always uses Te_bazowe (not current Te)
- Shows final performance goal consistently
- Enables meaningful before/after comparison
- Does NOT track disturbances (they show as deviations)

**Random Setpoint Generation**: Mathematical divisor ensures ~100 discrete values
- Formula: `dzielnik = 10^ceil(max(0, log10(100/range)))`
- Adapts automatically from tiny (0.01) to large (100+) ranges

**Episode Length Strategy** (Intentional Asymmetry):
- **Load Disturbance Mode**: Randomized ~N(3000, 150) - prevents overfitting
- **Setpoint Change Mode**: Fixed length - manual control for testing

**Exploration Logic** (m_losowanie_nowe.m):
- **Same-side constraint**: State > goal → Action > goal (prevents wrong control direction)
- **Mode 0** (staged): Range from neighboring states' best actions (adaptive)
- **Mode 1** (projection): Range from current best ± RD (fixed)
- RD parameter (default 5) controls exploration width

**On-Trajectory Problem** (Critical for Projection Mode):
- When system follows trajectory: `de = -e/Te` → `s = 0` (goal state) regardless of error magnitude!
- Example: e=30%, de=-6, Te=5 → s = -6 + 30/5 = 0 (at goal!)
- **Consequence**: Identity Q-matrix returns action=0, controller does nothing
- **Solution**: Projection must be applied based on error magnitude, not state

**Scaling Convention**: `f_skalowanie(max_in, min_in, max_out, min_out, value)`
- Process ranges: Error [-100,+100]%, Output/Control [0,100]%
- Normalized: Error [-1,+1], Output/Control [0,1]
- **Important**: Plant gain `k` defined in process units, requires symmetric u/y scaling

## Debug Tools

**MATLAB**: `diagnose_q_table.m`, `analyze_debug_logs.m`

**Python** (Claude_tools/): Requires `debug_logging = 1` in config.m
- `summary_report.py` - Full diagnostic
- `compare_logs.py` - Before vs After comparison
- See `Claude_tools/TOOLS.md` for details

**Debug fields**: DEBUG_old_state, DEBUG_old_action, DEBUG_R_buffered, DEBUG_stan_T0_for_bootstrap

**Performance cost**: ~600 MB for 2000 epochs, ~10-15% CPU overhead

## Critical Bug History

**See `bugs.md` for detailed history and root cause analysis.**

Key lessons learned:
1. Same-side constraint essential for directional control
2. Projection mode has complex interaction with Q-learning (use staged learning instead)
3. Temporal alignment critical for proper credit assignment
4. Continuous state_value needed for projection (not discretized action_value)
5. Goal state requires special handling in projection mode

## Verification Flow

1. **Before learning**: Run verification → stores `logi_before_learning`
2. **Training**: Q-learning with staged Te reduction
3. **After learning**: Run verification → stores `logi_after_learning`
4. **Plots**: Q-before vs PI vs Q-after comparison

## Workflows

**Standard Experiment**:
1. Edit `config.m`: Set `max_epoki`, `nr_modelu`, plant parameters
2. Run `main.m`
3. Monitor: Epoch progress, stabilization %, current Te
4. View plots: Performance comparison, trajectory, Q-matrix evolution

**Change Plant Model**:
```matlab
T = [5 2]; nr_modelu = 3;  % 2nd order
% May adjust: Te_bazowe, Ti, Kp
```

## Publications

1. **2022**: "Implementation aspects..." - Introduces Q2d, validates on 2nd order
2. **ASC (Submitted)**: "Application of Self-Improving..." - Industrial focus, bumpless switching
3. **TIE (In prep)**: "PLC-based Implementation..." - Q2dPLC extensions, staged learning, PTC metric
