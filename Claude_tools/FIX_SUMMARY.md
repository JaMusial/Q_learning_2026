# Initialization Problem Fix - Summary

**Date**: 2026-01-18
**Issue**: Q-controller and PI-controller diverge during Phase 1 (SP tracking) of verification experiment, but match well in Phases 2 & 3 (disturbance/recovery).

## Problem Analysis

### Symptoms
- **Phase 1** (SP step 20→50%): Mean control difference = **1.96%**, max = **9.25%**
- **Phase 2** (Disturbance): Mean control difference = **0.30%** ✓
- **Phase 3** (Recovery): Mean control difference = **0.23%** ✓

### Root Cause

**Sign protection was blocking projection during large transients:**

1. During SP step (e=30%), Q-controller selects state 49:
   - Action value from Q-matrix: +0.2
   - Projection term: e × (1/Te - 1/Ti) = 30 × 0.15 = **+4.5**
   - Final action: 0.2 - 4.5 = **-4.3** (negative)

2. Old code detected sign flip and **disabled projection**:
   ```matlab
   if sign(wart_akcji_po_proj) ~= sign(wart_akcji)
       funkcja_rzutujaca = 0;  % BLOCKED!
   end
   ```

3. **Result**:
   - Q-controller stuck at u ≈ 49% (no projection applied)
   - PI-controller correctly drops to u ≈ 40% then rises
   - Controllers diverge during entire transient (~100s)

### Why Phases 2 & 3 Worked

By Phase 2, errors were already small (< 1%), so:
- Projection term small (< 0.3)
- Sign flips rare
- Sign protection rarely triggered
- Controllers matched well

## Solution Implemented

**File**: `m_regulator_Q.m` (lines 287-322)

**Change**: Conditional sign protection based on error magnitude

### Three Error Regimes

1. **Very small error** (|e| ≤ 0.5%):
   ```matlab
   funkcja_rzutujaca = 0;  % No projection needed at setpoint
   ```

2. **Large error** (|e| > 1.0%):
   ```matlab
   wart_akcji = wart_akcji - funkcja_rzutujaca;
   % Allow sign flip - essential for bumpless transfer!
   ```

3. **Small error** (0.5% < |e| ≤ 1.0%):
   ```matlab
   if sign_would_flip
       funkcja_rzutujaca = 0;  % Prevent oscillation
   else
       wart_akcji = wart_akcji - funkcja_rzutujaca;
   end
   ```

### Threshold Definition

```matlab
large_error_threshold = dokladnosc_gen_stanu * 2;  % 0.5 * 2 = 1.0%
very_small_error = abs(e) <= dokladnosc_gen_stanu;  % ≤ 0.5%
large_error = abs(e) > large_error_threshold;       % > 1.0%
```

## Expected Results

### Before Fix
```
Phase 1: u_Q ≈ 49% (flat), u_PI: 50% → 40% → 48% (dynamic)
         Mean difference: 1.96%
Phase 2: Mean difference: 0.30%
Phase 3: Mean difference: 0.23%
```

### After Fix
```
Phase 1: Both controllers should follow same trajectory
         Expected mean difference: < 0.5%
Phase 2: Should remain at 0.30% (unchanged)
Phase 3: Should remain at 0.23% (unchanged)
```

## Testing

Run verification experiment in MATLAB:
```matlab
clear all; close all; clc;
config;
m_inicjalizacja;

% Ensure projection mode enabled
assert(f_rzutujaca_on == 1, 'Set f_rzutujaca_on=1 in config.m');

% Run before-learning verification
main;
```

Check results:
```matlab
% Phase 1 analysis (samples 19-2006)
phase1_idx = 19:2006;
u_diff = abs(logi_before_learning.Q_u(phase1_idx) - logi_before_learning.PID_u(phase1_idx));
fprintf('Phase 1 mean u difference: %.3f%%\n', mean(u_diff));
fprintf('Phase 1 max u difference: %.3f%%\n', max(u_diff));

% Expected: mean < 0.5%, max < 2%
```

## Design Rationale

### Why Allow Sign Flip for Large Errors?

The projection function translates control from Te→Ti dynamics:

```
PI control:    u_inc = Kp × dt × (de + e/Ti)
Q with proj:   u_inc = Kp × dt × [(de + e/Te) - e×(1/Te - 1/Ti)]
                     = Kp × dt × (de + e/Ti)  ← MATCHES!
```

For this to work, projection MUST be allowed to dominate (and flip sign) during transients when:
- Q-matrix is untrained (identity initialization)
- Errors are large (e > 1%)
- Projection provides the "PI-like" control behavior

### Why Keep Sign Protection for Small Errors?

Near setpoint (0.5% < e < 1.0%):
- Q-table learning should start to dominate
- Sign flips could cause oscillation
- Protection provides smooth handoff from projection → Q-learning

## Files Modified

1. **m_regulator_Q.m** (lines 287-322)
   - Added conditional sign protection logic
   - Defined large_error_threshold
   - Three-regime error handling

## Related Documentation

- Original bug analysis: `Claude_tools/INITIALIZATION_PROBLEM_SOLUTION.md`
- Phase behavior analysis: `Claude_tools/phase_behavior_comparison.png`
- Verification tools: `Claude_tools/analyze_*.py`

## Notes

This fix is specific to **projection mode** (f_rzutujaca_on=1). Staged learning mode (f_rzutujaca_on=0) is unaffected and continues to be the recommended approach per CLAUDE.md.
