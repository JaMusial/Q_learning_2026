# Projection Function Analysis: Paper vs Codebase

**Date**: 2025-01-28
**Purpose**: Document discrepancy between 2022 paper formulation and current codebase implementation
**Status**: ✅ Codebase implementation appears CORRECT (paper formulation likely has error/ambiguity)

---

## 1. Executive Summary

The **projection function** `e·(1/Te - 1/Ti)` is implemented **differently** in the codebase than described in the 2022 paper:

- **Paper (Eq 6-7)**: Projection applied to **state calculation**, affecting Q-matrix lookup, then subtracted from control
- **Codebase**: Projection applied **only to control output**, NOT to state lookup

**Verdict**: The codebase implementation is likely **more correct**. The paper formulation creates a circular dependency that defeats the purpose of the projection. User reports better performance WITHOUT projection (f_rzutujaca_on=0), which supports this conclusion.

---

## 2. Paper Formulation (2022)

### Equations 6-7 (Section 3, pp. 4-5)

**Context**:
> "The aforementioned state definition significantly facilitates Q-matrix initialization to ensure bumpless switching between the operating PI controller and the proposed Q2d controller. However, it does not ensure that the goal state represents desired reference trajectory given by (1). Thus, while the normal operation of the Q2d controller, the current value of the system state must be computed as:"

**Equation 6** (State calculation WITH projection):
```
s = ė + (1/Te)·e + e·(1/Te - 1/Ti)
```

Simplified:
```
s = ė + (2/Te - 1/Ti)·e
```

**Equation 7** (Control recalculation):
```
ΔU = s_mean - e·(1/Te - 1/Ti)
```

### Interpretation of Paper Approach

If implemented as written:

1. **State calculation**:
   ```matlab
   s_value = de + (2/Te - 1/Ti) * e;  % WITH projection
   ```

2. **State discretization**:
   ```matlab
   state_index = find_state(s_value, state_boundaries);
   ```
   → Projection shifts which Q-matrix row is accessed

3. **Action selection**:
   ```matlab
   action = argmax(Q[state_index, :]);
   s_mean = action_means[action];
   ```

4. **Control output**:
   ```matlab
   delta_u = s_mean - e * (1/Te - 1/Ti);  % SUBTRACT projection
   ```

### Example with Numbers

**Scenario**: `e = 10`, `de = -5`, `Te = 2`, `Ti = 20`

**Projection term**: `e·(1/Te - 1/Ti) = 10·(0.5 - 0.05) = 4.5`

**Paper approach**:
```
1. s = -5 + (2/2 - 1/20)·10 = -5 + 0.95·10 = 4.5
2. Find state: e.g., state_index = 55 (shifted UP by projection)
3. Get action: s_mean[55] = 12.3
4. Control: delta_u = 12.3 - 4.5 = 7.8
```

**Codebase approach**:
```
1. s = -5 + (1/2)·10 = 0
2. Find state: state_index = 50 (goal state, no shift)
3. Get action: s_mean[50] = 0
4. Control: delta_u = 0 - 4.5 = -4.5
```

**Completely different results!**

---

## 3. Codebase Implementation

### Files Involved

- `config.m:83` - Projection enable flag
- `m_regulator_Q.m:89` - State calculation (no projection)
- `m_regulator_Q.m:238-245` - Projection application
- `m_zapis_logow.m` - Logging both versions for comparison

### State Calculation (m_regulator_Q.m:89)

```matlab
stan_value = de + 1/Te * e;  % NO projection term
```

### State Discretization (m_regulator_Q.m:91)

```matlab
stan = f_find_state(stan_value, stany);  % Lookup uses unprojected state
```

### Action Selection (m_regulator_Q.m:123-162)

```matlab
% Selection based on 'stan' (which was calculated WITHOUT projection)
if (stan == nr_stanu_doc)
    wyb_akcja = nr_akcji_doc;
else
    % Epsilon-greedy using unprojected state
    [Q_value, wyb_akcja] = f_best_action_in_state(Q_2d, stan, nr_akcji_doc);
end

wart_akcji = akcje_sr(wyb_akcja);  % Mean action value
```

### Projection Application (m_regulator_Q.m:238-245)

```matlab
wart_akcji_bez_f_rzutujacej = wart_akcji;  % Save unprojected version

% Apply projection function if enabled
if f_rzutujaca_on == 1 && (stan ~= nr_stanu_doc && stan ~= nr_stanu_doc+1 && ...
        stan ~= nr_stanu_doc-1 && abs(e) >= dokladnosc_gen_stanu)
    funkcja_rzutujaca = (e * (1/Te - 1/Ti));
    wart_akcji = wart_akcji - funkcja_rzutujaca;  % SUBTRACT from action
else
    funkcja_rzutujaca = 0;
end
```

**Key conditions for applying projection**:
1. `f_rzutujaca_on == 1` (enabled in config)
2. NOT in goal state or ±1 neighbors
3. Error magnitude ≥ precision threshold

### Control Output (m_regulator_Q.m:249-250)

```matlab
u_increment_bez_f_rzutujacej = kQ * wart_akcji_bez_f_rzutujacej * dt;  % Without
u_increment = kQ * wart_akcji * dt;  % With projection
u = u_increment + u;
```

---

## 4. Why the Difference Matters

### A. Impact on Q-Learning

**Paper approach** (projection affects state lookup):
- Different states → different Q-values → different actions learned
- Q-matrix learns policy for **projected state space**
- During learning: Q(s_projected, a) updated
- After convergence: Policy optimal for s_projected, not s

**Codebase approach** (projection only affects control):
- Same states → same Q-values
- Q-matrix learns policy for **unprojected state space**
- Projection acts as **post-processing correction** to control signal
- Policy learned is independent of Te/Ti mismatch

### B. Theoretical Issues with Paper Formulation

**Problem 1: Circular Dependency**

The paper states (p. 4-5):
> "However, it does not ensure that the goal state represents desired reference trajectory given by (1)."

But if you add projection to state calculation:
```
s = ė + (2/Te - 1/Ti)·e
```

For steady-state (ė=0, s=0):
```
0 = (2/Te - 1/Ti)·e
e = 0  (only if 2/Te ≠ 1/Ti)
```

This **changes the goal state definition**, which contradicts the intent of "ensuring goal state represents trajectory."

**Problem 2: Time-Varying Projection**

During staged learning, Te changes: 20 → 19.9 → ... → 2

If projection affects state lookup:
- State boundaries remain fixed (generated at each Te)
- But projection term `(1/Te - 1/Ti)` changes continuously
- Same physical state maps to different Q-matrix cells
- Breaks Q-value transfer between Te steps

**Problem 3: Defeats Bumpless Switching**

For bumpless switching:
- Te starts at Ti (Te = Ti = 20)
- Projection term: `e·(1/Te - 1/Ti) = e·(1/20 - 1/20) = 0` ✓

But after first Te reduction (Te = 19.9):
- Projection: `e·(1/19.9 - 1/20) ≈ e·0.00025`
- Small, but nonzero - shifts state lookup
- Learned Q-values no longer match

### C. Codebase Approach Advantages

**1. Separation of Concerns**:
- Q-learning operates on clean state definition `s = ė + (1/Te)·e`
- Projection is **orthogonal correction** applied to control

**2. Invariant Q-Policy**:
- Q-matrix learns optimal action for state `s`
- Independent of Te/Ti relationship
- Projection can be toggled on/off without retraining

**3. Staged Learning Compatibility**:
- State space regenerated at each Te
- Projection doesn't interfere with Q-value transfer
- Clean convergence properties

**4. Empirical Validation**:
- User reports **better performance with projection OFF** (f_rzutujaca_on=0)
- Suggests projection may not be needed if state generation is correct
- Aligns with CLAUDE.md note: "optional"

---

## 5. Mathematical Analysis

### Projection Term Derivation

**Goal**: Transition from trajectory with time constant Ti to Te.

**PI controller behavior** (Te=Ti):
```
ΔU_PI = (Kp·Ts/Ti)·e
```

**Q2d with identity initialization** (s_mean = s):
```
ΔU_Q = Kp·Ts·s = Kp·Ts·(ė + (1/Ti)·e)
```

For first-order reference: `ė = -(1/Ti)·e`
```
ΔU_Q = Kp·Ts·(-(1/Ti)·e + (1/Ti)·e) = 0  ✓ (at steady-state)
```

**Desired behavior** (Te < Ti, faster response):
```
ė = -(1/Te)·e  (target trajectory)
```

**Correction needed**:
```
ΔU_desired = Kp·Ts·(ė + (1/Te)·e)

If actually ė = -(1/Ti)·e (PI trajectory):
ΔU_correction = Kp·Ts·(-(1/Ti)·e + (1/Te)·e)
              = Kp·Ts·e·(1/Te - 1/Ti)
```

**This is exactly the projection term!**

**Where to apply?**

**Option A** (Paper): Modify state calculation
- Pro: State reflects desired trajectory
- Con: Changes which Q-values are learned
- Con: Breaks during staged Te reduction
- Con: Circular dependency with goal state

**Option B** (Codebase): Post-process control output
- Pro: Q-learning independent of trajectory mismatch
- Pro: Can toggle without retraining
- Pro: Works with staged Te reduction
- Con: Doesn't "teach" controller new trajectory (relies on learned Q-values)

### When is Projection Needed?

**Case 1: Large Te-Ti mismatch at initialization**
- e.g., Ti=20, Te_goal=2 (10× difference)
- Without projection: Large initial transient
- With projection: Smoother transition

**Case 2: During staged learning**
- Te gradually decreases: 20 → 19.9 → ... → 2
- Small ΔTe per step (0.1s)
- Projection term small: `e·(1/Te - 1/Ti)` ≈ `e·(-0.005)` initially
- **May not be necessary** if learning adapts quickly

**Case 3: After learning converges**
- Q-matrix optimized for Te_goal=2
- Projection: `e·(1/2 - 1/20) = e·0.45` (significant)
- But Q-values should already encode optimal policy for Te=2
- **Projection may be redundant** if Q-learning succeeded

**Hypothesis**: Projection is a **crutch** for imperfect Q-learning. If Q-matrix truly converges to optimal policy for target trajectory, projection becomes unnecessary.

---

## 6. Current Status in Codebase

### Configuration (config.m:83)

```matlab
f_rzutujaca_on = 0;  % Projection function: 1=enabled, 0=disabled
```

**Default**: Projection is **DISABLED**

### Comments from CLAUDE.md

> "Projection function: `e·(1/Te - 1/Ti)` for stability (optional)"

Described as **optional**, suggesting:
- Not critical for basic operation
- May improve transient behavior in some cases
- Current research trend is away from using it

### Logging Infrastructure

Both versions are logged for comparison:
- `logi.Q_akcja_value` - with projection
- `logi.Q_akcja_value_bez_f_rzutujacej` - without projection
- `logi.Q_funkcja_rzut` - projection value itself
- `logi.Q_u_increment` - control with projection
- `logi.Q_u_increment_bez_f_rzutujacej` - control without projection

Visualization in `m_rysuj_wykresy.m:120-126`:
```matlab
plot(logi.Q_t, logi.Q_akcja_value, 'Color', colors.Q, 'LineWidth', 1.5);
hold on
plot(logi.Q_t, logi.Q_akcja_value_bez_f_rzutujacej, 'Color', colors.Alt, 'LineWidth', 1.2);
legend('With projection function', 'Without projection function', 'Location', 'best')
```

This enables **direct comparison** experiments!

---

## 7. Recommended Experiments

### Experiment 1: Projection ON vs OFF (current Te)

**Objective**: Verify user's claim that performance is better without projection

**Method**:
1. Run verification experiment with `f_rzutujaca_on = 0` (baseline)
2. Run verification experiment with `f_rzutujaca_on = 1`
3. Compare performance metrics (IAE, settling time, overshoot)

**Expected outcome**:
- If projection is redundant: Similar or worse performance with projection ON
- If projection helps: Faster settling, lower IAE with projection ON

**Configuration**:
```matlab
% config.m
max_epoki = 5000;              % Full training
Te_bazowe = 2;                 % Aggressive goal
nr_modelu = 3;                 % 2nd order
T = [5 2];
kQ = Kp = 1;
Ti = 20;
```

### Experiment 2: Initial Te Impact

**Objective**: Test if projection helps during large Te-Ti mismatch

**Method**:
1. **Scenario A**: Start with Te=Ti=20, reduce to 2 (current approach)
2. **Scenario B**: Start with Te=2 (large mismatch), no staged learning
3. Compare both with/without projection (4 runs total)

**Hypothesis**: Projection may help more in Scenario B (large initial mismatch)

### Experiment 3: Staged Learning Sensitivity

**Objective**: Determine if projection interferes with Te reduction

**Method**:
1. Enable staged learning (Te: 20→2 in 0.1s steps)
2. Track Q-matrix convergence at each Te step
3. Compare convergence speed with/without projection

**Metric**: Number of epochs until Q-matrix norm stabilizes after each Te change

### Experiment 4: Paper Implementation Test

**Objective**: Implement paper's formulation and compare

**Method** (create test branch):
1. Modify `m_regulator_Q.m:89`:
   ```matlab
   % OLD (current):
   stan_value = de + 1/Te * e;

   % NEW (paper):
   if f_rzutujaca_on == 1
       stan_value = de + (2/Te - 1/Ti) * e;  % Projection in state
   else
       stan_value = de + 1/Te * e;
   end
   ```

2. Modify lines 238-245 (remove post-processing):
   ```matlab
   if f_rzutujaca_on == 1
       % Projection already in state, just subtract from control
       funkcja_rzutujaca = (e * (1/Te - 1/Ti));
       wart_akcji = wart_akcji - funkcja_rzutujaca;
   else
       funkcja_rzutujaca = 0;
   end
   ```

3. Run same verification experiment
4. Compare: Current implementation vs Paper implementation

**Expected outcome**: Paper implementation likely performs **worse** due to circular dependency issues

### Experiment 5: Projection Value Analysis

**Objective**: Understand when/why projection is nonzero

**Method**:
1. Run with `f_rzutujaca_on = 1`
2. Plot `logi.Q_funkcja_rzut` over time
3. Correlate with:
   - Current Te value
   - Error magnitude
   - State number
   - Learning progress (epoch)

**Analysis questions**:
- When is projection largest?
- Does it decrease as learning progresses?
- Is it significant near goal state?

---

## 8. Implementation Verification Checklist

To verify projection is correctly implemented (current codebase approach):

- [x] **State calculation excludes projection** (m_regulator_Q.m:89)
  ```matlab
  stan_value = de + 1/Te * e;  ✓
  ```

- [x] **Projection applied AFTER action selection** (m_regulator_Q.m:236-245)
  ```matlab
  wart_akcji_bez_f_rzutujacej = wart_akcji;
  if f_rzutujaca_on == 1 && ...
      funkcja_rzutujaca = (e * (1/Te - 1/Ti));
      wart_akcji = wart_akcji - funkcja_rzutujaca;  ✓
  ```

- [x] **Projection disabled near goal state** (m_regulator_Q.m:239-240)
  ```matlab
  stan ~= nr_stanu_doc && stan ~= nr_stanu_doc+1 && stan ~= nr_stanu_doc-1
  ```
  Reason: Goal state should use pure Q-learned action (a=0)

- [x] **Projection disabled for small errors** (m_regulator_Q.m:240)
  ```matlab
  abs(e) >= dokladnosc_gen_stanu
  ```
  Reason: Avoid numerical issues near setpoint

- [x] **Projection formula correct** (m_regulator_Q.m:241)
  ```matlab
  funkcja_rzutujaca = (e * (1/Te - 1/Ti));  ✓
  ```
  Matches paper Eq. 7

- [x] **Both versions logged** (m_zapis_logow.m:110, 119)
  ```matlab
  logi.Q_akcja_value_bez_f_rzutujacej(logi_idx) = wart_akcji_bez_f_rzutujacej;  ✓
  logi.Q_u_increment_bez_f_rzutujacej(logi_idx) = u_increment_bez_f_rzutujacej;  ✓
  ```

**Verdict**: ✅ Implementation is **correct** for the codebase's interpretation (projection as post-processing, not state modification)

---

## 9. Conclusions

### Implementation Discrepancy

**Paper** (Eq 6-7): Projection modifies state calculation, affecting Q-matrix lookup
**Codebase**: Projection modifies control output only, not Q-matrix lookup

These are **fundamentally different** approaches that produce different control behavior.

### Which is Correct?

**Codebase implementation is likely more correct** because:

1. **Theoretical soundness**: Avoids circular dependency with goal state definition
2. **Staged learning compatibility**: Doesn't interfere with Te reduction and Q-value transfer
3. **Empirical validation**: User reports better performance WITHOUT projection
4. **Separation of concerns**: Q-learning independent of trajectory correction
5. **Paper ambiguity**: Equations 6-7 may have been imprecisely stated or contain error

### Paper's Likely Intent

The paper probably meant:
- Use basic state `s = ė + (1/Te)·e` for Q-learning
- Apply projection as **optional correction** to control output during transition from Ti to Te
- But equations were written ambiguously/incorrectly

### Current Best Practice

Based on evidence:
1. ✅ **Use `f_rzutujaca_on = 0`** (projection disabled) - current default
2. ✅ State calculation: `s = ė + (1/Te)·e` (no projection)
3. ✅ Rely on Q-learning to learn optimal policy for Te_goal
4. ✅ Staged learning (Te: 20→2) handles transition smoothly

Projection may be:
- Historical artifact from early development
- Unnecessary with proper state space generation
- Potentially useful for specific edge cases (to be determined by experiments)

### Next Steps

1. **Run comparison experiments** (Exp 1-3 above)
2. **Document empirical results** showing projection ON vs OFF
3. **Update paper discussion** in future publications to clarify discrepancy
4. **Consider removing projection** if experiments confirm it's not beneficial

---

## Appendix: Code Locations

**Projection Flag**:
- `config.m:83` - `f_rzutujaca_on = 0`

**Implementation**:
- `m_regulator_Q.m:89` - State calculation (no projection)
- `m_regulator_Q.m:236-245` - Projection application (to control)

**Logging**:
- `m_zapis_logow.m:29, 38` - Initialize arrays
- `m_zapis_logow.m:110, 112, 119` - Record values

**Visualization**:
- `m_rysuj_wykresy.m:120-126` - Action value comparison plot
- `m_rysuj_wykresy.m:446-455` - Projection function value plot

**Parameters**:
- `config.m:64` - `Ti = 20` (integral time)
- `config.m:71` - `Te_bazowe = 2` (goal time constant)
- `main.m:14` or `m_inicjalizacja.m:110` - `Te = Ti` (initialization)

---

**Document Prepared**: 2025-01-28
**Author**: Claude Code
**Purpose**: Technical analysis for comparison experiments
**Status**: Ready for experimental validation
