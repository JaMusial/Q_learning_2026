"""
Goal State Analyzer
===================

Analyzes goal state behavior in Q-learning, focusing on:
- Q(goal, goal) evolution and convergence
- Goal→Goal transition consistency (Bug #5 detection)
- Bootstrap override effectiveness
- Goal state visitation patterns

Usage:
    python goal_state_analyzer.py [json_file]
    python goal_state_analyzer.py  # defaults to logi_training.json

Bug #5 Detection:
The "bootstrap contamination" bug occurs when numerical drift causes
next_state to not exactly equal goal_state during goal→goal transitions.
This causes Q(goal,goal) to decrease instead of increase.

Fix verification: stan_T0_for_bootstrap should override to goal state
when transitioning from goal state with goal action.
"""

import sys
import numpy as np
from pathlib import Path
from collections import Counter

sys.path.insert(0, str(Path(__file__).parent))
from json_loader import load_debug_json, LogData, get_available_logs


# Theoretical Q-value at goal with R=1, gamma=0.99
# Q* = R / (1 - gamma) = 1 / 0.01 = 100
THEORETICAL_MAX_Q = 100.0


def analyze_goal_q_evolution(data: LogData) -> dict:
    """
    Analyze Q(goal, goal) evolution over time.

    Expected behavior:
    - Q(goal, goal) should monotonically increase toward 100
    - No decreases (indicates bootstrap contamination - Bug #5)
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    goal_q = data.as_array('DEBUG_goal_Q')
    valid_mask = goal_q > 0
    valid_q = goal_q[valid_mask]

    if len(valid_q) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No goal Q-value data found")
        return results

    # Basic statistics
    results['metrics']['initial_value'] = float(valid_q[0])
    results['metrics']['final_value'] = float(valid_q[-1])
    results['metrics']['max_value'] = float(np.max(valid_q))
    results['metrics']['min_value'] = float(np.min(valid_q))
    results['metrics']['n_samples'] = int(len(valid_q))

    # Distance to theoretical maximum
    results['metrics']['distance_to_100'] = float(THEORETICAL_MAX_Q - valid_q[-1])

    # Check for convergence
    if valid_q[-1] < 50:
        results['status'] = 'ERROR'
        results['issues'].append(f"Goal Q far from target: {valid_q[-1]:.2f} (expected ~100)")
    elif valid_q[-1] < 90:
        results['status'] = 'WARNING'
        results['issues'].append(f"Goal Q not converged: {valid_q[-1]:.2f} (expected ~100)")

    # Check for decreases (Bug #5 symptom)
    decreases = np.diff(valid_q) < -0.1  # Allow small numerical noise
    n_decreases = np.sum(decreases)
    results['metrics']['n_decreases'] = int(n_decreases)
    results['metrics']['decrease_rate'] = float(100 * n_decreases / len(valid_q))

    if n_decreases > len(valid_q) * 0.01:  # More than 1% decreases
        results['status'] = 'WARNING'
        results['issues'].append(
            f"Goal Q decreased {n_decreases} times ({100*n_decreases/len(valid_q):.1f}%) - "
            "possible Bug #5 (bootstrap contamination)"
        )

        # Find largest decrease
        decrease_amounts = np.diff(valid_q)
        decrease_amounts[~decreases] = 0
        max_decrease = np.min(decrease_amounts)
        max_decrease_idx = np.argmin(decrease_amounts)
        results['details']['max_decrease'] = float(max_decrease)
        results['details']['max_decrease_idx'] = int(max_decrease_idx)

    # Net change
    net_change = valid_q[-1] - valid_q[0]
    results['metrics']['net_change'] = float(net_change)

    if net_change < 0:
        results['status'] = 'ERROR'
        results['issues'].append(f"Goal Q DECREASED overall: {valid_q[0]:.2f} -> {valid_q[-1]:.2f}")

    # Trend analysis
    if len(valid_q) > 100:
        # Split into quarters
        q1 = np.mean(valid_q[:len(valid_q)//4])
        q4 = np.mean(valid_q[3*len(valid_q)//4:])
        results['metrics']['quarter1_mean'] = float(q1)
        results['metrics']['quarter4_mean'] = float(q4)
        results['metrics']['improvement'] = float(q4 - q1)

    return results


def analyze_goal_transitions(data: LogData) -> dict:
    """
    Analyze goal→goal state transitions.

    For Bug #5 detection:
    - When in goal state with goal action, next state should be goal state
    - Bootstrap override should ensure stan_T0_for_bootstrap = goal_state
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    old_stan_T0 = data.as_array('DEBUG_old_stan_T0')
    wyb_akcja_T0 = data.as_array('DEBUG_wyb_akcja_T0')
    stan_T0 = data.as_array('DEBUG_stan_T0')
    stan_T0_bootstrap = data.as_array('DEBUG_stan_T0_for_bootstrap')
    is_updating_goal = data.as_array('DEBUG_is_updating_goal')
    uczenie_T0 = data.as_array('DEBUG_uczenie_T0')

    learning_mask = uczenie_T0 == 1

    if np.sum(learning_mask) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No learning samples")
        return results

    # Find goal state (typically 50)
    if len(is_updating_goal) > 0:
        goal_update_mask = (is_updating_goal == 1) & learning_mask
        if np.sum(goal_update_mask) > 0:
            # Most common state when updating goal
            states_when_goal = old_stan_T0[goal_update_mask]
            actions_when_goal = wyb_akcja_T0[goal_update_mask]

            state_counts = Counter(states_when_goal.astype(int))
            action_counts = Counter(actions_when_goal.astype(int))

            goal_state = state_counts.most_common(1)[0][0]
            goal_action = action_counts.most_common(1)[0][0]

            results['metrics']['detected_goal_state'] = int(goal_state)
            results['metrics']['detected_goal_action'] = int(goal_action)
            results['metrics']['n_goal_updates'] = int(np.sum(goal_update_mask))

    # Analyze goal→goal transitions specifically
    if 'detected_goal_state' in results['metrics']:
        goal_state = results['metrics']['detected_goal_state']
        goal_action = results['metrics']['detected_goal_action']

        # Find samples where we're at goal state with goal action
        goal_goal_mask = (
            (old_stan_T0 == goal_state) &
            (wyb_akcja_T0 == goal_action) &
            learning_mask
        )

        n_goal_goal = np.sum(goal_goal_mask)
        results['metrics']['n_goal_goal_transitions'] = int(n_goal_goal)

        if n_goal_goal > 0:
            # Check next state (actual vs bootstrap override)
            next_actual = stan_T0[goal_goal_mask]
            next_bootstrap = stan_T0_bootstrap[goal_goal_mask]

            # How many times did actual next state = goal state?
            actual_at_goal = np.sum(next_actual == goal_state)
            bootstrap_at_goal = np.sum(next_bootstrap == goal_state)

            results['metrics']['actual_next_at_goal'] = int(actual_at_goal)
            results['metrics']['actual_next_at_goal_pct'] = float(100 * actual_at_goal / n_goal_goal)
            results['metrics']['bootstrap_at_goal'] = int(bootstrap_at_goal)
            results['metrics']['bootstrap_at_goal_pct'] = float(100 * bootstrap_at_goal / n_goal_goal)

            # Bug #5 check: bootstrap should be 100% at goal for goal→goal
            if bootstrap_at_goal < n_goal_goal * 0.99:
                results['status'] = 'ERROR'
                results['issues'].append(
                    f"Bootstrap override failing: only {100*bootstrap_at_goal/n_goal_goal:.1f}% "
                    f"at goal (expected 100%) - Bug #5 not fixed!"
                )

            # Check if override is working (actual differs from bootstrap)
            override_needed = next_actual != goal_state
            n_override_needed = np.sum(override_needed)
            results['metrics']['n_override_needed'] = int(n_override_needed)

            if n_override_needed > 0:
                # Verify override was applied
                override_correct = next_bootstrap[override_needed] == goal_state
                n_override_correct = np.sum(override_correct)
                results['metrics']['n_override_correct'] = int(n_override_correct)

                if n_override_correct < n_override_needed:
                    results['status'] = 'ERROR'
                    results['issues'].append(
                        f"Bootstrap override failed {n_override_needed - n_override_correct} times"
                    )
                else:
                    results['details']['override_status'] = (
                        f"Override working: {n_override_needed} corrections applied successfully"
                    )

    return results


def analyze_goal_visitation(data: LogData) -> dict:
    """
    Analyze how often the controller visits the goal state region.

    Good learning requires:
    - Sufficient goal state visits for reward collection
    - Balanced exploration vs exploitation
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    state_nr = data.as_array('Q_stan_nr')
    is_goal = data.as_array('DEBUG_is_goal_state')

    valid_states = state_nr[state_nr > 0]

    if len(valid_states) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No state data")
        return results

    # State distribution
    state_counts = Counter(valid_states.astype(int))
    total = len(valid_states)

    # Goal region (states 49-51)
    goal_region = sum(state_counts.get(s, 0) for s in [49, 50, 51])
    results['metrics']['goal_region_visits'] = int(goal_region)
    results['metrics']['goal_region_pct'] = float(100 * goal_region / total)

    # Exact goal state (50)
    goal_exact = state_counts.get(50, 0)
    results['metrics']['goal_exact_visits'] = int(goal_exact)
    results['metrics']['goal_exact_pct'] = float(100 * goal_exact / total)

    # State distribution summary
    results['metrics']['n_unique_states'] = len(state_counts)
    results['metrics']['most_common_state'] = state_counts.most_common(1)[0][0]
    results['metrics']['most_common_count'] = state_counts.most_common(1)[0][1]

    # Check if goal is being visited enough
    if goal_region / total < 0.01:
        results['status'] = 'WARNING'
        results['issues'].append(
            f"Very low goal region visitation: {100*goal_region/total:.2f}% - "
            "learning may be too slow"
        )

    # Using DEBUG field if available
    if len(is_goal) > 0 and np.any(is_goal > 0):
        n_at_goal = np.sum(is_goal == 1)
        results['metrics']['debug_goal_visits'] = int(n_at_goal)
        results['metrics']['debug_goal_pct'] = float(100 * n_at_goal / len(is_goal))

    return results


def analyze_reward_at_goal(data: LogData) -> dict:
    """
    Analyze reward collection at goal state.

    R=1 should be given when controller is at goal state with goal action.
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    R_buffered = data.as_array('DEBUG_R_buffered')
    is_updating_goal = data.as_array('DEBUG_is_updating_goal')
    uczenie_T0 = data.as_array('DEBUG_uczenie_T0')

    learning_mask = uczenie_T0 == 1

    if np.sum(learning_mask) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No learning samples")
        return results

    # Overall reward statistics
    R_learning = R_buffered[learning_mask]
    n_r1 = np.sum(R_learning == 1)
    n_r0 = np.sum(R_learning == 0)

    results['metrics']['total_R1'] = int(n_r1)
    results['metrics']['total_R0'] = int(n_r0)
    results['metrics']['R1_rate'] = float(100 * n_r1 / len(R_learning))

    # Reward when updating goal state
    if len(is_updating_goal) > 0:
        goal_mask = (is_updating_goal == 1) & learning_mask
        n_goal_updates = np.sum(goal_mask)

        if n_goal_updates > 0:
            R_at_goal = R_buffered[goal_mask]
            n_r1_goal = np.sum(R_at_goal == 1)

            results['metrics']['R1_at_goal'] = int(n_r1_goal)
            results['metrics']['R1_at_goal_pct'] = float(100 * n_r1_goal / n_goal_updates)

            # Most goal updates should have R=1
            if n_r1_goal / n_goal_updates < 0.8:
                results['status'] = 'WARNING'
                results['issues'].append(
                    f"Only {100*n_r1_goal/n_goal_updates:.1f}% of goal updates have R=1 - "
                    "reward may not be properly aligned"
                )

    return results


def print_results(title: str, results: dict):
    """Pretty print analysis results."""
    status_symbol = {
        'OK': '✓',
        'WARNING': '⚠',
        'ERROR': '✗',
        'INFO': 'ℹ'
    }.get(results['status'], '?')

    print(f"\n{status_symbol} {title}")
    print("-" * 50)

    if results['metrics']:
        print("Metrics:")
        for key, value in results['metrics'].items():
            if isinstance(value, float):
                print(f"  {key}: {value:.4f}")
            else:
                print(f"  {key}: {value}")

    if results.get('details'):
        print("Details:")
        for key, value in results['details'].items():
            print(f"  {key}: {value}")

    if results['issues']:
        print("Issues:")
        for issue in results['issues']:
            print(f"  - {issue}")

    if results['status'] == 'OK' and not results['issues']:
        print("  No issues detected")


def analyze_goal_state(data: LogData) -> dict:
    """Run all goal state analyses."""
    print("=" * 60)
    print(f"Goal State Analysis: {data.filename}")
    print(f"Samples: {data.n_samples:,}")
    print(f"Theoretical Q(goal,goal) max: {THEORETICAL_MAX_Q}")
    print("=" * 60)

    all_results = {}

    # Q(goal, goal) evolution
    all_results['evolution'] = analyze_goal_q_evolution(data)
    print_results("Goal Q-Value Evolution", all_results['evolution'])

    # Goal→Goal transitions (Bug #5)
    all_results['transitions'] = analyze_goal_transitions(data)
    print_results("Goal→Goal Transitions (Bug #5)", all_results['transitions'])

    # Goal visitation
    all_results['visitation'] = analyze_goal_visitation(data)
    print_results("Goal State Visitation", all_results['visitation'])

    # Reward at goal
    all_results['reward'] = analyze_reward_at_goal(data)
    print_results("Reward at Goal State", all_results['reward'])

    # Summary
    print("\n" + "=" * 60)
    print("GOAL STATE SUMMARY")
    print("=" * 60)

    errors = sum(1 for r in all_results.values() if r['status'] == 'ERROR')
    warnings = sum(1 for r in all_results.values() if r['status'] == 'WARNING')

    if errors > 0:
        print(f"✗ {errors} ERROR(s) - Critical goal state issues detected")
        print("  Likely Bug #5 (bootstrap contamination) or related issue")
    elif warnings > 0:
        print(f"⚠ {warnings} WARNING(s) - Potential goal state issues")
    else:
        print("✓ All goal state checks passed")

    # Key recommendation
    if 'evolution' in all_results:
        final_q = all_results['evolution']['metrics'].get('final_value', 0)
        if final_q > 0:
            print(f"\nQ(goal,goal) = {final_q:.2f} / {THEORETICAL_MAX_Q}")
            if final_q >= 95:
                print("  Excellent convergence!")
            elif final_q >= 80:
                print("  Good progress, continue training")
            else:
                print("  More training needed or check for bugs")

    return all_results


def main():
    """Main entry point."""
    if len(sys.argv) > 1:
        filename = sys.argv[1]
    else:
        filename = 'logi_training.json'

    try:
        data = load_debug_json(filename)
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found")
        sys.exit(1)

    if not data.has_debug_data:
        print("Warning: Debug data appears empty. Enable debug_logging=1 in config.m")

    analyze_goal_state(data)


if __name__ == "__main__":
    main()
