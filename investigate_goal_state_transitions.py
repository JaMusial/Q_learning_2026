#!/usr/bin/env python3
"""
Investigate what happens AFTER goal state for T0=4
Critical finding: Q(50,50) is DECREASING from 94.31 to 74.10
This should never happen - suggests bootstrap term is getting smaller
"""

import json

# Configuration
GOAL_STATE = 50
GOAL_ACTION = 50
GAMMA = 0.99
THEORETICAL_MAX = 1 / (1 - GAMMA)

print("="*70)
print("INVESTIGATING GOAL STATE TRANSITIONS (T0=4)")
print("="*70)
print()

# Load JSON data
with open('logi_T0=4_max_epoki=50.json', 'r') as f:
    data = json.load(f)

# ========================================================================
# CRITICAL QUESTION: What is the "next state" when updating Q(50,50)?
# ========================================================================
print("CRITICAL QUESTION: What happens AFTER goal state?")
print("="*70)
print()

# Find all goal state updates
goal_updates = [i for i, v in enumerate(data['DEBUG_is_updating_goal']) if v == 1]
print(f"Total goal state updates: {len(goal_updates)}\n")

# For each goal update, check what the NEXT STATE is
# (This is DEBUG_stan_T0, which is used for bootstrap calculation)
print("Analyzing next state distribution after goal updates:")
print("-"*70)

next_states_after_goal = {}
for idx in goal_updates:
    next_state = int(data['DEBUG_stan_T0'][idx])
    next_states_after_goal[next_state] = next_states_after_goal.get(next_state, 0) + 1

# Sort by frequency
sorted_next_states = sorted(next_states_after_goal.items(), key=lambda x: x[1], reverse=True)

print(f"\nNext State Distribution (top 10):")
print(f"{'State':<10} {'Count':<10} {'Percentage':<12} {'Is Goal?'}")
print("-"*50)
for state, count in sorted_next_states[:10]:
    pct = 100 * count / len(goal_updates)
    is_goal = "✓ GOAL" if state == GOAL_STATE else "✗ NOT GOAL"
    print(f"{state:<10} {count:<10} {pct:>6.2f}%      {is_goal}")

# Critical check: How often does goal state lead back to goal?
goal_to_goal = next_states_after_goal.get(GOAL_STATE, 0)
goal_to_non_goal = len(goal_updates) - goal_to_goal
pct_goal_to_goal = 100 * goal_to_goal / len(goal_updates)

print()
print("="*70)
print(f"CRITICAL FINDING:")
print(f"  Goal → Goal: {goal_to_goal} ({pct_goal_to_goal:.1f}%)")
print(f"  Goal → Non-Goal: {goal_to_non_goal} ({100 - pct_goal_to_goal:.1f}%)")
print("="*70)

if pct_goal_to_goal < 90:
    print("\n⚠️  PROBLEM IDENTIFIED:")
    print("   After being in goal state, system frequently transitions to NON-goal states!")
    print("   This causes bootstrap term γ·max(Q(s',:)) to be based on non-goal Q-values")
    print("   which are lower, pulling down Q(50,50) over time.\n")

# ========================================================================
# INVESTIGATE: Why does goal action not keep system at goal?
# ========================================================================
print()
print("INVESTIGATING: Why doesn't goal action keep system at goal?")
print("="*70)
print()

# For goal state updates, check what ACTION was selected
print("Actions taken in goal state:")
actions_in_goal = {}
for idx in goal_updates:
    action = int(data['DEBUG_wyb_akcja_T0'][idx])
    actions_in_goal[action] = actions_in_goal.get(action, 0) + 1

sorted_actions = sorted(actions_in_goal.items(), key=lambda x: x[1], reverse=True)

print(f"{'Action':<10} {'Count':<10} {'Percentage':<12} {'Is Goal Action?'}")
print("-"*55)
for action, count in sorted_actions[:10]:
    pct = 100 * count / len(goal_updates)
    is_goal_act = "✓ GOAL ACTION" if action == GOAL_ACTION else "✗ OTHER"
    print(f"{action:<10} {count:<10} {pct:>6.2f}%      {is_goal_act}")

# ========================================================================
# BOOTSTRAP VALUE ANALYSIS FOR GOAL UPDATES
# ========================================================================
print()
print("\nBOOTSTRAP VALUE ANALYSIS FOR GOAL UPDATES")
print("="*70)
print()

# Calculate statistics for bootstrap values during goal updates
goal_bootstraps = [data['DEBUG_bootstrap'][i] for i in goal_updates]
goal_Q_at_update = [data['DEBUG_Q_old_value'][i] for i in goal_updates]
goal_TD_errors = [data['DEBUG_TD_error'][i] for i in goal_updates]

# Calculate means manually
bootstrap_mean = sum(goal_bootstraps) / len(goal_bootstraps)
Q_old_mean = sum(goal_Q_at_update) / len(goal_Q_at_update)
TD_mean = sum(goal_TD_errors) / len(goal_TD_errors)

print(f"Average bootstrap value when updating goal: {bootstrap_mean:.4f}")
print(f"Average Q(50,50) before update: {Q_old_mean:.4f}")
print(f"Average TD error for goal updates: {TD_mean:.4f}")
print(f"\nExpected TD error for goal → goal transition:")
expected_TD = 1 - (1 - GAMMA) * Q_old_mean
print(f"  1 - (1-γ)·Q(50,50) = 1 - 0.01·{Q_old_mean:.2f} = {expected_TD:.4f}")
print(f"\nActual TD error: {TD_mean:.4f}")
print(f"Difference: {TD_mean - expected_TD:.4f}")

if abs(TD_mean - expected_TD) > 0.5:
    print("\n⚠️  MISMATCH DETECTED:")
    print("   Actual TD error deviates significantly from expected!")
    print("   This confirms that next state after goal is often NOT goal state.\n")

# ========================================================================
# TIMELINE ANALYSIS: When did Q(50,50) start decreasing?
# ========================================================================
print()
print("TIMELINE ANALYSIS: When did Q(50,50) start decreasing?")
print("="*70)
print()

# Get Q(50,50) evolution
goal_Q_evolution = [data['DEBUG_Q_new_value'][i] for i in goal_updates]

# Find peak Q-value
peak_Q = max(goal_Q_evolution)
peak_idx_in_list = goal_Q_evolution.index(peak_Q)
peak_iteration = goal_updates[peak_idx_in_list]

print(f"Peak Q(50,50): {peak_Q:.4f}")
print(f"Occurred at: iteration {peak_iteration} (goal update #{peak_idx_in_list+1})")
print(f"Final Q(50,50): {goal_Q_evolution[-1]:.4f}")
print(f"Decrease from peak: {peak_Q - goal_Q_evolution[-1]:.4f} ({100*(peak_Q - goal_Q_evolution[-1])/peak_Q:.1f}%)")

# Check if global max left goal around same time
global_max_states = data['DEBUG_global_max_state']
global_max_actions = data['DEBUG_global_max_action']

# Find when global max first left goal permanently
left_goal_permanent = None
for i in range(peak_iteration, len(global_max_states)):
    if global_max_states[i] != GOAL_STATE or global_max_actions[i] != GOAL_ACTION:
        # Check if it stays away for at least 100 iterations
        stayed_away = True
        for j in range(i, min(i+100, len(global_max_states))):
            if global_max_states[j] == GOAL_STATE and global_max_actions[j] == GOAL_ACTION:
                stayed_away = False
                break
        if stayed_away:
            left_goal_permanent = i
            break

if left_goal_permanent:
    print(f"\nGlobal max left goal permanently: iteration {left_goal_permanent}")
    print(f"Moved to: Q({int(global_max_states[left_goal_permanent])}, "
          f"{int(global_max_actions[left_goal_permanent])}) = "
          f"{data['DEBUG_global_max_Q'][left_goal_permanent]:.4f}")

# ========================================================================
# FINAL DIAGNOSIS
# ========================================================================
print()
print("="*70)
print("FINAL DIAGNOSIS")
print("="*70)
print()

if pct_goal_to_goal < 90:
    print("ROOT CAUSE IDENTIFIED:")
    print()
    print("1. DEAD TIME COMPENSATION CAUSES STATE DRIFT")
    print(f"   - System in goal state (50) only leads back to goal {pct_goal_to_goal:.1f}% of time")
    print(f"   - Remaining {100-pct_goal_to_goal:.1f}% transitions to non-goal states")
    print()
    print("2. BOOTSTRAP CONTAMINATION")
    print("   - Q(50,50) update uses: Q += α·[R + γ·max(Q(s',:)) - Q]")
    print(f"   - When s' ≠ goal, max(Q(s',:)) is LOWER than Q(50,50)")
    print(f"   - This pulls Q(50,50) DOWN instead of converging to {THEORETICAL_MAX:.0f}")
    print()
    print("3. LIKELY CAUSE: NEXT STATE CALCULATION ERROR FOR T0>0")
    print("   - For T0>0, DEBUG_stan_T0 = current state (not buffered)")
    print("   - But current state is T0_controller/dt steps AHEAD of action effect")
    print("   - Bootstrap should use state that ACTUALLY results from buffered action")
    print()
    print("RECOMMENDATION:")
    print("  Check m_regulator_Q.m lines 160-165 (T0_controller > 0 branch)")
    print("  The 'next state' for Q-update should be synchronized with action timing")
    print("  Current code: stan_T0 = stan (current state)")
    print("  Should be: stan_T0 = ??? (state that actually results from action)")
else:
    print("✓ Goal state transitions appear correct")
    print("  Further investigation needed for Q-value decrease")

print()
print("="*70)
print("END INVESTIGATION")
print("="*70)
