#!/usr/bin/env python3
"""
trace_initialization.py - Find why Q != PI at initialization

Compares Q and PI control signals sample-by-sample to find divergence.
"""

import json
import numpy as np

def load_json(filename):
    """Load JSON log file"""
    with open(filename, 'r') as f:
        return json.load(f)

def main():
    print("Loading before_learning data...")
    log = load_json('../logi_before_learning.json')

    Q_e = np.array(log['Q_e'])
    Q_de = np.array(log['Q_de'])
    Q_u = np.array(log['Q_u'])
    Q_u_inc = np.array(log['Q_u_increment'])
    Q_action = np.array(log['Q_akcja_value'])
    Q_action_no_proj = np.array(log['Q_akcja_value_bez_f_rzutujacej'])
    Q_proj = np.array(log['Q_funkcja_rzut'])
    Q_state = np.array(log['Q_stan_nr'])
    Q_state_value = np.array(log['Q_stan_value'])

    PID_e = np.array(log['PID_e'])
    PID_de = np.array(log['PID_de'])
    PID_u = np.array(log['PID_u'])
    PID_u_inc = np.array(log['PID_u_increment'])
    PID_action = np.array(log['PID_akcja_value'])

    print("\n" + "=" * 70)
    print("INITIALIZATION TRACE: First 50 samples")
    print("=" * 70)

    print(f"\n{'i':<4} {'e':<8} {'de':<8} {'Q_state':<8} {'Q_act_np':<8} {'Q_proj':<8} {'Q_act':<8} {'Q_u_inc':<10} {'PI_act':<8} {'PI_u_inc':<10} {'Diff':<8}")
    print("-" * 140)

    for i in range(min(50, len(Q_e))):
        diff = Q_u_inc[i] - PID_u_inc[i]
        marker = " ***" if abs(diff) > 0.01 else ""

        print(f"{i:<4} {Q_e[i]:<8.2f} {Q_de[i]:<8.4f} {Q_state[i]:<8.0f} {Q_action_no_proj[i]:<8.4f} {Q_proj[i]:<8.4f} {Q_action[i]:<8.4f} {Q_u_inc[i]:<10.6f} {PID_action[i]:<8.4f} {PID_u_inc[i]:<10.6f} {diff:<8.6f}{marker}")

    # Find first significant divergence
    u_inc_diff = np.abs(Q_u_inc - PID_u_inc)
    first_diverge = np.where(u_inc_diff > 0.01)[0]

    if len(first_diverge) > 0:
        idx = first_diverge[0]
        print(f"\n>>> First significant divergence at sample {idx}")
        print(f"    Q control increment: {Q_u_inc[idx]:.6f}")
        print(f"    PI control increment: {PID_u_inc[idx]:.6f}")
        print(f"    Difference: {u_inc_diff[idx]:.6f}")
        print(f"    Q state: {Q_state[idx]:.0f}, state_value: {Q_state_value[idx]:.4f}")
        print(f"    Q action (no proj): {Q_action_no_proj[idx]:.4f}")
        print(f"    Q projection: {Q_proj[idx]:.4f}")
        print(f"    Q action (final): {Q_action[idx]:.4f}")
        print(f"    PI action: {PID_action[idx]:.4f}")

    # Statistical comparison
    print("\n" + "=" * 70)
    print("STATISTICAL COMPARISON")
    print("=" * 70)

    # Skip first 10 samples (manual control)
    start_idx = 10

    corr = np.corrcoef(Q_u_inc[start_idx:], PID_u_inc[start_idx:])[0,1]
    print(f"\nControl increment correlation: {corr:.6f}")

    diff_mean = np.mean(Q_u_inc[start_idx:] - PID_u_inc[start_idx:])
    diff_std = np.std(Q_u_inc[start_idx:] - PID_u_inc[start_idx:])
    print(f"Control increment difference: mean={diff_mean:.6f}, std={diff_std:.6f}")

    # Check if projection is the issue
    proj_active = np.abs(Q_proj) > 0.001
    print(f"\nProjection active: {np.sum(proj_active)} / {len(Q_proj)} samples ({100*np.sum(proj_active)/len(Q_proj):.1f}%)")

    if np.sum(proj_active) > 0:
        # When projection is ON, Q_action should equal (Q_action_no_proj - projection)
        # And with identity Q-matrix, Q_action_no_proj should equal state_value
        # So effective should equal (state_value - projection) = de + e/Ti (PI control)

        print(f"\nWhen projection is ACTIVE:")
        print(f"  Q_action_no_proj ≈ state_value? {np.allclose(Q_action_no_proj[proj_active], Q_state_value[proj_active], atol=0.1)}")
        print(f"  Q_action ≈ (Q_action_no_proj - projection)? {np.allclose(Q_action[proj_active], Q_action_no_proj[proj_active] - Q_proj[proj_active], atol=0.01)}")

        # Calculate what effective action SHOULD be (PI formula)
        Te = 5  # From config
        Ti = 20
        PI_expected = Q_de[proj_active] + Q_e[proj_active] / Ti
        Q_actual = Q_action[proj_active]

        print(f"  Q_action ≈ (de + e/Ti)? {np.allclose(Q_actual, PI_expected, atol=0.1)}")
        print(f"  Mean difference: {np.mean(Q_actual - PI_expected):.6f}")

    proj_inactive = ~proj_active
    if np.sum(proj_inactive) > 0:
        print(f"\nWhen projection is INACTIVE (near goal):")
        print(f"  Q_action_no_proj ≈ state_value? {np.allclose(Q_action_no_proj[proj_inactive], Q_state_value[proj_inactive], atol=0.1)}")
        print(f"  Q_action ≈ Q_action_no_proj? {np.allclose(Q_action[proj_inactive], Q_action_no_proj[proj_inactive], atol=0.01)}")

if __name__ == "__main__":
    main()
