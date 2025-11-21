# Analysis of logi.json - Key Findings

## Overview

This document summarizes insights from analyzing `logi.json`, which contains data from the first 10 training epochs (26,798 samples total).

**Configuration**:
- Setpoint: SP = 100
- Disturbance range: [-0.149, +0.246]
- Precision threshold: ±0.5
- Goal state index: 50
- Goal action index: 50

---

## 1. Overall Performance Statistics

### Success Metrics
- **Samples within precision (|e| < 0.5)**: 7,172 / 26,798 (**26.8%**)
- **Samples in goal state**: 10,523 / 26,798 (**39.3%**)
- **Samples with reward (R > 0)**: 10,523 / 26,798 (39.3%)

### Critical Observation
**When in goal state**:
- Precision achieved: 66.8%
- **Precision FAILED: 33.2%** ← Problem indicator

This means **1 in 3 times** the controller is "on trajectory" (goal state) but error is still too large.

---

## 2. Two Distinct Problem Patterns

### Pattern A: Goal State with Large Error (Samples 157-179)

**Characteristics**:
- Controller stuck in goal state (state 50) for 23+ consecutive samples
- Error: e ≈ +0.832 → +0.793 (slowly decreasing)
- Error derivative: de ≈ -0.017 to -0.023
- State value: s ≈ +0.024 to +0.020 (within goal state bounds ±0.025)
- Action: Forced to 50 (a = 0, Δu = 0)
- Control: Frozen at u = 51.288

**State Calculation**:
```
s = de + e/Te
s = -0.019 + 0.827/20 = +0.023  → In goal state ✓
```

**Ideal Trajectory Check**:
```
de_ideal = -e/Te = -0.827/20 = -0.041
de_actual = -0.019
Deviation: 0.022 (controller NOT on ideal trajectory)
```

**What happens**:
1. Controller enters goal state when s crosses into [-0.025, +0.025]
2. Goal state forces action a=0 → control signal held constant
3. Error decays slowly due to plant dynamics only (no active control)
4. Reward R=1 given despite error >> precision
5. Takes many samples to reduce error naturally

**Key insight**: Being in goal state (s ≈ 0) does NOT mean controller is on ideal exponential trajectory. It just means de and e/Te cancel out to near zero.

---

### Pattern B: Oscillatory Equilibrium at Wrong Steady-State (Samples 12648-17666)

**Characteristics**:
- Duration: 5,018 consecutive samples stuck
- Error: e ≈ -1.72 (mean), range [-1.95, -1.36]
- Output: y ≈ 51.72 (mean), range [51.36, 51.95]
- Control: u ≈ 50.32 (mean), oscillating
- Error derivative: de ≈ 0 (mean -0.000012) ← **Steady-state!**

**State Distribution**:
- State 53: 63.2% of samples (s ≈ -0.087)
- State 52: 28.9% of samples (s ≈ -0.083)
- State 54: 6.3% of samples
- State 51: 1.6% of samples

**Action Distribution**:
- Action 51 (Δu = -0.005): 27.5%
- Action 49 (Δu = +0.005): 24.2%
- Action 47 (Δu = +0.009): 24.1%
- Action 52 (Δu = -0.007): 18.1%
- Action 54 (Δu = -0.011): 4.3%

**Equilibrium Analysis**:
- Positive increments: 2,474 samples, total = +17.63
- Negative increments: 2,544 samples, total = -16.58
- **Net effect: +1.05 over 5,018 samples**
- **Average Δu per sample: +0.0002** ← Essentially zero!

**Net Effect by State**:
- State 52: Net Δu = +0.0067 (slightly positive)
- State 53: Net Δu = -0.0019 (slightly negative)

**What's happening**:
1. Controller oscillates between states 52 ↔ 53
2. Oscillates between positive actions (47, 49) and negative actions (51, 52)
3. Positive and negative actions **cancel each other out**
4. System stuck at wrong steady-state: y ≈ 51.7 instead of SP = 100
5. Error e ≈ -1.72 is constant (de ≈ 0)

**Why this is wrong**:
- Need: y = 51.7 → 100 (increase by 48.3)
- Need: u to increase significantly
- Getting: Net Δu ≈ 0 (no progress)

---

## 3. State Space Structure

### Goal State Boundaries
- **State 50** (goal): s ∈ [-0.0250, +0.0250]
- Width: 0.0500
- This is approximately equal to minimum action increment (precision*2/Te = 0.5*2/20 = 0.05)

### States Around Goal
```
State 45: s ≈ +0.133
State 46: s ≈ +0.114
State 47: s ≈ +0.092
State 48: s ≈ +0.069
State 49: s ≈ +0.029
State 50: s ≈ +0.025  <-- GOAL
State 51: s ≈ -0.045  <-- Note: NEGATIVE despite state number > goal
State 52: s ≈ -0.083
State 53: s ≈ -0.087
State 54: s ≈ -0.103
State 55: s ≈ -0.138
```

**Critical observation**: States 51-54 have **negative state values** but state **numbers > 50** (goal state number). This violates the assumption that state numbering matches state value direction.

---

## 4. Action Space Structure

### Actions Around Goal Action (50)

```
Action 45: a = +0.137, Δu = +0.0137 (large positive)
Action 46: a = +0.112, Δu = +0.0112
Action 47: a = +0.092, Δu = +0.0092
Action 48: a = +0.075, Δu = +0.0075
Action 49: a = +0.050, Δu = +0.0050 (small positive)
Action 50: a = +0.000, Δu = +0.0000 (GOAL - zero increment)
Action 51: a = -0.050, Δu = -0.0050 (small negative)
Action 52: a = -0.075, Δu = -0.0075
Action 53: a = -0.092, Δu = -0.0092
Action 54: a = -0.112, Δu = -0.0112
Action 55: a = -0.137, Δu = -0.0137 (large negative)
```

---

## 5. Exploration vs Exploitation Analysis

### State 52 (Samples 12648-17666)
- **Total samples in state 52**: 1,449
- **Exploration** (33.1%): 479 samples
  - Action 47: 80.2% (384 samples) - Δu = +0.0092
  - Action 46: 5.2% (25 samples) - Δu = +0.0112
  - Action 48: 5.6% (27 samples) - Δu = +0.0075
  - Action 49: 5.6% (27 samples) - Δu = +0.0050
  - Action 52: 3.3% (16 samples) - Δu = -0.0075

- **Exploitation** (66.9%): 970 samples
  - Action 47: 76.6% (743 samples) - Δu = +0.0092
  - Action 51: 23.4% (227 samples) - Δu = -0.0050

### State 53 (Samples 12648-17666)
- **Total samples in state 53**: 3,173
- **Exploration** (31.4%): 995 samples
  - Action 49: 62.0% (617 samples) - Δu = +0.0050
  - Action 52: 23.6% (235 samples) - Δu = -0.0075
  - Action 51: 14.4% (143 samples) - Δu = -0.0050

- **Exploitation** (68.6%): 2,178 samples
  - Action 51: 45.0% (981 samples) - Δu = -0.0050
  - Action 52: 28.8% (628 samples) - Δu = -0.0075
  - Action 49: 26.1% (569 samples) - Δu = +0.0050

---

## 6. Exploration Constraint Behavior

### Constraint Logic (m_losowanie_nowe.m:16-18)

```matlab
if wyb_akcja3~=nr_akcji_doc && wyb_akcja3 ~= wyb_akcja &&...
    ((wyb_akcja > nr_akcji_doc && stan > nr_stanu_doc) ||...
    (wyb_akcja < nr_akcji_doc && stan < nr_stanu_doc))
```

**Interpretation**: Accept random action if:
1. Random action ≠ goal action (50), AND
2. Random action ≠ best action, AND
3. Either:
   - Best action > 50 AND state > 50, OR
   - Best action < 50 AND state < 50

### What Constraint Allows/Blocks for State 52

**State 52** (state number > 50):
- ✓ **Allows**: Actions > 50 (actions 51, 52, 53, ... = NEGATIVE Δu)
- ✗ **Blocks**: Actions < 50 (actions 45, 46, 47, 48, 49 = POSITIVE Δu)

**BUT**: With e ≈ -1.72 (y < SP), we **NEED positive Δu** to increase y!

**However**: During exploration in state 52:
- 95% of selected actions are 46-49 (positive) ✗ Should be blocked?
- 5% are action 52 (negative) ✓ Allowed

**Contradiction**: The constraint should block positive actions in state 52, but they're being selected during exploration anyway. This suggests:
1. The constraint checks `wyb_akcja` (best action), not `wyb_akcja3` (random action)
2. If best action is 47 (< 50), the constraint check `(47 < 50 && 52 < 50)` = FALSE
3. So positive actions get REJECTED when randomly selected
4. Falls back to best action exploitation more frequently

---

## 7. Q-Value Learning Issues

### State 52
**Exploitation behavior**:
- Action 47: Selected 76.6% of time
- Action 51: Selected 23.4% of time

This indicates Q(52, 47) and Q(52, 51) have similar values, with Q(52, 47) slightly higher.

**Problem**: Action 47 (Δu = +0.0092) and Action 51 (Δu = -0.0050) produce **opposite effects**. The fact that both are selected frequently during exploitation means the controller hasn't learned which one is actually better.

### State 53
**Exploitation behavior**:
- Action 51: 45.0%
- Action 52: 28.8%
- Action 49: 26.1%

All three actions selected with similar frequency → Q-values are nearly equal.

**Actions 51 and 52 are negative** (decrease u), **Action 49 is positive** (increase u). With e ≈ -1.72, the correct action is 49 (or larger positive actions). But action 51 is selected most often!

---

## 8. Temporal Evolution (Samples 15000-20000)

### Action Selection Changes Over Time

| Samples | State 53 Dominant Action | Δu | Correct? |
|---------|-------------------------|-----|----------|
| 15000-15999 | Action 49 (48%) | +0.005 | ✓ Yes |
| 16000-16999 | Action 51 (45%) | -0.005 | ✗ No |
| 17000-17999 | Action 51 (60%) | -0.005 | ✗ No |
| 18000-18999 | Action 51 (68%) | -0.005 | ✗ No |
| 19000-19999 | Action 51 (71%) | -0.005 | ✗ No |

**Observation**: Over time, controller increasingly prefers action 51 (wrong direction) over action 49 (correct direction). This suggests Q(53, 51) is increasing relative to Q(53, 49) due to learning updates.

---

## 9. Key Problems Identified

### Problem 1: Goal State Definition Too Permissive
Goal state condition `s ≈ 0` accepts combinations of (e, de) where:
- Controller is NOT on ideal trajectory (de ≠ -e/Te)
- Error is large (|e| >> precision)
- Example: e = 0.83, de = -0.019, s = 0.023 → In goal state but wrong!

### Problem 2: Oscillatory Equilibrium at Wrong Value
- Controller settles at y ≈ 51.7 instead of SP = 100
- Oscillates between states 52 ↔ 53
- Oscillates between positive and negative actions
- Net control increment ≈ 0
- Q-values converged to similar values for opposing actions

### Problem 3: State Numbering vs State Value Mismatch
- States 51-54 have negative state values but state numbers > goal
- Exploration constraint assumes state numbering matches state value sign
- This assumption is violated

### Problem 4: Q-Values Not Distinguishing Good from Bad Actions
- State 52: Q(52, 47) ≈ Q(52, 51) despite opposite effects
- State 53: Q(53, 49) ≈ Q(53, 51) ≈ Q(53, 52) despite different directions
- Controller hasn't learned which actions actually reduce error

### Problem 5: Exploration Insufficient for Large Errors
- Actions 45-48 (large positive corrections) rarely selected
- In state 52: Action 46 only 1.7%, Action 47 dominates at 77.8%
- In state 53: Actions 45-48 almost never selected
- Controller stuck using minimum corrective actions

---

## 10. Measurements for Future Diagnosis

### To Check Goal State Behavior
Look at samples where `stan_nr == 50`:
- Distribution of error values
- Distribution of de values
- How long controller stays in goal state
- Whether error decreases while in goal state

### To Check Equilibrium Points
For any extended range (e.g., 5000+ samples):
- Calculate net Δu (should be non-zero for progress)
- Check error derivative mean (de ≈ 0 indicates steady-state)
- State distribution (stuck in few states?)
- Action oscillation (switching between positive/negative?)

### To Check Q-Value Learning
For specific states:
- Count action selections during exploitation
- If multiple actions selected with similar frequency → Q-values not learned
- Compare positive vs negative action selection rates

### To Check Exploration Effectiveness
For critical states (far from goal):
- Are large corrective actions being explored?
- Is constraint blocking useful exploration?
- What percentage of actions fall back to exploitation?

---

## 11. Sign Conventions (Verified from Data)

```
e = SP - y     (error = setpoint - output)

If y < SP:  e > 0  → Need to increase y → increase u (positive Δu)
If y > SP:  e < 0  → Need to decrease y → decrease u (negative Δu)
```

**Verified**: Sample 15000 has SP=100, y=51.67, e=-1.67 (sign convention ERROR in original logs!)

**Correction**: Logged error appears to be `e = y - SP`, not `e = SP - y`
- When e < 0 in logs: y < SP → need to increase y → positive Δu correct
- When e > 0 in logs: y > SP → need to decrease y → negative Δu correct

**Important**: Verify error sign convention in m_regulator_Q.m to confirm.

---

## 12. Summary Statistics Table

| Metric | Value | Comments |
|--------|-------|----------|
| **Overall Performance** |
| Within precision | 26.8% | Low - target should be >60% |
| In goal state | 39.3% | High relative to precision |
| Goal state quality | 66.8% | 1/3 of goal state samples fail precision |
| **Problem Pattern A (157-179)** |
| Duration | 23+ samples | Stuck in goal with large error |
| Error range | 0.832 → 0.793 | Slow natural decay |
| State | 50 (goal) | Forced action = 0 |
| On ideal trajectory | No | de deviation = 0.022 |
| **Problem Pattern B (12648-17666)** |
| Duration | 5,018 samples | Oscillatory equilibrium |
| Error | -1.72 ± 0.09 | Constant (wrong steady-state) |
| Net Δu | +0.0002/sample | Actions cancel out |
| States | 52 (29%), 53 (63%) | Oscillating |
| Actions | Mixed ± | Conflicting directions |

---

## 13. Questions for Further Investigation

1. **Error sign convention**: Is logged error `e = SP - y` or `e = y - SP`?
2. **Goal state sizing**: Should goal state be narrower to prevent accepting off-trajectory states?
3. **Reward structure**: Should reward consider error magnitude, not just state value?
4. **Exploration constraint**: What is design intent? Is implementation correct?
5. **Q-value initialization**: How are Q-values initialized? Identity matrix?
6. **Learning rate schedule**: Is α constant or decaying?
7. **Epsilon schedule**: Is ε constant at 0.3 throughout training?
8. **State generation**: Why do states 51-54 have negative values but numbers > 50?
9. **Action selection fallback**: What happens after 10 failed exploration attempts?
10. **Episode boundaries**: Are buffers reset between episodes? How does this affect learning?

---

## 14. Data Files Generated

From this analysis, the following files were created:
- `LOGI.md` (this file) - Comprehensive findings from logi.json analysis
- `EXPLORATION_CONSTRAINT_BUG.md` (deleted) - Hypothesized but fix didn't work
- `FIX_APPLIED.md` (deleted) - Attempted fix that was reverted

---

## Notes

This analysis is based on logi.json containing data from the **first 10 training epochs**. The controller is still in early learning phase with Te = 20 (initial value, not yet reduced toward Te_bazowe = 2).

Key limitation: Cannot see full training progression or final performance. Would need logs from later epochs (e.g., 1000+) to understand long-term behavior.
