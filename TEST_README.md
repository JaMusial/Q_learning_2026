# Dead Time Implementation Tests

## Overview

`test_dead_time.m` - Comprehensive test suite to verify that dead time compensation works correctly in plant models **without any controller in the loop**.

## What It Tests

### Test 1: Buffer Function Verification
- Verifies `f_bufor()` FIFO buffer operates correctly
- Checks filling phase (outputs zeros)
- Checks steady-state (output = input delayed by T0)

### Test 2: Step Response Timing
Tests all major plant models (1, 3, 5, 8) with various dead times:
- **T0 = 0s** (baseline - no dead time)
- **T0 = 1s** (small dead time)
- **T0 = 2s** (moderate)
- **T0 = 3s** (large)
- **T0 = 5s** (very large)

Verifies that:
- ✓ Response starts exactly T0 seconds after step input
- ✓ Timing error < 2×dt tolerance (0.02s)

### Test 3: Response Shape Comparison
- Verifies T0>0 response is identical to T0=0 response, just time-shifted
- Calculates RMS difference between shifted responses
- Should be <1% difference (confirms pure delay, no distortion)

## How to Run

### Quick Test
```matlab
>> test_dead_time
```

The script will:
1. Run all tests automatically (takes ~30-60 seconds)
2. Print results to console
3. Generate figures showing step responses

### Expected Output

```
========================================
  DEAD TIME IMPLEMENTATION TEST
========================================

TEST 1: f_bufor() Function Verification
----------------------------------------
  ✓ PASSED: f_bufor() operates correctly

TEST 2: Step Response with Dead Time
----------------------------------------
Testing Model 1 (Order: 1, T=[5], k=1.000)
  Response start times (5% threshold):
    T0=0.0s: Response at t=5.00s (expected: 5.00s, error: 0.000s) ✓
    T0=1.0s: Response at t=6.00s (expected: 6.00s, error: 0.000s) ✓
    T0=2.0s: Response at t=7.00s (expected: 7.00s, error: 0.000s) ✓
    ...
  ✓ PASSED: All dead time delays are correct

...

========================================
  TEST SUMMARY
========================================
Model 1: ✓ PASSED
Model 3: ✓ PASSED
Model 5: ✓ PASSED
Model 8: ✓ PASSED

✓ ALL TESTS PASSED
Dead time implementation is working correctly!
```

## Interpreting Results

### Figures Generated
For each model, the test creates a 2-panel figure:

**Top panel**: Output responses for different T0 values
- Each curve should be identical in shape
- Later curves shifted right by T0
- All should reach same steady-state

**Bottom panel**: Delayed control signals
- Shows step input after buffering
- Visualizes the T0 delay clearly

### What "PASSED" Means
- ✓ **Timing correct**: Response starts at t = (step_time + T0)
- ✓ **Shape preserved**: Time-shifted response matches T0=0 baseline (<1% RMS error)
- ✓ **No distortion**: Dead time implementation doesn't alter system dynamics

### What "FAILED" Means
- ✗ **Timing error**: Response starts too early or too late
  - Could indicate: Wrong buffer size calculation, incorrect dt
- ✗ **Shape mismatch**: Response shape different from baseline
  - Could indicate: Buffer corrupting signal, double-delaying, model issue

## Models Tested

| Model | Type | Time Constants | Gain | Notes |
|-------|------|----------------|------|-------|
| 1 | 1st order | T = [5] | k = 1.0 | Simple inertia |
| 3 | 2nd order | T = [5, 2] | k = 1.0 | Two inertias |
| 5 | 3rd order | T = [2.34, 1.55, 9.38] | k = 1.0 | Multi-inertia |
| 8 | 3rd order pneumatic | T = [2.34, 1.55, 9.38] | k = 0.386 | Nonlinear (realistic) |

Models 2 and 4 are deprecated aliases, so they're not tested separately.

## Configuration

You can modify test parameters at the top of `test_dead_time.m`:

```matlab
dt = 0.01;              % Simulation timestep [s]
simulation_time = 50;   % Total simulation time [s]
u_step = 50;            % Step magnitude [%]
step_time = 5;          % When to apply step [s]
T0_values = [0, 1, 2, 3, 5];  % Dead times to test [s]
```

## Troubleshooting

### Test fails for large T0
- **Cause**: Simulation time too short
- **Fix**: Increase `simulation_time` in script (e.g., to 100s for T0=10s)

### "No response detected"
- **Cause**: System very slow, or threshold too high
- **Fix**: Increase `simulation_time` or adjust threshold calculation

### Timing error > tolerance
- **Cause**: Buffer size calculation incorrect
- **Fix**: Check `round(T0/dt)` gives correct number of samples

### Shape mismatch (>1% RMS)
- **Cause**: Buffer corrupting signal, or model internal issue
- **Fix**: Debug f_bufor() output, check model states initialization

## Next Steps

After verifying dead time works in open loop:

1. **Test with Q-controller**: Run `main.m` with T0 > 0, `reakcja_na_T0 = 0`
2. **Characterize performance**: How does learning degrade with increasing T0/T ratio?
3. **Compare methods**: Test simple buffering vs state augmentation
4. **Real system**: Validate on physical pneumatic system

## Related Files

- `f_bufor.m` - FIFO buffer implementation
- `f_obiekt.m` - Plant model simulation
- `m_inicjalizacja.m` - Sets T0 parameter for Q-learning experiments
- `m_regulator_Q.m` - Uses buffers for dead time compensation
- `DEAD_TIME_IMPLEMENTATION.md` - Full analysis and recommendations

## Contact

For questions about this test:
- **Jakub Musiał** - Silesian University of Technology
- **Email**: Via Prof. Jacek Czeczot (jacek.czeczot@polsl.pl)
