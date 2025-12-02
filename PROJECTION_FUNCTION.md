# Projection Function with Dead Time Compensation - Analysis and Fixes

**Date**: 2025-12-01 (initial), 2025-12-02 (additional bugs)
**Status**: UPDATED - Additional bugs discovered, threshold solution removed

## Problem Statement

When both `T0_controller > 0` (dead time compensation) AND `f_rzutujaca_on = 1` (projection function enabled), the controller exhibited severe performance degradation:

- **Symptom 1**: Controller stuck far from setpoint, oscillating between wrong actions
- **Symptom 2**: Divergence to saturation (0% or 100% control)
- **Symptom 3**: Action 50 (goal action, value=0.000) selected in non-goal states

With `T0_controller = 0`, projection worked correctly. The bug was specific to the combination of projection + dead time compensation.

## Root Cause: Credit Assignment Corruption

### How Dead Time Compensation Works

When `T0_controller > 0`, delayed credit assignment is used:

```matlab
% At iteration k:
1. Observe state s(k), select action a(k)
2. Buffer: bufor_state(k), bufor_wyb_akcja(k)
3. After T0_controller/dt iterations:
4. Retrieve: old_stan_T0 = bufor_state(k-T0), wyb_akcja_T0 = bufor_wyb_akcja(k-T0)
5. Update: Q(old_stan_T0, wyb_akcja_T0) based on current outcome s(k)
```

This ensures actions are credited when their effects are actually observed.

### How Projection Function Works

```matlab
wart_akcji = akcje_sr(wyb_akcja);              % Get action value from Q-table
funkcja_rzutujaca = e * (1/Te - 1/Ti);         % Calculate projection
wart_akcji = wart_akcji - funkcja_rzutujaca;  % Modify action value
u = u + kQ * wart_akcji * dt;                  % Apply to plant
```

For Te=2, Ti=20: `(1/Te - 1/Ti) = 0.5 - 0.05 = 0.45`

With large error (e.g., e=5), projection = 5 × 0.45 = 2.25 (very large!)

### The Incompatibility

**Timeline at iteration k**:

1. **State 37, Error 5.0** (output too low, needs MORE control)
2. **Q-learning selects**: action INDEX 38 → value 0.954 (from Q-table)
3. **Projection modifies**: 0.954 - 2.25 = **-1.296** (completely different!)
4. **Plant receives**: Control with -1.296 (REDUCES control - wrong direction!)
5. **Action INDEX 38 buffered** for later Q-update
6. **After T0_controller delay**: Q-update modifies Q(37, 38)
7. **But**: Outcome was caused by -1.296, NOT 0.954!

**Result**: Q-learning learns "action 38 performed poorly in state 37", even though the plant received a completely different action value. The Q-table becomes corrupted with wrong associations.

### Observed Corruption Patterns

From log analysis (`logi_uczenie.json`):

```
Sample 3214: Error=5.28, State=38, Action=38
  Action value: 0.954
  Projection: 0.264 (27.7% reduction!)
  Effective control: 0.690
  Q-update credits action 38, but plant received 0.690!
```

After many corrupted updates:
- Q(50, 50) became high even in non-goal states
- Controller selected action 50 (zero increment) in states requiring control
- System diverged to saturation

## Failed Fix Attempts

### Attempt 1: Buffer Error for Temporal Consistency

**Hypothesis**: When T0_controller > 0, projection should use the buffered error (from T0 steps ago) that was present when the action was selected.

**Implementation**:
```matlab
[e_T0, bufor_e] = f_bufor(e, bufor_e);
% Apply projection using e_T0 instead of current e
```

**Result**: FAILED - Made it worse. Projection must always use CURRENT error because it modifies control applied RIGHT NOW, not in the past.

### Attempt 2: Map to Effective Action Index

**Hypothesis**: Find which action INDEX corresponds to the projected action VALUE and buffer that index instead.

**Implementation**:
```matlab
% After projection
wart_akcji = wart_akcji - funkcja_rzutujaca;
% Find action index closest to projected value
wyb_akcja_effective = f_find_state(wart_akcji, akcje_sr);
% Buffer effective action instead of original
[wyb_akcja_T0, bufor_wyb_akcja] = f_bufor(wyb_akcja_effective, bufor_wyb_akcja);
```

**Result**: FAILED CATASTROPHICALLY
- Action 50 selected 19,071 times in non-goal states (out of 90K samples)
- Controller diverged to 0% or 100% saturation
- Q-learning learned completely wrong policy

**Why it failed**:
- Q-learning NEEDS to learn "action 50 is wrong in state 46"
- By buffering "effective action", we prevented Q-learning from learning this
- Q(46, 50) never got negative feedback, so action 50 appeared optimal everywhere

### Attempt 3: Prevent Sign Flips

**Hypothesis**: When projection flips action sign, clamp to maintain direction.

**Implementation**:
```matlab
sign_flipped = (wart_akcji_bez_f_rzutujacej * wart_akcji < 0);
if sign_flipped
    if wart_akcji_bez_f_rzutujacej > 0
        wart_akcji = 0.001;  % Minimum positive
    else
        wart_akcji = -0.001;  % Minimum negative
    end
end
```

**Result**: FAILED - Prevented divergence but Q-learning still corrupted because the mapping to effective action was still wrong.

## Final Solution: Disable Q-Learning

**Insight**: You cannot make discrete Q-learning work with projection + dead time when projection significantly modifies actions. The only correct solution is to disable Q-learning when projection corrupts credit assignment.

### Implementation

**File**: `m_regulator_Q.m`, lines 264-277

```matlab
% Apply projection function if enabled
if f_rzutujaca_on == 1 && (stan ~= nr_stanu_doc && stan ~= nr_stanu_doc+1 && ...
        stan ~= nr_stanu_doc-1 && abs(e) >= dokladnosc_gen_stanu)
    funkcja_rzutujaca = (e * (1/Te - 1/Ti));
    wart_akcji = wart_akcji - funkcja_rzutujaca;

    % CRITICAL FIX 2025-12-01: Disable Q-learning when projection + dead time active
    % Rationale: With T0_controller > 0, projection breaks discrete Q-learning credit assignment
    %   - Q-learning selects action INDEX (e.g., action 50 = value 0.000)
    %   - Projection modifies the value (e.g., 0.000 → -0.100)
    %   - Plant receives modified control
    %   - After T0_controller delay, Q-update credits action INDEX 50
    %   - But action 50 represents 0.000, not -0.100!
    %   - Q-learning learns corrupted associations (e.g., "action 50 good in wrong states")
    % Solution: Disable learning when projection significantly modifies action
    %   - Projection still works for control (as it did with T0=0)
    %   - Q-learning only updates when projection is minimal (credit assignment valid)
    if T0_controller > 0 && abs(funkcja_rzutujaca) > 0.05
        uczenie = 0;  % Disable Q-learning when projection corrupts credit assignment
    end
else
    funkcja_rzutujaca = 0;
end
```

### How It Works

1. **Projection still modifies control**: Plant receives projected action (same as T0=0 case)
2. **Q-learning disabled when projection large**: When `abs(funkcja_rzutujaca) > 0.05`
3. **Q-learning enabled when projection small**: When projection ≤ 0.05, credit assignment is valid
4. **Gradual learning near goal**: As error → 0, projection → 0, Q-learning resumes

### Threshold Selection

The threshold `0.05` was chosen as a compromise:
- Too small (e.g., 0.01): Disables almost all learning
- Too large (e.g., 0.5): Allows corrupted learning
- 0.05: Allows learning when action modification < 5% of typical action range

The threshold can be tuned based on:
- Action space granularity
- Maximum projection magnitude
- Acceptable credit assignment error

## Why T0=0 Worked

With `T0_controller = 0`, there is NO delayed credit assignment:
- Action selected → immediately applied → outcome immediately visible
- Q-update uses: `Q(s(k-1), a(k-1))` with outcome `s(k)`
- Even though projection modifies action VALUE, the Q-learning still associates:
  - **State s(k-1)** with **action INDEX a(k-1)** and **observed outcome s(k)**
- The corrupted credit is local (one-step), not accumulated over delays
- Q-learning can still converge (though suboptimally)

With `T0_controller > 0`, the delay amplifies the corruption:
- Action buffered → T0 steps later, plant shows effect
- Meanwhile, system has moved through many states
- Wrong action-outcome associations learned and reinforced over time

## Theoretical Implications

### Fundamental Incompatibility

**Discrete Q-learning assumption**: Each (state, action) pair produces consistent outcomes.

**Projection function reality**: Same (state, action) pair produces VARIABLE outcomes depending on error magnitude.

Example:
- State 37, Action 38, Error 2.0 → Effective action: 0.954 - 0.90 = 0.054
- State 37, Action 38, Error 5.0 → Effective action: 0.954 - 2.25 = -1.296
- **Same (s,a), completely different outcomes!**

This violates Q-learning's Markov assumption when combined with delayed credit assignment.

### Alternative Approaches (Not Implemented)

1. **Continuous action Q-learning**: Learn Q(s, a_value) instead of Q(s, a_index)
   - Requires function approximation (neural networks)
   - Much more complex than discrete Q-learning

2. **Model-based compensation**: Learn model of projection's effect
   - Requires estimating P(s'|s,a,e) where e affects projection
   - Adds complexity and potential instability

3. **Projection without Q-learning**: Use projection only for initialization
   - After initial bumpless transfer, disable projection and rely on Q-learning
   - Loses theoretical benefit of projection during learning

4. **Adaptive projection**: Reduce projection magnitude as Q-learning progresses
   - `projection_weight = max(0, 1 - epoch/max_epochs)`
   - Gradually transition from projection to pure Q-learning
   - Not tested, but theoretically viable

## Experimental Validation Needed

To confirm the fix works:

1. **Test with T0_controller > 0, f_rzutujaca_on = 1**:
   - Should reach setpoint without divergence
   - Q-learning updates should be limited (most iterations uczenie=0)
   - Control should be dominated by projection, not Q-learning

2. **Compare metrics**:
   - T0=0, projection=1 (baseline - known to work)
   - T0>0, projection=0 (staged learning - recommended approach)
   - T0>0, projection=1 (this fix - experimental)

3. **Expected behavior**:
   - Projection provides initial good control (via projection term)
   - Q-learning refines near-goal behavior (where projection ≈ 0)
   - Overall performance may be worse than staged learning (f_rzutujaca_on=0)

## Configuration

### To Test This Fix

```matlab
% config.m
T0 = 3;                  % Plant dead time
T0_controller = 3;       % Controller compensation (matched)
f_rzutujaca_on = 1;      % Enable projection
Te_bazowe = 2;           % Goal time constant
Ti = 20;                 % Integral time (from PI tuning)
```

### Recommended Production Settings (from CLAUDE.md)

```matlab
f_rzutujaca_on = 0;      % Disable projection - use staged learning instead
Te = Ti;                 % Start at Ti for bumpless transfer
% Te reduces gradually: 20 → 2 in 0.1s steps
% Staged learning is proven to work correctly
```

## Files Modified

1. **m_regulator_Q.m** (lines 250-280):
   - Added `uczenie = 0` when `T0_controller > 0 && abs(funkcja_rzutujaca) > 0.05`
   - Removed failed "effective action" mapping code
   - Removed error buffering for projection (was incorrect)

2. **m_inicjalizacja.m** (line 217):
   - Added `bufor_e` initialization (kept for consistency, not actively used)

3. **m_eksperyment_weryfikacyjny.m** (line 97):
   - Added `bufor_e` reset for clean verification tests

## Key Takeaways

1. **Projection + Dead Time + Discrete Q-learning = Fundamentally Incompatible**
   - When projection significantly modifies actions AND credit assignment is delayed
   - Cannot be fixed by clever action mapping

2. **Solution: Disable learning when incompatible**
   - Projection provides control (its original purpose)
   - Q-learning only updates when credit assignment is valid
   - Trade-off: Less learning, but correct learning

3. **Staged Learning is Better** (CLAUDE.md recommendation)
   - No projection (`f_rzutujaca_on = 0`)
   - Te starts at Ti, reduces gradually
   - No credit assignment corruption
   - Proven to work in practice

4. **The fix allows testing projection + dead time combination**
   - For research purposes (comparing approaches)
   - Not recommended for production use
   - Staged learning remains the preferred method

## Additional Bugs Found (2025-12-02)

### Bug #6: Same-Side Constraint Disabled

**Problem**: Lines 61-62 in `m_losowanie_nowe.m` were commented out, disabling same-side matching constraint when `f_rzutujaca_on = 1`.

**Impact**:
- 9,007 constraint violations in 90,051 samples (10% violation rate)
- Controller selected wrong control direction:
  - State 48 < 50 (needs positive control) → Action 51 > 50 (negative control)
  - State 52 > 50 (needs negative control) → Action 49 < 50 (positive control)
- Controller stuck oscillating between states 45-47 with actions near goal action 50
- Actions too close to goal (47-49) provided weak control increment
- 6,058 violations during exploitation (Q-table corrupted by wrong explorations)

**Fix**: Uncommented lines 61-62 to re-enable constraint:
```matlab
if wyb_akcja3 ~= wyb_akcja && wyb_akcja3 ~= nr_akcji_doc && ...
       ((wyb_akcja3 > nr_akcji_doc && stan > nr_stanu_doc) || ...
        (wyb_akcja3 < nr_akcji_doc && stan < nr_stanu_doc))
```

**Result**: Eliminates all constraint violations, prevents oscillation.

### Bug #7: Overly Aggressive Threshold

**Problem**: The 0.05 threshold (implemented to fix credit assignment corruption) was too aggressive:
- With Te=10, Ti=20: projection coefficient = 0.05
- Threshold triggered when `abs(e) > 1%`
- Q-learning disabled for 99% of training duration
- Controller operated almost entirely on projection, minimal Q-learning refinement

**Decision**: Threshold solution REMOVED (2025-12-02)
- Lines 257-270 deleted from `m_regulator_Q.m`
- Q-learning now enabled at all error levels
- Credit assignment mismatch remains (fundamental incompatibility)
- May cause Q-table corruption with large projection coefficients
- **Strongly recommend `f_rzutujaca_on = 0` (staged learning) for production**

### Combined Effect

Both bugs worked together to prevent learning:
1. Bug #6: Constraint disabled → Wrong actions explored → Q-table corrupted
2. Bug #7: Threshold too low → Q-learning rarely active → Corrupted Q-table not corrected

After fixes:
- Constraint prevents wrong explorations
- Q-learning active throughout training
- Still fundamentally incompatible, but may converge with small projection coefficients

## References

- **CLAUDE.md**: Project overview, explains staged learning approach
- **Previous bug**: PROJECTION_LEARNING_PROBLEM.md (analysis of projection with T0=0)
- **Code location**: m_regulator_Q.m lines 250-280
- **Test logs**: logi_uczenie.json (documents failure patterns)

## Future Work

1. **Tune threshold**: The 0.05 threshold may need adjustment based on:
   - Action space density
   - Plant characteristics
   - Acceptable learning rate vs. credit assignment accuracy

2. **Adaptive projection**: Implement gradual reduction of projection weight during training

3. **Comparative study**: Benchmark projection+dead-time vs staged learning on multiple plants

4. **Continuous action Q-learning**: Explore function approximation to handle variable action effects
