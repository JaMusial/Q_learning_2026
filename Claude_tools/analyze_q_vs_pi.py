#!/usr/bin/env python3
"""
analyze_q_vs_pi.py - Detailed comparison of Q vs PI controller behavior

Analyzes why Q and PI controllers differ and why learning makes it worse.
"""

import json
import numpy as np
import matplotlib.pyplot as plt

def load_json(filename):
    """Load JSON log file"""
    with open(filename, 'r') as f:
        return json.load(f)

def analyze_controllers(log_data, title="Analysis"):
    """Compare Q vs PI controller behavior"""

    # Extract data
    Q_e = np.array(log_data['Q_e'])
    Q_u = np.array(log_data['Q_u'])
    Q_y = np.array(log_data['Q_y'])
    Q_action = np.array(log_data['Q_akcja_value'])
    Q_action_no_proj = np.array(log_data['Q_akcja_value_bez_f_rzutujacej'])
    Q_proj = np.array(log_data['Q_funkcja_rzut'])
    Q_state = np.array(log_data['Q_stan_nr'])
    Q_SP = np.array(log_data['Q_SP'])
    Q_t = np.array(log_data['Q_t'])

    PID_e = np.array(log_data['PID_e'])
    PID_u = np.array(log_data['PID_u'])
    PID_y = np.array(log_data['PID_y'])

    print("=" * 70)
    print(f"{title}")
    print("=" * 70)

    # Basic statistics
    print("\nBASIC STATISTICS:")
    print("-" * 70)
    print(f"{'Metric':<30} {'Q':<15} {'PI':<15} {'Diff':<10}")
    print("-" * 70)
    print(f"{'Mean Absolute Error':<30} {np.mean(np.abs(Q_e)):<15.4f} {np.mean(np.abs(PID_e)):<15.4f} {np.mean(np.abs(Q_e)) - np.mean(np.abs(PID_e)):<10.4f}")
    print(f"{'RMS Error':<30} {np.sqrt(np.mean(Q_e**2)):<15.4f} {np.sqrt(np.mean(PID_e**2)):<15.4f} {np.sqrt(np.mean(Q_e**2)) - np.sqrt(np.mean(PID_e**2)):<10.4f}")
    print(f"{'Max Error':<30} {np.max(np.abs(Q_e)):<15.4f} {np.max(np.abs(PID_e)):<15.4f} {np.max(np.abs(Q_e)) - np.max(np.abs(PID_e)):<10.4f}")
    print(f"{'Mean Control':<30} {np.mean(Q_u):<15.4f} {np.mean(PID_u):<15.4f} {np.mean(Q_u) - np.mean(PID_u):<10.4f}")
    print(f"{'Control Variance':<30} {np.var(Q_u):<15.4f} {np.var(PID_u):<15.4f} {np.var(Q_u) - np.var(PID_u):<10.4f}")

    # Projection analysis
    print("\n" + "=" * 70)
    print("PROJECTION FUNCTION ANALYSIS:")
    print("-" * 70)

    # Find where projection is active
    proj_active = np.abs(Q_proj) > 0.001
    proj_inactive = ~proj_active

    print(f"Samples with projection ON:  {np.sum(proj_active)} ({100*np.sum(proj_active)/len(Q_proj):.1f}%)")
    print(f"Samples with projection OFF: {np.sum(proj_inactive)} ({100*np.sum(proj_inactive)/len(Q_proj):.1f}%)")

    # Analyze projection contribution
    if np.sum(proj_active) > 0:
        print(f"\nWhen projection is ON:")
        print(f"  Mean projection magnitude: {np.mean(np.abs(Q_proj[proj_active])):.4f}")
        print(f"  Max projection magnitude:  {np.max(np.abs(Q_proj[proj_active])):.4f}")
        print(f"  Mean Q-action (no proj):   {np.mean(np.abs(Q_action_no_proj[proj_active])):.4f}")
        print(f"  Mean effective action:     {np.mean(np.abs(Q_action[proj_active])):.4f}")

        # Check how often projection flips sign
        sign_flips = np.sum(np.sign(Q_action_no_proj[proj_active]) != np.sign(Q_action[proj_active]))
        print(f"  Sign flips (protection triggered): {sign_flips} ({100*sign_flips/np.sum(proj_active):.1f}%)")

    # State distribution analysis
    print("\n" + "=" * 70)
    print("STATE DISTRIBUTION:")
    print("-" * 70)

    unique_states, counts = np.unique(Q_state, return_counts=True)
    total_samples = len(Q_state)

    print(f"Total unique states visited: {len(unique_states)}")
    print(f"Most common states:")

    # Sort by count
    sorted_indices = np.argsort(counts)[::-1]
    for i in range(min(10, len(unique_states))):
        idx = sorted_indices[i]
        state = unique_states[idx]
        count = counts[idx]
        pct = 100 * count / total_samples
        print(f"  State {state:3.0f}: {count:5d} samples ({pct:5.1f}%)")

    # Analyze control action vs state
    print("\n" + "=" * 70)
    print("CONTROL ACTION ANALYSIS:")
    print("-" * 70)

    # Calculate control increments
    Q_u_inc = np.diff(Q_u)
    PID_u_inc = np.diff(PID_u)

    print(f"Q control increment - Mean: {np.mean(Q_u_inc):.6f}, Std: {np.std(Q_u_inc):.6f}")
    print(f"PI control increment - Mean: {np.mean(PID_u_inc):.6f}, Std: {np.std(PID_u_inc):.6f}")

    # Check if there are systematic biases
    print(f"\nControl increment correlation: {np.corrcoef(Q_u_inc, PID_u_inc)[0,1]:.4f}")

    # Analyze steady-state regions
    print("\n" + "=" * 70)
    print("STEADY-STATE ANALYSIS:")
    print("-" * 70)

    # Define steady state as |e| < 1%
    Q_steady = np.abs(Q_e) < 1.0
    PID_steady = np.abs(PID_e) < 1.0

    print(f"Q controller in steady state:  {100*np.sum(Q_steady)/len(Q_e):.1f}% of time")
    print(f"PI controller in steady state: {100*np.sum(PID_steady)/len(PID_e):.1f}% of time")

    if np.sum(Q_steady) > 0:
        print(f"\nQ steady-state error: Mean={np.mean(Q_e[Q_steady]):.4f}, Std={np.std(Q_e[Q_steady]):.4f}")
    if np.sum(PID_steady) > 0:
        print(f"PI steady-state error: Mean={np.mean(PID_e[PID_steady]):.4f}, Std={np.std(PID_e[PID_steady]):.4f}")

    return {
        'Q_MAE': np.mean(np.abs(Q_e)),
        'PI_MAE': np.mean(np.abs(PID_e)),
        'proj_active_pct': 100*np.sum(proj_active)/len(Q_proj),
        'Q_steady_pct': 100*np.sum(Q_steady)/len(Q_e),
        'PI_steady_pct': 100*np.sum(PID_steady)/len(PID_e)
    }

def main():
    print("Loading data...")
    before = load_json('../logi_before_learning.json')
    after = load_json('../logi_after_learning.json')

    print("\n")
    results_before = analyze_controllers(before, "BEFORE LEARNING")
    print("\n\n")
    results_after = analyze_controllers(after, "AFTER LEARNING")

    print("\n" + "=" * 70)
    print("SUMMARY: WHY DOES LEARNING MAKE IT WORSE?")
    print("=" * 70)

    mae_change = results_after['Q_MAE'] - results_before['Q_MAE']
    mae_change_pct = 100 * mae_change / results_before['Q_MAE']

    print(f"\nQ controller MAE:")
    print(f"  Before: {results_before['Q_MAE']:.4f}")
    print(f"  After:  {results_after['Q_MAE']:.4f}")
    print(f"  Change: {mae_change:+.4f} ({mae_change_pct:+.1f}%)")

    print(f"\nProjection active:")
    print(f"  Before: {results_before['proj_active_pct']:.1f}%")
    print(f"  After:  {results_after['proj_active_pct']:.1f}%")

    print(f"\nTime in steady state:")
    print(f"  Q Before: {results_before['Q_steady_pct']:.1f}%")
    print(f"  Q After:  {results_after['Q_steady_pct']:.1f}%")
    print(f"  PI:       {results_before['PI_steady_pct']:.1f}%")

if __name__ == "__main__":
    main()
