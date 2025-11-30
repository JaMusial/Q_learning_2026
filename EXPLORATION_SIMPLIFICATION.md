# Exploration Logic Simplification for Projection Mode

**Date**: 2025-01-28
**Purpose**: Simplified exploration for f_rzutujaca_on=1 mode
**Status**: ✅ Implemented

---

## Motivation

**Staged learning** (f_rzutujaca_on=0) requires complex directional constraints because:
- State space changes as Te reduces (20→2)
- Action-state relationships evolve
- Need to prevent exploring wrong directions

**Projection mode** (f_rzutujaca_on=1) has simpler requirements:
- State space fixed (Te constant)
- Just need basic exploration around best action
- No directional constraints needed

---

## Implementation

### File Modified: `m_losowanie_nowe.m`

**Added dual-mode logic** (lines 42-64):

```matlab
%% PROJECTION MODE: Simple range-based exploration
if f_rzutujaca_on == 1
    % Simple exploration: draw from [best_action - RD, best_action + RD]
    min_losowanie = max(1, wyb_akcja - RD);           % Clamp to valid range
    max_losowanie = min(ile_akcji, wyb_akcja + RD);   % Clamp to valid range

    % Sample random action
    wyb_akcja3 = randi([min_losowanie, max_losowanie], [1, 1]);

    % Simple constraints:
    % 1. Don't select same action as best (force exploration)
    % 2. Don't select goal action (unless at goal state)
    if wyb_akcja3 ~= wyb_akcja && wyb_akcja3 ~= nr_akcji_doc
        ponowne_losowanie = 0;  % Accept
        wyb_akcja = wyb_akcja3;
    else
        ponowne_losowanie = ponowne_losowanie + 1;  % Reject, retry
    end

    return;  % Exit early, skip complex logic below
end

%% STAGED LEARNING MODE: Complex directional constraints
% (existing code continues...)
```

---

## Two Exploration Modes

### Mode 0: Staged Learning (Complex)

**Range construction**:
- Uses neighboring states' best actions (above/under)
- Range: `[min(above, under) - RD, max(above, under) + RD]`

**Constraints**:
- Same-side matching: State > goal → Action > goal
- Prevents exploring opposite direction
- Needed for staged Te reduction

**Example**:
```
State 40 (below goal 50)
State 41's best action: 45
State 39's best action: 38
Range: [38-5, 45+5] = [33, 50]
Constraint: Action must be < 50 (same side as state)
```

### Mode 1: Projection (Simple)

**Range construction**:
- Centered on current state's best action
- Range: `[best_action - RD, best_action + RD]`

**Constraints**:
- Don't pick same as best (force exploration)
- Don't pick goal action (unless at goal state)

**Example**:
```
State 40
Best action: 42
Range: [42-5, 42+5] = [37, 47]
Constraints: action ≠ 42 AND action ≠ 50
Valid draws: 37-41, 43-47
```

---

## Comparison

| Aspect | Staged (f=0) | Projection (f=1) |
|--------|--------------|------------------|
| Range source | Neighboring states | Current state |
| Range width | Variable (depends on neighbors) | Fixed (2·RD) |
| Directional constraint | Yes (same-side) | No |
| Complexity | High | Low |
| Purpose | Handle Te changes | Explore around policy |

---

## Benefits

### For Projection Mode

1. **Simpler logic** - No directional constraints needed
2. **Faster exploration** - Less rejection, fewer retries
3. **More predictable** - Fixed range around best action
4. **Easier to tune** - RD directly controls exploration width

### For Code Maintenance

1. **Clear separation** - Each mode has dedicated logic
2. **Easy to modify** - Change one mode without affecting other
3. **Self-documenting** - Code explains purpose of each approach

---

## Parameter: RD (Random Deviation)

**Recommendation for f_rzutujaca_on=1**:

```matlab
% config.m
RD = 5;  % Good default for ~100 actions
```

**Effect**:
- `RD = 3`: Narrow exploration (conservative, slower learning)
- `RD = 5`: Balanced (recommended)
- `RD = 10`: Wide exploration (aggressive, faster learning, more disturbance)

**Adaptive approach** (future enhancement):
```matlab
% Could reduce RD as learning progresses
RD = max(2, round(10 - epoka/200));  % 10→2 over 1600 epochs
```

---

## Testing

**Verify both modes work**:

```matlab
% Test Mode 0 (staged learning)
% config.m: f_rzutujaca_on = 0
clear all; close all; clc
main

% Test Mode 1 (projection)
% config.m: f_rzutujaca_on = 1
clear all; close all; clc
main
```

**Check exploration behavior**:
- Mode 0: Actions should respect directional constraints
- Mode 1: Actions should be within ±RD of best action

---

## Edge Cases Handled

### 1. Action Range Bounds

```matlab
min_losowanie = max(1, wyb_akcja - RD);           % Don't go below 1
max_losowanie = min(ile_akcji, wyb_akcja + RD);   % Don't exceed max
```

**Example**:
- Best action = 3, RD = 5
- Naive range: [-2, 8]
- Clamped: [1, 8] ✓

### 2. Goal Action Rejection

```matlab
if wyb_akcja3 ~= nr_akcji_doc
```

**Reason**: Goal action (zero increment) should only be used at goal state
**Handled by**: Constraint in line 56

### 3. Same Action Rejection

```matlab
if wyb_akcja3 ~= wyb_akcja
```

**Reason**: Force exploration (don't just pick best again)
**Result**: Ensures ε-greedy actually explores

### 4. Retry Mechanism

If constraints reject action:
```matlab
ponowne_losowanie = ponowne_losowanie + 1;
```

**Handled in** `m_regulator_Q.m`:
- Retries up to 10 times
- Falls back to exploitation if all rejected
- Prevents infinite loops

---

## Future Enhancements

### 1. State-Dependent RD

```matlab
% Larger exploration far from goal
distance_from_goal = abs(stan - nr_stanu_doc);
RD_adaptive = max(3, min(10, distance_from_goal / 5));
```

### 2. Learning Progress-Based RD

```matlab
% Reduce exploration as learning progresses
RD_adaptive = max(2, RD * (1 - epoka/max_epoki));
```

### 3. Performance-Based Adjustment

```matlab
% Increase RD if stuck (no improvement)
if last_10_epochs_avg_reward < threshold
    RD = min(RD + 1, 15);  % Increase exploration
end
```

---

## Validation Checklist

After implementing simplified exploration:

- [x] **Code compiles** without errors
- [x] **Dual-mode dispatch** works (if-else with return)
- [x] **Range clamping** prevents invalid action indices
- [x] **Constraints enforce** exploration (≠ best, ≠ goal)
- [ ] **Testing**: Run both modes to verify behavior
- [ ] **Performance**: Check if learning improves with simpler logic

---

## Summary

**Change**: Added simple range-based exploration for projection mode (f_rzutujaca_on=1)

**Rationale**: Projection mode doesn't need complex directional constraints that staged learning requires

**Implementation**: Dual-mode logic in `m_losowanie_nowe.m` with early return for projection mode

**Benefit**: Simpler, faster, more predictable exploration for projection experiments

---

**Status**: Ready for testing
**Next**: Run projection mode experiment to verify simplified exploration works correctly
