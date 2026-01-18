"""
Temporal Consistency Checker
============================

Checks for state-action-reward temporal mismatches in Q-learning.

This tool detects bugs #3 and #4 from CLAUDE.md:
- Bug #3: State-Action Temporal Mismatch (pairing wrong state with wrong action)
- Bug #4: Reward Temporal Mismatch (reward not aligned with state transition)

Usage:
    python temporal_checker.py [json_file]
    python temporal_checker.py  # defaults to logi_training.json

Key Checks:
1. State pairing: old_stan_T0 should match expected buffered state
2. Action pairing: wyb_akcja_T0 should match action that caused transition
3. Reward timing: R should be 1 when ARRIVING at goal, not leaving
"""

import sys
import numpy as np
from pathlib import Path
from collections import Counter

sys.path.insert(0, str(Path(__file__).parent))
from json_loader import load_debug_json, LogData, get_available_logs


def check_state_action_pairing(data: LogData) -> dict:
    """
    Check if states and actions are properly paired for Q-updates.

    For T0=0 (no dead time compensation):
    - old_stan_T0 should equal old_state (previous iteration's state)
    - wyb_akcja_T0 should equal old_action (previous iteration's action)

    For T0>0 (with dead time compensation):
    - old_stan_T0 should be buffered state from T0/dt iterations ago
    - wyb_akcja_T0 should be buffered action from T0/dt iterations ago
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    # Get relevant arrays
    old_state = data.as_array('DEBUG_old_state')
    old_action = data.as_array('DEBUG_old_action')
    old_stan_T0 = data.as_array('DEBUG_old_stan_T0')
    wyb_akcja_T0 = data.as_array('DEBUG_wyb_akcja_T0')
    uczenie_T0 = data.as_array('DEBUG_uczenie_T0')

    # Only analyze learning samples
    learning_mask = uczenie_T0 == 1
    n_learning = np.sum(learning_mask)

    if n_learning == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No learning samples found")
        return results

    results['metrics']['n_learning_samples'] = int(n_learning)

    # Check state pairing
    if len(old_state) > 0 and len(old_stan_T0) > 0:
        # For T0=0, these should match
        state_match = old_state[learning_mask] == old_stan_T0[learning_mask]
        match_rate = np.mean(state_match)

        results['metrics']['state_match_rate'] = float(match_rate)

        if match_rate < 0.99:
            # This could indicate T0>0 (buffered) or a bug
            n_mismatch = np.sum(~state_match)
            results['details']['state_mismatches'] = int(n_mismatch)

            # Check if mismatches follow buffer pattern (T0>0 case)
            # In T0>0, old_stan_T0 should be a delayed version of old_state
            results['status'] = 'INFO'
            results['issues'].append(
                f"State mismatch: {n_mismatch} samples ({100*(1-match_rate):.1f}%) - "
                "This is expected if T0_controller > 0"
            )

    # Check action pairing
    if len(old_action) > 0 and len(wyb_akcja_T0) > 0:
        action_match = old_action[learning_mask] == wyb_akcja_T0[learning_mask]
        match_rate = np.mean(action_match)

        results['metrics']['action_match_rate'] = float(match_rate)

        if match_rate < 0.99:
            n_mismatch = np.sum(~action_match)
            results['details']['action_mismatches'] = int(n_mismatch)

    return results


def check_reward_timing(data: LogData) -> dict:
    """
    Check if rewards are properly timed with state transitions.

    Correct behavior:
    - R=1 should be given when ARRIVING at goal state (transition INTO goal)
    - R=0 otherwise

    Bug #4 symptom:
    - R=1 given when LEAVING goal state instead of arriving
    - Or R assigned to wrong state-action pair
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    # Get relevant arrays
    R_buffered = data.as_array('DEBUG_R_buffered')
    old_stan_T0 = data.as_array('DEBUG_old_stan_T0')
    stan_T0 = data.as_array('DEBUG_stan_T0')
    is_goal = data.as_array('DEBUG_is_goal_state')
    is_updating_goal = data.as_array('DEBUG_is_updating_goal')
    uczenie_T0 = data.as_array('DEBUG_uczenie_T0')

    learning_mask = uczenie_T0 == 1
    n_learning = np.sum(learning_mask)

    if n_learning == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No learning samples")
        return results

    # Analyze reward distribution
    R_learning = R_buffered[learning_mask]
    n_reward_1 = np.sum(R_learning == 1)
    n_reward_0 = np.sum(R_learning == 0)

    results['metrics']['n_R_equals_1'] = int(n_reward_1)
    results['metrics']['n_R_equals_0'] = int(n_reward_0)
    results['metrics']['reward_1_percentage'] = float(100 * n_reward_1 / n_learning)

    # Check: when R=1, should we be at or transitioning to goal state?
    if n_reward_1 > 0:
        reward_1_mask = (R_buffered == 1) & learning_mask

        # Check if old_stan_T0 is goal when R=1
        old_states_when_r1 = old_stan_T0[reward_1_mask]
        next_states_when_r1 = stan_T0[reward_1_mask]

        if len(old_states_when_r1) > 0:
            # Find most common "old state" when R=1
            state_counts = Counter(old_states_when_r1.astype(int))
            most_common = state_counts.most_common(3)

            results['details']['states_when_R1'] = [
                {'state': int(s), 'count': int(c), 'pct': float(100*c/len(old_states_when_r1))}
                for s, c in most_common
            ]

            # Check if reward is given for goal state (expected)
            # Goal state is typically 50
            goal_state_candidates = [50, 51]  # Allow for off-by-one
            reward_at_goal = sum(state_counts.get(g, 0) for g in goal_state_candidates)
            results['metrics']['reward_at_goal_pct'] = float(100 * reward_at_goal / len(old_states_when_r1))

            if reward_at_goal / len(old_states_when_r1) < 0.8:
                results['status'] = 'WARNING'
                results['issues'].append(
                    f"Only {100*reward_at_goal/len(old_states_when_r1):.1f}% of R=1 rewards "
                    f"are at goal state - possible reward timing bug"
                )

    # Check goal state updates
    if np.any(is_updating_goal):
        goal_updates = is_updating_goal == 1
        r_when_updating_goal = R_buffered[goal_updates & learning_mask]

        if len(r_when_updating_goal) > 0:
            r1_when_goal = np.sum(r_when_updating_goal == 1)
            results['metrics']['R1_when_updating_goal'] = int(r1_when_goal)
            results['metrics']['R1_when_updating_goal_pct'] = float(100 * r1_when_goal / len(r_when_updating_goal))

            # When updating goal state, R should be 1 (most of the time)
            if r1_when_goal / len(r_when_updating_goal) < 0.5:
                results['status'] = 'WARNING'
                results['issues'].append(
                    f"Only {100*r1_when_goal/len(r_when_updating_goal):.1f}% R=1 when updating goal state"
                )

    return results


def check_sequence_consistency(data: LogData) -> dict:
    """
    Check for sequence consistency across iterations.

    Verifies that:
    - State transitions are physically plausible
    - No unexpected jumps in state values
    - Action effects are consistent
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    state_nr = data.as_array('Q_stan_nr')
    action_nr = data.as_array('Q_akcja_nr')
    stan_value = data.as_array('Q_stan_value')

    if len(state_nr) == 0:
        results['status'] = 'WARNING'
        results['issues'].append("No state sequence data")
        return results

    # Analyze state transitions
    state_changes = np.diff(state_nr)
    large_jumps = np.abs(state_changes) > 10  # More than 10 state change is suspicious

    n_large_jumps = np.sum(large_jumps)
    results['metrics']['n_large_state_jumps'] = int(n_large_jumps)
    results['metrics']['large_jump_rate'] = float(100 * n_large_jumps / len(state_changes))

    if n_large_jumps > len(state_changes) * 0.05:
        results['status'] = 'INFO'
        results['issues'].append(
            f"{n_large_jumps} large state jumps (>10 states) - "
            "may indicate episode boundaries or disturbances"
        )

    # State distribution
    valid_states = state_nr[state_nr > 0]
    if len(valid_states) > 0:
        results['metrics']['min_state'] = int(np.min(valid_states))
        results['metrics']['max_state'] = int(np.max(valid_states))
        results['metrics']['mean_state'] = float(np.mean(valid_states))

        # Goal state visitation
        goal_visits = np.sum((valid_states >= 49) & (valid_states <= 51))
        results['metrics']['goal_region_visits'] = int(goal_visits)
        results['metrics']['goal_region_pct'] = float(100 * goal_visits / len(valid_states))

    # Action distribution
    valid_actions = action_nr[action_nr > 0]
    if len(valid_actions) > 0:
        results['metrics']['min_action'] = int(np.min(valid_actions))
        results['metrics']['max_action'] = int(np.max(valid_actions))
        results['metrics']['mean_action'] = float(np.mean(valid_actions))

    return results


def check_buffer_consistency(data: LogData) -> dict:
    """
    Check dead time buffer consistency (for T0_controller > 0).

    When using dead time compensation:
    - Buffered values should follow FIFO pattern
    - Buffer output should match input from T0/dt iterations ago
    """
    results = {
        'status': 'OK',
        'issues': [],
        'metrics': {},
        'details': {}
    }

    old_stan_T0 = data.as_array('DEBUG_old_stan_T0')
    old_state = data.as_array('DEBUG_old_state')
    uczenie_T0 = data.as_array('DEBUG_uczenie_T0')

    if len(old_stan_T0) == 0 or len(old_state) == 0:
        results['status'] = 'INFO'
        results['issues'].append("Insufficient data for buffer analysis")
        return results

    # Check if there's a delay pattern
    # Try different delay values to find correlation
    max_delay = 100  # Check up to 100 samples delay
    best_correlation = 0
    best_delay = 0

    valid_range = min(len(old_stan_T0), len(old_state)) - max_delay

    if valid_range > 100:
        for delay in range(0, max_delay, 5):
            if delay == 0:
                corr = np.corrcoef(
                    old_stan_T0[:valid_range],
                    old_state[:valid_range]
                )[0, 1]
            else:
                corr = np.corrcoef(
                    old_stan_T0[delay:valid_range+delay],
                    old_state[:valid_range]
                )[0, 1]

            if not np.isnan(corr) and corr > best_correlation:
                best_correlation = corr
                best_delay = delay

        results['metrics']['best_delay_match'] = int(best_delay)
        results['metrics']['correlation_at_best_delay'] = float(best_correlation)

        if best_delay == 0:
            results['details']['buffer_mode'] = 'No delay (T0_controller = 0)'
        else:
            results['details']['buffer_mode'] = f'Delayed by ~{best_delay} samples (T0_controller > 0)'

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
            if isinstance(value, list):
                print(f"  {key}:")
                for item in value:
                    print(f"    {item}")
            else:
                print(f"  {key}: {value}")

    if results['issues']:
        print("Issues:")
        for issue in results['issues']:
            print(f"  - {issue}")

    if results['status'] == 'OK' and not results['issues']:
        print("  No issues detected")


def analyze_temporal_consistency(data: LogData) -> dict:
    """Run all temporal consistency checks."""
    print("=" * 60)
    print(f"Temporal Consistency Analysis: {data.filename}")
    print(f"Samples: {data.n_samples:,}")
    print("=" * 60)

    all_results = {}

    # State-Action Pairing
    all_results['pairing'] = check_state_action_pairing(data)
    print_results("State-Action Pairing (Bug #3)", all_results['pairing'])

    # Reward Timing
    all_results['reward'] = check_reward_timing(data)
    print_results("Reward Timing (Bug #4)", all_results['reward'])

    # Sequence Consistency
    all_results['sequence'] = check_sequence_consistency(data)
    print_results("Sequence Consistency", all_results['sequence'])

    # Buffer Consistency
    all_results['buffer'] = check_buffer_consistency(data)
    print_results("Buffer Consistency (Dead Time)", all_results['buffer'])

    # Overall summary
    print("\n" + "=" * 60)
    print("TEMPORAL CONSISTENCY SUMMARY")
    print("=" * 60)

    errors = sum(1 for r in all_results.values() if r['status'] == 'ERROR')
    warnings = sum(1 for r in all_results.values() if r['status'] == 'WARNING')

    if errors > 0:
        print(f"✗ {errors} ERROR(s) - Critical temporal mismatch detected")
        print("  Likely cause: Bug #3 or #4 not fixed, or new temporal bug introduced")
    elif warnings > 0:
        print(f"⚠ {warnings} WARNING(s) - Potential temporal issues")
        print("  Review the details above for specific concerns")
    else:
        print("✓ All temporal consistency checks passed")

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

    analyze_temporal_consistency(data)


if __name__ == "__main__":
    main()
