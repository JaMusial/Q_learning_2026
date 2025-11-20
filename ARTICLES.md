# ARTICLES.md

Comprehensive analysis of published and submitted Q-learning controller research articles for future reference.

## Overview

This document summarizes three key publications on Q-learning-based self-improving controllers:
1. **2022 Conference Paper**: Initial Q2d concept introduction
2. **ASC Submission** (rev2): Comprehensive Q2d methodology with experimental validation
3. **TIE Preparation**: Q2dPLC extension for higher-order processes and PLC implementation

---

## Article 1: Implementation Aspects (2022 Conference)

**Title**: "Implementation aspects of Q-learning controller for a class of dynamical processes"

**Authors**: Jakub Musiał, Krzysztof Stebel, Jacek Czeczot
**Affiliation**: Silesian University of Technology, Department of Automatic Control and Robotics

### Key Contributions

1. **Q3d → Q2d Breakthrough**: Reduced Q-matrix from 3D to 2D while preserving error derivative information
2. **State Merging**: Combined error `e` and derivative `ė` into single state: `s = ė + (1/Te)·e`
3. **Simplified Initialization**: Q-matrix as identity matrix ensures PI-like initial behavior
4. **Parameter Reduction**: From 4 parameters (Q3d) to 2 parameters (Q2d)
5. **Learning Acceleration**: 3× faster learning compared to Q3d

### Theoretical Foundation

**Target Trajectory**: First-order closed-loop dynamics
```
F(e,ė) = ė + (1/Te)·e = 0  →  e(t) = e₀·exp(-t/Te)
```

**Control Law Similarity**:
- **PI**: `ΔU_PI = K_PI · Ts · (e + (1/TI)·ė)`
- **Q2d**: `ΔU_Q = K_Q · Ts · a(s)` where `s = ė + (1/Te)·e`

Setting `K_Q = K_PI`, `Te = TI`, Q-matrix = identity → identical initial behavior

### State/Action Generation

**Exponential Discretization**:
- Parameter `τ` defines decay ratio (not Te-dependent)
- Denser states near goal for accurate setpoint tracking
- Parameter `precision` defines steady-state accuracy
- Parameter `e_max` defines expected error range

**Procedure**:
1. Generate exponential trajectory: `e(i) = e_max · exp(-t/τ)`, `ė(i) = de/dt`
2. Compute state boundaries: `s(k) = ė(i) + (1/Te)·e(j)` for all i,j combinations
3. Merge close boundaries (< precision threshold) → N states
4. Extend symmetrically for negative values → (2N-1) states total
5. Q-matrix size: (2N-1) × (2N-1)

**Action Initialization**:
- Compute mean values for each state: `s_mean(i)`
- Assign actions: `a(i) = K_Q · Ts · s_mean(i)`
- Initialize Q-matrix as identity

**Current State Calculation** (during operation):
```matlab
s_current = ė + (1/Te)·e  % Uses current Te, not initialization Te
a_selected = actions(best_Q_index)
U_increment = K_Q · a_selected · e / s_current  % Recalculation (Eq. 7)
```

### Validation

**Test Processes**:
- **K1(s)**: `G(s) = 1/[(5s+1)(2s+1)]` - Second-order with different time constants
- **K2(s)**: `G(s) = 1/[(2s+1)²]` - Second-order with equal time constants (challenging)

**PI Tunings** (Siemens PLC defaults): `K_PI = 1`, `TI = 20`

**Results**:
- Q-matrix size reduction: [191×321×321] (Q3d) → [105×105] (Q2d)
- Learning epochs for convergence: ~9000-10000 (Q3d) → ~2000-3000 (Q2d)
- Norm convergence: ΔN → 0 after ~3000 epochs (Q2d) vs. constant learning (Q3d)
- Both methods achieve accurate trajectory tracking after learning
- Learning from disturbances (not just setpoint changes) validated

### Exploration/Exploitation

**ε-greedy Method**:
- `eps ∈ [0,1]`: Probability of exploration
- If `random() < eps`: Explore (draw random action)
- Else: Exploit (select best Q-value action)

**Constrained Exploration** (RD parameter):
- Limits action drawing range: `[a_best - RD, a_best + RD]`
- Smaller RD = less disturbance, slower learning
- Too small RD → may not reach goal state → no learning
- Trade-off: Learning speed vs. process disturbance

### Limitations & Future Work

- Application to processes with significant time delay (unsolved)
- PLC implementation not yet demonstrated
- Extensive laboratory experiments needed

### Parameters Summary

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `K_PI` | 1 | PI gain (default Siemens) |
| `TI` | 20 | PI integral time |
| `Te` | 8 (K1), varies | Target trajectory time constant |
| `eps` | 0.3 | Exploration rate |
| `α` | 0.1 | Learning rate |
| `γ` | 0.99 | Discount factor |
| `RD` | 5-10 | Random deviation range |
| `τ` | varies | Exponential decay parameter |
| `precision` | varies | Steady-state accuracy |
| `max_epochs` | 10000 | Training duration |

---

## Article 2: ASC Submission (Q2d Comprehensive)

**Title**: "Application of Self-Improving Q-learning Controller for a Class of Dynamical Processes: Implementation Aspects"

**Authors**: Jakub Musial, Krzysztof Stebel, Jacek Czeczot (corresponding), Pawel Nowak, Bogdan Gabrys
**Affiliations**:
- Silesian University of Technology
- Complex Adaptive Systems Laboratory, University of Technology Sydney

**Status**: Submitted to ASC (revision 2 with BG edits)
**Funding**: SUT subsidy 2023, BKM grant (02/060/BKM22/0037)

### Abstract Summary

Practical Q-learning controller that:
- Starts with predefined performance (bumpless switching from PI)
- Learns online without disturbing normal operation
- No process model required
- Improves until reaching desired user-defined performance level

### Key Novelties (vs. Article 1)

1. **Extended Literature Review**: Comprehensive RL methods survey including recent applications
2. **Detailed Q3d vs Q2d Comparison**: Memory and computational complexity analysis
3. **Three Process Validation**: K1, K2 (challenging equal time constants), K3 (oscillatory)
4. **Quantitative Quality Metrics**: IAE, max overshoot, settling time, max control increment
5. **Experimental Validation**: Real asynchronous motor system (first practical demonstration)
6. **Disturbance-Based Learning**: Learning only from load disturbances (more realistic)

### Industrial Motivation

**Critical Problem**: 60% of industrial PID loops perform poorly due to inadequate tuning
- Retuning requires expert knowledge and experimental data
- Impractical for factories with hundreds of simultaneous loops
- Existing solutions require process models or offline learning

### Q2d vs Q3d Detailed Comparison

**Memory Requirements**:
- **Q3d**: N² states, N² actions, N³ Q-matrix values
- **Q2d**: N states, N actions, N² Q-matrix values
- **Reduction**: Dramatic for large N (e.g., N=100: 10⁶ → 10⁴)

**Computational Complexity Reduction**:
1. State generation: One-dimensional merging vs. separate e and ė merging
2. Initialization: Identity matrix vs. 3D complete survey
3. Action search: Single column vs. 3D search
4. Faster learning: Fewer states need multiple visits

**Key Insight**: Only minor disadvantage is action recalculation (Eq. 8) to account for current `e` value

### State/Action Generation (Enhanced Description)

**Key Difference from Q3d**:
- **Q3d**: State generation depends on Te (changes require regeneration)
- **Q2d**: Uses parameter τ (independent of Te) → more flexible

**State Boundaries Computation**:
```
For i=1 to imax, j=1 to imax:
    s(k) = ė(j) + (1/Te)·e(i)
    k++
```
Result: k_max boundaries → merge close ones → N states → extend symmetrically → (2N-1) states

**Mean State Values** (for action initialization):
```
s_mean(i) = (s_boundary(i) + s_boundary(i+1)) / 2
```

**Action Recalculation** (critical for Q2d):
```
a_selected = action from Q-matrix
U_increment = K_Q · a_selected · e / s  % Eq. (8)
```
Reason: Same `s` value can result from many (e,ė) combinations

### Validation Results

**Three Processes**:
- **K1**: `G(s) = 1/[(5s+1)(2s+1)]`
- **K2**: `G(s) = 1/[(2s+1)²]` (most challenging)
- **K3**: `G(s) = 1/[(4s²+1.6s+1)]` (oscillatory)

**Common Settings**:
- PI tunings: `K_PI = 1`, `TI = 20` (Siemens defaults)
- Q-learning: `eps = 0.3`, `α = 0.1`, `γ = 0.99`
- Different RD: K1=10, K2=5, K3=2 (adapted to process dynamics)
- Different Te: K1=8, K2=15, K3=10 (realistic targets)

**Learning from Disturbances**:
- Amplitude randomized: `d ∈ (-0.5, +0.5)`
- Validation with smaller amplitude: `d = ±0.3`
- Epoch: Single disturbance application + rejection (max 2000 samples)

**Quantitative Results** (Table I):
- **IAE**: Monotonic decrease over learning for all processes
- **Max overshoot**: Significant reduction for K1, K2; minor irregularities for K3
- **Settling time**: Monotonic decrease for all (tracking & disturbance rejection)
- **Max Δ U**: Monotonic increase (price for better performance)
- **Best results**: After 5000 epochs for K1, varies for K2/K3

**Q-matrix Norm Convergence**:
- Q2d: ΔN → 0 after ~1200 epochs (trend tangent: -0.083 → -8.67e-04)
- Q3d: Constant learning even after 5000 epochs (tangent: -0.0035)
- Clear two-stage behavior for Q2d: fast learning → plateau

### Experimental Validation (NEW)

**Setup**: Asynchronous motor speed control
- First practical Q-learning controller with bumpless initialization
- Learning from realistic disturbances only
- No temporary performance degradation
- Gradual improvement validated on real hardware

**Significance**: Demonstrates industrial applicability beyond simulation

### Quality Metrics Definitions

1. **IAE** (Integral Absolute Error): `∫|e(t)|dt`
   - Tracking: setpoint changes
   - Disturbance rejection: load changes
2. **Max Overshoot**: Maximum |Y - Y_sp| after step change
3. **Settling Time**: Time to reach steady state (±ε tolerance)
4. **Max ΔU**: Maximum control signal increment (aggressiveness measure)

**Usage**: Industrial standards for PI tuning optimization, used here for Q-learning comparison

### Exploration/Exploitation Details

**ε-greedy Implementation**:
```
Draw A ∈ [0,1]
if A < eps:
    Exploration: Draw action from [a_best - RD, a_best + RD]
else:
    Exploitation: Select action with max Q-value
```

**Tuning Recommendations**:
- Start with small `eps` and `RD`
- Increase gradually if learning too slow
- **RD**: Controls amplitude of intentional disturbances
- **eps**: Controls intensity (frequency) of disturbances
- Separate effects: RD = amplitude, eps = frequency

### Practical Considerations

**Online Learning Definition**:
- Learning only by interaction with real process
- No offline learning (simulations, expert knowledge, etc.)
- Minimal modification of normal operation

**User-Adjustable Settings**:
- `RD`: Trade-off between learning speed and disturbance amplitude
- `eps`: Trade-off between learning speed and disturbance frequency
- Both require careful tuning (start small, increase cautiously)

**Precision Parameter**:
- `precision = 0.01` typical
- Steady-state error maintained at precision level (not eliminated)
- Acceptable for most industrial applications

### Research Gap Addressed

**Practitioners Need**:
- Predictable closed-loop behavior (initial and during learning)
- No initial learning based on process model
- Controlled (acceptable) online learning
- Limited random action variations during normal operation
- Minimal memory and computational resources

**Q2d Solution**:
- Deterministic initialization from PI tunings
- Bumpless switching guaranteed
- Constrained exploration (RD, eps)
- 2D Q-matrix (minimal resources)
- Experimental validation on real system

### Future Directions (from Article 2)

- Extension to higher-order processes
- PLC implementation and industrial validation
- Time delay handling (critical unsolved problem)
- Multi-input-multi-output (MIMO) systems
- Further reduction of computational requirements

---

## Article 3: Q2dPLC for TIE (In Preparation)

**Title**: "PLC-based Implementation of Self-improving Q-learning Controller and Validation for Higher-Order Processes"

**Status**: In preparation for IEEE Transactions on Industrial Electronics (TIE)
**Version**: ver 2 with BG comments

### Scope

Extension of Q2d to Q2dPLC with focus on:
- Higher-order process control (3rd order and above)
- PLC function block implementation
- Staged learning with Te reduction
- Reversed state/action generation
- Percentage Trajectory Completion (PTC) metric
- Real industrial hardware validation

### Key Extensions (Q2dPLC)

1. **Staged Te Reduction**: Gradual improvement from TI → Te_goal
   - Start: `Te = TI` (PI integral time)
   - Goal: `Te = Te_bazowe` (e.g., 2s for faster response)
   - Steps: Small increments (e.g., 0.1s)
   - Trigger: MNK filter convergence metrics

2. **Reversed Generation**: Actions first, then states
   - Based on `U_max` (maximum control authority)
   - Geometric action distribution: small (precision) + large (speed)
   - States derived from actions

3. **PLC Library Function Block**:
   - Normalized I/O: 0-100% (industrial standard)
   - Memory-efficient implementation
   - Real-time constraints
   - Integration with existing PLC systems

4. **PTC Metric** (Percentage Trajectory Completion):
   - Supervision of learning progress
   - Quantifies trajectory tracking quality
   - Decision support for Te reduction timing

5. **Higher-Order Validation**:
   - 3rd order pneumatic systems (industrial relevance)
   - T = [2.34, 1.55, 9.38] (real pneumatic actuator)
   - Complex dynamics validation

### Implementation Requirements

**PLC Constraints**:
- Limited memory (2D essential, not 3D)
- Real-time execution (<100ms cycles typical)
- Integer/fixed-point arithmetic preferred
- Modular function block architecture
- Standard I/O: 4-20mA, 0-100%

**Industrial I/O Normalization**:
- Control error: [-100%, +100%]
- Process output: [0%, 100%]
- Control signal: [0%, 100%]
- Internal calculations may use extended range

### MNK Filter (Convergence Detection)

**Purpose**: Detect when to reduce Te during staged learning

**Metrics**:
```matlab
mean(a_mnk_mean) > 0.2
mean(b_mnk_mean) ∈ (-0.05, 0.05)
flaga_zmiana_Te == 1
```

**Result**: Trigger Te reduction by 0.1s, reset MNK metrics

### Staged Learning Rationale

**Challenge**: Large Te change (20→2) in one step causes:
- Catastrophic forgetting of learned Q-values
- State/action semantic shift too large
- Poor transient performance

**Solution**: Small incremental steps
- Q-matrix preserved across Te changes
- State/action spaces regenerated for each Te
- Controller adapts gradually through continued learning
- Precision maintained via `precision*2/Te` scaling

---

## Common Themes Across All Articles

### Fundamental Innovations

1. **Bumpless Switching**: Initialize Q-matrix from existing PI tunings
2. **Model-Free**: No process model required (only PI tunings)
3. **First-Order Trajectory**: `ė + (1/Te)·e = 0` defines desired closed-loop performance
4. **2D State Space**: Merge e and ė without losing information
5. **Practical Learning**: Constrained exploration (RD, eps) for industrial acceptance

### Validation Progression

- **Article 1**: 2nd order simulation (K1, K2)
- **Article 2**: 3 processes (K1, K2, K3) + real motor validation
- **Article 3**: 3rd order pneumatic + PLC implementation

### Parameters Evolution

| Parameter | Article 1 | Article 2 | Article 3 (Q2dPLC) |
|-----------|-----------|-----------|---------------------|
| State dimension | 2D | 2D | 2D |
| Te strategy | Fixed | Fixed | **Staged (TI→Te_goal)** |
| Generation | e,ė → s | e,ė → s | **Actions→states** |
| Distribution | Exponential | Exponential | **Geometric** |
| PLC focus | Mentioned | Future work | **Core contribution** |
| I/O | Process units | Process units | **Normalized 0-100%** |
| Supervision | Norm | Norm | **PTC metric** |

### Research Impact

**Conference (2022)**:
- Introduced Q2d concept
- Proved 2D reduction feasibility
- 3× learning acceleration

**ASC (Submitted)**:
- Industrial motivation (60% poor loops)
- Comprehensive comparison
- Experimental validation
- Closed research gap

**TIE (In prep)**:
- Extension to higher-order
- PLC industrial implementation
- Staged learning for complex processes
- Real hardware validation

### Key Equations Reference

**Target Trajectory**:
```
ė + (1/Te)·e = 0  →  e(t) = e₀·exp(-t/Te)
```

**State Definition**:
```
s = ė + (1/Te)·e
```

**Control Law**:
```
U(t) = U(t-1) + K_Q · Ts · a(s)
```

**Q-Learning Update**:
```
Q(s,a) ← Q(s,a) + α[R + γ·max(Q(s',·)) - Q(s,a)]
```

**Action Recalculation** (Q2d specific):
```
U_increment = K_Q · a · e / s  % Eq. (8)
```

### Critical Success Factors

1. **Initialization**: Q-matrix as identity, based on PI tunings
2. **State Precision**: Exponential distribution, denser near goal
3. **Exploration**: Constrained (RD), ε-greedy for practical acceptance
4. **Validation**: Multiple processes, real hardware
5. **Industrial Focus**: PLC constraints, normalized I/O, minimal resources

---

## Writing Guidelines for Future Articles

### Structure Based on These Articles

1. **Abstract**: Problem statement → Solution features → Validation results
2. **Introduction**:
   - Industrial problem (60% poor loops)
   - Literature review (RL methods, Q-learning applications)
   - Research gap identification
   - Novelty summary (bulleted list)
3. **Problem Statement**:
   - Q-learning basics
   - Controller design requirements
   - Target trajectory definition
4. **Methodology**:
   - State/action generation algorithm
   - Q-matrix initialization
   - Exploration/exploitation strategy
   - Complete flowchart
5. **Validation**:
   - Simulation (multiple processes)
   - Quantitative metrics (tables)
   - Experimental (real hardware)
6. **Discussion**: Comparison, benefits, limitations
7. **Conclusions**: Summary, future work

### Terminology Standards

- **Q3d**: 3-dimensional Q-matrix approach (error + derivative separate)
- **Q2d**: 2-dimensional Q-matrix approach (merged state)
- **Q2dPLC**: PLC-focused extension with staged learning
- **Bumpless switching**: Seamless PI → Q-learning transition
- **Staged learning**: Gradual Te reduction with Q-matrix preservation
- **Exploration/Exploitation**: ε-greedy with constrained RD
- **Target/Reference trajectory**: First-order desired closed-loop dynamics
- **Goal state**: s ≈ 0 (on trajectory)
- **Epoch**: Single learning cycle (disturbance or setpoint change)

### Key Phrases to Use

- "Model-free" (not "model-independent")
- "Bumplessly replace" (not "seamlessly substitute")
- "Online learning" (emphasize no offline training)
- "Practical applicability" (not just "implementation")
- "Industrial closed-loop control systems" (specific context)
- "Self-improving controller" (key feature)
- "Gradually improve" (not "optimize immediately")
- "Without assuming any knowledge of process dynamics"

### Metrics to Report

1. **Learning Speed**: Norm convergence, epochs to target
2. **Memory**: Q-matrix size, state/action vector sizes
3. **Control Quality**: IAE, overshoot, settling time, ΔU_max
4. **Comparison**: Q3d vs Q2d, Q vs PI, Before vs After learning
5. **Hardware**: Execution time, memory usage, cycle time

---

## References Architecture

**Categories**:
1. Q-learning fundamentals (Watkins, theoretical foundations)
2. RL applications to process control
3. Industrial automation challenges
4. PI controller tuning methods
5. MPC and Q-learning similarities
6. Initialization methods
7. Exploration strategies
8. Experimental validations

**Our Previous Work**:
- [16-17] (Article 1): Q3d preliminary work
- [35-36] (Article 2): Q3d detailed description
- [36] (Article 2): Conference Q2d introduction
- [37] (Article 2): This article reference

---

## Contact Information

**Primary Authors**:
- Jakub Musiał (Jakub.Musial@polsl.pl)
- Krzysztof Stebel (Krzysztof.Stebel@polsl.pl)
- **Jacek Czeczot** (jacek.czeczot@polsl.pl) - **Corresponding author**
- Pawel Nowak

**Affiliation**: Silesian University of Technology, Faculty of Automatic Control, Electronics and Computer Science, Department of Automatic Control and Robotics, 44-100 Gliwice, Poland

**Collaboration**: Bogdan Gabrys (University of Technology Sydney)

**Funding**: SUT subsidy, BKM grant (02/060/BKM22/0037)
