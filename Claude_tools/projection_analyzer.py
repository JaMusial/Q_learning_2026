"""
Projection Function Analyzer
============================

Analyzes the projection function behavior in Q-learning controller.

This tool detects Bug #10 from CLAUDE.md:
- Projection function was disabled at goal state due to state-based exclusion
- On-trajectory problem: state ≈ 0 even with large error when following trajectory
- Sign check failure when action value = 0

Projection Function Math:
    PI control:     u_inc = Kp·dt·(de + e/Ti)
    Q2d state:      s = de + e/Te
    With identity Q: action ≈ state_value = de + e/Te
    Projection:     action - e·(1/Te - 1/Ti) = de + e/Ti  ✓ matches PI!

Usage:
    python projection_analyzer.py [json_file]
    python projection_analyzer.py  # defaults to logi_training.json
"""

import sys
import numpy as np
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from json_loader import load_debug_json, LogData, get_available_logs


def analyze_projection_application(data: LogData) -> dict:
    """
    Analyze when projection function is applied.

    Bug #10 symptoms:
    - Projection not applied at goal state (state ∈ {49, 50, 51})
    - Projection not applied when action value = 0 (sign check fails)
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    funkcja_rzut = data.as_array('Q_funkcja_rzut')
    akcja_value = data.as_array('Q_akcja_value')
    akcja_bez_rzut = data.as_array('Q_akcja_value_bez_f_rzutujacej')
    state_nr = data.as_array('Q_stan_nr')
    error = data.as_array('Q_e')

    if len(funkcja_rzut) == 0:
        results['status'] = 'INFO'
        results['issues'].append("No projection data - f_rzutujaca_on may be 0")
        return results

    # Check if projection is being used at all
    nonzero_proj = np.sum(funkcja_rzut != 0)
    results['metrics']['n_nonzero_projection'] = int(nonzero_proj)
    results['metrics']['projection_usage_rate'] = float(100 * nonzero_proj / len(funkcja_rzut))

    if nonzero_proj == 0:
        results['status'] = 'INFO'
        results['issues'].append("Projection function is all zeros - f_rzutujaca_on=0 or Te=Ti")
        return results

    # Analyze projection vs action difference
    if len(akcja_value) > 0 and len(akcja_bez_rzut) > 0:
        # Difference between action with and without projection
        diff = akcja_value - akcja_bez_rzut
        nonzero_diff = np.sum(diff != 0)

        results['metrics']['n_projection_applied'] = int(nonzero_diff)
        results['metrics']['projection_applied_rate'] = float(100 * nonzero_diff / len(diff))

        # Check consistency: diff should equal -funkcja_rzut when applied
        if nonzero_diff > 0:
            expected_diff = -funkcja_rzut
            match = np.isclose(diff, expected_diff, atol=0.001)
            match_rate = np.sum(match) / len(diff)
            results['metrics']['projection_consistency'] = float(100 * match_rate)

    # Bug #10 check: projection at goal state region
    if len(state_nr) > 0:
        # Goal state region (49, 50, 51)
        goal_region = (state_nr >= 49) & (state_nr <= 51)
        n_goal_region = np.sum(goal_region)

        if n_goal_region > 0:
            proj_at_goal = funkcja_rzut[goal_region]
            n_proj_applied_at_goal = np.sum(proj_at_goal != 0)

            results['metrics']['n_samples_at_goal_region'] = int(n_goal_region)
            results['metrics']['projection_at_goal_region'] = int(n_proj_applied_at_goal)
            results['metrics']['projection_at_goal_rate'] = float(
                100 * n_proj_applied_at_goal / n_goal_region
            )

            # Bug #10: projection should still be applied at goal if error is large
            if len(error) > 0:
                error_at_goal = error[goal_region]
                large_error_at_goal = np.abs(error_at_goal) > 0.5  # > 0.5% error
                n_large_error = np.sum(large_error_at_goal)

                if n_large_error > 0:
                    proj_when_large_error = proj_at_goal[large_error_at_goal] != 0
                    n_proj_when_needed = np.sum(proj_when_large_error)

                    results['metrics']['n_large_error_at_goal'] = int(n_large_error)
                    results['metrics']['projection_when_needed'] = int(n_proj_when_needed)
                    results['metrics']['projection_when_needed_rate'] = float(
                        100 * n_proj_when_needed / n_large_error
                    )

                    if n_proj_when_needed < n_large_error * 0.9:
                        results['status'] = 'WARNING'
                        results['issues'].append(
                            f"Projection missing at goal with large error: "
                            f"only {100*n_proj_when_needed/n_large_error:.1f}% applied - Bug #10?"
                        )

    return results


def analyze_on_trajectory_problem(data: LogData) -> dict:
    """
    Analyze the on-trajectory problem.

    When system follows target trajectory perfectly:
    - de + e/Te ≈ 0 (state value near zero)
    - Even with large error, state is near goal
    - Q controller may do nothing while PI correctly drives output
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    error = data.as_array('Q_e')
    de = data.as_array('Q_de')
    stan_value = data.as_array('Q_stan_value')
    state_nr = data.as_array('Q_stan_nr')

    if len(error) == 0 or len(de) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No error/derivative data")
        return results

    # Find samples where error is large but state is at goal
    # This indicates on-trajectory behavior
    large_error_threshold = 5.0  # 5% error
    goal_state_region = (49, 51)

    large_error = np.abs(error) > large_error_threshold
    at_goal = (state_nr >= goal_state_region[0]) & (state_nr <= goal_state_region[1])

    # On-trajectory: large error but at goal state
    on_trajectory = large_error & at_goal
    n_on_trajectory = np.sum(on_trajectory)

    results['metrics']['n_large_error'] = int(np.sum(large_error))
    results['metrics']['n_at_goal'] = int(np.sum(at_goal))
    results['metrics']['n_on_trajectory_problem'] = int(n_on_trajectory)

    if np.sum(large_error) > 0:
        results['metrics']['on_trajectory_rate'] = float(
            100 * n_on_trajectory / np.sum(large_error)
        )

    if n_on_trajectory > 0:
        # Analyze these problematic samples
        on_traj_errors = error[on_trajectory]
        on_traj_de = de[on_trajectory]
        on_traj_state_val = stan_value[on_trajectory]

        results['details']['on_traj_error_mean'] = float(np.mean(np.abs(on_traj_errors)))
        results['details']['on_traj_error_max'] = float(np.max(np.abs(on_traj_errors)))
        results['details']['on_traj_state_val_mean'] = float(np.mean(on_traj_state_val))

        # This is the on-trajectory problem: state_value ≈ 0 despite large error
        if np.mean(np.abs(on_traj_state_val)) < 1.0:
            results['status'] = 'INFO'
            results['issues'].append(
                f"{n_on_trajectory} samples with on-trajectory problem: "
                f"error={np.mean(np.abs(on_traj_errors)):.1f}% but state≈0"
            )

    return results


def analyze_projection_effectiveness(data: LogData) -> dict:
    """
    Analyze if projection makes Q controller behave like PI.

    Goal: action_after_projection ≈ PI_action_increment
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    q_u_inc = data.as_array('Q_u_increment')
    pid_e = data.as_array('PID_e')
    pid_de = data.as_array('PID_de') if 'PID_de' in data else None

    if len(q_u_inc) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No control increment data")
        return results

    # Compare Q and PI control signals
    q_u = data.as_array('Q_u')
    pid_u = data.as_array('PID_u')

    if len(q_u) > 0 and len(pid_u) > 0:
        # Control signal comparison
        valid_mask = (q_u > 0) & (pid_u > 0)
        n_valid = np.sum(valid_mask)

        if n_valid > 0:
            q_valid = q_u[valid_mask]
            pid_valid = pid_u[valid_mask]

            # Calculate difference
            diff = q_valid - pid_valid
            results['metrics']['control_diff_mean'] = float(np.mean(diff))
            results['metrics']['control_diff_std'] = float(np.std(diff))
            results['metrics']['control_diff_max'] = float(np.max(np.abs(diff)))

            # Correlation
            if np.std(q_valid) > 0 and np.std(pid_valid) > 0:
                corr = np.corrcoef(q_valid, pid_valid)[0, 1]
                results['metrics']['q_pi_correlation'] = float(corr)

                if corr < 0.9:
                    results['status'] = 'WARNING'
                    results['issues'].append(
                        f"Low Q-PI correlation: {corr:.3f} - projection may not be working"
                    )

    # Analyze control increment comparison
    q_u_inc_bez = data.as_array('Q_u_increment_bez_f_rzutujacej')

    if len(q_u_inc) > 0 and len(q_u_inc_bez) > 0:
        # Impact of projection on control increments
        proj_impact = q_u_inc - q_u_inc_bez
        nonzero_impact = np.sum(proj_impact != 0)

        results['metrics']['n_projection_changes'] = int(nonzero_impact)
        results['metrics']['mean_projection_impact'] = float(np.mean(np.abs(proj_impact)))

    return results


def analyze_te_ti_relationship(data: LogData) -> dict:
    """
    Analyze the Te/Ti relationship for projection.

    Projection coefficient: 1/Te - 1/Ti
    - Te = Ti: projection = 0 (no effect)
    - Te < Ti: projection > 0 (adds to action)
    - Te > Ti: projection < 0 (subtracts from action)
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    funkcja_rzut = data.as_array('Q_funkcja_rzut')
    error = data.as_array('Q_e')

    if len(funkcja_rzut) == 0 or np.all(funkcja_rzut == 0):
        results['status'] = 'INFO'
        results['issues'].append("No projection data to analyze Te/Ti relationship")
        return results

    # Estimate projection coefficient from data
    # projection = e * (1/Te - 1/Ti)
    # coefficient = projection / e (when e ≠ 0)

    nonzero_error = np.abs(error) > 0.1
    if np.sum(nonzero_error) > 100:
        e_valid = error[nonzero_error]
        proj_valid = funkcja_rzut[nonzero_error]

        # Estimate coefficient
        coefficients = proj_valid / e_valid
        # Filter outliers
        coefficients = coefficients[np.abs(coefficients) < 1.0]

        if len(coefficients) > 10:
            coef_mean = np.mean(coefficients)
            coef_std = np.std(coefficients)

            results['metrics']['estimated_coefficient'] = float(coef_mean)
            results['metrics']['coefficient_std'] = float(coef_std)

            # Interpret coefficient
            # coef = 1/Te - 1/Ti
            # If coef > 0: Te < Ti
            # If coef < 0: Te > Ti
            # If coef ≈ 0: Te ≈ Ti
            if abs(coef_mean) < 0.001:
                results['details']['interpretation'] = "Te ≈ Ti (no projection effect)"
            elif coef_mean > 0:
                # 1/Te - 1/Ti > 0 → 1/Te > 1/Ti → Te < Ti
                results['details']['interpretation'] = f"Te < Ti (coefficient={coef_mean:.4f})"
            else:
                results['details']['interpretation'] = f"Te > Ti (coefficient={coef_mean:.4f})"

            # Estimate Te if Ti is known (assume Ti=20)
            Ti_assumed = 20.0
            if abs(coef_mean) > 0.001:
                # coef = 1/Te - 1/Ti
                # 1/Te = coef + 1/Ti
                # Te = 1 / (coef + 1/Ti)
                Te_estimated = 1.0 / (coef_mean + 1.0/Ti_assumed)
                if Te_estimated > 0 and Te_estimated < 100:
                    results['metrics']['estimated_Te'] = float(Te_estimated)
                    results['details']['Te_Ti_note'] = f"Assuming Ti={Ti_assumed}, Te≈{Te_estimated:.1f}"

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


def analyze_projection(data: LogData) -> dict:
    """Run all projection function analyses."""
    print("=" * 60)
    print(f"Projection Function Analysis: {data.filename}")
    print(f"Samples: {data.n_samples:,}")
    print("=" * 60)

    all_results = {}

    # Projection application
    all_results['application'] = analyze_projection_application(data)
    print_results("Projection Application (Bug #10)", all_results['application'])

    # On-trajectory problem
    all_results['on_trajectory'] = analyze_on_trajectory_problem(data)
    print_results("On-Trajectory Problem", all_results['on_trajectory'])

    # Projection effectiveness
    all_results['effectiveness'] = analyze_projection_effectiveness(data)
    print_results("Projection Effectiveness (Q vs PI)", all_results['effectiveness'])

    # Te/Ti relationship
    all_results['te_ti'] = analyze_te_ti_relationship(data)
    print_results("Te/Ti Relationship", all_results['te_ti'])

    # Summary
    print("\n" + "=" * 60)
    print("PROJECTION ANALYSIS SUMMARY")
    print("=" * 60)

    errors = sum(1 for r in all_results.values() if r['status'] == 'ERROR')
    warnings = sum(1 for r in all_results.values() if r['status'] == 'WARNING')

    if errors > 0:
        print(f"✗ {errors} ERROR(s) - Projection function issues detected")
    elif warnings > 0:
        print(f"⚠ {warnings} WARNING(s) - Potential projection issues")
    else:
        print("✓ All projection checks passed (or projection disabled)")

    # Check if projection is even being used
    app_results = all_results.get('application', {})
    usage_rate = app_results.get('metrics', {}).get('projection_usage_rate', 0)
    if usage_rate < 1:
        print("\nNote: Projection function appears disabled (f_rzutujaca_on=0)")
        print("This is RECOMMENDED for production use (staged learning mode)")

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

    analyze_projection(data)


if __name__ == "__main__":
    main()
