# CLAUDE.md

Guidance for Claude Code when working with this Q2d Q-learning controller repository.

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

**Configure** (`m_inicjalizacja.m`):
- `poj_iteracja_uczenia`: 1=single iteration mode, 0=full verification with metrics
- `max_epoki`: Training duration (500 for testing, 5000+ for full training)
- `nr_modelu`: Plant model 1-8 (1=1st order, 3=2nd order, 8=3rd order pneumatic)

**Performance**: ~30-35 seconds per 100 epochs. Bottleneck: f_skalowanie() called 9.75M times.

## Core Algorithm (m_regulator_Q.m)

**Manual Control** (first 5 samples): `u = SP/k` to initialize toward setpoint

**Q-Learning Phase**:
1. **State**: `s = ė + (1/Te)·e`, discretize to index
2. **Q-update**: `Q(s,a) += α·(R + γ·max(Q(s',·)) - Q(s,a))`
3. **Action**: ε-greedy (explore/exploit), always a=0 at target state
4. **Control**: `u += K_Q·a·dt` with saturation [0,100]%
5. **Simulate**: Plant at 0.01s timestep

**Key Features**:
- Projection function: `e·(1/Te - 1/Ti)` for stability (optional)
- Dead time: External delay buffers (T0 > 0)
- Reference trajectory: Uses Te_bazowe (goal) for consistent visualization
- Learning disabled when control saturates

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
| **PI (comparison)** | | |
| `Kp` | 1 | Proportional gain |
| `Ti` | 20 | Integral time [s] |
| **Plant** | | |
| `nr_modelu` | 1-8 | Model selection (1=1st order, 8=3rd order pneumatic) |
| `T` | varies | Time constant(s) [s] |
| `k` | varies | Process gain |
| `T0` | 0 | Dead time [s] |

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

## Workflows

**Standard Experiment**:
1. Edit `m_inicjalizacja.m`: Set `max_epoki`, `uczenie_obciazeniowe`, `nr_modelu`, `T`, `k`
2. Run `main.m`
3. Monitor: Epoch progress, stabilization %, current Te
4. View plots: Q vs PI vs Reference, trajectory realization, Q-matrix evolution

**Change Plant Model**:
```matlab
% Example: 2nd order
T = [5 2]; nr_modelu = 3; Ks = tf(1,[5 1])*tf(1,[2 1]);
% May adjust: Te_bazowe, Ti, Kp, maksymalna_ilosc_iteracji_uczenia
```

## Coding Standards

**Performance**:
- Preallocate arrays, use indexed access with counters (`logi_idx`)
- Trim arrays when done (`trim_logi` flag)
- Wrap size calculations in `round()`

**Visualization**:
- Theme-neutral colors (RGB arrays, never 'w' or 'k')
- Use `figure()` without Position for tabbed interface
- Check variable existence: `exist()`, `isfield()`, `~isempty()`
- Dynamic sizing: `size()`, `length()` instead of hardcoded dimensions

**Verification Flow**:
- First run (before learning): stores `logi_before_learning`
- Second run (after learning): uses `logi`
- Plots show Q-before vs PI vs Q-after comparison

## Scaling Convention

`f_skalowanie(max_in, min_in, max_out, min_out, value)` for bidirectional conversion:
- **Process ranges**: Error [-100,+100]%, Output [0,100]%, Control [0,100]%
- **Normalized**: Error [-1,+1], Output [0,1], Control [0,2] (allows 200% authority)

## Design Insights

**Staged Learning**: Te reduction preserves Q-matrix while regenerating state/action spaces
- Small 0.1s steps prevent catastrophic forgetting
- `precision*2/Te` scaling maintains accuracy
- Continued learning adapts Q-values naturally

**Reference Trajectory**: Always uses Te_bazowe (not current Te)
- Shows final performance goal consistently
- Enables meaningful before/after comparison
- Does NOT track disturbances (they show as deviations controllers must reject)

**Multi-Model**: 8 models share same Q2d implementation (1st→3rd order, nonlinear)

## Publications

1. **2022**: "Implementation aspects..." - Introduces Q2d, validates on 2nd order
2. **ASC (Submitted)**: "Application of Self-Improving..." - Industrial focus, bumpless switching
3. **TIE (In prep)**: "PLC-based Implementation..." - Q2dPLC extensions, staged learning, PTC metric


## Contact

**Jakub Musiał** - Silesian University of Technology, Dept. of Automatic Control and Robotics
**Primary**: Prof. Jacek Czeczot (jacek.czeczot@polsl.pl)
