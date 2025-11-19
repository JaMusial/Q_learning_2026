# Dead Time (T0) Implementation for Q2d Controller

**Author**: Claude Code Analysis
**Date**: November 17, 2025
**Purpose**: Critical analysis and recommendations for handling processes with dead time in Q2d Q-learning controller

---

## Executive Summary

The current implementation of dead time compensation (`reakcja_na_T0 = 1` mode) has **fundamental conceptual issues** that will prevent correct operation. This document provides:

1. Critical analysis of existing implementation
2. Three recommended approaches (ranked by complexity/effectiveness)
3. Practical implementation steps
4. Testing strategy
5. Research considerations for publication

**Key Finding**: The current approach double-delays the state, creating incorrect temporal associations in Q-learning updates. **Recommendation**: Start with simple Mode 1, then implement state augmentation for proper solution.

---

## Table of Contents

1. [Current Implementation Issues](#current-implementation-issues)
2. [Theoretical Background](#theoretical-background)
3. [Recommended Solutions](#recommended-solutions)
4. [Implementation Guide](#implementation-guide)
5. [Testing Strategy](#testing-strategy)
6. [Research Considerations](#research-considerations)

---

## Current Implementation Issues

### Issue #1: Missing f_bufor() Function ✅ RESOLVED

**Status**: Function now created (`f_bufor.m`)

**Function**: FIFO buffer for dead time simulation
- Shifts buffer left by one position
- Returns oldest value (delayed output)
- Appends new input at end

---

### Issue #2: Fundamental Timing Mismatch 🔴 CRITICAL

**Location**: `m_regulator_Q.m`, lines 88-115

**Problem**: Double-delaying the state creates incorrect temporal associations.

#### What the Code Does (INCORRECT):

```matlab
% At time t:
[stan_T0, bufor_state] = f_bufor(stan, bufor_state);           % stan(t) → stan(t-T0)
[old_stan_T0, bufor_old_state] = f_bufor(old_state, bufor_old_state);  % old_state(t) → old_state(t-T0)
[wyb_akcja_T0, bufor_wyb_akcja] = f_bufor(wyb_akcja, bufor_wyb_akcja); % action(t) → action(t-T0)

% Q-learning update
Q_update = alfa * (R + gamma * maxS - Q_2d(old_stan_T0, wyb_akcja_T0));
```

**Temporal Analysis**:
- `stan(t)` is ALREADY the result of `action(t-T0)` (due to dead time in plant)
- Buffering `stan(t)` gives `stan(t-T0)`
- Buffering `old_state(t)` gives `old_state(t-T0)`
- **Result**: Q-update associates `action(t-T0)` with `state(t-2*T0)` → **WRONG!**

#### Correct Association Should Be:

```
Q(state at t-T0, action at t-T0) → observed state at time t
```

The observed state at time `t` is already delayed by `T0` relative to the action that caused it!

#### Timing Diagram:

```
Timeline:
    t-T0         t-T0+dt        ...         t            t+dt
    ↓             ↓                          ↓             ↓
Action taken:
    a(t-T0)  ──┐                           a(t)     ──┐
                │                                     │
                │ Dead time T0 passes                │ Dead time T0 passes
                ↓                                     ↓
Effect observed:
    s(t-T0)     s(t-T0+dt)     ...        s(t)         s(t+dt)
                                           ↑
                            This state is CAUSED by a(t-T0)!

Current (WRONG) implementation:
    Buffer s(t) → s(t-T0)     ✗ WRONG! s(t) already reflects a(t-T0)
    Buffer a(t) → a(t-T0)
    Update: Q(s(t-2*T0), a(t-T0)) ← Incorrect timing

What should happen:
    Store: s(t-T0) when action a(t-T0) was taken
    Observe: s(t) now
    Update: Q(s(t-T0), a(t-T0)) ← using s(t) as the resulting state
```

---

### Issue #3: Incorrect Reward Timing 🟠 MAJOR

**Location**: `m_regulator_Q.m`, lines 94-98

```matlab
if old_stan_T0 == nr_stanu_doc
    R = 1;
else
    R = 0;
end
```

**Problems**:

1. **Reward reflects past, not present**:
   - Reward should be: "Is the system at setpoint NOW (at time t)?"
   - Current code rewards: "Was the system at setpoint at (t-T0)?"

2. **Breaks Markov property**:
   - Reward `R(t)` should depend on transition `s(t-1) → s(t)`
   - Current: `R(t)` depends on `s(t-T0)`, which is misaligned

3. **Learning confusion**:
   - Controller receives positive reward for OLD achievement
   - Doesn't know if CURRENT state is good or bad
   - Slows convergence dramatically

**Correct approach**:
```matlab
% Reward based on CURRENT state
if stan == nr_stanu_doc
    R = 1;
else
    R = 0;
end
```

---

### Issue #4: No State Augmentation 🟡 MODERATE

**Problem**: The Markov property is violated in dead time systems.

**Why it matters**:
- In Q-learning, state must contain all information needed to predict next state
- With dead time, current `(e, de)` is insufficient
- Recent actions (not yet visible in state) affect future states
- System is **non-Markovian** without action history

**Consequence**:
- Q-learning may converge slowly or to suboptimal policy
- Oscillatory behavior likely
- Performance degrades as T0/T ratio increases

---

## Theoretical Background

### The Dead Time Problem in Control

**Dead time (T0)**: Delay between control action and its effect on process output.

**Examples**:
- **Pipeline systems**: Fluid transport delay
- **Temperature control**: Sensor/actuator distance
- **Chemical processes**: Reaction time, mixing delays
- **Pneumatic systems**: Air compression and transport

**Impact on control**:
- **Destabilizing**: Feedback arrives too late
- **Performance degradation**: Can't react quickly
- **Oscillations**: Controller "overshoots" before seeing effect

### Dead Time in Q-Learning

**Classical Q-learning assumption**: Markov Decision Process (MDP)
- State `s(t)` fully describes system
- Action `a(t)` immediately affects transition to `s(t+1)`
- `P(s(t+1) | s(t), a(t))` doesn't depend on history

**With dead time**: System becomes Partially Observable (POMDP)
- State `s(t)` = observable part (e, de)
- Hidden state = actions in pipeline: `[a(t-n), a(t-n+1), ..., a(t-1)]`
- True state = `s_augmented = [s_observable, s_hidden]`

**Solutions**:
1. **Ignore it**: Treat as part of plant dynamics (slow, but simple)
2. **Augment state**: Include action history (proper MDP)
3. **Model-based**: Use predictor (e.g., Smith Predictor)

---

## Recommended Solutions

### Solution 1: Simple Buffering (EASIEST) ⭐

**Approach**: Just delay the control signal, treat dead time as part of plant.

**Implementation**:
```matlab
% In m_regulator_Q.m (already implemented at line 222-226)
if T0 > 0
    [u_T0, bufor_T0] = f_bufor(u, bufor_T0);
else
    u_T0 = u;
end

% Apply u_T0 to plant (line 229)
[y, y1_n, y2_n, y3_n, bufor_Q] = f_obiekt(..., u_T0 + d_obiekt, bufor_Q);
```

**Set**: `reakcja_na_T0 = 0`

**How it works**:
- Q-learning sees: "I take action A, after some time, state changes to B"
- Dead time absorbed into state transition dynamics
- No modification to state space needed

**Advantages**:
✅ Minimal code changes (already implemented!)
✅ Conceptually simple
✅ Works for moderate T0 (T0/T < 0.5)
✅ No risk of implementation errors

**Disadvantages**:
❌ Slower convergence
❌ May not work for large T0/T ratios (> 0.5)
❌ Suboptimal performance
❌ Doesn't fully utilize Q-learning potential

**Recommendation**: **Start here!** Test with T0 = 1-3 seconds before attempting more complex solutions.

---

### Solution 2: State Augmentation (RECOMMENDED) ⭐⭐⭐

**Approach**: Include recent action history in state definition to make system Markovian.

**New state definition**:
```
s_augmented = [e, de, u(t-1), u(t-2), ..., u(t-n)]

where n = ceil(T0/dt)
```

**Why it works**:
- State now contains ALL information needed to predict next state
- Actions "in the pipeline" are visible to Q-learning
- System becomes proper MDP again
- Can learn: "If error is X and I recently applied Y, taking action Z leads to X'"

**Implementation outline**:

```matlab
%% 1. In m_inicjalizacja.m - add action history buffer

if T0 > 0
    n_history = ceil(T0/dt);
    action_history = zeros(1, n_history);  % Initialize action history
else
    n_history = 0;
    action_history = [];
end

%% 2. Modify f_generuj_stany_v2.m - generate augmented state space

function [stany_aug, akcje_sr, ...] = f_generuj_stany_augmented(...)
    % Generate base states (e + (1/Te)*de)
    [stany_base, akcje_sr, ...] = f_generuj_stany_v2(...);

    % For each base state, create variants with different action histories
    % This creates a much larger state space!
    % Discretize action history into bins (e.g., 5 bins per action)

    % Alternative: Use continuous state approximation (function approximation)
    % Neural network Q(s, a; θ) instead of table
end

%% 3. In m_regulator_Q.m - compute augmented state

% Compute base state value
stan_value_base = de + (1/Te) * e;

% Create augmented state
if T0 > 0 && n_history > 0
    stan_value_augmented = [stan_value_base, action_history];
    stan = f_find_state_augmented(stan_value_augmented, stany_augmented);
else
    stan = f_find_state(stan_value_base, stany);
end

%% 4. After action selection - update history

if T0 > 0 && n_history > 0
    % Shift history and add new action
    action_history = [action_history(2:end), u_increment];
end

%% 5. Q-learning update - unchanged!
% Same as before, but now state is Markovian
Q_update = alfa * (R + gamma * maxS - Q_2d(old_state, old_action));
Q_2d(old_state, old_action) += Q_update;
```

**Advantages**:
✅ Theoretically correct
✅ Makes system Markovian
✅ Can learn optimal policy
✅ Generalizes to any T0
✅ Consistent with Q2dPLC philosophy

**Disadvantages**:
❌ Significantly larger state space
❌ Much slower learning (curse of dimensionality)
❌ May require function approximation (neural network)
❌ Complex implementation

**Dimension explosion example**:
- Original Q2d: 100 states × 100 actions = 10,000 Q-values
- With T0=2s, dt=0.1s → 20 actions in history
- If discretize each to 5 bins: 100 × 5^20 ≈ 10^17 states! 😱

**Mitigation strategies**:

1. **Reduce history granularity**:
   - Don't store all n actions
   - Store summary: `[mean(u_recent), trend(u_recent), last_u]`
   - Example: 100 × 5 × 5 × 5 = 125,000 states (manageable)

2. **Function approximation**:
   - Use neural network: `Q(s, a; θ)` instead of table
   - State input: `[e, de, u_hist_features]`
   - Deep Q-Network (DQN) approach
   - Much more complex, but scalable

3. **Tile coding**:
   - CMAC-style generalization
   - Multiple overlapping discretizations
   - Good compromise between table and NN

**Recommendation**: **For Q2dPLC paper** - implement simplified version with summary statistics.

---

### Solution 3: Smith Predictor Variant (ADVANCED) ⭐⭐

**Approach**: Use reference model to predict future state, act on prediction.

**Concept**:
```
         ┌──────────────────────────────────┐
         │   Smith Predictor Structure      │
         │                                   │
    SP ──┴─→ Q-Controller ──→ u ──→ Delay ──→ Real Plant ──→ y
              ↑
              │ predicted y_pred
              └──── Model (no delay) ─────────┘
                         ↑
                         u (no delay)
```

**How it works**:
1. Q-controller sees predicted output (no delay)
2. Can react immediately to actions
3. Model error compensated by feedback

**Implementation**:
```matlab
% Reference model (same as real plant but T0=0)
y_model = f_obiekt(nr_modelu, dt, k, T, y_model, ..., u, bufor_model);

% Error correction
y_pred = y_model + (y - y_delayed_model);

% Q-learning acts on predicted state
e_pred = SP - y_pred;
de_pred = (e_pred - e_pred_old) / dt;
stan_value = de_pred + (1/Te) * e_pred;
```

**Advantages**:
✅ Well-known in industry
✅ No state space expansion
✅ Good performance if model accurate
✅ Publishable (novel Q-learning + Smith Predictor combination)

**Disadvantages**:
❌ Requires process model (contradicts Q2d philosophy!)
❌ Performance degrades with model mismatch
❌ Complex implementation
❌ Model must be tuned

**Recommendation**: **For future research**, not Q2dPLC focus. Contradicts "no model" principle.

---

## Implementation Guide

### Phase 1: Fix Current Issues (IMMEDIATE)

**Step 1**: Verify f_bufor() works
```matlab
% Test script
T0 = 2;
dt = 0.1;
buffer = zeros(1, round(T0/dt));

for i = 1:30
    [output, buffer] = f_bufor(i, buffer);
    fprintf('Input: %d, Output: %d\n', i, output);
end
% Expected: First 20 outputs are 0, then 1, 2, 3, ...
```

**Step 2**: Disable problematic mode
```matlab
% In m_inicjalizacja.m
reakcja_na_T0 = 0;  % Use simple buffering
```

**Step 3**: Enable dead time in plant
```matlab
% In m_inicjalizacja.m
T0 = 1;  % Start with small dead time (1 second)
```

**Step 4**: Test baseline performance
- Run `main.m`
- Monitor convergence
- Check for oscillations
- Compare with T0=0 case

---

### Phase 2: Test Simple Buffering (SHORT-TERM)

**Experimental plan**:

```matlab
% Test cases (T0 as ratio of dominant time constant)
test_cases = [
    0.0,  % Baseline (no dead time)
    0.5,  % Small dead time
    1.0,  % Moderate
    2.0,  % Large
    3.0,  % Very large
    5.0   % Extreme (T0 ≈ T)
];

for T0 = test_cases
    % Run experiment
    % Measure:
    % - Convergence time (epochs to reach 80% trajectory realization)
    % - Final performance (IAE, overshoot)
    % - Stability (oscillations?)
    % - Q-matrix norm evolution
end
```

**Expected results**:
- T0/T < 0.3: Good performance, minor degradation
- T0/T = 0.3-0.5: Acceptable, slower convergence
- T0/T > 0.5: Poor performance, may not converge

**Decision point**:
- If works up to T0/T ≈ 0.5 → **Sufficient for Q2dPLC paper**
- If fails at T0/T < 0.3 → **Need state augmentation**

---

### Phase 3: Implement State Augmentation (MEDIUM-TERM)

**Option A: Simplified approach** (RECOMMENDED for Q2dPLC)

```matlab
%% Define augmented state with summary statistics

% In m_regulator_Q.m
persistent u_history mean_u trend_u;

if isempty(u_history)
    n_hist = ceil(T0/dt);
    u_history = zeros(1, n_hist);
    mean_u = 0;
    trend_u = 0;
end

% Update statistics
mean_u = mean(u_history);
if length(u_history) > 1
    trend_u = (u_history(end) - u_history(1)) / (length(u_history) * dt);
end

% Augmented state (3 components instead of 1+n)
stan_value_base = de + (1/Te) * e;
stan_value_aug = [stan_value_base, mean_u, trend_u];

% Discretize augmented state
% Need new function f_find_state_3d or discretize each component separately
stan_base = f_find_state(stan_value_base, stany);
stan_mean_u = discretize(mean_u, u_bins);  % Define bins
stan_trend_u = discretize(trend_u, trend_bins);

% Combined state index
stan = sub2ind([n_states_base, n_bins_u, n_bins_trend], ...
               stan_base, stan_mean_u, stan_trend_u);

% Q-matrix now: [n_states_base × n_bins_u × n_bins_trend] × n_actions
% Example: 100 × 5 × 5 × 100 = 2.5M entries (large but manageable)
```

**Option B: Full history** (for thesis/future work)

Use function approximation (neural network):
- Input: `[e, de, u(t-1), u(t-2), ..., u(t-n)]`
- Output: `Q(s, a1), Q(s, a2), ..., Q(s, am)`
- MATLAB Deep Learning Toolbox or Python/TensorFlow

---

### Phase 4: Comparative Study (FOR PUBLICATION)

Compare all three approaches:

| Method | T0/T Range | Convergence | Final IAE | Complexity |
|--------|------------|-------------|-----------|------------|
| Simple buffering | 0-0.5 | ??? | ??? | Low |
| State aug (summary) | 0-1.0 | ??? | ??? | Medium |
| State aug (full) | 0-∞ | ??? | ??? | High |
| Smith predictor | 0-∞ | ??? | ??? | Medium |

**Publication angle**:
"Comparative study of Q-learning approaches for processes with dead time: From simple buffering to state augmentation"

---

## Testing Strategy

### Unit Tests

**Test 1: f_bufor() correctness**
```matlab
% test_f_bufor.m
function test_f_bufor()
    T0 = 2.0;
    dt = 0.1;
    n = round(T0/dt);
    buffer = zeros(1, n);

    % Test filling phase
    for i = 1:n
        [out, buffer] = f_bufor(i, buffer);
        assert(out == 0, 'Filling phase should output 0');
    end

    % Test steady state
    for i = 1:10
        [out, buffer] = f_bufor(n+i, buffer);
        assert(out == i, sprintf('Expected %d, got %d', i, out));
    end

    fprintf('✓ f_bufor() tests passed\n');
end
```

**Test 2: Dead time delay verification**
```matlab
% test_dead_time.m
function test_dead_time()
    % Set up system with known T0
    T0 = 2.0;
    dt = 0.1;

    % Apply step input
    u_step = 50;

    % Measure when output changes
    % Should be ceil(T0/dt) samples later

    % TODO: Implement verification
end
```

---

### Integration Tests

**Test 3: Convergence with T0**
```matlab
% test_convergence_with_T0.m
T0_values = [0, 0.5, 1, 2, 3];
convergence_epochs = zeros(size(T0_values));

for i = 1:length(T0_values)
    T0 = T0_values(i);
    % Run learning
    % Measure epochs to reach 80% trajectory realization
    convergence_epochs(i) = ???;
end

figure;
plot(T0_values, convergence_epochs);
xlabel('Dead time T0 [s]');
ylabel('Convergence epochs');
title('Impact of Dead Time on Learning Speed');
```

**Test 4: Stability analysis**
```matlab
% Check for oscillations
% Measure: settling time, overshoot, oscillation frequency
% Compare T0=0 vs T0>0
```

---

### Performance Metrics

For each T0 value, measure:

1. **Learning metrics**:
   - Epochs to 80% trajectory realization
   - Final percentage realization
   - Q-matrix norm convergence rate

2. **Control metrics** (from m_eksperyment_weryfikacyjny):
   - IAE (Integral Absolute Error)
   - Overshoot percentage
   - Settling time (2% band)
   - Max control signal change

3. **Stability metrics**:
   - Oscillation index (count zero crossings)
   - Damping ratio (from step response)
   - Phase margin (if frequency analysis available)

---

## Research Considerations

### For Q2dPLC Paper (TIE Submission)

**Primary focus**: PLC implementation for higher-order processes

**Dead time as secondary contribution**:
- Section: "Extension to Processes with Dead Time"
- Show: Simple buffering (Mode 1) works for moderate T0/T < 0.5
- Demonstrate: Q2dPLC maintains bumpless switching with T0
- Results: Performance degradation curve vs T0/T ratio

**Key message**:
"Q2dPLC handles moderate dead times without modification. For severe cases (T0/T > 0.5), state augmentation extension is possible."

**Recommended experiments**:
1. Pneumatic system (Model 8) + T0 = [0, 1, 2, 3] seconds
2. Show convergence, IAE, settling time vs T0
3. One figure showing performance degradation
4. Brief discussion of state augmentation for future work

---

### For Future Publication

**Title ideas**:
- "Q-learning Control for Processes with Dead Time: State Augmentation Approach"
- "Handling Dead Time in Q2d Self-Improving Controller"
- "Comparative Study of Q-learning Strategies for Dead Time Compensation"

**Novel contributions**:
1. **State augmentation with summary statistics**:
   - Avoids dimension explosion
   - Maintains Q2d philosophy (tabular learning)
   - Scalable to PLC implementation

2. **Theoretical analysis**:
   - When does simple buffering suffice? (T0/T < threshold)
   - State space expansion vs performance tradeoff
   - Convergence guarantees with augmented state

3. **Experimental validation**:
   - Real pneumatic system with artificial delay
   - Compare: Simple, Summary, Full history, Smith predictor
   - Industrial applicability analysis

---

### Open Questions for Research

1. **What is the critical T0/T ratio?**
   - When does simple buffering fail?
   - Is there a clear threshold?
   - Process-dependent or universal?

2. **Optimal action history representation?**
   - Mean + trend sufficient?
   - Need higher-order moments?
   - Recency weighting?

3. **Function approximation necessity?**
   - Can tabular Q-learning handle moderate-dimensional augmented state?
   - When is neural network required?
   - Tradeoff: performance vs complexity

4. **Bumpless switching with dead time?**
   - Can PI tunings still initialize Q-matrix with augmented state?
   - How to handle action history initialization?

5. **PLC implementation feasibility?**
   - Memory constraints for augmented Q-matrix
   - Computational load for history management
   - Real-time performance with larger state space

---

## Practical Recommendations Summary

### Immediate Actions (This Week):

1. ✅ **Created**: `f_bufor.m` function
2. 🔧 **Set**: `reakcja_na_T0 = 0` in `m_inicjalizacja.m`
3. 🧪 **Test**: Run with `T0 = 1` (simple buffering mode)
4. 📊 **Baseline**: Record performance with T0 = 0 for comparison
5. 📈 **Experiment**: Test T0 = [0.5, 1, 2, 3] seconds

### Short-term (This Month):

1. 📉 **Characterize**: Performance degradation curve vs T0/T
2. 📝 **Document**: Which T0 ranges work with simple buffering
3. 🎯 **Decision**: Is simple buffering sufficient for Q2dPLC paper?
4. 🔍 **If needed**: Begin state augmentation design

### Medium-term (Next 3 Months):

1. 🏗️ **Implement**: State augmentation with summary statistics
2. 📊 **Compare**: Simple vs Augmented performance
3. 📄 **Write**: Q2dPLC paper section on dead time
4. 🧪 **Validate**: On real pneumatic system if available

### Long-term (Thesis/Future Papers):

1. 🔬 **Deep dive**: Full state augmentation analysis
2. 🤖 **Explore**: Function approximation (neural networks)
3. 📚 **Theory**: Convergence proofs for augmented state Q-learning
4. 🏭 **Industrial**: Real-world validation on processes with significant T0

---

## Conclusion

Your current dead time implementation (`reakcja_na_T0 = 1`) has fundamental issues:
- ❌ Double-delays states (timing mismatch)
- ❌ Incorrect reward assignment
- ❌ Will not converge correctly

**Recommended path forward**:

1. **Phase 1** (Now): Use simple buffering (`reakcja_na_T0 = 0`, T0 > 0)
   - Already implemented
   - Works for moderate T0
   - Sufficient for initial Q2dPLC results

2. **Phase 2** (If needed): Implement state augmentation
   - Use summary statistics (mean, trend)
   - Manageable state space expansion
   - Better performance for large T0

3. **Phase 3** (Future research): Advanced methods
   - Full history with function approximation
   - Smith predictor variant
   - Theoretical analysis

**For Q2dPLC paper**: Focus on PLC implementation, treat dead time as secondary extension. Show that simple buffering works up to T0/T ≈ 0.5, which covers many industrial cases.

**Key insight**: Don't let perfect be enemy of good. Simple buffering may be sufficient for publication while maintaining Q2d's "no model" philosophy. State augmentation is a future enhancement, not a requirement.

---

## References

### Q-learning with Dead Time (Literature to Review):

1. **Watkins, C.J.C.H. (1989)**. "Learning from Delayed Rewards" - Original Q-learning thesis
2. **Sutton & Barto (2018)**. "Reinforcement Learning: An Introduction" - Chapter on eligibility traces
3. **Lin, L.J. (1992)**. "Self-Improving Reactive Agents Based On Reinforcement Learning..."  - Experience replay for delayed rewards
4. **Bradtke, S.J. & Duff, M.O. (1995)**. "Reinforcement Learning Methods for Continuous-Time Markov Decision Problems" - Continuous-time RL

### Dead Time Compensation (Classical Control):

1. **Smith, O.J.M. (1957)**. "Closer Control of Loops with Dead Time" - Original Smith Predictor
2. **Palmor, Z.J. (1996)**. "Time-Delay Compensation - Smith Predictor and Its Modifications" - Review
3. **Normey-Rico, J.E. & Camacho, E.F. (2007)**. "Control of Dead-time Processes" - Comprehensive book

### Q-learning in Process Control:

1. **Your own papers** - Q2d methodology foundation
2. **Spielberg, S. et al. (2017)**. "Toward self-driving processes: A deep reinforcement learning approach to control"
3. **Lee, J. et al. (2020)**. "Reinforcement learning for process control: Review and benchmark"

---

**Document Version**: 1.0
**Next Review**: After Phase 1 testing complete
**Contact**: Jakub Musiał (Silesian University of Technology)
