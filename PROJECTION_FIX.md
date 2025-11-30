# Projection Function Fix

**Date**: 2025-01-28
**Issue**: Projection function caused wrong control direction
**Status**: ✅ FIXED - Sign corrected

---

## Problem Identified

The projection function implementation had **wrong sign**, causing control to move in opposite direction from setpoint.

### Observed Behavior (Before Fix)

With `f_rzutujaca_on = 1`, after 1000 epochs:
- Output stuck at 44.89% (setpoint: 100%)
- Error: +5.11% (positive, output below setpoint)
- Q-action: -0.28
- Projection: +2.30
- Net control: `-0.28 - 2.30 = -2.58` ❌ (decreased control when should increase)

**Result**: Controller trapped in limit cycle, cannot reach setpoint.

---

## Root Cause

**File**: `m_regulator_Q.m`, line 242 (before fix)

```matlab
funkcja_rzutujaca = (e * (1/Te - 1/Ti));
wart_akcji = wart_akcji - funkcja_rzutujaca;  // ❌ SUBTRACTION
```

**Why this is wrong**:
- When output below setpoint: error `e > 0` (positive)
- With Te < Ti: `(1/Te - 1/Ti) > 0` (positive)
- Therefore: `funkcja_rzutujaca > 0` (positive)
- Subtracting positive value makes control MORE negative
- This drives output DOWN when it should go UP
- **Opposite of required direction!**

---

## Fix Applied

**File**: `m_regulator_Q.m`, line 244 (after fix)

```matlab
funkcja_rzutujaca = (e * (1/Te - 1/Ti));
wart_akcji = wart_akcji + funkcja_rzutujaca;  // ✅ ADDITION
```

**Why this is correct**:
- When output below setpoint: `e > 0`, projection `> 0`
- Adding positive value makes control MORE positive
- This drives output UP toward setpoint ✓
- Correct direction!

**Example calculation** (same scenario as before):
- Q-action: -0.28
- Projection: +2.30
- Net control: `-0.28 + 2.30 = +2.02` ✅ (increases control correctly)

---

## Expected Behavior After Fix

### Initialization (epoch 0)
- Should still match PI controller behavior
- Bumpless switching verified in original experiment ✓

### During Learning (epochs 1-1000)
With corrected sign:
- Controller should now be able to reach setpoint
- Projection provides additional "boost" toward faster response
- Q-learning can now learn meaningful policy
- No limit cycle (should explore multiple states)

### After Learning (verification)
Expected improvements:
- Output reaches ~100% (matches setpoint)
- Steady-state error ~0%
- Visits multiple states (not stuck in limit cycle)
- Control direction correct

**However**: Performance still likely worse than staged learning (f=0) because:
- Large initial transient (Te=2 vs Ti=20)
- Projection magnitude still large (may dominate Q-learning)
- No gradual adaptation

But it should at least **work** and reach the setpoint.

---

## Testing Protocol

### Quick Verification

Run short test to verify fix works:

```matlab
% config.m
f_rzutujaca_on = 1;     % Projection enabled (fixed version)
max_epoki = 100;        % Short test
poj_iteracja_uczenia = 0;  % Full verification

% Run
clear all; close all; clc
main
```

**Check after training**:
1. Plot `logi.Q_y` - should reach ~100% in verification
2. Check `logi.Q_e` - should settle near 0%
3. Check `logi.Q_stan_nr` - should visit many states, not just 2
4. Check `logi.Q_u_increment` - should be positive initially

### Full Training

Once verified working:

```matlab
% config.m
f_rzutujaca_on = 1;
max_epoki = 1000;       % Full training

% Run
clear all; close all; clc
main
save('results_projection_fixed.mat')
```

**Success criteria**:
- IAE finite (not diverging)
- Output tracks setpoint in verification experiment
- Steady-state error < 1%
- No limit cycle behavior

---

## Verification Checklist

After running experiment, check:

- [ ] Output reaches setpoint (95-105% range acceptable)
- [ ] Steady-state error < 1%
- [ ] Controller visits > 5 different states
- [ ] Control increment has correct sign when error > 0
- [ ] No oscillation or limit cycle
- [ ] Q-matrix shows learning (values change over epochs)

If all checks pass: ✅ Fix successful

---

## Code Changes Summary

**File modified**: `m_regulator_Q.m`

**Line 242** (before):
```matlab
wart_akcji = wart_akcji - funkcja_rzutujaca;
```

**Line 244** (after):
```matlab
wart_akcji = wart_akcji + funkcja_rzutujaca;
```

**Lines 242-243** (added comments):
```matlab
% FIXED 2025-01-28: Changed from subtraction to addition
% For Te < Ti and positive error, projection is positive and should INCREASE control
```

---

## Understanding the Projection Term

### Physical Meaning

The projection term compensates for trajectory mismatch:

**PI controller** assumes trajectory with time constant `Ti`:
```
ė = -(1/Ti)·e
```

**Q-learning target** trajectory with time constant `Te`:
```
ė = -(1/Te)·e
```

**Mismatch**: When Te ≠ Ti, the derivative term differs by:
```
Δė = -(1/Te)·e - (-(1/Ti)·e) = e·(1/Ti - 1/Te)
```

**Correction needed**: To compensate, add term proportional to this difference:
```
Δu_correction = K·e·(1/Te - 1/Ti)
```

This is the projection function!

### When It Helps

Projection is beneficial when:
1. Starting with large Te-Ti mismatch
2. Want immediate aggressive response (Te << Ti)
3. Q-learning hasn't adapted yet
4. Temporary boost during transition

### Limitations

Even with correct sign:
1. **Large magnitude**: For Te=2, Ti=20, coefficient = 0.45 (huge)
2. **Dominates Q-learning**: Learned actions get overwhelmed
3. **Not adaptive**: Fixed formula, doesn't learn
4. **Requires tuning**: Only works for specific Te-Ti ranges

This is why staged learning is better - it eliminates the mismatch gradually.

---

## Next Steps

1. **Test the fix**: Run 100 epoch experiment to verify it works
2. **Verify metrics**: Check that output reaches setpoint
3. **Compare performance**: Quantify IAE, settling time, overshoot
4. **Document results**: Record that fix enables basic functionality
5. **Note limitations**: Document remaining issues (large transient, etc.)

---

## Expected Outcome

### Realistic Expectations

With the sign fix:
- ✅ Controller should reach setpoint
- ✅ No limit cycle
- ✅ Q-learning can function
- ⚠️ Large initial transient (expected with Te=2, Ti=20)
- ⚠️ Slower convergence than staged learning
- ⚠️ Projection still dominates Q-learning

**Bottom line**: Fix makes it **functional** but not **optimal**.

For optimal performance, staged learning (f=0) remains superior.

---

## Conclusion

**Problem**: Projection function had wrong sign (subtraction instead of addition)

**Fix**: Changed line 242 in `m_regulator_Q.m` from `-` to `+`

**Status**: Ready for testing

**Expected**: Controller should now work and reach setpoint (though with limitations)

Test with short run (100 epochs) to verify, then proceed with full training.

---

**Document Status**: Fix applied, ready for experimental validation
**Next Action**: Run test experiment to confirm fix resolves issue
