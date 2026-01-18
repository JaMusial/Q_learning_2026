"""
Log Comparison Tool
===================

Compares before and after learning logs to evaluate Q-learning improvement.

This tool helps answer:
- Did learning improve controller performance?
- How does Q controller compare to PI controller?
- What metrics improved/degraded during training?

Usage:
    python compare_logs.py
    python compare_logs.py before.json after.json

Comparison Metrics:
- Error (Q_e, PID_e): Should decrease after learning
- Control effort (Q_u, PID_u): Similar or smoother after learning
- Goal state visitation: Should increase after learning
- Q-value convergence: Q(goal,goal) should approach 100
"""

import sys
import numpy as np
from pathlib import Path
from typing import Dict, Tuple

sys.path.insert(0, str(Path(__file__).parent))
from json_loader import load_debug_json, get_available_logs, LogData


def calculate_performance_metrics(data: LogData) -> Dict[str, float]:
    """
    Calculate performance metrics for a log dataset.

    Returns dict with:
    - IAE (Integrated Absolute Error)
    - ITAE (Integrated Time-weighted Absolute Error)
    - Control effort
    - Settling metrics
    """
    metrics = {}

    # Error metrics (Q controller)
    q_e = data.as_array('Q_e')
    q_t = data.as_array('Q_t')

    if len(q_e) > 0:
        valid = q_e != 0
        if np.sum(valid) > 0:
            q_e_valid = q_e[valid]
            metrics['Q_MAE'] = float(np.mean(np.abs(q_e_valid)))
            metrics['Q_RMS_error'] = float(np.sqrt(np.mean(q_e_valid**2)))
            metrics['Q_max_error'] = float(np.max(np.abs(q_e_valid)))

            # IAE approximation
            if len(q_t) == len(q_e):
                dt = np.diff(q_t)
                if len(dt) > 0:
                    dt_mean = np.mean(dt[dt > 0]) if np.any(dt > 0) else 0.1
                    metrics['Q_IAE'] = float(np.sum(np.abs(q_e_valid)) * dt_mean)

    # Error metrics (PI controller)
    pid_e = data.as_array('PID_e')

    if len(pid_e) > 0:
        valid = pid_e != 0
        if np.sum(valid) > 0:
            pid_e_valid = pid_e[valid]
            metrics['PI_MAE'] = float(np.mean(np.abs(pid_e_valid)))
            metrics['PI_RMS_error'] = float(np.sqrt(np.mean(pid_e_valid**2)))
            metrics['PI_max_error'] = float(np.max(np.abs(pid_e_valid)))

    # Control effort (Q)
    q_u = data.as_array('Q_u')
    if len(q_u) > 0:
        valid = q_u > 0
        if np.sum(valid) > 0:
            q_u_valid = q_u[valid]
            metrics['Q_mean_control'] = float(np.mean(q_u_valid))
            metrics['Q_control_variance'] = float(np.var(q_u_valid))

            # Control smoothness (sum of squared increments)
            du = np.diff(q_u_valid)
            metrics['Q_control_smoothness'] = float(np.sum(du**2))

    # Control effort (PI)
    pid_u = data.as_array('PID_u')
    if len(pid_u) > 0:
        valid = pid_u > 0
        if np.sum(valid) > 0:
            pid_u_valid = pid_u[valid]
            metrics['PI_mean_control'] = float(np.mean(pid_u_valid))
            metrics['PI_control_variance'] = float(np.var(pid_u_valid))

            du = np.diff(pid_u_valid)
            metrics['PI_control_smoothness'] = float(np.sum(du**2))

    # Goal state metrics
    state_nr = data.as_array('Q_stan_nr')
    if len(state_nr) > 0:
        valid = state_nr > 0
        if np.sum(valid) > 0:
            states = state_nr[valid]
            # Time at/near goal (states 49-51)
            at_goal = np.sum((states >= 49) & (states <= 51))
            metrics['goal_region_time_pct'] = float(100 * at_goal / len(states))

    # Q-value metrics
    goal_q = data.as_array('DEBUG_goal_Q')
    if len(goal_q) > 0:
        valid = goal_q > 0
        if np.sum(valid) > 0:
            metrics['goal_Q_final'] = float(goal_q[valid][-1])
            metrics['goal_Q_max'] = float(np.max(goal_q[valid]))

    return metrics


def compare_metrics(before: Dict, after: Dict) -> Dict[str, Dict]:
    """
    Compare metrics between before and after learning.

    Returns dict with comparison results for each metric.
    """
    comparisons = {}

    all_keys = set(before.keys()) | set(after.keys())

    for key in all_keys:
        val_before = before.get(key)
        val_after = after.get(key)

        if val_before is not None and val_after is not None:
            diff = val_after - val_before
            pct_change = 100 * diff / val_before if val_before != 0 else float('inf')

            # Determine if change is improvement
            # For error metrics: decrease is good
            # For goal_Q: increase is good
            # For smoothness: decrease is good
            if 'error' in key.lower() or 'mae' in key.lower() or 'rms' in key.lower():
                improved = diff < 0
            elif 'goal_q' in key.lower() or 'goal_region' in key.lower():
                improved = diff > 0
            elif 'smoothness' in key.lower() or 'variance' in key.lower():
                improved = diff < 0
            else:
                improved = None  # Neutral

            comparisons[key] = {
                'before': val_before,
                'after': val_after,
                'diff': diff,
                'pct_change': pct_change,
                'improved': improved
            }

    return comparisons


def compare_q_vs_pi(data: LogData) -> Dict[str, Dict]:
    """
    Compare Q controller vs PI controller within the same log.
    """
    comparisons = {}

    # Error comparison
    q_e = data.as_array('Q_e')
    pid_e = data.as_array('PID_e')

    if len(q_e) > 0 and len(pid_e) > 0:
        # Align lengths
        min_len = min(len(q_e), len(pid_e))
        q_e = q_e[:min_len]
        pid_e = pid_e[:min_len]

        valid = (q_e != 0) | (pid_e != 0)
        if np.sum(valid) > 0:
            q_mae = np.mean(np.abs(q_e[valid]))
            pi_mae = np.mean(np.abs(pid_e[valid]))

            comparisons['MAE'] = {
                'Q': float(q_mae),
                'PI': float(pi_mae),
                'ratio': float(q_mae / pi_mae) if pi_mae > 0 else float('inf'),
                'Q_better': q_mae < pi_mae
            }

            q_rms = np.sqrt(np.mean(q_e[valid]**2))
            pi_rms = np.sqrt(np.mean(pid_e[valid]**2))

            comparisons['RMS'] = {
                'Q': float(q_rms),
                'PI': float(pi_rms),
                'ratio': float(q_rms / pi_rms) if pi_rms > 0 else float('inf'),
                'Q_better': q_rms < pi_rms
            }

    # Control effort comparison
    q_u = data.as_array('Q_u')
    pid_u = data.as_array('PID_u')

    if len(q_u) > 0 and len(pid_u) > 0:
        min_len = min(len(q_u), len(pid_u))
        q_u = q_u[:min_len]
        pid_u = pid_u[:min_len]

        valid = (q_u > 0) | (pid_u > 0)
        if np.sum(valid) > 0:
            # Control smoothness
            q_du = np.sum(np.diff(q_u[valid])**2)
            pi_du = np.sum(np.diff(pid_u[valid])**2)

            comparisons['control_smoothness'] = {
                'Q': float(q_du),
                'PI': float(pi_du),
                'ratio': float(q_du / pi_du) if pi_du > 0 else float('inf'),
                'Q_better': q_du < pi_du
            }

    return comparisons


def print_comparison_report(before_metrics: Dict, after_metrics: Dict,
                           comparisons: Dict, q_vs_pi: Dict = None):
    """Print a formatted comparison report."""
    print("\n" + "=" * 70)
    print("                    LEARNING COMPARISON REPORT")
    print("=" * 70)

    # Summary table
    print("\nMETRIC COMPARISON: BEFORE vs AFTER LEARNING")
    print("-" * 70)
    print(f"{'Metric':<30} {'Before':>12} {'After':>12} {'Change':>12} {'Status':<8}")
    print("-" * 70)

    for key, comp in sorted(comparisons.items()):
        status = ""
        if comp['improved'] is True:
            status = "✓ Better"
        elif comp['improved'] is False:
            status = "✗ Worse"
        else:
            status = "- N/A"

        pct_str = f"{comp['pct_change']:+.1f}%" if abs(comp['pct_change']) < 1000 else "N/A"

        print(f"{key:<30} {comp['before']:>12.4f} {comp['after']:>12.4f} {pct_str:>12} {status:<8}")

    print("-" * 70)

    # Q vs PI comparison
    if q_vs_pi:
        print("\nQ CONTROLLER vs PI CONTROLLER (After Learning)")
        print("-" * 70)
        print(f"{'Metric':<30} {'Q':>12} {'PI':>12} {'Ratio':>12} {'Winner':<8}")
        print("-" * 70)

        for key, comp in sorted(q_vs_pi.items()):
            winner = "Q" if comp.get('Q_better') else "PI"
            print(f"{key:<30} {comp['Q']:>12.4f} {comp['PI']:>12.4f} {comp['ratio']:>12.4f} {winner:<8}")

        print("-" * 70)

    # Summary
    print("\nSUMMARY")
    print("=" * 70)

    improvements = sum(1 for c in comparisons.values() if c.get('improved') is True)
    degradations = sum(1 for c in comparisons.values() if c.get('improved') is False)

    print(f"Improvements: {improvements}")
    print(f"Degradations: {degradations}")

    # Key findings
    goal_q_before = before_metrics.get('goal_Q_final', 0)
    goal_q_after = after_metrics.get('goal_Q_final', 0)

    if goal_q_after > 0:
        print(f"\nQ(goal,goal): {goal_q_before:.2f} → {goal_q_after:.2f}")
        if goal_q_after >= 90:
            print("  ✓ Q-value well converged")
        elif goal_q_after >= 70:
            print("  ⚠ Q-value partially converged, more training may help")
        else:
            print("  ✗ Q-value not converged, check for bugs")

    # Q vs PI verdict
    if q_vs_pi:
        q_wins = sum(1 for c in q_vs_pi.values() if c.get('Q_better'))
        pi_wins = len(q_vs_pi) - q_wins

        print(f"\nQ vs PI: Q wins {q_wins}, PI wins {pi_wins}")
        if q_wins > pi_wins:
            print("  ✓ Q controller outperforms PI")
        elif q_wins == pi_wins:
            print("  - Q controller matches PI performance")
        else:
            print("  ⚠ Q controller underperforms PI, learning may not be effective")


def main():
    """Main entry point."""
    args = [a for a in sys.argv[1:] if not a.startswith('-')]

    if len(args) == 2:
        # Compare two specific files
        before_file, after_file = args
        try:
            before_data = load_debug_json(before_file)
            after_data = load_debug_json(after_file)
        except FileNotFoundError as e:
            print(f"Error: {e}")
            sys.exit(1)
    else:
        # Use default before/after files
        logs = get_available_logs()

        if 'before' not in logs or 'after' not in logs:
            print("Error: Need both 'before' and 'after' learning logs")
            print("Available logs:", list(logs.keys()))
            print("\nUsage: python compare_logs.py [before.json after.json]")
            sys.exit(1)

        before_data = logs['before']
        after_data = logs['after']

    print("=" * 70)
    print("Q-LEARNING COMPARISON TOOL")
    print("=" * 70)
    print(f"Before: {before_data.filename} ({before_data.n_samples:,} samples)")
    print(f"After:  {after_data.filename} ({after_data.n_samples:,} samples)")

    # Calculate metrics
    print("\nCalculating metrics...")
    before_metrics = calculate_performance_metrics(before_data)
    after_metrics = calculate_performance_metrics(after_data)

    # Compare before vs after
    comparisons = compare_metrics(before_metrics, after_metrics)

    # Compare Q vs PI (using after data)
    q_vs_pi = compare_q_vs_pi(after_data)

    # Print report
    print_comparison_report(before_metrics, after_metrics, comparisons, q_vs_pi)


if __name__ == "__main__":
    main()
