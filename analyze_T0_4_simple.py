#!/usr/bin/env python3
"""
Analyze T0=4 convergence issues without numpy dependency
Uses pure Python for JSON analysis
"""

import json
import math

# Configuration
T0_CONTROLLER = 4
GOAL_STATE = 50
GOAL_ACTION = 50
GAMMA = 0.99
THEORETICAL_MAX = 1 / (1 - GAMMA)

print("="*70)
print("T0=4 CONVERGENCE ANALYSIS (Pure Python)")
print("="*70)
print()

# Load JSON data
print("Loading T0=4 debug logs...")
with open('logi_T0=4_max_epoki=50.json', 'r') as f:
    data = json.load(f)

n_iterations = len(data['DEBUG_goal_Q'])
print(f"Loaded {n_iterations} iterations\n")

# ========================================================================
# SECTION 1: GOAL Q-VALUE EVOLUTION
# ========================================================================
print("="*70)
print("SECTION 1: GOAL Q-VALUE EVOLUTION")
print("="*70)
print()

# Find all goal state updates
goal_updates = [i for i, v in enumerate(data['DEBUG_is_updating_goal']) if v == 1]
n_goal_updates = len(goal_updates)
print(f"Total goal state updates: {n_goal_updates}")

# Analyze goal Q-value trajectory
goal_Q_values = [data['DEBUG_goal_Q'][i] for i in goal_updates]
print(f"Initial Q(50,50): {goal_Q_values[0]:.4f}")
print(f"Final Q(50,50): {goal_Q_values[-1]:.4f}")
print(f"Theoretical max: {THEORETICAL_MAX:.4f}")
gap = THEORETICAL_MAX - goal_Q_values[-1]
gap_pct = 100 * gap / THEORETICAL_MAX
print(f"Gap: {gap:.4f} ({gap_pct:.1f}%)\n")

# Check if still increasing
if n_goal_updates >= 100:
    early_vals = goal_Q_values[:50]
    late_vals = goal_Q_values[-50:]
    early_mean = sum(early_vals) / len(early_vals)
    late_mean = sum(late_vals) / len(late_vals)

    print(f"Early average (first 50 updates): {early_mean:.4f}")
    print(f"Late average (last 50 updates): {late_mean:.4f}")
    increase = late_mean - early_mean
    increase_pct = 100 * increase / early_mean
    print(f"Increase: {increase:.4f} ({increase_pct:.1f}%)")

    if late_mean > early_mean:
        print("✓ Goal Q-value still increasing (needs more training)\n")
    else:
        print("⚠️  Goal Q-value plateaued or decreasing\n")

# ========================================================================
# SECTION 2: REWARD DISTRIBUTION
# ========================================================================
print("="*70)
print("SECTION 2: REWARD DISTRIBUTION ANALYSIS")
print("="*70)
print()

# Overall reward statistics
learning_updates = [i for i, v in enumerate(data['DEBUG_uczenie_T0']) if v == 1]
total_updates = len(learning_updates)
R1_updates = sum(1 for i in learning_updates if data['DEBUG_R_buffered'][i] == 1)

print(f"Total Q-updates: {total_updates}")
print(f"R=1 updates: {R1_updates} ({100*R1_updates/total_updates:.1f}%)")
print(f"R=0 updates: {total_updates - R1_updates} ({100*(total_updates - R1_updates)/total_updates:.1f}%)\n")

# States that received R=1
R1_indices = [i for i in learning_updates if data['DEBUG_R_buffered'][i] == 1]
states_with_R1 = sorted(set(data['DEBUG_old_stan_T0'][i] for i in R1_indices))
print(f"States that received R=1: {len(states_with_R1)} unique states")
print(f"States: {states_with_R1}\n")

# Goal state reward analysis
goal_R1 = sum(1 for i in goal_updates if data['DEBUG_R_buffered'][i] == 1)
goal_R0 = n_goal_updates - goal_R1

print("Goal state updates:")
print(f"  R=1: {goal_R1} ({100*goal_R1/n_goal_updates:.1f}%)")
print(f"  R=0: {goal_R0} ({100*goal_R0/n_goal_updates:.1f}%)")

if goal_R0 > 0:
    print(f"  ⚠️  WARNING: Goal state received R=0 {goal_R0} times!\n")
else:
    print("  ✓ OK: Goal state always receives R=1\n")

# ========================================================================
# SECTION 3: GLOBAL MAXIMUM TRACKING
# ========================================================================
print("="*70)
print("SECTION 3: GLOBAL MAXIMUM TRACKING")
print("="*70)
print()

# When is global maximum at goal state?
max_at_goal = sum(1 for i in range(len(data['DEBUG_global_max_state']))
                  if data['DEBUG_global_max_state'][i] == GOAL_STATE
                  and data['DEBUG_global_max_action'][i] == GOAL_ACTION)
pct_max_at_goal = 100 * max_at_goal / len(data['DEBUG_global_max_state'])
print(f"Global max at goal state: {pct_max_at_goal:.1f}% of iterations")

# Find when maximum first leaves goal
not_at_goal = [i for i in range(len(data['DEBUG_global_max_state']))
               if data['DEBUG_global_max_state'][i] != GOAL_STATE
               or data['DEBUG_global_max_action'][i] != GOAL_ACTION]

if not_at_goal:
    first_departure = not_at_goal[0]
    print(f"First departure from goal: iteration {first_departure}")
    print(f"  Moved to: Q({int(data['DEBUG_global_max_state'][first_departure])}, "
          f"{int(data['DEBUG_global_max_action'][first_departure])}) = "
          f"{data['DEBUG_global_max_Q'][first_departure]:.4f}")

    # Most common non-goal maximum location
    non_goal_pairs = {}
    for i in not_at_goal:
        pair = (int(data['DEBUG_global_max_state'][i]), int(data['DEBUG_global_max_action'][i]))
        non_goal_pairs[pair] = non_goal_pairs.get(pair, 0) + 1

    most_common = max(non_goal_pairs.items(), key=lambda x: x[1])
    print(f"\nMost common non-goal maximum:")
    print(f"  Q({most_common[0][0]}, {most_common[0][1]}) appears {most_common[1]} times")
else:
    print("✓ Global maximum always at goal state")
print()

# ========================================================================
# SECTION 4: BOOTSTRAP VALUE ANALYSIS
# ========================================================================
print("="*70)
print("SECTION 4: BOOTSTRAP VALUE ANALYSIS")
print("="*70)
print()

bootstrap_values = [data['DEBUG_bootstrap'][i] for i in learning_updates]

# Calculate statistics manually
bootstrap_mean = sum(bootstrap_values) / len(bootstrap_values)
bootstrap_variance = sum((x - bootstrap_mean)**2 for x in bootstrap_values) / len(bootstrap_values)
bootstrap_std = math.sqrt(bootstrap_variance)
bootstrap_max = max(bootstrap_values)
bootstrap_min = min(bootstrap_values)

print("Bootstrap value statistics:")
print(f"  Mean: {bootstrap_mean:.4f}")
print(f"  Std: {bootstrap_std:.4f}")
print(f"  Max: {bootstrap_max:.4f}")
print(f"  Min: {bootstrap_min:.4f}")
theoretical_limit = GAMMA * THEORETICAL_MAX
print(f"  Theoretical limit (γ×100): {theoretical_limit:.4f}")

# Check for bootstrap inflation
inflated = [v for v in bootstrap_values if v > theoretical_limit + 0.1]
if inflated:
    print(f"  ⚠️  WARNING: {len(inflated)} bootstrap values exceed theoretical limit!")

    # Find first inflated bootstrap
    for i, idx in enumerate(learning_updates):
        if data['DEBUG_bootstrap'][idx] > theoretical_limit + 0.1:
            print(f"  First occurrence at iteration {idx}")
            print(f"    Next state: {int(data['DEBUG_stan_T0'][idx])}")
            print(f"    Bootstrap: {data['DEBUG_bootstrap'][idx]:.4f}")
            break
else:
    print("  ✓ OK: All bootstrap values within theoretical bounds")
print()

# ========================================================================
# SECTION 5: TD ERROR TRENDS
# ========================================================================
print("="*70)
print("SECTION 5: TD ERROR TRENDS")
print("="*70)
print()

TD_errors = [data['DEBUG_TD_error'][i] for i in learning_updates]

# Calculate statistics
TD_mean = sum(TD_errors) / len(TD_errors)
TD_variance = sum((x - TD_mean)**2 for x in TD_errors) / len(TD_errors)
TD_std = math.sqrt(TD_variance)
TD_max = max(TD_errors)
TD_min = min(TD_errors)

print("TD error statistics:")
print(f"  Mean: {TD_mean:.4f}")
print(f"  Std: {TD_std:.4f}")
print(f"  Max positive: {TD_max:.4f}")
print(f"  Max negative: {TD_min:.4f}")

# Compare first half vs second half
mid_point = len(TD_errors) // 2
first_half = TD_errors[:mid_point]
second_half = TD_errors[mid_point:]

first_mean = sum(first_half) / len(first_half)
first_var = sum((x - first_mean)**2 for x in first_half) / len(first_half)
first_std = math.sqrt(first_var)

second_mean = sum(second_half) / len(second_half)
second_var = sum((x - second_mean)**2 for x in second_half) / len(second_half)
second_std = math.sqrt(second_var)

print("\nFirst half vs Second half:")
print(f"  First half: mean={first_mean:.4f}, std={first_std:.4f}")
print(f"  Second half: mean={second_mean:.4f}, std={second_std:.4f}")

if abs(second_mean) < abs(first_mean):
    print("  ✓ OK: TD error magnitude decreasing")
else:
    print("  ⚠️  WARNING: TD error magnitude NOT decreasing")

if second_std < first_std:
    print("  ✓ OK: TD error variance decreasing")
else:
    print("  ⚠️  WARNING: TD error variance NOT decreasing")
print()

# ========================================================================
# SECTION 6: COMPARISON WITH T0=0
# ========================================================================
print("="*70)
print("SECTION 6: COMPARISON WITH T0=0")
print("="*70)
print()

print("T0=0 results (from tests_rusults.txt):")
print("  Final Q(50,50): 92.46")
print("  Goal updates: 4134")
print("  TD error trend: Decreasing ✓\n")

print("T0=4 results (current analysis):")
print(f"  Final Q(50,50): {goal_Q_values[-1]:.2f}")
print(f"  Goal updates: {n_goal_updates}")
if second_std < first_std:
    print("  TD error trend: Decreasing ✓\n")
else:
    print("  TD error trend: NOT decreasing ⚠️\n")

print("Key differences:")
updates_ratio = 100 * n_goal_updates / 4134
print(f"  Fewer goal updates: {n_goal_updates} vs 4134 ({updates_ratio:.1f}%)")
Q_gap = 100 * (92.46 - goal_Q_values[-1]) / 92.46
print(f"  Lower final Q-value: {goal_Q_values[-1]:.2f} vs 92.46 ({Q_gap:.1f}% gap)")

# ========================================================================
# FINAL DIAGNOSIS
# ========================================================================
print()
print("="*70)
print("FINAL DIAGNOSIS")
print("="*70)
print()

diagnosis = []

# Check 1: Insufficient training
if goal_Q_values[-1] < 0.9 * THEORETICAL_MAX and late_mean > early_mean:
    diagnosis.append("LIKELY CAUSE: Insufficient training - Q-value still increasing")
    recommended_epochs = math.ceil(50 * THEORETICAL_MAX / goal_Q_values[-1])
    diagnosis.append(f"  Recommendation: Increase max_epoki to at least {recommended_epochs}")

# Check 2: Fewer goal updates
if n_goal_updates < 3000:
    diagnosis.append(f"CONTRIBUTING FACTOR: Fewer goal state visits ({n_goal_updates} vs 4134 for T0=0)")
    diagnosis.append("  Explanation: Dead time compensation delays learning, system spends less time at goal")

# Check 3: Bootstrap inflation
if inflated:
    diagnosis.append("POTENTIAL BUG: Bootstrap value inflation detected")
    diagnosis.append("  Recommendation: Investigate state transitions leading to inflated bootstraps")

# Check 4: Goal state getting R=0
if goal_R0 > 0:
    diagnosis.append("CRITICAL BUG: Goal state receiving R=0")
    diagnosis.append("  Recommendation: Check reward logic for T0>0 case")

# Check 5: TD error not converging
if second_std >= first_std:
    diagnosis.append("CONCERN: TD error variance not decreasing")
    diagnosis.append("  Possible cause: Exploration rate too high or environment non-stationary")

if not diagnosis:
    print("✓ NO CRITICAL ISSUES DETECTED")
    print("  T0=4 convergence is slower but progressing correctly")
    print("  Recommendation: Increase training duration")
else:
    for item in diagnosis:
        print(item)

print()
print("="*70)
print("END ANALYSIS")
print("="*70)
