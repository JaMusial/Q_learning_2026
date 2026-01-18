
## Critical Bug Fixes (2025-01-23 to 2026-01-15)

**All experiments before 2026-01-16 must be re-run.** Twelve critical bugs were discovered and fixed:

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
**Caveat**: Credit assignment mismatch with projection + dead time was fixed in Bug #11
- Previous issue: Q-table corruption with large projection coefficients
- Fix: Buffer effective action (with projection) instead of raw Q-action
- Projection mode with T0>0 should now work correctly

### Results After Fixes
**T0=0, 50 epochs**:
- Q(50,50): 92.46 (converging to 100) ✓
- TD error: Decreasing ✓

**T0=4**: Expected to converge with Bug #5 fix

### Bug #8: Te Not Set for Projection Mode (2026-01-13)
**File**: m_inicjalizacja.m, main.m
**Problem**: Te was always initialized to Ti in m_inicjalizacja.m, even when f_rzutujaca_on=1
- With Te=Ti, projection = `e·(1/Te - 1/Ti) = 0` (no projection applied!)
- State space generated with wrong granularity
**Fix**: main.m lines 16-24 override Te based on f_rzutujaca_on:
```matlab
if f_rzutujaca_on == 1
    Te = Te_bazowe;  % Projection mode: use goal Te
else
    Te = Ti;         % Staged learning: start at Ti
end
```
**Impact**: Projection now calculated correctly with Te≠Ti

### Bug #9: Array Overflow in Verification (2026-01-13)
**File**: m_eksperyment_weryfikacyjny.m
**Problem**: Array index exceeded bounds during verification experiment
**Fix**: Added bounds checking and proper array sizing
**Impact**: Verification experiments complete without errors

### Bug #10: Projection Disabled at Goal State (2026-01-15)
**File**: m_regulator_Q.m (lines 250-268)
**Problem**: Two conditions prevented projection from being applied:
1. **State-based exclusion**: Projection disabled when `state ∈ {49, 50, 51}` (near goal)
   - With Te=5, Ti=20: state_value = de + e/Te ≈ 0 even with 30% error!
   - System on target trajectory → state near goal → projection disabled
   - Q controller did nothing while PI correctly drove output
2. **Sign check failure**: When `wart_akcji = 0` (at goal state), sign check `(wart_akcji<0 && ...) || (wart_akcji>0 && ...)` was FALSE
   - Projection never applied at goal state
**Root Cause Analysis**:
```
Sample 20: e=29.42%, de=-5.78, state_value = -5.78 + 29.42/5 = 0.10 ≈ 0
           → state=50 (goal!) → action=0 → Q does nothing
           → PI correctly gives: Kp·dt·(de + e/Ti) = -0.45
```
**Fix**: Changed condition from state-based to error-based:
```matlab
% OLD (broken): Excluded states {49,50,51}
if f_rzutujaca_on == 1 && (stan ~= nr_stanu_doc && stan ~= nr_stanu_doc+1 && ...
        stan ~= nr_stanu_doc-1 && abs(e) >= dokladnosc_gen_stanu)
    if wart_akcji<0 && ... || wart_akcji>0 && ...  % Sign check failed for 0
        wart_akcji = wart_akcji - funkcja_rzutujaca;

% NEW (fixed): Only check error magnitude, always apply projection
if f_rzutujaca_on == 1 && abs(e) >= dokladnosc_gen_stanu
    wart_akcji = wart_akcji - funkcja_rzutujaca;  % No sign check
```
**Impact**: Q controller now matches PI behavior during initialization transient

### Bug #11: Credit Assignment Mismatch with Projection + Dead Time (2026-01-15)
**File**: m_regulator_Q.m (lines 185-217)
**Problem**: When T0>0 and f_rzutujaca_on=1, Q-learning credited Q-actions for outcomes caused by projection
- Control = Q_action - projection, but only Q_action was buffered
- Projection did most of the control work during transients
- Q-table learned wrong values (credited Q for projection's work)
- After training: System stuck at wrong setpoints (6-9% steady-state error)

**Root Cause Analysis**:
```
Training with T0=0.5s:
  Sample k: state=40, Q selects action=42 (value=0.8)
  Projection = e·(1/Te-1/Ti) = 30·(0.2-0.05) = 4.5
  Actual control = 0.8 - 4.5 = -3.7  ← Projection drives output!
  Sample k+5: Good outcome observed (effect of -3.7 control)
  Q-update: Q(40,42) increases  ← WRONG! Action 42 didn't cause this!

After training:
  State=40, Q selects action=42 (corrupted high Q-value)
  Actual control = 0.8 - projection = small value
  System stuck at e=6% (insufficient control)
```

**Attempted fixes that failed**:
1. Buffer effective action → Maps everything to action 50 (goal), corrupts Q-table
2. Proportional credit → Q-action and -projection always opposite signs, disables all learning
3. Sign-aware credit → Same issue as proportional credit

**Fix**: Limit Q-learning to near-setpoint region where projection is small:
```matlab
if f_rzutujaca_on == 1
    PROJ_COEFF = abs(1/Te - 1/Ti);
    MAX_PROJ_FOR_LEARNING = 0.3;  % Control units
    error_threshold = MAX_PROJ_FOR_LEARNING / (PROJ_COEFF + 0.001);
    if abs(e) > error_threshold
        uczenie = 0;  % Disable Q-update during large transients
    end
end
```
**Impact**: Q learns fine-tuning near setpoint; projection handles transients (like PI)
**Limitation**: Q-learning only active in ~2% error range (for Te=5, Ti=20)
**Recommendation**: Use f_rzutujaca_on=0 (staged learning) with T0>0 for better Q-table development

### Bug #12: Quantization Error Causes Steady-State Offset (2026-01-16)
**File**: m_regulator_Q.m (lines 283-306)
**Problem**: Using discretized action_value instead of continuous state_value for projection caused quantization errors that flipped control sign
- action_value comes from Q-table (discretized to ~100 levels)
- projection calculated from continuous error
- When both small and similar magnitude, quantization error determines sign!

**Root Cause Analysis**:
```
At steady state with e = -1.44% (y > SP, need to DECREASE u):
  state_value = de + e/Te = 0 + (-1.44)/5 = -0.288 (continuous)
  action_value = -0.200 (discretized from Q-table)
  projection = e*(1/Te - 1/Ti) = -1.44*0.15 = -0.217

Using discretized action:
  effective = -0.200 - (-0.217) = +0.017  ← WRONG SIGN! (increases u)

Using continuous state_value:
  effective = -0.288 - (-0.217) = -0.071  ← CORRECT (decreases u)
```

**Evidence**: System stuck at steady-state error for 285+ samples (28+ seconds) with wrong control direction

**Fix**: Use continuous state_value instead of discretized action_value:
```matlab
if f_rzutujaca_on == 1 && abs(e) >= dokladnosc_gen_stanu
    funkcja_rzutujaca = (e * (1/Te - 1/Ti));
    % Use continuous state_value instead of discretized action_value
    wart_akcji = stan_value - funkcja_rzutujaca;  % = de + e/Ti (= PI)
end
```
**Impact**: Control now mathematically equals PI: `effective = de + e/Te - e*(1/Te - 1/Ti) = de + e/Ti`
**Note**: This makes projection mode behave exactly like PI controller, with Q-learning disabled during transients (Bug #11)

### Bug #13: Error Threshold Disabled All Learning in Projection Mode (2026-01-16)
**File**: m_regulator_Q.m (lines 199-211, 285-318)
**Problem**: Bug #11 fix disabled learning when `|e| > 2%`, but this prevented almost all learning
- Credit ratio Te/Ti = 0.25 is CONSTANT regardless of error magnitude
- Error threshold doesn't improve credit assignment, just blocks learning
- Combined with 30% exploration rate, effective learning rate dropped to ~5%

**Root Cause Analysis**:
```
The error threshold approach was based on wrong assumption:
  "When error is large, projection dominates, so don't learn"

Reality: The ratio effective/action = Te/Ti is constant!
  Whether e=2% or e=30%, only 25% of Q-action is executed (for Te=5, Ti=20)
  Error threshold doesn't fix credit assignment.

The REAL problem is the "on-trajectory" case:
  When de = -e/Te (system following trajectory):
    state_value = de + e/Te = 0  → Goal state!
    Q selects action = 0 (goal action)
    projection = e * (1/Te - 1/Ti) ≠ 0
    effective = 0 - projection = -projection

  Q did NOTHING, but control came from projection!
  Crediting action=0 for projection's work gives wrong Q-values.
```

**Fix**: Replace error threshold with goal-state check and sign protection:
```matlab
% Remove Bug #11 error threshold (lines 199-211)

% New projection logic (lines 285-318):
if f_rzutujaca_on == 1
    funkcja_rzutujaca = (e * (1/Te - 1/Ti));

    % Turn off projection near goal state (ensures goal action = 0 works)
    near_goal_state = (stan >= nr_stanu_doc - 1) && (stan <= nr_stanu_doc + 1);
    small_error = abs(e) < dokladnosc_gen_stanu;

    if near_goal_state || small_error
        funkcja_rzutujaca = 0;
        wart_akcji = stan_value;
    else
        wart_akcji_po_proj = stan_value - funkcja_rzutujaca;

        % Sign protection: don't let projection flip control direction
        if stan_value ~= 0 && sign(wart_akcji_po_proj) ~= sign(stan_value)
            funkcja_rzutujaca = sign(funkcja_rzutujaca) * abs(stan_value) * 0.9;
            wart_akcji = stan_value - funkcja_rzutujaca;
        else
            wart_akcji = wart_akcji_po_proj;
        end
    end
end
```

**Key Changes**:
1. **Removed error threshold** - allows learning during transients
2. **Projection off near goal state** - ensures goal action (0) produces zero control increment
3. **Sign protection** - projection cannot flip control direction (preserves Q-action intent)
4. **Preserve Q-table action** - when projection disabled, keep learned action (don't override with state_value)

**Impact**: Learning enabled during transients while maintaining correct goal state behavior
