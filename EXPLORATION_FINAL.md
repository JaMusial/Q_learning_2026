# Final Exploration Logic - Both Modes

**Date**: 2025-01-28
**Status**: ✅ Complete - Both modes have directional constraints
**File**: `m_losowanie_nowe.m`

---

## Overview

Both projection mode (f=1) and staged learning mode (f=0) now use **same-side matching constraint** to ensure correct exploration direction. The only difference is the **range source**.

---

## Constraints (Both Modes)

### 1. Force Exploration
```matlab
wyb_akcja3 ~= wyb_akcja
```
Don't select same action as current best → forces actual exploration

### 2. Goal Action Protection
```matlab
wyb_akcja3 ~= nr_akcji_doc
```
Don't select goal action unless at goal state

### 3. Same-Side Matching (Directional)
```matlab
(wyb_akcja3 > nr_akcji_doc && stan > nr_stanu_doc) ||  % Both on same side
(wyb_akcja3 < nr_akcji_doc && stan < nr_stanu_doc)     % Both on same side
```

**Logic**:
- **State > goal** (below trajectory) → **Action > goal** (negative control increment)
- **State < goal** (above trajectory) → **Action < goal** (positive control increment)

**Why needed**: Prevents exploring opposite direction from goal, ensures convergence

---

## Mode Differences

### Mode 0: Staged Learning (f_rzutujaca_on=0)

**Range Source**: Neighboring states' best actions
```matlab
min_losowanie = min(wyb_akcja_above, wyb_akcja_under) - RD
max_losowanie = max(wyb_akcja_above, wyb_akcja_under) + RD
```

**Rationale**:
- State space changes as Te reduces
- Neighboring states guide exploration
- Adapts to evolving policy

**Example**:
```
State 40 (below goal 50)
State 41's best action: 45
State 39's best action: 38
Range: [38-5, 45+5] = [33, 50]
Constraint: Action must be > 50 (same side as state 40 > 50)
Valid: None! Will retry or fallback
```

### Mode 1: Projection (f_rzutujaca_on=1)

**Range Source**: Current state's best action ± RD
```matlab
min_losowanie = max(1, wyb_akcja - RD)
max_losowanie = min(ile_akcji, wyb_akcja + RD)
```

**Rationale**:
- State space fixed (Te constant)
- Explore around current policy
- Simpler, more predictable range

**Example**:
```
State 40 (below goal 50)
Best action: 60
Range: [60-5, 60+5] = [55, 65]
Constraint: Action must be > 50 (same side as state 40 > 50)
Valid: 55-65 (all satisfy constraint) ✓
```

---

## Constraint Logic (Identical for Both Modes)

```matlab
if wyb_akcja3 ~= wyb_akcja && ...                           % Not best action
   wyb_akcja3 ~= nr_akcji_doc && ...                        % Not goal action
   ((wyb_akcja3 > nr_akcji_doc && stan > nr_stanu_doc) || ...  % Same side
    (wyb_akcja3 < nr_akcji_doc && stan < nr_stanu_doc))        % Same side

    ponowne_losowanie = 0;  % Accept
    wyb_akcja = wyb_akcja3;
else
    ponowne_losowanie = ponowne_losowanie + 1;  % Reject, retry
end
```

---

## Why Same-Side Matching is Critical

### Without Constraint (broken)

```
State 40 (below goal 50, need to move toward 50)
Action 30 selected (also below goal)
Result: Moves AWAY from goal → divergence
```

### With Constraint (correct)

```
State 40 (below goal 50)
Constraint: Action must be > 50 (opposite side)
Action 60 selected
Result: Moves TOWARD goal → convergence ✓
```

---

## Index Interpretation

**State/Action arrays**: Ordered as [high values → 0 → low values]

**Example** (101 states/actions):
```
Index 1:   Large positive s (far above trajectory)
Index 50:  Zero (goal state/action)
Index 100: Large negative s (far below trajectory)
```

**Directional logic**:
- Index < 50: Positive control increment (increase u)
- Index = 50: Zero increment (maintain)
- Index > 50: Negative control increment (decrease u)

---

## Retry Mechanism

**In m_regulator_Q.m**:
```matlab
ponowne_losowanie = 1;
while ponowne_losowanie > 0 && ponowne_losowanie <= max_powtorzen_losowania_RD
    m_losowanie_nowe
end
```

**Behavior**:
- Try up to 10 times to find valid action
- If all rejected → fallback to exploitation (select best action)
- Sets `uczenie = 0` (don't update Q-values for fallback)

**Why needed**:
- Constraint may reject many random draws
- Prevents infinite loop
- Ensures algorithm always progresses

---

## Comparison: Range Sources

| Aspect | Staged (f=0) | Projection (f=1) |
|--------|--------------|------------------|
| **Range center** | Between neighbors | Current best action |
| **Range width** | Variable | Fixed (2·RD) |
| **Adaptation** | Follows policy evolution | Static around policy |
| **Rejection rate** | Higher (narrow range) | Lower (centered) |
| **Purpose** | Track changing Te | Explore fixed space |

---

## Tuning Parameter: RD

**Effect on both modes**:
- **RD = 3**: Conservative, narrow exploration
- **RD = 5**: Balanced (recommended)
- **RD = 10**: Aggressive, wide exploration

**Trade-off**:
- Larger RD → More exploration → Faster learning → More disturbance
- Smaller RD → Less exploration → Slower learning → More stable

**Recommendation**:
```matlab
RD = 5;  % Good default for ~100 action space
```

---

## Testing Verification

**Check constraint logic works**:

```matlab
% Scenario 1: State below goal
stan = 60;          % Below goal (50)
nr_stanu_doc = 50;
nr_akcji_doc = 50;

wyb_akcja3 = 55;    % Action also below goal
% Constraint: (55 > 50 && 60 > 50) → TRUE ✓ Accept

wyb_akcja3 = 45;    % Action above goal
% Constraint: (45 < 50 && 60 > 50) → FALSE ✗ Reject

% Scenario 2: State above goal
stan = 40;          % Above goal (50)

wyb_akcja3 = 45;    % Action also above goal
% Constraint: (45 < 50 && 40 < 50) → TRUE ✓ Accept

wyb_akcja3 = 55;    % Action below goal
% Constraint: (55 > 50 && 40 < 50) → FALSE ✗ Reject
```

---

## Summary

**Both modes now share**:
- ✅ Same-side matching constraint
- ✅ Goal action protection
- ✅ Force exploration (≠ best)

**Key difference**:
- Mode 0: Range from **neighboring states** (adaptive)
- Mode 1: Range from **best action** (fixed)

**Result**: Robust exploration for both approaches, each optimized for its use case.

---

**Status**: Implementation complete and tested
**Files**: `m_losowanie_nowe.m` (lines 42-69 for projection mode)
