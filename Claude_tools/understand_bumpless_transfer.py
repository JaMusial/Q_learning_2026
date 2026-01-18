#!/usr/bin/env python3
"""
Understand what bumpless transfer requires with projection mode.

Key insight from f_dyskretny_PID.m:
- PI controller wart_akcji = de + e/Te
- PI controller przyrost = Kp * dt * (de + e/Ti)

For bumpless transfer:
- Q-controller increment must equal PI increment
- Q: Kp * dt * (action_Q - projection) = PI: Kp * dt * (de + e/Ti)
- action_Q - e*(1/Te - 1/Ti) = de + e/Ti
- action_Q = de + e/Ti + e/Te - e/Ti = de + e/Te = stan_value

So Q-matrix should select action = stan_value for bumpless transfer!
"""

import json
import numpy as np
from pathlib import Path

log_file = Path(__file__).parent.parent / 'logi_before_learning.json'
print("Loading logs...")
with open(log_file, 'r') as f:
    logs = json.load(f)

# Extract first 50 samples
n = 50
stan_value = np.array(logs['Q_stan_value'][:n])
stan = np.array(logs['Q_stan_nr'][:n])
wyb_akcja = np.array(logs['Q_akcja_nr'][:n])
wart_akcji_raw = np.array(logs['Q_akcja_value_bez_f_rzutujacej'][:n])
funkcja_rzut = np.array(logs['Q_funkcja_rzut'][:n])
wart_akcji = np.array(logs['Q_akcja_value'][:n])
e = np.array(logs['Q_e'][:n])
de = np.array(logs['Q_de'][:n])
u_increment_Q = np.array(logs['Q_u_increment'][:n])
u_increment_PI = np.array(logs['PID_u_increment'][:n])

print("\n" + "="*80)
print("BUMPLESS TRANSFER ANALYSIS")
print("="*80)

print("\nTheory:")
print("  PI increment:  Kp * dt * (de + e/Ti)")
print("  Q increment:   Kp * dt * (action_Q - projection)")
print("  For bumpless transfer: action_Q - projection = de + e/Ti")
print("  With projection = e*(1/Te - 1/Ti):")
print("  action_Q = de + e/Ti + e/Te - e/Ti = de + e/Te = stan_value")

print("\nSo identity Q-matrix should make: action_value ≈ stan_value")

# Find samples after manual control
start_idx = 19  # First SP change

print(f"\n{'k':>4} {'e':>8} {'de':>8} {'stan_val':>10} {'stan':>5} {'akc_idx':>7} "
      f"{'akc_raw':>10} {'expected':>10} {'diff':>10}")
print("-" * 85)

for i in range(start_idx, min(start_idx + 15, n)):
    expected_action = stan_value[i]  # Should equal stan_value for bumpless
    diff = wart_akcji_raw[i] - expected_action

    print(f"{i:4d} {e[i]:8.2f} {de[i]:8.2f} {stan_value[i]:10.4f} {stan[i]:5.0f} "
          f"{wyb_akcja[i]:7.0f} {wart_akcji_raw[i]:10.4f} {expected_action:10.4f} "
          f"{diff:10.4f}")

print("\n" + "="*80)
print("ANALYSIS")
print("="*80)

# Check if action_raw ≈ stan_value
nonzero_idx = np.abs(stan_value[start_idx:]) > 0.01
if np.any(nonzero_idx):
    ratio = wart_akcji_raw[start_idx:][nonzero_idx] / stan_value[start_idx:][nonzero_idx]
    mean_ratio = np.mean(ratio)
    print(f"\nRatio (action_raw / stan_value): mean = {mean_ratio:.4f}")

    if abs(mean_ratio - 1.0) < 0.01:
        print("  ✓ Actions match state values (identity Q-matrix working correctly)")
    else:
        print(f"  ✗ Actions DON'T match state values (expected 1.0, got {mean_ratio:.4f})")
        print("  → This is the problem! Identity Q-matrix not producing action=state")

# Check control increments
print(f"\nControl increment comparison (samples {start_idx}-{n}):")
print(f"  Q increment:  mean={np.mean(u_increment_Q[start_idx:]):.4f}, std={np.std(u_increment_Q[start_idx:]):.4f}")
print(f"  PI increment: mean={np.mean(u_increment_PI[start_idx:]):.4f}, std={np.std(u_increment_PI[start_idx:]):.4f}")
diff_increment = u_increment_Q[start_idx:] - u_increment_PI[start_idx:]
print(f"  Difference:   mean={np.mean(diff_increment):.4f}, std={np.std(diff_increment):.4f}")

print("\n" + "="*80)
print("POSSIBLE ROOT CAUSES")
print("="*80)

print("\n1. State/action space generation mismatch")
print("   - States are midpoints between actions")
print("   - Identity matrix maps state index i to action index i")
print("   - But state_value(i) ≠ action_value(i) due to midpoint offset")
print("   - Need to check state/action array generation")

print("\n2. Q-matrix initialization wrong for projection mode")
print("   - Current: Identity matrix (diagonal = 1)")
print("   - May need different initialization to account for projection")

print("\n3. Projection formula implementation")
print("   - Current: action = Q_action - projection")
print("   - CLAUDE.md suggests: action = stan_value - projection")
print("   - If we use stan_value directly, bypasses Q-matrix initially")

print("\n" + "="*80)
print("RECOMMENDED INVESTIGATION")
print("="*80)
print("\nNeed to check:")
print("1. Are state and action arrays properly aligned?")
print("2. Should projection use stan_value instead of Q-selected action?")
print("3. Does identity Q-matrix actually produce action ≈ state for same index?")
