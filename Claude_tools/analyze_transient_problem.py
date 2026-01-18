#!/usr/bin/env python3
"""
Analyze why controllers diverge during transient but converge in steady-state.
Focus on first 100 seconds (transient period).
"""

import json
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

# Load logs
log_file = Path(__file__).parent.parent / 'logi_before_learning.json'
with open(log_file, 'r') as f:
    logs = json.load(f)

# Extract data
t = np.array(logs['Q_t'])
e_Q = np.array(logs['Q_e'])
e_PI = np.array(logs['PID_e'])
u_Q = np.array(logs['Q_u'])
u_PI = np.array(logs['PID_u'])
stan_value_Q = np.array(logs['Q_stan_value'])
stan_value_PI = np.array(logs['PID_stan_value'])
wart_akcji_Q = np.array(logs['Q_akcja_value'])
wart_akcji_PI = np.array(logs['PID_akcja_value'])
funkcja_rzut = np.array(logs['Q_funkcja_rzut'])
u_inc_Q = np.array(logs['Q_u_increment'])
u_inc_PI = np.array(logs['PID_u_increment'])

# Focus on transient (samples 19-1000)
start_idx = 19
end_idx = min(1000, len(t))

print("="*80)
print("TRANSIENT PERIOD ANALYSIS (t=2s to t=100s)")
print("="*80)

# Find where controllers start to match (error < 0.5%)
u_diff = np.abs(u_Q - u_PI)
converge_idx = np.where(u_diff[start_idx:end_idx] < 0.5)[0]
if len(converge_idx) > 10:
    # Find first sustained convergence (10+ consecutive samples)
    for i in range(len(converge_idx) - 10):
        if all(converge_idx[i:i+10] == np.arange(converge_idx[i], converge_idx[i]+10)):
            converge_sample = start_idx + converge_idx[i]
            print(f"\nControllers converge at sample {converge_sample}, t={t[converge_sample]:.1f}s")
            break
    else:
        converge_sample = end_idx
else:
    converge_sample = end_idx

# Compare PI action formula with Q action formula
print(f"\n{'='*80}")
print("ACTION FORMULA COMPARISON")
print(f"{'='*80}")

print("\nPI controller (from f_dyskretny_PID.m):")
print("  wart_akcji_PI = de + e/Te")
print("  u_increment_PI = Kp * dt * (de + e/Ti)")
print("  Note: Uses Te for action calculation but Ti for control!")

print("\nQ controller (with projection):")
print("  wart_akcji_Q = (selected from Q-matrix)")
print("  wart_akcji_after_proj = wart_akcji_Q - e*(1/Te - 1/Ti)")
print("  u_increment_Q = Kp * dt * wart_akcji_after_proj")

print(f"\n{'='*80}")
print("KEY HYPOTHESIS")
print(f"{'='*80}")

print("\nPI uses DIFFERENT Te for action vs control:")
print("  - Action (wart_akcji): Uses current Te (line 8: de + e/Te)")
print("  - Control increment: Uses Ti (line 9: Kp*dt*(de + e/Ti))")
print("  → This is INCONSISTENT!")

print("\nChecking if this explains the mismatch:")
print(f"{'k':>4} {'t':>6} {'e_Q':>8} {'de_Q':>8} {'stan_Q':>10} {'akc_Q':>10} "
      f"{'stan_PI':>10} {'akc_PI':>10} {'diff':>10}")
print("-" * 95)

for i in range(start_idx, min(start_idx + 20, len(t))):
    diff_stan = stan_value_Q[i] - stan_value_PI[i]
    diff_akc = wart_akcji_Q[i] - wart_akcji_PI[i]

    print(f"{i:4d} {t[i]:6.1f} {e_Q[i]:8.2f} {logs['Q_de'][i]:8.2f} "
          f"{stan_value_Q[i]:10.4f} {wart_akcji_Q[i]:10.4f} "
          f"{stan_value_PI[i]:10.4f} {wart_akcji_PI[i]:10.4f} "
          f"{diff_akc:10.4f}")

# Check if PI is using Te or Ti in its state calculation
print(f"\n{'='*80}")
print("VERIFICATION: What Te does PI use?")
print(f"{'='*80}")

# PI state should be: de + e/Te
# Verify by computing: (stan_value_PI - de_PI) should equal e_PI/Te
print("\nIf PI uses Te=5:")
print(f"{'k':>4} {'e':>8} {'de':>8} {'stan_PI':>10} {'e/Te':>10} {'de+e/Te':>10} {'match?':>8}")
print("-" * 75)

for i in range(start_idx, min(start_idx + 10, len(t))):
    e_pi = logs['PID_e'][i]
    de_pi = logs['PID_de'][i]
    stan_pi = logs['PID_stan_value'][i]

    e_over_Te = e_pi / 5.0  # Te_bazowe = 5
    expected_stan = de_pi + e_over_Te
    matches = "YES" if abs(stan_pi - expected_stan) < 0.01 else "NO"

    print(f"{i:4d} {e_pi:8.2f} {de_pi:8.2f} {stan_pi:10.4f} {e_over_Te:10.4f} {expected_stan:10.4f} {matches:>8}")

print(f"\nIf PI uses Te=20:")
print(f"{'k':>4} {'e':>8} {'de':>8} {'stan_PI':>10} {'e/Te':>10} {'de+e/Te':>10} {'match?':>8}")
print("-" * 75)

for i in range(start_idx, min(start_idx + 10, len(t))):
    e_pi = logs['PID_e'][i]
    de_pi = logs['PID_de'][i]
    stan_pi = logs['PID_stan_value'][i]

    e_over_Te = e_pi / 20.0  # Ti = 20
    expected_stan = de_pi + e_over_Te
    matches = "YES" if abs(stan_pi - expected_stan) < 0.01 else "NO"

    print(f"{i:4d} {e_pi:8.2f} {de_pi:8.2f} {stan_pi:10.4f} {e_over_Te:10.4f} {expected_stan:10.4f} {matches:>8}")

print(f"\n{'='*80}")
print("ROOT CAUSE HYPOTHESIS")
print(f"{'='*80}")

print("\nBoth Q and PI controllers calculate stan_value = de + e/Te")
print("where Te is a GLOBAL variable used by both!")
print("\nIn main.m with f_rzutujaca_on=1:")
print("  Te = Te_bazowe = 5")
print("\nSo BOTH controllers use Te=5 for state calculation!")
print("But PI uses Ti=20 for control increment calculation.")
print("\nThis creates mismatch during transient when errors are large.")
