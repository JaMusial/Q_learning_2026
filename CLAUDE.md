# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Research Context and Motivation

### The Industrial Problem
**60% of industrial PID control loops perform poorly** due to inadequate tuning. Retuning requires expert knowledge, experimental data, and is often impractical in factories with hundreds of simultaneous control loops. This research develops a **self-improving Q-learning controller** that can:
- **Bumplessly replace** existing poorly-tuned PI controllers
- **Start with similar performance** to the existing controller
- **Gradually improve online** through reinforcement learning during normal operation
- Work **without any process model** or knowledge of process dynamics

### Research Evolution: Q3d → Q2d → Q2dPLC

#### **Q3d (Initial Approach - Abandoned)**
- Used **3-dimensional Q-matrix** with separate state spaces for error `e` and derivative `de`
- **Problems**: Extremely slow learning, large memory requirements, too many tuning parameters
- **Not practical** for industrial PLC implementation

#### **Q2d (Current Implementation - This Codebase)**
The breakthrough came from **merging error and derivative into a single state** based on the **first-order target trajectory**:

**Target Trajectory**: `F(e,ė) = e + (1/Te)·e = 0`

**Key Innovations**:
- **2D Q-matrix** by defining state as: `s = e + (1/Te)·e`
- **Similarity to PI controller**:
  - PI: `ΔU_PI = K_PI · Ts · (e + (1/TI)·e)`
  - Q2d: `ΔU_Q = K_Q · Ts · a` where action `a` depends on state `s`
- **Bumpless initialization**: Setting `K_Q = K_PI`, `Te = TI`, and Q-matrix as identity matrix produces identical behavior to existing PI controller
- **Exponential state distribution**: Denser states near setpoint for accurate control
- **No model required**: Only needs existing PI tunings (K_PI, T_I)

#### **Q2dPLC (Future Direction - Not Yet Implemented)**
Extension of Q2d for higher-order processes and PLC implementation:
- **Staged learning**: Te gradually decreases from TI to Te_goal
- **Reversed generation**: Actions generated first (based on U_max), then states
- **Geometric action distribution**: Small actions for precision, large for fast response
- **PLC library function block** with normalized I/O
- **Percentage Trajectory Completion (PTC)** metric for learning supervision

### Core Theoretical Foundation

**Target Trajectory**: The closed-loop system should follow a first-order reference trajectory:
```
F(e,ė) = e + (1/Te)·e = 0
```
where:
- `e = SP - y` (control error)
- `ė = de/dt` (error derivative)
- `Te` (trajectory time constant) defines desired closed-loop speed

**State Definition**: The continuous state value is:
```
s = e + (1/Te)·e
```
This value is discretized into state intervals, with the target state being `s ≈ 0`.

**Control Law**: Incremental form similar to PI controller:
```
U_Q(t) = U_Q(t-1) + K_Q · Ts · a(s)
```
where action `a(s)` is selected from the Q-matrix based on current state `s`.

## Project Overview

This is a MATLAB implementation of the **Q2d Q-learning controller** for adaptive control of dynamic processes. The implementation validates the Q2d methodology through simulation on various plant models, particularly focusing on **3rd-order pneumatic systems** which represent realistic industrial processes with complex dynamics.

## How to Run

### Main Execution
- **Standard mode**: Run `main.m` in MATLAB
- The code has been optimized for the critical bottleneck (dynamic array growth in trajectory realization)

### Configuration
- Edit `m_inicjalizacja.m` to change simulation parameters
- Set `poj_iteracja_uczenia = 1` for single iteration learning mode
- Set `poj_iteracja_uczenia = 0` for full experimental verification with metrics
- Set `max_epoki = 500` to control training duration

### Expected Performance
- **~30-35 seconds per 100 epochs** on typical hardware
- Main bottleneck is f_skalowanie() called 9.75M times (inherent MATLAB limitation)
- Further optimization would require MEX (C) implementation or migration to Python/NumPy

## Core Architecture

### Main Loop Structure
The learning process follows this flow:

1. **Initialization** (`m_inicjalizacja.m`, `m_inicjalizacja_buforov.m`)
   - Sets simulation parameters (max_epoki, learning rate, exploration rate)
   - Defines plant model (8 different models available)
   - Initializes Q-learning parameters (alfa, gamma, epsilon)
   - Sets up scaling parameters for normalization

2. **State/Action Generation** (`f_generuj_stany_v2.m`)
   - Generates discretized state space based on exponential distribution
   - Creates action space symmetric around zero
   - Number of states controlled by `oczekiwana_ilosc_stanow` and `dokladnosc_gen_stanu`

3. **Q-matrix Initialization** (`f_generuj_macierz_Q_2d.m`)
   - Creates 2D Q-learning matrix (states × actions)
   - Can be initialized as identity matrix for PI-like behavior

4. **Learning Episodes** - Main while loop (`epoka <= max_epoki`):
   - **Q-regulator step** (`m_regulator_Q.m`): Selects and applies actions
   - **Logging** (`m_zapis_logow.m`): Records state, action, reward, etc.
   - **Trajectory metrics** (`m_realizacja_trajektorii_v2.m`): Computes percentage of trajectory realization
   - **Stopping condition** (`m_warunek_stopu.m`): Checks if episode should end
   - **Reset** (`m_reset.m`): Randomizes disturbance/setpoint for next episode
   - **Adaptive Te adjustment**: Reduces Te when learning converges (controlled by MNK filter)

5. **Verification** (`m_eksperyment_weryfikacyjny.m`)
   - Runs validation experiments comparing Q-controller vs PID
   - Computes performance indices (IAE, overshoot, settling time)

6. **Visualization** (`m_rysuj_wykresy.m`, `m_rysuj_mac_Q.m`)
   - Plots control performance
   - Visualizes Q-matrix evolution

### Q-Learning Controller (`m_regulator_Q.m`)

The core algorithm implements Q2d methodology:

#### **Manual Control Phase** (first ~5 samples)
- Initializes system with open-loop control: `u = y/k`
- Establishes initial conditions

#### **Standard Q-Learning Phase**
1. **State computation**:
   ```matlab
   e = SP - y                    % Control error
   de = (e - e_prev) / dt        % Error derivative
   stan_value = de + (1/Te) * e  % Q2d state definition
   stan = f_find_state(stan_value, stany)  % Discretize
   ```

2. **Q-learning update** (if learning enabled):
   ```matlab
   Q_update = alfa * (R + gamma * maxS - Q_2d(old_state, old_action))
   Q_2d(old_state, old_action) += Q_update
   ```

3. **Action selection** (epsilon-greedy):
   - If `epsilon >= random()`: **Exploration** - random action with constraints (`m_losowanie_nowe.m`)
   - Else: **Exploitation** - best action from Q-matrix (`f_best_action_in_state.m`)
   - If in target state (`stan == nr_stanu_doc`): Always select zero action

4. **Control signal calculation**:
   ```matlab
   u_increment = K_Q * action * dt
   u = u + u_increment
   ```
   with saturation at `[0, 100]%`

5. **Plant simulation**:
   - Internal loop at 0.01s timestep for accuracy
   - Handles delay buffers if `T0 > 0`
   - Supports 8 different plant models via `f_obiekt.m`

#### **Key Features**
- **Projection function** (optional, `f_rzutujaca_on`): Adds `e·(1/Te - 1/Ti)` term for stability
- **Delay compensation**: Buffers for systems with time delay `T0`
- **Reference trajectory tracking**: Maintains `e_ref`, `y_ref` for comparison
- **Learning control**: Disables learning when control saturates

### State/Action Space Generation

#### **State Space**
States are generated by discretizing the continuous state value `s = e + (1/Te)·e`:
- **Exponential distribution** controlled by parameter `τ` (tau)
- Denser spacing near `s = 0` (target state) for accurate setpoint tracking
- Symmetric around target state
- Merged intervals that are too close (< precision threshold)

#### **Action Space**
Actions represent control signal increments:
- **Symmetric distribution** around zero action ("do nothing")
- Exponentially spaced for coverage of small (precise) and large (fast) corrections
- Mapped to discrete action indices for Q-matrix

#### **Key Indices**
- `nr_stanu_doc`: Index of target state (s ≈ 0)
- `nr_akcji_doc`: Index of target action (a = 0, "do nothing")

### Dynamic Plant Models (`f_obiekt.m`)

Supports 8 different plant types selected via `nr_modelu`:

1. **1st order inertia**: `G(s) = k/(T·s + 1)`
2. **DEPRECATED - Alias for model 1** (use model 1 with T0 > 0 instead)
3. **2nd order inertia**: `G(s) = k/[(T1·s + 1)(T2·s + 1)]`
4. **DEPRECATED - Alias for model 3** (use model 3 with T0 > 0 instead)
5. **3rd order inertia**: `G(s) = k/[(T1·s + 1)(T2·s + 1)(T3·s + 1)]`
6. **Pneumatic (nonlinear)**: Complex 3rd order with nonlinear elements
7. **Oscillatory 2nd order**: Tested for T=[5 2 1]
8. **3rd order pneumatic** (default): Real pneumatic actuator model with T=[2.34 1.55 9.38], k=0.994×0.968×0.4

**Dead Time Handling**: All models support dead time by setting `T0 > 0` in `m_inicjalizacja.m`. Dead time is implemented externally by delaying the control signal before it enters the plant, giving transfer function: `G_total(s) = e^(-T0·s) · G_plant(s)`

**Current configuration**: Model 8 (3rd order pneumatic system), T0 = 0 (no delay)

### Adaptive Te Adjustment

The system implements **staged learning** by gradually reducing Te:
- **Initial**: `Te = Ti` (matches existing PI controller integral time)
- **Target**: `Te = Te_bazowe` (typically 2 seconds for faster response)
- **Trigger**: When MNK filter metrics indicate convergence:
  ```matlab
  mean(a_mnk_mean) > 0.2 &&
  mean(b_mnk_mean) in (-0.05, 0.05) &&
  flaga_zmiana_Te == 1
  ```
- **Step**: `Te = Te - 0.1`
- **Effect**: Regenerates state/action spaces for new trajectory

This allows the controller to gradually improve closed-loop performance as learning progresses.

## Key Files

### Main Scripts
- `main.m` - Entry point for Q2d learning experiments

### Controllers
- `m_regulator_Q.m` - **Q2d controller implementation** (core algorithm)
- `m_regulator_PID.m` - PID controller for comparison/verification
- `f_dyskretny_PID.m` - Discrete PID implementation

### Initialization & Configuration
- `m_inicjalizacja.m` - **Simulation parameters** (Q-learning settings, plant model, scaling, dead time buffers)
- `m_inicjalizacja_buforov.m` - Initializes logging vectors
- `m_reset.m` - Resets episode (randomizes disturbance or setpoint)

### State/Action Management
- `f_generuj_stany_v2.m` - Generates discretized state and action spaces
- `f_find_state.m` - Maps continuous state to discrete state index (vectorized for speed)
- `f_best_action_in_state.m` - Finds optimal action from Q-matrix for given state
- `f_generuj_macierz_Q_2d.m` - Initializes 2D Q-matrix

### Exploration/Exploitation
- `m_losowanie_nowe.m` - **Constrained random action selection** during exploration
- `m_losowanie_stare.m` - Old randomization method (not used)

### Learning Management
- `m_warunek_stopu.m` - Stopping condition (checks stabilization or max iterations)
- `m_realizacja_trajektorii_v2.m` - **Trajectory realization percentage** computation
- `m_norma_macierzy.m` - Computes Q-matrix norm for convergence monitoring

### Logging and Visualization
- `m_zapis_logow.m` - Logs Q-controller and reference trajectory data
- `m_rysuj_wykresy.m` - Plots control performance, actions, trajectory realization
- `m_rysuj_mac_Q.m` - Visualizes Q-matrix as 3D mesh plot

### Verification
- `m_eksperyment_weryfikacyjny.m` - Runs validation experiments
- `f_licz_wskazniki.m` - Computes performance indices (IAE, overshoot, settling time)

### Utility Functions
- `f_skalowanie.m` - **Bidirectional scaling** between physical and normalized ranges
- `f_obiekt.m` - Plant model simulation (8 different models, dead time handled externally)
- `f_bufor.m` - FIFO buffer for dead time compensation

## Important Parameters

### Q-Learning Parameters (in `m_inicjalizacja.m`)

**Learning**:
- `alfa = 0.1` - Learning rate (how quickly Q-matrix is updated)
- `gamma = 0.99` - Discount factor (importance of future rewards)
- `eps_ini = 0.3` - Initial exploration rate (probability of random action)
- `nagroda = 1` - Reward for reaching target state

**Exploration**:
- `RD = 5` - Random deviation range for constrained exploration
- `max_powtorzen_losowania_RD = 10` - Max attempts to find valid random action

**Controller Gain**:
- `kQ = Kp = 1` - Q-controller gain (initialized from PI controller)

**Trajectory**:
- `Te_bazowe = 2` - Target trajectory time constant (goal)
- `Te = Ti = 20` - Initial trajectory time constant (starts at PI integral time)

**State Space**:
- `dokladnosc_gen_stanu = 0.5` - State generation precision (determines steady-state accuracy)
- `oczekiwana_ilosc_stanow = 100` - Expected number of states (actual may vary after merging)

**Optional Features**:
- `f_rzutujaca_on = 0` - Enable/disable projection function
- `reakcja_na_T0 = 0` - Enable/disable delay buffer response

### Simulation Parameters

**Training Duration**:
- `max_epoki = 500` - Maximum training epochs
- `maksymalna_ilosc_iteracji_uczenia = 4000` - Max iterations per epoch (randomized around µ=3000)
- `oczekiwana_ilosc_probek_stabulizacji = 20` - Samples required to declare stabilization

**Timing**:
- `dt = 0.1` - Sampling time for Q-controller and logging
- Internal plant simulation: 0.01s (10x finer for accuracy)

**Learning Modes**:
- `uczenie_obciazeniowe = 1` - Learn with **load disturbances** (d randomized)
- `uczenie_zmiana_SP = 0` - Learn with **setpoint changes** (SP randomized)
- Only one mode should be active

**Disturbance Settings** (if uczenie_obciazeniowe = 1):
- `zakres_losowania_zakl_obc = 0.5` - Range for load disturbance randomization
- Disturbance `d` drawn from normal distribution: µ=0, σ=0.167

### PI Controller Parameters (for comparison)
- `Kp = 1` - Proportional gain
- `Ti = 20` - Integral time
- `Td = 0` - Derivative time (not used)
- `dt_PID = 0.1` - PID sampling time

### Plant Parameters

**Currently Selected: Model 8** (3rd order pneumatic system)
- `nr_modelu = 8`
- `T = [2.34 1.55 9.38]` - Time constants [s]
- `k = 0.994 × 0.968 × 0.4 = 0.386` - Overall gain
- `Ks = tf(0.994,[2.34 1])*tf(0.968,[1.55 1])*tf(0.4,[9.38 1])`

**Other Settings**:
- `SP_ini = 50` - Initial setpoint [%]
- `T0 = 0` - Time delay (disabled)
- `dist_on = 0` - Measurement noise (disabled)

### Scaling Convention

The system uses bidirectional scaling via `f_skalowanie(max_in, min_in, max_out, min_out, value)`:

**Process Variable Ranges** (proc_* variables):
- Error: `[-100%, +100%]`
- Output: `[0%, 100%]`
- Control: `[0%, 100%]`

**Normalized Ranges** (wart_* variables):
- Error: `[-1, +1]`
- Output: `[0, 1]`
- Control: `[0, 2]` (allows 200% control authority internally)

**Usage**:
```matlab
% Scale to normalized
e_norm = f_skalowanie(wart_max_e, wart_min_e, proc_max_e, proc_min_e, e);

% Scale back to physical
e_phys = f_skalowanie(proc_max_e, proc_min_e, wart_max_e, wart_min_e, e_norm);
```

## Common Workflows

### Running a Standard Training Experiment
1. Configure parameters in `m_inicjalizacja.m`:
   - Set `max_epoki` (typically 500 for testing, 5000+ for full training)
   - Choose learning mode: `uczenie_obciazeniowe` or `uczenie_zmiana_SP`
   - Select plant model via `nr_modelu` and corresponding `T`, `k`

2. Run `main.m` in MATLAB

3. Monitor console output showing:
   - Epoch progress every 100 epochs
   - Time per 100 epochs (~30-35 seconds)
   - Percentage of epochs ending in stabilization
   - Current Te value

4. Results are plotted automatically:
   - Control performance (Q vs PI vs Reference)
   - Trajectory realization percentage
   - Q-matrix evolution

### Testing Different Plant Models
1. Edit `m_inicjalizacja.m`:
   ```matlab
   % Example: 2nd order system
   T = [5 2];
   nr_modelu = 3;
   Ks = tf(1,[5 1])*tf(1,[2 1]);
   ```

2. May need to adjust:
   - `Te_bazowe` (smaller for faster systems)
   - `Ti`, `Kp` (PI tunings to match system dynamics)
   - `maksymalna_ilosc_iteracji_uczenia` (longer for slower systems)

3. Run `main.m`

### Analyzing Q-Matrix Convergence
- Q-matrix norm sampled every `probkowanie_norma_macierzy = 100` epochs
- View evolution: `plot(max_macierzy_Q)`
- Enable animation: `gif_on = 1` in `m_inicjalizacja.m`
- Norm computed in `m_norma_macierzy.m`

### Comparing Q-Learning vs PI Performance
After training completes, `m_eksperyment_weryfikacyjny.m` automatically:
1. Runs verification experiments (default: 600 seconds)
2. Tests both Q-controller and PI controller on same scenarios
3. Computes metrics: IAE, overshoot, settling time
4. Results stored in: `IAE_wek`, `maks_przereg_wek`, `czas_regulacji_wek`

## Performance Notes

### Current Bottlenecks
Profiling shows the main performance limitations:
1. **f_skalowanie()**: 6.43s self-time (9.75M calls) - scaling function overhead
2. **f_obiekt()**: 18.52s (1.58M calls) - plant simulation
3. **m_warunek_stopu()**: 13.45s - stopping condition checks
4. **mean()**: 10.77s - MATLAB built-in statistics

**Optimization attempts showed**: MATLAB's interpreted nature makes millions of function calls inherently slow. Further speedup (10-100x) would require:
- MEX (C/C++) implementation of critical functions
- Python + NumPy for better vectorization
- Julia for JIT compilation

### Minimal Optimizations Applied
The codebase includes one critical optimization:
- **Preallocated `realizacja_traj_epoka` array** in `m_inicjalizacja.m` (line 133)
- Uses indexed access instead of dynamic growth (`end+1`)
- Index reset in `m_reset.m` for each epoch

**Result**: Marginal improvement (~10% faster) without added complexity

## Research Publications

This codebase supports three published/submitted articles:

1. **"Implementation aspects of Q-learning controller for a class of dynamical processes"** (2022)
   - Introduces Q2d approach
   - Shows 2D Q-matrix reduces learning time compared to Q3d
   - Validates on 2nd order systems

2. **"Application of Self-Improving Q-learning Controller for a Class of Dynamical Processes: Implementation Aspects"** (Submitted to ASC)
   - Comprehensive Q2d methodology
   - Practical industrial focus
   - Addresses 60% poor PID loop performance problem
   - Bumpless switching without process model

3. **"PLC-based Implementation of Self-improving Q-learning Controller and Validation for Higher-Order Processes"** (In preparation for TIE)
   - Extends Q2d to Q2dPLC
   - Staged learning for higher-order processes
   - PLC function block implementation
   - Percentage Trajectory Completion (PTC) metric

## Future Directions (Q2dPLC)

The next research phase will implement Q2dPLC extensions:
- [ ] Staged Te reduction from TI to Te_goal
- [ ] Reversed action/state generation (actions first)
- [ ] Geometric action distribution
- [ ] PLC library function block
- [ ] Normalized I/O (0-100%)
- [ ] PTC-based learning supervision
- [ ] Validation on real industrial hardware

## Contact

For questions about this research:
- **Jakub Musiał** - Silesian University of Technology, Department of Automatic Control and Robotics
- **Primary contact**: Prof. Jacek Czeczot (jacek.czeczot@polsl.pl)
