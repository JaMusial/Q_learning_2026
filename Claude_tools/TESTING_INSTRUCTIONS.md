# Testing Instructions for Initialization Fix

## Quick Test

1. **Run verification experiment in MATLAB**:
   ```matlab
   clear all; close all; clc;
   main
   ```

2. **Verify the fix with Python**:
   ```bash
   cd Claude_tools
   python3 verify_fix.py
   ```

3. **Expected output**:
   ```
   Phase 1 (SP tracking):
     Mean control difference: < 0.5%
     Max control difference:  < 2.0%
     Status: ✓ PASS

   Phase 2 (Disturbance):
     Mean control difference: < 0.5%
     Status: ✓ PASS

   Phase 3 (Recovery):
     Mean control difference: < 0.5%
     Status: ✓ PASS

   ✓✓✓ FIX SUCCESSFUL!
   ```

## Visual Verification

After running `main.m`, check the generated plots:
- Q-controller and PI-controller should overlap during Phase 1
- Control signal should show same "rise-drop-rise" pattern for both controllers

## What Changed

The fix modifies projection behavior in `m_regulator_Q.m`:

**Before**:
- Sign protection blocked projection at state 49 during transients
- Q-controller stayed at u ≈ 49% (flat)
- PI-controller dropped to u ≈ 40% then rose (dynamic)
- **Result**: Controllers diverged by ~2-9% during Phase 1

**After**:
- Sign protection disabled for large errors (|e| > 1%)
- Projection allowed to flip sign during transients (essential for Te→Ti translation)
- Both controllers follow same trajectory
- **Result**: Controllers match within ~0.5% during Phase 1

## Detailed Analysis

Use the analysis tools:

```bash
cd Claude_tools

# Phase-by-phase comparison
python3 analyze_verification_phases.py

# Control signal patterns
python3 compare_phase_behavior.py

# Sample-by-sample trace
python3 analyze_transient_problem.py
```

## Configuration Requirements

Ensure in `config.m`:
```matlab
f_rzutujaca_on = 1;          % Projection mode enabled
Te_bazowe = 5;               % Goal time constant
Ti = 20;                     % PI integral time
dokladnosc_gen_stanu = 0.5;  % Precision (sets error thresholds)
```

The fix uses `dokladnosc_gen_stanu * 2 = 1.0%` as the threshold between:
- Large errors: Sign protection OFF (allow bumpless transfer)
- Small errors: Sign protection ON (prevent oscillation)

## Troubleshooting

### If Phase 1 still shows large difference (> 1%):

1. **Check projection is enabled**:
   ```matlab
   % In MATLAB after running main.m:
   assert(f_rzutujaca_on == 1, 'Projection must be enabled');
   ```

2. **Check logs show projection active**:
   ```bash
   python3 -c "
   import json
   import numpy as np
   with open('../logi_before_learning.json') as f:
       logs = json.load(f)
   proj = np.array(logs['Q_funkcja_rzut'][19:2000])
   print(f'Projection active: {np.sum(np.abs(proj) > 0.01)} / {len(proj)} samples')
   "
   ```
   - Should show > 90% of samples have active projection

3. **Verify error threshold**:
   ```matlab
   % In MATLAB:
   fprintf('Large error threshold: %.2f%%\n', dokladnosc_gen_stanu * 2);
   % Should print: 1.00%
   ```

### If Phases 2&3 show degraded performance:

This is unexpected - the fix only affects behavior when |e| > 1%, which rarely occurs in Phases 2&3. If this happens:

1. Check if small error threshold changed
2. Verify sign protection still active for 0.5% < |e| < 1%
3. Review m_regulator_Q.m lines 299-319

## Success Criteria

**Minimum acceptable**:
- Phase 1: mean < 1.0%, max < 5.0%

**Target (bumpless transfer)**:
- Phase 1: mean < 0.5%, max < 2.0%
- Phase 2: mean < 0.5%
- Phase 3: mean < 0.5%

## Next Steps After Verification

If fix is successful:
1. Run full training experiment (set `max_epoki = 5000` in config.m)
2. Compare before/after learning performance
3. Check if Q-learning improves beyond PI baseline

If fix is not successful:
1. Save current logs: `cp logi_before_learning.json logi_before_learning_FAILED.json`
2. Report results and analysis output
3. May need to investigate alternative approaches (e.g., use stan_value directly in projection)
