"""
Constraint Violation Checker
============================

Detects same-side constraint violations in Q-learning exploration.

This tool detects Bug #6 from CLAUDE.md:
- Same-side matching: state > goal → action > goal, state < goal → action < goal
- Violations cause controller to apply wrong control direction
- Results in oscillation around goal state

Usage:
    python constraint_checker.py [json_file]
    python constraint_checker.py  # defaults to logi_training.json

Constraint Rule:
    When exploring, selected action must be on same side of goal as state:
    - State > goal_state → Action > goal_action (positive error → increase control)
    - State < goal_state → Action < goal_action (negative error → decrease control)
"""

import sys
import numpy as np
from pathlib import Path
from collections import Counter

sys.path.insert(0, str(Path(__file__).parent))
from json_loader import load_debug_json, LogData, get_available_logs


def detect_goal_indices(data: LogData) -> tuple:
    """
    Detect goal state and action indices from the data.

    Returns:
        (goal_state, goal_action) tuple, typically (50, 50)
    """
    # Try to detect from global max location
    max_state = data.as_array('DEBUG_global_max_state')
    max_action = data.as_array('DEBUG_global_max_action')

    valid_states = max_state[max_state > 0]
    valid_actions = max_action[max_action > 0]

    if len(valid_states) > 0 and len(valid_actions) > 0:
        state_counts = Counter(valid_states.astype(int))
        action_counts = Counter(valid_actions.astype(int))

        goal_state = state_counts.most_common(1)[0][0]
        goal_action = action_counts.most_common(1)[0][0]
        return goal_state, goal_action

    # Default assumption
    return 50, 50


def check_same_side_constraint(data: LogData) -> dict:
    """
    Check for same-side constraint violations.

    The constraint ensures exploration actions are in the correct direction:
    - State above goal (error positive) → Action above goal (increase control)
    - State below goal (error negative) → Action below goal (decrease control)
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    state_nr = data.as_array('Q_stan_nr')
    action_nr = data.as_array('Q_akcja_nr')
    losowanie = data.as_array('Q_losowanie')  # 1 = exploration, 0 = exploitation

    if len(state_nr) == 0 or len(action_nr) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No state/action data found")
        return results

    # Detect goal indices
    goal_state, goal_action = detect_goal_indices(data)
    results['metrics']['detected_goal_state'] = int(goal_state)
    results['metrics']['detected_goal_action'] = int(goal_action)

    # Valid samples (non-zero)
    valid_mask = (state_nr > 0) & (action_nr > 0)
    n_valid = np.sum(valid_mask)

    if n_valid == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No valid state-action pairs")
        return results

    results['metrics']['n_valid_samples'] = int(n_valid)

    # Check constraint: same side of goal
    states = state_nr[valid_mask]
    actions = action_nr[valid_mask]

    # Violation: state and action on opposite sides of goal
    # (state > goal AND action < goal) OR (state < goal AND action > goal)
    violations = (
        ((states > goal_state) & (actions < goal_action)) |
        ((states < goal_state) & (actions > goal_action))
    )

    n_violations = np.sum(violations)
    results['metrics']['n_violations'] = int(n_violations)
    results['metrics']['violation_rate'] = float(100 * n_violations / n_valid)

    if n_violations > 0:
        results['status'] = 'WARNING' if n_violations < n_valid * 0.05 else 'ERROR'
        results['issues'].append(
            f"{n_violations} same-side constraint violations ({100*n_violations/n_valid:.2f}%)"
        )

        # Analyze violation patterns
        violation_states = states[violations]
        violation_actions = actions[violations]

        # States above goal with actions below goal
        high_state_low_action = np.sum(
            (violation_states > goal_state) & (violation_actions < goal_action)
        )
        # States below goal with actions above goal
        low_state_high_action = np.sum(
            (violation_states < goal_state) & (violation_actions > goal_action)
        )

        results['details']['high_state_low_action'] = int(high_state_low_action)
        results['details']['low_state_high_action'] = int(low_state_high_action)

    # Separate analysis for exploration vs exploitation
    if len(losowanie) > 0:
        exploration_mask = (losowanie == 1) & valid_mask
        exploitation_mask = (losowanie == 0) & valid_mask

        n_exploration = np.sum(exploration_mask)
        n_exploitation = np.sum(exploitation_mask)

        results['metrics']['n_exploration'] = int(n_exploration)
        results['metrics']['n_exploitation'] = int(n_exploitation)

        if n_exploration > 0:
            exp_states = state_nr[exploration_mask]
            exp_actions = action_nr[exploration_mask]
            exp_violations = (
                ((exp_states > goal_state) & (exp_actions < goal_action)) |
                ((exp_states < goal_state) & (exp_actions > goal_action))
            )
            n_exp_violations = np.sum(exp_violations)

            results['metrics']['exploration_violations'] = int(n_exp_violations)
            results['metrics']['exploration_violation_rate'] = float(
                100 * n_exp_violations / n_exploration
            )

            if n_exp_violations > 0:
                results['issues'].append(
                    f"{n_exp_violations} violations during EXPLORATION - "
                    "constraint not being enforced!"
                )

        if n_exploitation > 0:
            exploit_states = state_nr[exploitation_mask]
            exploit_actions = action_nr[exploitation_mask]
            exploit_violations = (
                ((exploit_states > goal_state) & (exploit_actions < goal_action)) |
                ((exploit_states < goal_state) & (exploit_actions > goal_action))
            )
            n_exploit_violations = np.sum(exploit_violations)

            results['metrics']['exploitation_violations'] = int(n_exploit_violations)
            results['metrics']['exploitation_violation_rate'] = float(
                100 * n_exploit_violations / n_exploitation
            )

            if n_exploit_violations > 0:
                results['details']['exploitation_note'] = (
                    f"{n_exploit_violations} violations during exploitation - "
                    "Q-table may be corrupted from past exploration violations"
                )

    return results


def check_action_direction(data: LogData) -> dict:
    """
    Check if actions are moving the system toward the goal.

    Positive state (error) should have positive action (increase control)
    Negative state (error) should have negative action (decrease control)
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    stan_value = data.as_array('Q_stan_value')
    akcja_value = data.as_array('Q_akcja_value')

    if len(stan_value) == 0 or len(akcja_value) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No state/action value data")
        return results

    # Filter valid samples
    valid_mask = (stan_value != 0) | (akcja_value != 0)
    n_valid = np.sum(valid_mask)

    if n_valid == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No valid samples")
        return results

    states = stan_value[valid_mask]
    actions = akcja_value[valid_mask]

    # Check sign alignment (same sign = correct direction)
    # Note: Near zero, signs may differ legitimately
    threshold = 0.1  # Ignore small values

    significant_mask = np.abs(states) > threshold
    n_significant = np.sum(significant_mask)

    if n_significant > 0:
        sig_states = states[significant_mask]
        sig_actions = actions[significant_mask]

        # Same sign = correct direction
        correct_direction = np.sign(sig_states) == np.sign(sig_actions)
        n_correct = np.sum(correct_direction)

        results['metrics']['n_significant_samples'] = int(n_significant)
        results['metrics']['n_correct_direction'] = int(n_correct)
        results['metrics']['correct_direction_rate'] = float(100 * n_correct / n_significant)

        if n_correct / n_significant < 0.7:
            results['status'] = 'WARNING'
            results['issues'].append(
                f"Only {100*n_correct/n_significant:.1f}% actions in correct direction"
            )

    return results


def check_oscillation_pattern(data: LogData) -> dict:
    """
    Detect oscillation patterns that indicate constraint violations.

    Oscillation symptoms:
    - State alternating above/below goal
    - Action alternating above/below goal
    - Limited progress toward goal
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    state_nr = data.as_array('Q_stan_nr')
    goal_state, _ = detect_goal_indices(data)

    valid_mask = state_nr > 0
    states = state_nr[valid_mask]

    if len(states) < 100:
        results['status'] = 'INFO'
        results['issues'].append("Insufficient data for oscillation analysis")
        return results

    # Calculate state position relative to goal
    relative_pos = states - goal_state

    # Sign changes indicate crossing goal
    sign_changes = np.diff(np.sign(relative_pos)) != 0
    n_sign_changes = np.sum(sign_changes)

    results['metrics']['n_goal_crossings'] = int(n_sign_changes)
    results['metrics']['crossing_rate'] = float(100 * n_sign_changes / len(states))

    # High crossing rate with little time at goal = oscillation
    at_goal = np.abs(relative_pos) <= 1  # Within 1 state of goal
    time_at_goal = np.sum(at_goal) / len(states)

    results['metrics']['time_at_goal_pct'] = float(100 * time_at_goal)

    # Detect oscillation: many crossings but little time at goal
    if n_sign_changes / len(states) > 0.1 and time_at_goal < 0.1:
        results['status'] = 'WARNING'
        results['issues'].append(
            f"Possible oscillation: {n_sign_changes} goal crossings but only "
            f"{100*time_at_goal:.1f}% time at goal"
        )

    # Check for stuck pattern (state staying in narrow range)
    state_range = np.max(states) - np.min(states)
    state_std = np.std(states)

    results['metrics']['state_range'] = int(state_range)
    results['metrics']['state_std'] = float(state_std)

    # Analyze recent behavior (last 1000 samples)
    if len(states) > 1000:
        recent = states[-1000:]
        recent_at_goal = np.sum(np.abs(recent - goal_state) <= 1) / len(recent)
        results['metrics']['recent_time_at_goal_pct'] = float(100 * recent_at_goal)

        if recent_at_goal < 0.05:
            results['issues'].append(
                f"Recent behavior: only {100*recent_at_goal:.1f}% time at goal"
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


def analyze_constraints(data: LogData) -> dict:
    """Run all constraint violation checks."""
    print("=" * 60)
    print(f"Constraint Violation Analysis: {data.filename}")
    print(f"Samples: {data.n_samples:,}")
    print("=" * 60)

    all_results = {}

    # Same-side constraint (Bug #6)
    all_results['same_side'] = check_same_side_constraint(data)
    print_results("Same-Side Constraint (Bug #6)", all_results['same_side'])

    # Action direction
    all_results['direction'] = check_action_direction(data)
    print_results("Action Direction Check", all_results['direction'])

    # Oscillation detection
    all_results['oscillation'] = check_oscillation_pattern(data)
    print_results("Oscillation Pattern Detection", all_results['oscillation'])

    # Summary
    print("\n" + "=" * 60)
    print("CONSTRAINT ANALYSIS SUMMARY")
    print("=" * 60)

    errors = sum(1 for r in all_results.values() if r['status'] == 'ERROR')
    warnings = sum(1 for r in all_results.values() if r['status'] == 'WARNING')

    if errors > 0:
        print(f"✗ {errors} ERROR(s) - Constraint violations detected")
        print("  Likely Bug #6: same-side constraint not enforced")
        print("  Check m_losowanie_nowe.m lines 60-62")
    elif warnings > 0:
        print(f"⚠ {warnings} WARNING(s) - Potential constraint issues")
    else:
        print("✓ All constraint checks passed")

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

    analyze_constraints(data)


if __name__ == "__main__":
    main()
