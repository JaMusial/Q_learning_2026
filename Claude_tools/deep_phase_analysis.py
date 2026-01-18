#!/usr/bin/env python3
"""
Deep analysis: What's fundamentally different between Phase 1 and Phases 2&3?
"""

import json
import numpy as np
from pathlib import Path

with open(Path(__file__).parent.parent / 'logi_before_learning.json', 'r') as f:
    logs = json.load(f)

# Key arrays
t = np.array(logs['Q_t'])
e_Q = np.array(logs['Q_e'])
e_PI = np.array(logs['PID_e'])
de_Q = np.array(logs['Q_de'])
de_PI = np.array(logs['PID_de'])
stan_value_Q = np.array(logs['Q_stan_value'])
stan_value_PI = np.array(logs['PID_stan_value'])
u_Q = np.array(logs['Q_u'])
u_PI = np.array(logs['PID_u'])
d = np.array(logs['Q_d'])

# Phase boundaries
phase1_start = 19
phase2_start = np.where(np.abs(d) > 0.01)[0][0]
phase2_end = np.where(np.abs(d) > 0.01)[0][-1] + 1
phase3_start = phase2_end

print("="*80)
print("DEEP ANALYSIS: What triggers Phase 2&3 to work?")
print("="*80)

# Phase 1: First few samples after SP change
print("\n--- PHASE 1: SP step response (samples 19-30) ---")
print(f"{'k':>4} {'e_Q':>8} {'de_Q':>10} {'sv_Q':>10} {'e_PI':>8} {'de_PI':>10} {'sv_PI':>10} {'u_Q':>8} {'u_PI':>8}")
print("-" * 95)
for i in range(19, 31):
    print(f"{i:4d} {e_Q[i]:8.2f} {de_Q[i]:10.2f} {stan_value_Q[i]:10.4f} "
          f"{e_PI[i]:8.2f} {de_PI[i]:10.2f} {stan_value_PI[i]:10.4f} "
          f"{u_Q[i]:8.2f} {u_PI[i]:8.2f}")

# Phase 2: First few samples after disturbance
print(f"\n--- PHASE 2: Disturbance applied (samples {phase2_start}-{phase2_start+11}) ---")
print(f"{'k':>4} {'e_Q':>8} {'de_Q':>10} {'sv_Q':>10} {'e_PI':>8} {'de_PI':>10} {'sv_PI':>10} {'u_Q':>8} {'u_PI':>8}")
print("-" * 95)
for i in range(phase2_start, phase2_start + 12):
    print(f"{i:4d} {e_Q[i]:8.2f} {de_Q[i]:10.2f} {stan_value_Q[i]:10.4f} "
          f"{e_PI[i]:8.2f} {de_PI[i]:10.2f} {stan_value_PI[i]:10.4f} "
          f"{u_Q[i]:8.2f} {u_PI[i]:8.2f}")

# Key observation: Before disturbance, what are the states?
print(f"\n--- Just BEFORE Phase 2 (sample {phase2_start-1}) ---")
i = phase2_start - 1
print(f"Q:  e={e_Q[i]:.4f}, de={de_Q[i]:.4f}, stan_value={stan_value_Q[i]:.6f}, u={u_Q[i]:.2f}")
print(f"PI: e={e_PI[i]:.4f}, de={de_PI[i]:.4f}, stan_value={stan_value_PI[i]:.6f}, u={u_PI[i]:.2f}")

print(f"\n--- Just BEFORE Phase 1 SP change (sample 18) ---")
i = 18
print(f"Q:  e={e_Q[i]:.4f}, de={de_Q[i]:.4f}, stan_value={stan_value_Q[i]:.6f}, u={u_Q[i]:.2f}")
print(f"PI: e={e_PI[i]:.4f}, de={de_PI[i]:.4f}, stan_value={stan_value_PI[i]:.6f}, u={u_PI[i]:.2f}")

print("\n" + "="*80)
print("KEY DIFFERENCE ANALYSIS")
print("="*80)

print("\nPhase 1 starts with:")
print("  - Perfect initial sync (both at e=0, u=20%)")
print("  - STEP change in SP → STEP change in e (0→30%)")
print("  - HUGE de spike (+300 for one sample)")

print("\nPhase 2 starts with:")
print(f"  - ALREADY DIVERGED states (u_Q={u_Q[phase2_start-1]:.2f} vs u_PI={u_PI[phase2_start-1]:.2f})")
print("  - Disturbance d=-0.3 applied GRADUALLY affects error")
print("  - de changes GRADUALLY (no spike)")

# Check if controllers are synced before phase 2
u_diff_before_p2 = abs(u_Q[phase2_start-1] - u_PI[phase2_start-1])
e_diff_before_p2 = abs(e_Q[phase2_start-1] - e_PI[phase2_start-1])

print(f"\nBefore Phase 2:")
print(f"  u difference: {u_diff_before_p2:.4f}%")
print(f"  e difference: {e_diff_before_p2:.4f}%")

# Maybe they've CONVERGED by end of Phase 1?
# Check convergence at end of Phase 1
for check_sample in [100, 500, 1000, 1500, 2000]:
    if check_sample < phase2_start:
        u_diff = abs(u_Q[check_sample] - u_PI[check_sample])
        e_diff = abs(e_Q[check_sample] - e_PI[check_sample])
        print(f"  At sample {check_sample}: u_diff={u_diff:.4f}%, e_diff={e_diff:.4f}%")

print("\n" + "="*80)
print("HYPOTHESIS: Controllers CONVERGE during Phase 1!")
print("="*80)
print("""
Phase 1 starts with SYNCHRONIZED controllers (e=0, u=20%)
The SP step causes immediate divergence due to discretization
But then they GRADUALLY CONVERGE as error becomes small

By the time Phase 2 starts, they're already close (u_diff ~0.3%)
Phase 2&3 work well because they START from an already-converged state!

The "problem" isn't that Phase 2&3 work differently -
it's that Phase 1 has a TRANSIENT divergence that self-corrects.

The question is: Is this transient divergence acceptable?
Or do we need perfect match even during the initial transient?
""")
