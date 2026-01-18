"""
Q-Learning Convergence Analyzer
===============================

Analyzes Q-learning convergence by examining:
- TD (Temporal Difference) error trends
- Q-value evolution over time
- Bootstrap term analysis
- Learning rate effectiveness

Usage:
    python q_convergence_analyzer.py [json_file]
    python q_convergence_analyzer.py  # defaults to logi_training.json

Key Metrics:
- TD error should decrease over time (convergence)
- Q(goal,goal) should approach theoretical maximum (~100)
- Bootstrap values should be bounded
"""

import sys
import numpy as np
from pathlib import Path

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent))
from json_loader import load_debug_json, LogData, get_available_logs


def analyze_td_error(data: LogData) -> dict:
    """
    Analyze Temporal Difference error trends.

    TD error = R + gamma * max(Q(s',:)) - Q(s,a)

    Good signs:
    - Mean TD error decreasing over time
    - TD error variance decreasing
    - Mostly positive TD error (learning underestimated values)

    Bad signs:
    - TD error increasing or oscillating wildly
    - Large negative TD error (overestimated values)
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {}
    }

    td_error = data.as_array('DEBUG_TD_error')

    # Filter out zeros (non-learning samples)
    uczenie = data.as_array('DEBUG_uczenie_T0')
    learning_mask = uczenie == 1

    if np.sum(learning_mask) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No learning samples found (DEBUG_uczenie_T0 all zeros)")
        return results

    td_learning = td_error[learning_mask]

    # Skip if all zeros
    if np.all(td_learning == 0):
        results['status'] = 'WARNING'
        results['issues'].append("TD error is all zeros - debug logging may not be working")
        return results

    # Basic statistics
    results['metrics']['mean'] = float(np.mean(td_learning))
    results['metrics']['std'] = float(np.std(td_learning))
    results['metrics']['min'] = float(np.min(td_learning))
    results['metrics']['max'] = float(np.max(td_learning))
    results['metrics']['n_samples'] = int(len(td_learning))

    # Trend analysis: compare first half vs second half
    mid = len(td_learning) // 2
    if mid > 100:
        first_half_mean = np.mean(np.abs(td_learning[:mid]))
        second_half_mean = np.mean(np.abs(td_learning[mid:]))
        results['metrics']['first_half_abs_mean'] = float(first_half_mean)
        results['metrics']['second_half_abs_mean'] = float(second_half_mean)
        results['metrics']['improvement_ratio'] = float(first_half_mean / second_half_mean) if second_half_mean > 0 else 0

        if second_half_mean > first_half_mean * 1.2:
            results['status'] = 'WARNING'
            results['issues'].append(f"TD error INCREASED: {first_half_mean:.4f} -> {second_half_mean:.4f}")

    # Check for large negative TD errors (overestimation)
    large_negative = np.sum(td_learning < -10)
    if large_negative > len(td_learning) * 0.1:
        results['status'] = 'WARNING'
        results['issues'].append(f"{large_negative} samples ({100*large_negative/len(td_learning):.1f}%) have TD < -10 (overestimation)")

    # Moving average for trend
    window = min(1000, len(td_learning) // 10)
    if window > 10:
        td_abs = np.abs(td_learning)
        moving_avg = np.convolve(td_abs, np.ones(window)/window, mode='valid')
        results['metrics']['trend_start'] = float(moving_avg[0])
        results['metrics']['trend_end'] = float(moving_avg[-1])

    return results


def analyze_q_value_evolution(data: LogData) -> dict:
    """
    Analyze Q-value evolution during learning.

    Key metrics:
    - Q(goal, goal) should converge to ~100 (theoretical max with R=1, gamma=0.99)
    - Global max should stay at goal state
    - Q-values should be bounded
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {}
    }

    # Goal Q evolution
    goal_q = data.as_array('DEBUG_goal_Q')
    valid_goal_q = goal_q[goal_q > 0]

    if len(valid_goal_q) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No goal Q-value data found")
        return results

    results['metrics']['goal_q_start'] = float(valid_goal_q[0])
    results['metrics']['goal_q_end'] = float(valid_goal_q[-1])
    results['metrics']['goal_q_max'] = float(np.max(valid_goal_q))
    results['metrics']['goal_q_min'] = float(np.min(valid_goal_q))

    # Theoretical max: with R=1, gamma=0.99, Q_max = R/(1-gamma) = 100
    THEORETICAL_MAX = 100.0
    distance_to_max = THEORETICAL_MAX - valid_goal_q[-1]
    results['metrics']['distance_to_theoretical_max'] = float(distance_to_max)

    if valid_goal_q[-1] < 50:
        results['status'] = 'ERROR'
        results['issues'].append(f"Goal Q-value too low: {valid_goal_q[-1]:.2f} (expected ~100)")
    elif valid_goal_q[-1] < 90:
        results['status'] = 'WARNING'
        results['issues'].append(f"Goal Q-value not converged: {valid_goal_q[-1]:.2f} (expected ~100)")

    # Check if goal Q decreased (Bug #5 symptom)
    if valid_goal_q[-1] < valid_goal_q[0] - 5:
        results['status'] = 'ERROR'
        results['issues'].append(f"Goal Q DECREASED: {valid_goal_q[0]:.2f} -> {valid_goal_q[-1]:.2f} (Bug #5?)")

    # Global max location
    max_state = data.as_array('DEBUG_global_max_state')
    max_action = data.as_array('DEBUG_global_max_action')
    valid_mask = max_state > 0

    if np.sum(valid_mask) > 0:
        # Find most common max location
        from collections import Counter
        states = max_state[valid_mask].astype(int)
        actions = max_action[valid_mask].astype(int)

        state_counts = Counter(states)
        action_counts = Counter(actions)

        most_common_state = state_counts.most_common(1)[0]
        most_common_action = action_counts.most_common(1)[0]

        results['metrics']['most_common_max_state'] = most_common_state[0]
        results['metrics']['most_common_max_state_pct'] = 100 * most_common_state[1] / len(states)
        results['metrics']['most_common_max_action'] = most_common_action[0]
        results['metrics']['most_common_max_action_pct'] = 100 * most_common_action[1] / len(actions)

        # Check if max is at expected goal (typically state/action 50)
        if most_common_state[1] / len(states) < 0.9:
            results['status'] = 'WARNING'
            results['issues'].append(
                f"Global max not stable at goal state: only {most_common_state[1]/len(states)*100:.1f}% at state {most_common_state[0]}"
            )

    return results


def analyze_bootstrap(data: LogData) -> dict:
    """
    Analyze bootstrap term: gamma * max(Q(s',:))

    The bootstrap should:
    - Be bounded by gamma * Q_max (typically ~99)
    - Gradually increase as Q-values improve
    - Not show extreme values
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {}
    }

    bootstrap = data.as_array('DEBUG_bootstrap')
    uczenie = data.as_array('DEBUG_uczenie_T0')
    learning_mask = uczenie == 1

    if np.sum(learning_mask) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No learning samples for bootstrap analysis")
        return results

    bootstrap_learning = bootstrap[learning_mask]

    # Filter out zeros
    valid = bootstrap_learning[bootstrap_learning > 0]
    if len(valid) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("Bootstrap values all zero")
        return results

    results['metrics']['mean'] = float(np.mean(valid))
    results['metrics']['std'] = float(np.std(valid))
    results['metrics']['min'] = float(np.min(valid))
    results['metrics']['max'] = float(np.max(valid))

    # Expected max bootstrap: gamma * Q_max ~ 0.99 * 100 = 99
    EXPECTED_MAX_BOOTSTRAP = 99.0
    if np.max(valid) > EXPECTED_MAX_BOOTSTRAP + 5:
        results['status'] = 'WARNING'
        results['issues'].append(f"Bootstrap exceeds expected max: {np.max(valid):.2f} > {EXPECTED_MAX_BOOTSTRAP}")

    # Check trend
    if len(valid) > 200:
        first_100 = np.mean(valid[:100])
        last_100 = np.mean(valid[-100:])
        results['metrics']['trend_start'] = float(first_100)
        results['metrics']['trend_end'] = float(last_100)

        if last_100 < first_100 * 0.9:
            results['status'] = 'WARNING'
            results['issues'].append(f"Bootstrap decreased: {first_100:.2f} -> {last_100:.2f}")

    return results


def analyze_q_updates(data: LogData) -> dict:
    """
    Analyze Q-value update magnitudes.

    Healthy learning:
    - Updates gradually decrease in magnitude
    - No extreme updates (indicates instability)
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {}
    }

    q_old = data.as_array('DEBUG_Q_old_value')
    q_new = data.as_array('DEBUG_Q_new_value')

    # Calculate updates
    updates = q_new - q_old
    valid_mask = (q_old != 0) | (q_new != 0)

    if np.sum(valid_mask) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No Q-update data found")
        return results

    valid_updates = updates[valid_mask]

    results['metrics']['mean_update'] = float(np.mean(valid_updates))
    results['metrics']['std_update'] = float(np.std(valid_updates))
    results['metrics']['max_positive_update'] = float(np.max(valid_updates))
    results['metrics']['max_negative_update'] = float(np.min(valid_updates))
    results['metrics']['n_positive'] = int(np.sum(valid_updates > 0))
    results['metrics']['n_negative'] = int(np.sum(valid_updates < 0))

    # Check for extreme updates
    extreme_threshold = 10.0
    n_extreme = np.sum(np.abs(valid_updates) > extreme_threshold)
    if n_extreme > len(valid_updates) * 0.01:
        results['status'] = 'WARNING'
        results['issues'].append(f"{n_extreme} extreme updates (|delta Q| > {extreme_threshold})")

    # Trend: updates should decrease
    if len(valid_updates) > 200:
        first_half = np.mean(np.abs(valid_updates[:len(valid_updates)//2]))
        second_half = np.mean(np.abs(valid_updates[len(valid_updates)//2:]))
        results['metrics']['first_half_mean_abs'] = float(first_half)
        results['metrics']['second_half_mean_abs'] = float(second_half)

        if second_half > first_half * 1.5:
            results['status'] = 'WARNING'
            results['issues'].append(f"Update magnitude increased: {first_half:.4f} -> {second_half:.4f}")

    return results


def print_results(title: str, results: dict):
    """Pretty print analysis results."""
    status_symbol = {
        'OK': '✓',
        'WARNING': '⚠',
        'ERROR': '✗'
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

    if results['issues']:
        print("Issues:")
        for issue in results['issues']:
            print(f"  - {issue}")

    if results['status'] == 'OK' and not results['issues']:
        print("  No issues detected")


def analyze_convergence(data: LogData) -> dict:
    """Run all convergence analyses on log data."""
    print("=" * 60)
    print(f"Q-Learning Convergence Analysis: {data.filename}")
    print(f"Samples: {data.n_samples:,}")
    print("=" * 60)

    all_results = {}

    # TD Error Analysis
    all_results['td_error'] = analyze_td_error(data)
    print_results("TD Error Analysis", all_results['td_error'])

    # Q-Value Evolution
    all_results['q_evolution'] = analyze_q_value_evolution(data)
    print_results("Q-Value Evolution", all_results['q_evolution'])

    # Bootstrap Analysis
    all_results['bootstrap'] = analyze_bootstrap(data)
    print_results("Bootstrap Analysis", all_results['bootstrap'])

    # Q-Update Analysis
    all_results['q_updates'] = analyze_q_updates(data)
    print_results("Q-Update Magnitudes", all_results['q_updates'])

    # Overall summary
    print("\n" + "=" * 60)
    print("OVERALL SUMMARY")
    print("=" * 60)

    errors = sum(1 for r in all_results.values() if r['status'] == 'ERROR')
    warnings = sum(1 for r in all_results.values() if r['status'] == 'WARNING')

    if errors > 0:
        print(f"✗ {errors} ERROR(s) found - Q-learning has serious issues")
    elif warnings > 0:
        print(f"⚠ {warnings} WARNING(s) found - Q-learning may have issues")
    else:
        print("✓ All checks passed - Q-learning appears to be converging properly")

    return all_results


def main():
    """Main entry point."""
    # Determine which file to analyze
    if len(sys.argv) > 1:
        filename = sys.argv[1]
    else:
        filename = 'logi_training.json'

    try:
        data = load_debug_json(filename)
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found")
        print("\nAvailable files:")
        logs = get_available_logs()
        for name in logs:
            print(f"  - {name}")
        sys.exit(1)

    if not data.has_debug_data:
        print("Warning: Debug data appears to be empty or all zeros")
        print("Make sure debug_logging=1 in config.m before running MATLAB")

    analyze_convergence(data)


if __name__ == "__main__":
    main()
