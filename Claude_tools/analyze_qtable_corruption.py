#!/usr/bin/env python3
"""
analyze_qtable_corruption.py - Analyze why Q-table is corrupted after learning

Examines which Q-values are wrong and why the controller avoids goal state.
"""

import json
import numpy as np

def load_json(filename):
    """Load JSON log file"""
    with open(filename, 'r') as f:
        return json.load(f)

def analyze_debug_data(log_data, title="Analysis"):
    """Analyze Q-learning debug data"""

    if 'DEBUG_goal_Q' not in log_data or not log_data['DEBUG_goal_Q']:
        print(f"{title}: No debug data available")
        return None

    # Extract debug data
    goal_Q = np.array(log_data['DEBUG_goal_Q'])
    uczenie_T0 = np.array(log_data['DEBUG_uczenie_T0'])
    stan_T0 = np.array(log_data['DEBUG_stan_T0'])
    old_stan_T0 = np.array(log_data['DEBUG_old_stan_T0'])
    wyb_akcja_T0 = np.array(log_data['DEBUG_wyb_akcja_T0'])
    R_buffered = np.array(log_data['DEBUG_R_buffered'])
    TD_error = np.array(log_data['DEBUG_TD_error'])
    Q_old_value = np.array(log_data['DEBUG_Q_old_value'])
    Q_new_value = np.array(log_data['DEBUG_Q_new_value'])
    is_goal_state = np.array(log_data['DEBUG_is_goal_state'])
    is_updating_goal = np.array(log_data['DEBUG_is_updating_goal'])

    # Filter to valid debug samples (non-zero)
    valid = (Q_old_value != 0) | (Q_new_value != 0)

    print("=" * 70)
    print(f"{title}")
    print("=" * 70)

    print(f"\nTotal samples with Q-updates: {np.sum(uczenie_T0 > 0)}")
    print(f"Goal state visits: {np.sum(is_goal_state)}")
    print(f"Goal state Q-updates: {np.sum(is_updating_goal)}")

    print(f"\nGoal Q-value:")
    print(f"  Initial: {goal_Q[0]:.2f}")
    print(f"  Final: {goal_Q[-1]:.2f}")
    print(f"  Max: {np.max(goal_Q):.2f}")
    print(f"  Min: {np.min(goal_Q[goal_Q > 0]):.2f}")

    # Analyze TD errors
    valid_TD = TD_error != 0
    if np.sum(valid_TD) > 0:
        print(f"\nTD Error statistics:")
        print(f"  Mean: {np.mean(TD_error[valid_TD]):.4f}")
        print(f"  Std: {np.std(TD_error[valid_TD]):.4f}")
        print(f"  Positive (Q increasing): {np.sum(TD_error > 0)} ({100*np.sum(TD_error > 0)/np.sum(valid_TD):.1f}%)")
        print(f"  Negative (Q decreasing): {np.sum(TD_error < 0)} ({100*np.sum(TD_error < 0)/np.sum(valid_TD):.1f}%)")

    # Check which states are being updated
    valid_updates = (uczenie_T0 > 0) & (old_stan_T0 > 0)
    if np.sum(valid_updates) > 0:
        unique_states, counts = np.unique(old_stan_T0[valid_updates], return_counts=True)

        print(f"\nStates receiving Q-updates:")
        print(f"  Total unique states updated: {len(unique_states)}")
        print(f"  Most frequently updated states:")

        sorted_indices = np.argsort(counts)[::-1]
        for i in range(min(10, len(unique_states))):
            idx = sorted_indices[i]
            state = int(unique_states[idx])
            count = counts[idx]
            pct = 100 * count / np.sum(valid_updates)
            print(f"    State {state:3d}: {count:5d} updates ({pct:5.1f}%)")

    # Analyze reward distribution
    print(f"\nReward distribution:")
    print(f"  R=1 (goal state): {np.sum(R_buffered == 1)} ({100*np.sum(R_buffered == 1)/len(R_buffered):.1f}%)")
    print(f"  R=0 (non-goal): {np.sum(R_buffered == 0)} ({100*np.sum(R_buffered == 0)/len(R_buffered):.1f}%)")

    # Check for reward at goal state
    goal_rewards = R_buffered[is_goal_state]
    if len(goal_rewards) > 0:
        print(f"\nWhen IN goal state:")
        print(f"  R=1: {np.sum(goal_rewards == 1)} / {len(goal_rewards)} ({100*np.sum(goal_rewards == 1)/len(goal_rewards):.1f}%)")

    return {
        'goal_Q_final': goal_Q[-1],
        'uczenie_count': np.sum(uczenie_T0 > 0),
        'goal_visits': np.sum(is_goal_state)
    }

def main():
    print("Loading data...")
    before = load_json('../logi_before_learning.json')
    after = load_json('../logi_after_learning.json')

    # Check if training log exists with debug data
    try:
        training = load_json('../logi_training.json')
        if training.get('DEBUG_goal_Q') and len(training['DEBUG_goal_Q']) > 0:
            print("\n")
            analyze_debug_data(training, "DURING TRAINING")
    except:
        print("\nNo training debug data available")

    print("\n")
    results_before = analyze_debug_data(before, "BEFORE LEARNING (Verification)")
    print("\n")
    results_after = analyze_debug_data(after, "AFTER LEARNING (Verification)")

    if results_before and results_after:
        print("\n" + "=" * 70)
        print("HYPOTHESIS: Why learning makes it worse")
        print("=" * 70)
        print("""
The Q-table is being updated during training, but the learned policy is
actually WORSE than the initial identity matrix policy!

Possible causes:
1. Credit assignment is still wrong (projection interfering)
2. Exploration is corrupting Q-values (random actions getting rewards)
3. Bootstrap contamination (wrong Q-values propagating)
4. Reward function issue (not properly reinforcing goal state)
5. State/action mismatch (buffering issue with T0>0)

Next steps:
- Check Q-updates during TRAINING (not just verification)
- Verify that Q(goal, goal) is maximum value in table
- Check if non-goal states have higher Q-values than goal
""")

if __name__ == "__main__":
    main()
