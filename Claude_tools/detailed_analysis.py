#!/usr/bin/env python3
"""
Detailed sample-by-sample analysis to find where controllers diverge.
"""

import json
import numpy as np
from pathlib import Path

log_file = Path(__file__).parent.parent / 'logi_before_learning.json'
print(f"Loading {log_file}...")

with open(log_file, 'r') as f:
    logs = json.load(f)

# Convert to numpy arrays
t = np.array(logs['Q_t'])
e = np.array(logs['Q_e'])
e_PID = np.array(logs['PID_e'])
u = np.array(logs['Q_u'])
u_PID = np.array(logs['PID_u'])
y = np.array(logs['Q_y'])
y_PID = np.array(logs['PID_y'])
SP = np.array(logs['Q_SP'])
d = np.array(logs['Q_d'])

# Q-controller internals
stan_value = np.array(logs['Q_stan_value'])
stan = np.array(logs['Q_stan_nr'])
wyb_akcja = np.array(logs['Q_akcja_nr'])
wart_akcji = np.array(logs['Q_akcja_value'])
wart_akcji_raw = np.array(logs['Q_akcja_value_bez_f_rzutujacej'])
funkcja_rzut = np.array(logs['Q_funkcja_rzut'])
u_increment = np.array(logs['Q_u_increment'])

# Find when disturbance is first applied
dist_idx = np.where(np.abs(d) > 1e-6)[0]
if len(dist_idx) > 0:
    print(f"\nFirst disturbance at sample {dist_idx[0]}, t={t[dist_idx[0]]:.1f}s, d={d[dist_idx[0]]:.4f}")
else:
    print("\nNo disturbances found in log")

# Find when error first becomes non-zero
error_idx = np.where(np.abs(e) > 1e-6)[0]
if len(error_idx) > 0:
    print(f"First non-zero error at sample {error_idx[0]}, t={t[error_idx[0]]:.1f}s, e={e[error_idx[0]]:.4f}")

# Find when controllers start to diverge
u_diff = np.abs(u - u_PID)
diverge_threshold = 0.1  # 0.1% difference
diverge_idx = np.where(u_diff > diverge_threshold)[0]
if len(diverge_idx) > 0:
    print(f"Control signals diverge at sample {diverge_idx[0]}, t={t[diverge_idx[0]]:.1f}s")
    print(f"  u={u[diverge_idx[0]]:.4f}, u_PID={u_PID[diverge_idx[0]]:.4f}, diff={u_diff[diverge_idx[0]]:.4f}")

# Detailed view around first divergence
if len(diverge_idx) > 0:
    start_idx = max(0, diverge_idx[0] - 5)
    end_idx = min(len(t), diverge_idx[0] + 15)

    print(f"\n{'='*150}")
    print(f"DETAILED VIEW: Samples {start_idx} to {end_idx} (around first divergence)")
    print(f"{'='*150}")
    print(f"{'k':>4} {'t':>6} {'SP':>6} {'d':>8} {'e_Q':>8} {'e_PI':>8} {'stan':>5} {'akc':>5} "
          f"{'raw_akc':>10} {'f_rzut':>10} {'wart_akc':>10} {'u_inc':>10} {'u_Q':>10} {'u_PI':>10} {'diff':>10}")
    print('-' * 150)

    for i in range(start_idx, end_idx):
        print(f"{i:4d} {t[i]:6.1f} {SP[i]:6.2f} {d[i]:8.4f} {e[i]:8.4f} {e_PID[i]:8.4f} "
              f"{stan[i]:5.0f} {wyb_akcja[i]:5.0f} {wart_akcji_raw[i]:10.6f} {funkcja_rzut[i]:10.6f} "
              f"{wart_akcji[i]:10.6f} {u_increment[i]:10.6f} {u[i]:10.6f} {u_PID[i]:10.6f} {u_diff[i]:10.6f}")

# Check Te and Ti values by reverse-engineering from projection function
# funkcja_rzutujaca = e * (1/Te - 1/Ti)
# If we know e and funkcja_rzutujaca, we can check if 1/Te - 1/Ti makes sense

print(f"\n{'='*150}")
print(f"PROJECTION FUNCTION ANALYSIS")
print(f"{'='*150}")

# Find samples where both e != 0 and funkcja_rzut != 0
valid_idx = np.where((np.abs(e) > 1e-6) & (np.abs(funkcja_rzut) > 1e-6))[0]
if len(valid_idx) > 10:
    # Pick some samples to check
    check_idx = valid_idx[:10]
    print(f"\nChecking projection formula: funkcja_rzutujaca = e * (1/Te - 1/Ti)")
    print(f"Expected: Te=5, Ti=20, so (1/Te - 1/Ti) = (1/5 - 1/20) = 0.2 - 0.05 = 0.15")
    print(f"\n{'k':>4} {'e':>10} {'f_rzut':>12} {'ratio':>12} {'expected':>12}")
    print('-' * 60)

    for i in check_idx:
        ratio = funkcja_rzut[i] / e[i] if abs(e[i]) > 1e-6 else 0
        expected = 0.15  # (1/5 - 1/20)
        print(f"{i:4d} {e[i]:10.4f} {funkcja_rzut[i]:12.6f} {ratio:12.6f} {expected:12.6f}")

print(f"\n{'='*150}")
print("HYPOTHESIS CHECK")
print(f"{'='*150}")

print("\nPossible root causes:")
print("1. Te initialization: Is Te=Te_bazowe(5) instead of Te=Ti(20) at start?")
print("2. Projection function: Is projection being applied when it shouldn't?")
print("3. Q-matrix initialization: Are state/action indices matching correctly?")

# Check if Te = 5 or Te = 20 by looking at projection ratio
if len(valid_idx) > 10:
    ratios = funkcja_rzut[valid_idx[:100]] / e[valid_idx[:100]]
    mean_ratio = np.mean(ratios)

    print(f"\nMean projection ratio: {mean_ratio:.6f}")
    print(f"  If Te=5,  Ti=20: ratio should be (1/5 - 1/20) = 0.150")
    print(f"  If Te=20, Ti=20: ratio should be (1/20 - 1/20) = 0.000")

    if abs(mean_ratio - 0.15) < 0.01:
        print(f"\n>>> FOUND THE PROBLEM! Te appears to be {5} instead of {20}")
        print(f">>> For bumpless transfer, Te should equal Ti (20s) at initialization")
        print(f">>> The projection function is adding extra control that PI doesn't have")
    elif abs(mean_ratio) < 0.01:
        print(f"\n>>> Te appears to be correctly set to Ti (20s)")
        print(f">>> The problem is elsewhere")
