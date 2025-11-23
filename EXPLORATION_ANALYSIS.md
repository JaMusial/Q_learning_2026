# Exploration Mechanism Analysis

## Executive Summary

**CRITICAL BUG IDENTIFIED**: The exploration constraint logic in `m_losowanie_nowe.m` is **inverted**, causing it to reject correct exploration in **50% of the state space** (states 51-100).

**Impact**:
- Exploration fails in states with negative state values (s < 0)
- System falls back to exploitation, reinforcing wrong actions
- Q-values converge to incorrect policies
- Controller gets stuck in oscillatory equilibrium at wrong steady-state

**Root Cause** (m_losowanie_nowe.m:16-18):
```matlab
% CURRENT (WRONG):
((wyb_akcja > nr_akcji_doc && stan > nr_stanu_doc) || ...
 (wyb_akcja < nr_akcji_doc && stan < nr_stanu_doc))

% Should be:
((wyb_akcja < nr_akcji_doc && stan > nr_stanu_doc) || ...  % FLIPPED
 (wyb_akcja > nr_akcji_doc && stan < nr_stanu_doc))        % FLIPPED
```

**Why**: State > 50 means s < 0 (below trajectory), requiring positive Δu (action < 50), but current logic expects action > 50.

---

## Overview

This document provides a detailed analysis of the exploration process in the Q2d Q-learning controller, focusing on `m_losowanie_nowe.m` and the action selection logic in `m_regulator_Q.m`.

---

## 1. Epsilon-Greedy Framework

### Basic Structure (m_regulator_Q.m:147-168)

```matlab
a = randi([0, 100], [1, 1]) / 100;  % Random value [0, 1]

if eps >= a
    % EXPLORATION (30% of time when eps_ini=0.3)
    ponowne_losowanie = 1;
    while ponowne_losowanie > 0 && ponowne_losowanie <= max_powtorzen_losowania_RD
        m_losowanie_nowe
    end
    if ponowne_losowanie >= max_powtorzen_losowania_RD
        [Q_value, wyb_akcja] = f_best_action_in_state(Q_2d, stan, nr_akcji_doc);
    end
    uczenie = 1;
    czy_losowanie = 1;

elseif stan ~= 0
    % EXPLOITATION (70% of time)
    [Q_value, wyb_akcja] = f_best_action_in_state(Q_2d, stan, nr_akcji_doc);
    uczenie = 0;
    czy_losowanie = 0;
end
```

**Key Configuration**:
- `eps_ini = 0.3` → 30% exploration probability
- `max_powtorzen_losowania_RD = 10` → Max 10 attempts before fallback to exploitation

**Critical Observation**: If exploration fails 10 times, the system falls back to **exploitation** (best action), but still sets `uczenie=1` and `czy_losowanie=1`. This means failed exploration is treated as successful exploration for Q-learning purposes.

---

## 2. Exploration Sampling Range Calculation

### Neighboring States Best Actions (m_regulator_Q.m:122-133)

Before sampling, the algorithm retrieves best actions from neighboring states:

```matlab
% State above (stan+1)
if stan + 1 > ilosc_stanow
    wyb_akcja_above = wyb_akcja;  % Use current if at boundary
else
    [Q_value_state_above, wyb_akcja_above] = f_best_action_in_state(Q_2d, stan+1, nr_akcji_doc);
end

% State below (stan-1)
if stan - 1 < 1
    wyb_akcja_under = wyb_akcja;  % Use current if at boundary
else
    [Q_value_state_under, wyb_akcja_under] = f_best_action_in_state(Q_2d, stan-1, nr_akcji_doc);
end
```

### Range Construction (m_losowanie_nowe.m:3-15)

```matlab
[Q_value, wyb_akcja] = f_best_action_in_state(Q_2d, stan, nr_akcji_doc);

if wyb_akcja_above < wyb_akcja_under
    min_losowanie = wyb_akcja_under - RD;
    max_losowanie = wyb_akcja_above + RD;
else
    min_losowanie = wyb_akcja_above - RD;
    max_losowanie = wyb_akcja_under + RD;
end

if max_losowanie > min_losowanie
    wyb_akcja3 = randi([min_losowanie, max_losowanie], [1, 1]);
else
    wyb_akcja3 = randi([max_losowanie, min_losowanie], [1, 1]);
end
```

**Design Intent**: Create a sampling range that spans the best actions of neighboring states ± RD (random deviation).

**Example**:
- Current state: 52
- Best action (state 52): 47
- Best action (state 53, above): 51
- Best action (state 51, under): 47
- RD = 5

Since 51 > 47:
- `min_losowanie = 47 - 5 = 42`
- `max_losowanie = 51 + 5 = 56`

Sampling range: **[42, 56]** (15 possible actions)

**Adaptive Behavior**: The range adapts to what neighboring states have learned, creating a "neighborhood exploration" strategy rather than uniform random exploration.

---

## 3. Exploration Constraint Logic

### The Critical Filter (m_losowanie_nowe.m:16-23)

```matlab
if wyb_akcja3 ~= nr_akcji_doc && wyb_akcja3 ~= wyb_akcja && ...
    ((wyb_akcja > nr_akcji_doc && stan > nr_stanu_doc) || ...
     (wyb_akcja < nr_akcji_doc && stan < nr_stanu_doc))
    ponowne_losowanie = 0;   % Accept random action
    wyb_akcja = wyb_akcja3;
else
    ponowne_losowanie = ponowne_losowanie + 1;  % Reject, retry
end
```

### Constraint Conditions (ALL must be true to ACCEPT)

1. **`wyb_akcja3 ~= nr_akcji_doc`** → Random action ≠ goal action (50)
   - Prevents random selection of zero-increment action

2. **`wyb_akcja3 ~= wyb_akcja`** → Random action ≠ best action
   - Ensures actual exploration (trying something new)

3. **Direction matching** (ONE of these must be true):
   - **`wyb_akcja > nr_akcji_doc && stan > nr_stanu_doc`**
     - Best action > 50 AND state number > 50
   - **`wyb_akcja < nr_akcji_doc && stan < nr_stanu_doc`**
     - Best action < 50 AND state number < 50

---

## 4. Constraint Design Philosophy

### Intended Behavior

The constraint attempts to enforce **directional consistency**:
- If state number > goal (50) → Best action should be > 50 (negative Δu)
- If state number < goal (50) → Best action should be < 50 (positive Δu)

### Assumed State-Action Relationship

The constraint assumes:
```
State number > 50  →  State value > 0  →  Need negative Δu  →  Action > 50
State number < 50  →  State value < 0  →  Need positive Δu  →  Action < 50
```

**This assumption is VIOLATED in the actual state space!**

---

## 5. Actual State Space Structure (from logi.md)

### States Around Goal (Actual Values)

```
State 45: s ≈ +0.133   (positive value, number < 50) ✓ Assumption holds
State 46: s ≈ +0.114
State 47: s ≈ +0.092
State 48: s ≈ +0.069
State 49: s ≈ +0.029
State 50: s ∈ [-0.025, +0.025]  ← GOAL STATE
State 51: s ≈ -0.045   (NEGATIVE value, number > 50) ✗ Assumption VIOLATED
State 52: s ≈ -0.083   (NEGATIVE value, number > 50) ✗ Assumption VIOLATED
State 53: s ≈ -0.087   (NEGATIVE value, number > 50) ✗ Assumption VIOLATED
State 54: s ≈ -0.103   (NEGATIVE value, number > 50) ✗ Assumption VIOLATED
State 55: s ≈ -0.138
```

**Critical Finding**: States 51-54 have **negative state values** but state **numbers > 50**. The numbering convention does NOT match the sign of the state value.

### Why This Breaks the Constraint

For **State 52** (s ≈ -0.083):
- State value is negative → System below trajectory
- Need: **Positive Δu** to increase s → Actions < 50 (correct)
- Observed best action: **47** (< 50) ✓ Correct direction
- State number: **52** (> 50)

Constraint check:
```matlab
(wyb_akcja < nr_akcji_doc && stan < nr_stanu_doc)
(47 < 50 && 52 < 50)
(TRUE && FALSE) = FALSE  ✗ REJECTED
```

The constraint **REJECTS** random exploration when the best action is correct!

---

## 6. Consequence: Exploration Failure in Critical States

### Typical Scenario in States 51-54

1. **Exploration triggered** (eps ≥ a)
2. **Sampling range calculated**: e.g., [42, 56]
3. **Random action selected**: e.g., action 48
4. **Constraint evaluated**:
   - action 48 ≠ 50 ✓
   - action 48 ≠ 47 (best) ✓
   - (47 < 50 && 52 < 50) = FALSE ✗
5. **Action REJECTED**, `ponowne_losowanie += 1`
6. **Retry** up to 10 times
7. All random actions likely rejected (same constraint)
8. **Fallback to exploitation** after 10 failures
9. Select best action (47) anyway, but with `uczenie=1`

### Empirical Evidence from logi.md

**State 52 exploration behavior (samples 12648-17666)**:
- Total samples in exploration mode: 479
- Action 47: 80.2% (384 samples) ← This is the BEST action
- Actions 46, 48, 49, 52: 19.8% combined

**Analysis**: 80% of "exploration" samples selected the best action (47), indicating the constraint rejected most random samples and fell back to exploitation while keeping the exploration flag set.

---

## 7. Impact on Q-Learning

### Learning Flag Logic

```matlab
if uczenie == 1 && pozwolenie_na_uczenia == 1 && stan_T0 ~= 0 && old_stan_T0 ~= 0
    Q_update = alfa * (R + gamma * maxS - Q_2d(old_stan_T0, wyb_akcja_T0));
    Q_2d(old_stan_T0, wyb_akcja_T0) = Q_2d(old_stan_T0, wyb_akcja_T0) + Q_update;
end
```

**Key**: Q-updates only occur when `uczenie == 1`

### Three Cases:

1. **True Exploration** (random action accepted):
   - `uczenie = 1` ✓
   - Updates Q(state, random_action)
   - Explores new state-action pairs

2. **Failed Exploration** (fallback to best action):
   - `uczenie = 1` ✓ (still set!)
   - Updates Q(state, best_action)
   - **Reinforces existing policy instead of exploring**

3. **Exploitation** (eps < a):
   - `uczenie = 0` ✗
   - No Q-update
   - Pure policy execution

### Problem: Failed Exploration Updates Best Action

When exploration fails and falls back to the best action, the system:
- Takes the best action (no exploration benefit)
- Updates Q(s, best_action) as if it explored (reinforces existing policy)
- Counts as exploration in statistics (`czy_losowanie = 1`)

This creates a **positive feedback loop**:
1. Best action is wrong direction
2. Constraint rejects random exploration
3. Fallback reinforces wrong best action
4. Q(s, wrong_action) increases
5. Wrong action becomes even more "best"
6. Cycle repeats

---

## 8. Why Oscillatory Equilibrium Occurs

### State 52-53 Oscillation Mechanism (logi.md samples 12648-17666)

#### Initial Conditions
- Error: e ≈ -1.72 (y ≈ 51.7, SP = 100)
- Need: Increase y → Positive Δu → Actions < 50

#### State 52 (63.2% of samples)
**Exploitation (66.9%)**:
- Action 47: 76.6% → Δu = +0.0092
- Action 51: 23.4% → Δu = -0.0050

**Exploration (33.1%)** - mostly failed, fallback to action 47

**Net effect**: Mixed positive/negative, Q-values for actions 47 and 51 are similar

#### State 53 (29.9% of samples)
**Exploitation (68.6%)**:
- Action 51: 45.0% → Δu = -0.0050
- Action 52: 28.8% → Δu = -0.0075
- Action 49: 26.1% → Δu = +0.0050

**Net effect**: Predominantly negative actions selected

#### Combined Result Over 5,018 Samples
- Positive increments: 2,474 samples, total = +17.63
- Negative increments: 2,544 samples, total = -16.58
- **Net Δu: +1.05 over 5,018 samples**
- **Average: +0.0002 per sample** ≈ **ZERO**

#### Why Q-Values Converged Incorrectly

1. **Sparse reward structure**: R=1 only at goal state (50)
2. **Bootstrapping from similar states**: Q(52, a) learns from max(Q(53, ·))
3. **States 52 and 53 have similar Q-values** → Similar action preferences
4. **Positive and negative actions get similar rewards** via bootstrapping
5. **Temporal difference learning averages effects** over oscillations
6. **System stabilizes at local equilibrium** where net Δu ≈ 0

---

## 9. Temporal Evolution: Learning in Wrong Direction

### State 53 Action Selection Over Time (logi.md)

| Samples     | Dominant Action | Δu     | Correct? | Selection % |
|-------------|----------------|--------|----------|-------------|
| 15000-15999 | Action 49      | +0.005 | ✓ Yes    | 48%         |
| 16000-16999 | Action 51      | -0.005 | ✗ No     | 45%         |
| 17000-17999 | Action 51      | -0.005 | ✗ No     | 60%         |
| 18000-18999 | Action 51      | -0.005 | ✗ No     | 68%         |
| 19000-19999 | Action 51      | -0.005 | ✗ No     | 71%         |

**Observation**: Over time, Q(53, 51) grows relative to Q(53, 49), causing **increasing preference for the WRONG action**.

**Mechanism**:
1. Actions 49 and 51 initially have similar Q-values
2. Both get selected during exploration/exploitation
3. Both lead to oscillation between states 52 ↔ 53
4. Bootstrapping from max(Q(52, ·)) and max(Q(53, ·))
5. Random fluctuations cause Q(53, 51) to drift higher
6. Positive feedback: Higher Q → More selection → More updates → Even higher Q
7. **Convergence to wrong action**

---

## 10. Goal State Trapping

### Pattern A from logi.md (Samples 157-179)

**Scenario**: Controller enters goal state with large error

```
Sample 157: e = 0.832, de = -0.019, s = 0.023
State: 50 (goal) → Forced action: 50 (Δu = 0)
Control: u = 51.288 (frozen)
```

**Ideal trajectory check**:
```
de_ideal = -e/Te = -0.832/20 = -0.0416
de_actual = -0.019
Deviation: 0.0226 (NOT on trajectory!)
```

**What happens**:
1. State value s = de + e/Te = -0.019 + 0.832/20 = 0.023
2. Goal state bounds: [-0.025, +0.025]
3. s = 0.023 is within bounds → Enter goal state
4. Force action = 50 (Δu = 0)
5. Reward R = 1 (despite e = 0.832 >> precision = 0.5)
6. Control frozen, error decays slowly via plant dynamics
7. Stuck for 23+ samples until s drifts out of goal state

**Root cause**: Goal state condition `|s| < 0.025` accepts states where de and e/Te cancel out, but the system is NOT on the ideal trajectory.

---

## 11. Summary of Issues

### Issue 1: **CRITICAL BUG - Constraint Logic Inverted**
- **Design**: State numbering DOES match state value sign ✓
- **Bug**: Constraint logic is **backwards** - enforces OPPOSITE relationship
- **Current logic**: State > 50 requires Action > 50 (negative Δu)
- **Correct logic**: State > 50 requires Action < 50 (positive Δu)
- **Impact**: Constraint rejects ALL correct exploration in states 51-100 (half the state space!)

### Issue 2: Failed Exploration Reinforces Wrong Policy
- **Design**: Exploration should try new actions
- **Reality**: After 10 rejections, falls back to best action
- **Impact**: Sets `uczenie=1`, updates Q(s, best_action), reinforcing existing policy

### Issue 3: Positive Feedback Loop
- Failed exploration → Fallback to best action → Q-update reinforces it → Best action becomes stronger → Future exploration also fails → Loop

### Issue 4: Oscillatory Equilibrium
- **Cause**: Q-values for opposing actions converge to similar values
- **Mechanism**: Bootstrapping between oscillating states 52 ↔ 53
- **Result**: Net Δu ≈ 0, stuck at wrong steady-state

### Issue 5: Learning Wrong Actions Over Time
- Q(53, 51) increases relative to Q(53, 49)
- Wrong action (negative Δu) becomes preferred over correct action (positive Δu)
- Random drift + positive feedback → Convergence to suboptimal policy

### Issue 6: Goal State Too Permissive
- Accepts s ≈ 0 even when NOT on ideal trajectory
- Gives reward for off-trajectory states
- Freezes control with large error present

---

## 12. Key Design Questions

### 1. What is the purpose of the exploration constraint?
**Hypothesis**: Prevent exploration from selecting "obviously wrong" actions
**Problem**: Assumes state numbering = state value sign (violated)

### 2. Should failed exploration update Q-values?
**Current**: Yes (`uczenie=1` even after fallback)
**Alternative**: Set `uczenie=0` if `ponowne_losowanie >= max` (only update on successful exploration)

### 3. Should the constraint check state VALUE or state NUMBER?
**Current**: Checks state NUMBER (stan)
**Alternative**: Check state VALUE (stan_value = de + e/Te)

### 4. Should goal state bounds be tighter?
**Current**: Width = 0.05 (accepts s ∈ [-0.025, +0.025])
**Alternative**: Additional check: Is system on trajectory? (|de + e/Te| < threshold AND |de - de_ideal| < threshold)

### 5. Should Q-updates occur during exploitation?
**Current**: Only during exploration (`uczenie=1`)
**Standard Q-learning**: Update on ALL transitions
**Alternative**: Always update, or use separate on-policy/off-policy learning

---

## 13. State Numbering Convention - VERIFIED

### State Generation Process (f_generuj_stany_v2.m)

The state table is generated through the following process:

1. **Generate positive actions geometrically** (lines 6-26):
   ```matlab
   akcje = [0, precision*2/Te, (precision*2/Te)*q, (precision*2/Te)*q^2, ...]
   ```
   - Minimum action: `precision*2/Te` (e.g., 0.05 for Te=20, precision=0.5)
   - Geometric growth with ratio q

2. **Generate states as midpoints** (lines 28-30):
   ```matlab
   stany(i) = (akcje(i+1) + akcje(i)) / 2
   ```
   - Creates representative values for positive states

3. **Mirror to create full space** (lines 32-33):
   ```matlab
   stany = [flip(stany), -stany]
   akcje = [flip(akcje), -akcje(2:end)]
   ```
   - Result: `stany = [large_pos, ..., small_pos, small_neg, ..., large_neg]`
   - Table is in **DESCENDING order**

4. **Goal state index** (line 37):
   ```matlab
   state_doc = floor(no_of_states/2) + 1  % e.g., 51 for 100 states
   ```

### State Assignment Logic (f_find_state.m)

Since `table(1) > 0` (positive), the **descending branch** is used (lines 34-56):

```matlab
% For descending table:
if e < table(end)       → stan = n+1  (out of bounds, large negative)
elseif e > table(1)     → stan = 1    (out of bounds, large positive)
else                    → find first i where e > table(i), set stan = i
```

**This creates the mapping**:
- **State 1**: Largest positive state values (s >> 0)
- **States 2-49**: Decreasing positive values
- **State 50-51**: Near zero (goal region)
- **States 52-100**: Increasingly negative values (s << 0)
- **State 101**: Out of bounds (s << table(end))

### Critical Finding: State Numbering MATCHES Value Sign

**The constraint assumption is CORRECT**:
- State number < 50 → State value > 0 (positive)
- State number > 50 → State value < 0 (negative)

**BUT the constraint logic is INVERTED**!

Let me trace the constraint for **State 52** (negative state value):

```matlab
% Observed: e ≈ -1.72, need positive Δu to increase y
% Best action: 47 (Δu = +0.0092, CORRECT direction)
% State: 52 (> 50, negative state value)

% Constraint check:
(wyb_akcja > nr_akcji_doc && stan > nr_stanu_doc) || ...
(wyb_akcja < nr_akcji_doc && stan < nr_stanu_doc)

% Substituting:
(47 > 50 && 52 > 50) || (47 < 50 && 52 < 50)
(FALSE && TRUE) || (TRUE && FALSE)
FALSE || FALSE = FALSE  ✗ REJECTED
```

### The Logic Error

**State 52 (s < 0)** needs **positive Δu** → **Action < 50** ✓ (action 47 is correct)

**But the constraint expects**:
- State > 50 → Action > 50 (negative Δu) ✗ WRONG

**The constraint is backwards!** It should be:
```matlab
% Correct logic:
(wyb_akcja < nr_akcji_doc && stan > nr_stanu_doc) || ...  % Flipped!
(wyb_akcja > nr_akcji_doc && stan < nr_stanu_doc)         % Flipped!
```

**Explanation**:
- State value s = de + e/Te
- If s < 0 (state > 50): System below desired trajectory
  - Need to increase state value → Need positive Δu
  - Positive Δu → Action < 50 ✓
- If s > 0 (state < 50): System above desired trajectory
  - Need to decrease state value → Need negative Δu
  - Negative Δu → Action > 50 ✓

The current constraint enforces the OPPOSITE relationship!

---

## 14. Recommendations for Investigation

### Immediate Diagnostics

1. **Log constraint rejections**: Track how often constraint rejects per state
2. **Compare state number vs state value**: Scatter plot
3. **Track Q-value evolution**: Plot Q(52, 47) and Q(52, 51) over time
4. **Measure true exploration rate**: % samples where random action != best action

### Potential Fixes (Analysis Only - No Implementation)

1. **FIX THE INVERTED CONSTRAINT LOGIC** (m_losowanie_nowe.m:16-18):
   ```matlab
   % CURRENT (WRONG):
   if wyb_akcja3~=nr_akcji_doc && wyb_akcja3 ~= wyb_akcja &&...
       ((wyb_akcja > nr_akcji_doc && stan > nr_stanu_doc) ||...
        (wyb_akcja < nr_akcji_doc && stan < nr_stanu_doc))

   % CORRECTED:
   if wyb_akcja3~=nr_akcji_doc && wyb_akcja3 ~= wyb_akcja &&...
       ((wyb_akcja < nr_akcji_doc && stan > nr_stanu_doc) ||...  % FLIPPED
        (wyb_akcja > nr_akcji_doc && stan < nr_stanu_doc))       % FLIPPED
   ```
   **Rationale**: State > 50 means s < 0 (below trajectory), needs positive Δu (action < 50)

2. **Disable learning on failed exploration**:
   ```matlab
   if ponowne_losowanie >= max_powtorzen_losowania_RD
       uczenie = 0;  % Don't update if exploration failed
   ```

3. **Tighten goal state definition**:
   ```matlab
   de_ideal = -e/Te;
   on_trajectory = abs(de - de_ideal) < threshold;
   if (stan == nr_stanu_doc) && on_trajectory
   ```

4. **Remove constraint entirely**: Trust epsilon-greedy to balance exploration/exploitation

5. **Always update Q-values**: Set `uczenie=1` for both exploration and exploitation (standard Q-learning)

---

## Contact

Analysis by Claude Code (Anthropic)
Based on Q2d controller by Jakub Musiał, Silesian University of Technology
