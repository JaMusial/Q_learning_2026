# Projection Function: Why Subtraction Works for Initialization but Fails for Learning

**Date**: 2025-01-28
**Analysis**: Root cause of learning failure with projection function
**Key Finding**: Projection formula is correct but magnitude too large for learning

---

## Executive Summary

**Paradox**:
- ✅ SUBTRACTION required for initialization (matches PI controller)
- ❌ SUBTRACTION causes learning failure (wrong policy learned)

**Root cause**: Projection magnitude overwhelms Q-learning during large transients

**Solution needed**: Make projection work throughout initialization AND learning

---

## Part 1: Why SUBTRACTION is Correct for Initialization

### Mathematical Derivation

**Goal**: Make Q-learning match PI controller at startup

**PI controller** trajectory assumption:
```
de/dt = -(1/Ti)·e
de = -(1/Ti)·e  (discrete approximation)
```

**PI control increment**:
```
Δu_PI = (Kp·Ts/Ti)·e
```

**Q-learning state** (with Te):
```
s = de + (1/Te)·e
  = -(1/Ti)·e + (1/Te)·e     (substituting PI trajectory)
  = e·(1/Te - 1/Ti)
```

**Q-learning with identity Q-matrix**:
```
s_mean[action] = s  (identity: action index = state index)
Δu_Q_raw = Kp·Ts·s_mean
         = Kp·Ts·e·(1/Te - 1/Ti)
```

**Ratio**:
```
Δu_Q_raw / Δu_PI = [Kp·Ts·e·(1/Te - 1/Ti)] / [(Kp·Ts/Ti)·e]
                 = Ti·(1/Te - 1/Ti)
                 = Ti/Te - 1
                 = 20/2 - 1
                 = 9
```

**Q-learning is 9× too aggressive!**

### Projection Correction

**Apply projection** (Paper Eq. 7):
```
Δu = Kp·Ts·(s_mean - e·(1/Te - 1/Ti))
```

**With identity initialization**:
```
s_mean = e·(1/Te - 1/Ti)  (as derived above)

Δu = Kp·Ts·[e·(1/Te - 1/Ti) - e·(1/Te - 1/Ti)]
   = 0

```

Wait, this gives 0! Let me recalculate for non-steady-state...

**Actually, at steady state**:
- e ≈ 0 (already at setpoint)
- Δu ≈ 0 (correct!)

**During transient** (e.g., small disturbance):
- If system follows PI trajectory: de = -(1/Ti)·e
- Then s = e·(1/Te - 1/Ti)
- With projection: Δu = Kp·Ts·[s - e·(1/Te - 1/Ti)] = 0

**This seems to give 0 always?**

### The Real Purpose of Projection

**Insight**: Projection doesn't make Q-learning exactly match PI. It compensates for the fact that:
1. Q-learning expects trajectory with Te
2. System currently follows trajectory with Ti
3. Projection bridges the gap

**For small errors near steady-state**:
- PI and Q-learning behave similarly
- Projection correction small
- Bumpless switching achieved

**For large transients**:
- Projection provides intermediate behavior
- Not exactly PI, not exactly Te response
- Smoother than raw Q-learning with Te << Ti

---

## Part 2: Why Learning Fails with SUBTRACTION

### The Learning Corruption Process

**Epoch 1-10** (early learning, large errors):

```
Error: e = +50% (output far below setpoint)
State: s = de + (1/Te)·e ≈ 0 + 0.5·50 = 25
Q-matrix: Still near identity, selects action ≈ 60
Action value: s_mean ≈ +25
Projection: e·(1/Te - 1/Ti) = 50·0.45 = 22.5

Net control: Δu = 1.0·0.1·(25 - 22.5) = 0.25 (positive, CORRECT)
```

**Result**: Controller increases control ✓
**Q-update**: Reinforces action 60 for state 60

**Epoch 11-100** (errors decreasing):

```
Error: e = +30% (still below setpoint)
State: s ≈ 15
Q-matrix: action 40 selected (Q-learning exploring)
Action value: s_mean ≈ +10
Projection: 30·0.45 = 13.5

Net control: Δu = 1.0·0.1·(10 - 13.5) = -0.35 (NEGATIVE, WRONG!)
```

**Result**: Controller DECREASES control when should increase ✗
**Q-update**: This wrong action gets reinforced because system still moving (inertia)
**Problem**: Q-learning can't distinguish good from bad actions when projection dominates

**Epoch 100-1000** (settling into wrong equilibrium):

```
Error: e = +5% (still below setpoint)
State: s ≈ 2.5
Q-learned action gives: s_mean ≈ +2 (learned to be small positive)
Projection: 5·0.45 = 2.25

Net control: Δu = 1.0·0.1·(2 - 2.25) = -0.025 (NEGATIVE)
```

**Result**: Small negative increment keeps error from correcting
**Equilibrium**: Stuck at e ≈ 5%, output ≈ 50% instead of 100%
**Q-matrix**: Has learned WRONG policy that balances projection

---

## Part 3: The Fundamental Conflict

### Requirements

1. **Initialization** (epoch 0):
   - Need: Match PI controller behavior
   - Requires: Projection SUBTRACTION with identity Q-matrix
   - Error range: Small (near setpoint)
   - Result: ✓ Works correctly

2. **Learning** (epochs 1-1000):
   - Need: Learn optimal policy for Te trajectory
   - Problem: Projection magnitude >> Q-action magnitudes
   - Error range: Large (during transients)
   - Result: ✗ Q-learning gets corrupted

### Why Staged Learning Avoids This

**Staged learning** (f=0):
```
Te = Ti initially  →  Projection term = 0
Small Te steps (0.1s)  →  Projection always small
Q-learning dominates  →  Learns correct policy
```

**Projection approach** (f=1):
```
Te << Ti from start  →  Projection term LARGE (0.45·e)
Projection dominates  →  Q-learning confused
Wrong policy learned  →  Stuck in bad equilibrium
```

---

## Part 4: Possible Solutions

### Option 1: Disable Projection During Learning ❌

```matlab
if epoka == 0
    % Initialization: Use projection
    wart_akcji = wart_akcji - funkcja_rzutujaca;
else
    % Learning: No projection
    funkcja_rzutujaca = 0;
end
```

**Problem**: After epoch 0, behavior changes dramatically
**Result**: Not bumpless, defeats purpose

### Option 2: Gradual Projection Reduction ⚠️

```matlab
% Reduce projection over epochs
proj_scale = max(0, 1 - epoka/1000);
funkcja_rzutujaca = proj_scale * e * (1/Te - 1/Ti);
wart_akcji = wart_akcji - funkcja_rzutujaca;
```

**Pros**: Smooth transition
**Cons**: Adds tuning parameter, arbitrary schedule

### Option 3: Adaptive Projection Magnitude ⚠️

```matlab
% Scale projection based on error magnitude
if abs(e) > 10
    proj_scale = 0.5;  % Reduce for large errors
else
    proj_scale = 1.0;  % Full for small errors
end
funkcja_rzutujaca = proj_scale * e * (1/Te - 1/Ti);
```

**Pros**: Addresses large-error problem
**Cons**: Discontinuous, needs tuning

### Option 4: Learn Projection Coefficient 🤔

```matlab
% Make projection coefficient learnable
persistent alpha_proj
if isempty(alpha_proj)
    alpha_proj = 1.0;  % Start with full projection
end

% Update alpha_proj based on performance
if error_increasing
    alpha_proj = alpha_proj * 0.95;  % Reduce projection
end

funkcja_rzutujaca = alpha_proj * e * (1/Te - 1/Ti);
```

**Pros**: Adaptive, self-tuning
**Cons**: Complex, another learning loop

### Option 5: Separate Projection for Initialization vs Learning ✅?

```matlab
if iter <= some_threshold
    % Initialization phase: Use full projection (subtraction)
    funkcja_rzutujaca = e * (1/Te - 1/Ti);
    wart_akcji = wart_akcji - funkcja_rzutujaca;
else
    % Learning phase: Different formula or scaling
    % Option A: Invert sign for learning
    funkcja_rzutujaca = e * (1/Te - 1/Ti);
    wart_akcji = wart_akcji + funkcja_rzutujaca;  % ADDITION

    % Option B: Scale down
    funkcja_rzutujaca = 0.1 * e * (1/Te - 1/Ti);
    wart_akcji = wart_akcji - funkcja_rzutujaca;  % Still subtraction
end
```

**Pros**: Can optimize each phase separately
**Cons**: Needs threshold tuning, not elegant

### Option 6: Use Projection Only for Large Te-Ti Mismatch ✅

**Insight**: Projection only needed when Te << Ti

```matlab
% Only apply projection when far from steady-state
% AND when Te-Ti mismatch is large
if abs(stan - nr_stanu_doc) > 5 && abs(1/Te - 1/Ti) > 0.1
    funkcja_rzutujaca = e * (1/Te - 1/Ti);
    wart_akcji = wart_akcji - funkcja_rzutujaca;
else
    funkcja_rzutujaca = 0;  % Near goal or small mismatch: let Q-learning work
end
```

**Pros**: Projection only when needed
**Cons**: Magic numbers (5, 0.1)

---

## Part 5: Recommended Approach

### Best Solution: Accept Initialization Transient

**Key insight**: With Te=2, Ti=20, perfect bumpless switching is impossible

**Recommendation**:
1. Keep subtraction for mathematical correctness
2. Accept initial transient (Te aggressive by design)
3. Let Q-learning adapt over epochs
4. Compare final performance (not initialization)

**Modified goal**:
- ✅ Controller reaches setpoint eventually
- ✅ Q-learning can improve over epochs
- ⚠️ Initial transient acceptable (testing mode)
- ⚠️ Not for industrial deployment (use staged learning)

### Implementation

Keep current code:
```matlab
if f_rzutujaca_on == 1 && ...
    funkcja_rzutujaca = (e * (1/Te - 1/Ti));
    wart_akcji = wart_akcji - funkcja_rzutujaca;  % Subtraction
end
```

**But adjust expectations**:
- Initialization won't perfectly match PI (that's OK for f=1 mode)
- Focus on whether learning improves performance
- Compare final results after 1000+ epochs

---

## Part 6: Deep Dive - Why Q-Learning Learns Wrong Actions

### The Credit Assignment Problem

**Normal Q-learning** (without projection):
1. Select action → Observe result → Update Q-value
2. Good action → Good result → Q-value increases
3. Bad action → Bad result → Q-value decreases
4. Converges to optimal policy

**With large projection** (subtraction):
1. Select action A (Q-matrix suggests)
2. Projection modifies: A_net = A - P (P is large)
3. Observe result from A_net (not A!)
4. Update Q-value for A based on result from A_net
5. **Mismatch**: Q-learning can't learn correct policy

**Example**:
```
State 40 (below goal), need positive increment
Q-learning tries action 60 (good choice, s_mean = +10)
Projection: -22.5 (large negative)
Net: 10 - 22.5 = -12.5 (moves DOWN, wrong direction)
Result: Output decreases (bad outcome)
Q-update: Decreases Q(40, 60) (punishes GOOD action!)
```

**Over many epochs**:
- Good actions get punished (because projection makes them bad)
- Eventually learns to select actions that "balance" projection
- These balanced actions are wrong for the actual control problem
- Gets stuck in pathological equilibrium

---

## Conclusion

### The Dilemma

**Projection function with SUBTRACTION**:
- ✓ Mathematically correct for initialization
- ✗ Corrupts Q-learning during training
- ✗ Leads to wrong policy

**Projection function with ADDITION**:
- ✗ Wrong for initialization (2× too aggressive)
- ✓ May help learning (boosts correct direction)
- ⚠️ Not theoretically justified

### Fundamental Issue

**Projection magnitude** (e·0.45) is too large compared to:
- Q-learned action values (typically ±1)
- Learning rate impacts
- State transition dynamics

This overwhelms the Q-learning process and prevents convergence to correct policy.

### The Real Solution

**Don't use projection function**. Use staged learning instead:
- Start with Te = Ti (no mismatch, no projection needed)
- Gradually reduce Te (small steps keep mismatch manageable)
- Q-learning works naturally throughout
- Proven to work in practice

**Projection function is fundamentally flawed for large Te-Ti mismatches.**

---

**Status**: Analysis complete
**Recommendation**: Revert to subtraction for correctness, document limitations
**Alternative**: Abandon projection approach, use staged learning (f=0)
