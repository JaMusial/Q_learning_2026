# Changes Made in Session 2026-01-19

This document describes all changes made during the debugging session to fix projection mode with T0>0.

## Problem Addressed

Controller oscillated between states 46-47 when using projection mode (`f_rzutujaca_on=1`) with dead time compensation (`T0>0`). The system learned well with T0=0 but failed with T0>0.

## Root Causes Identified

1. **Temporal mismatch**: Projection decision used current error while Q-update used buffered error from T0 ago
2. **Buffer timing offset**: State/action buffers were 1 iteration too short, causing Q-updates to credit wrong action

## Changes Made

### Change 1: Fix Projection Temporal Mismatch (Commit 7733c58)

**File**: `m_regulator_Q.m`

**Lines 303-306** - Enabled large_error branch:
```matlab
# BEFORE:
    elseif large_error && 0
        % Large error (transient): Apply projection WITHOUT sign protection
        % This allows proper Te→Ti translation for bumpless transfer
        wart_akcji = wart_akcji - funkcja_rzutujaca;

# AFTER:
    elseif large_error
        % Large error (transient): Apply projection WITHOUT sign protection
        % This allows proper Te→Ti translation for bumpless transfer
        wart_akcji = wart_akcji - funkcja_rzutujaca;
```
**Change**: Removed `&& 0` to enable full projection during large errors for PI-equivalent initialization.

**Lines 253-271** - Added buffered error check to Q-update:
```matlab
# BEFORE:
    %% ========================================================================
    %% Q-learning update
    %% ========================================================================
    % Update Q-value for the BUFFERED state-action pair
    if uczenie_T0 == 1 && pozwolenie_na_uczenia == 1 && stan_T0_for_bootstrap ~= 0 && old_stan_T0 ~= 0
        Q_update = alfa * (R_buffered + gamma * maxS - Q_2d(old_stan_T0, wyb_akcja_T0));
        Q_2d(old_stan_T0, wyb_akcja_T0) = Q_2d(old_stan_T0, wyb_akcja_T0) + Q_update;
    end

# AFTER:
    %% ========================================================================
    %% Q-learning update
    %% ========================================================================
    % FIX 2026-01-19: For projection mode with T0>0, disable learning when buffered error was large
    % Rationale: Large projection dominates control, creating credit assignment mismatch.
    % Q(s,a_raw) would be credited for outcome caused by (a_raw - large_projection).
    % Solution: Use temporally-correct e_T0 (buffered error) to check if learning should occur.
    if f_rzutujaca_on == 1 && T0_controller > 0
        large_error_threshold = dokladnosc_gen_stanu * 2;
        large_error_T0 = abs(e_T0) > large_error_threshold;
    else
        large_error_T0 = false;  % Always allow learning when projection off or T0=0
    end

    % Update Q-value for the BUFFERED state-action pair
    if uczenie_T0 == 1 && ~large_error_T0 && pozwolenie_na_uczenia == 1 && stan_T0_for_bootstrap ~= 0 && old_stan_T0 ~= 0
        Q_update = alfa * (R_buffered + gamma * maxS - Q_2d(old_stan_T0, wyb_akcja_T0));
        Q_2d(old_stan_T0, wyb_akcja_T0) = Q_2d(old_stan_T0, wyb_akcja_T0) + Q_update;
    end
```
**Change**: Added check for buffered error magnitude before Q-update. Learning disabled when `abs(e_T0) > threshold` to prevent credit assignment corruption during large transients.

---

### Change 2: Fix Buffer Timing Offset (Commit d9203a0)

**File**: `m_inicjalizacja.m`

**Lines 212-224** - Increased controller buffer size:
```matlab
# BEFORE:
% Controller compensation buffers (what controller thinks - for delayed credit assignment)
if T0_controller ~= 0
    bufor_state = zeros(1, round(T0_controller/dt));
    bufor_wyb_akcja = zeros(1, round(T0_controller/dt));
    bufor_uczenie = zeros(1, round(T0_controller/dt));
    bufor_e = zeros(1, round(T0_controller/dt));  % Error buffer for projection temporal consistency
    bufor_credit = ones(1, round(T0_controller/dt));  % Credit ratio buffer (1.0 = full credit)
    fprintf('    Controller buffers: T0_controller=%g s, size=%d samples\n', ...
            T0_controller, round(T0_controller/dt));
end

# AFTER:
% Controller compensation buffers (what controller thinks - for delayed credit assignment)
% FIX 2026-01-19: Buffer size = T0_controller/dt + 1 for correct temporal alignment
% Rationale: y[k] reflects u[k-11] (not u[k-10]) due to plant update timing
if T0_controller ~= 0
    buffer_size_controller = round(T0_controller/dt) + 1;
    bufor_state = zeros(1, buffer_size_controller);
    bufor_wyb_akcja = zeros(1, buffer_size_controller);
    bufor_uczenie = zeros(1, buffer_size_controller);
    bufor_e = zeros(1, buffer_size_controller);  % Error buffer for projection temporal consistency
    bufor_credit = ones(1, buffer_size_controller);  % Credit ratio buffer (1.0 = full credit)
    fprintf('    Controller buffers: T0_controller=%g s, size=%d samples (T0/dt + 1)\n', ...
            T0_controller, buffer_size_controller);
end
```
**Change**: Buffer size increased from `round(T0_controller/dt)` to `round(T0_controller/dt) + 1`.

**File**: `m_eksperyment_weryfikacyjny.m`

**Lines 92-101** - Same buffer size fix for verification:
```matlab
# BEFORE:
% Reset controller compensation buffers for clean verification test
if T0_controller ~= 0
    bufor_state = zeros(1, round(T0_controller/dt));
    bufor_wyb_akcja = zeros(1, round(T0_controller/dt));
    bufor_uczenie = zeros(1, round(T0_controller/dt));
    bufor_e = zeros(1, round(T0_controller/dt));  % Error buffer for projection temporal consistency
    bufor_credit = ones(1, round(T0_controller/dt));  % Credit ratio buffer (1.0 = full credit)
end

# AFTER:
% Reset controller compensation buffers for clean verification test
% FIX 2026-01-19: Buffer size = T0_controller/dt + 1 for correct temporal alignment
if T0_controller ~= 0
    buffer_size_controller = round(T0_controller/dt) + 1;
    bufor_state = zeros(1, buffer_size_controller);
    bufor_wyb_akcja = zeros(1, buffer_size_controller);
    bufor_uczenie = zeros(1, buffer_size_controller);
    bufor_e = zeros(1, buffer_size_controller);  % Error buffer for projection temporal consistency
    bufor_credit = ones(1, buffer_size_controller);  % Credit ratio buffer (1.0 = full credit)
end
```
**Change**: Buffer size increased from `round(T0_controller/dt)` to `round(T0_controller/dt) + 1`.

---

## How to Revert Changes

### Option 1: Git Reset (Recommended)

```bash
# Revert to state before this session (before commit 7733c58)
git reset --hard c226625

# Or revert just the two commits from this session
git revert d9203a0 7733c58
```

### Option 2: Manual Revert

**m_regulator_Q.m**:
1. Line 303: Change `elseif large_error` back to `elseif large_error && 0`
2. Lines 253-265: Delete the new large_error_T0 check section
3. Line 268: Remove `&& ~large_error_T0` from the condition

**m_inicjalizacja.m**:
1. Lines 213-214: Remove comments about buffer timing
2. Line 216: Change `buffer_size_controller = round(T0_controller/dt) + 1;` to just use `round(T0_controller/dt)` directly
3. Lines 217-221: Change all `buffer_size_controller` back to `round(T0_controller/dt)`
4. Line 222: Remove "(T0/dt + 1)" from fprintf

**m_eksperyment_weryfikacyjny.m**:
1. Line 93: Remove comment about buffer timing
2. Line 95: Change `buffer_size_controller = round(T0_controller/dt) + 1;` to just use `round(T0_controller/dt)` directly
3. Lines 96-100: Change all `buffer_size_controller` back to `round(T0_controller/dt)`

---

## Git Commits

1. **7733c58** - "Fix temporal mismatch in projection mode with dead time compensation"
2. **d9203a0** - "Fix state/action buffer timing offset for dead time compensation"

## Expected Behavior After Changes

- **Initialization (verification phase 1)**: Q-controller should behave like PI during large setpoint changes
- **Learning**: Controller should learn near setpoint (small errors < 1%), not during transients
- **No oscillation**: States 46-47 oscillation should be eliminated due to correct temporal alignment

## References

- Analysis session: 2026-01-19
- Related bugs: See bugs.md for Bug #11 (credit assignment) and Bug #13 (error threshold issues)
- CLAUDE.md: Documents projection mode limitations for T0>0
