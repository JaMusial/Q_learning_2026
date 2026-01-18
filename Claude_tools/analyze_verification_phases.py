#!/usr/bin/env python3
"""
Analyze the 3 phases of verification experiment to understand why phase 1 fails
but phases 2 and 3 might work.
"""

import json
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

# Load logs
log_file = Path(__file__).parent.parent / 'logi_before_learning.json'
print(f"Loading {log_file}...")

with open(log_file, 'r') as f:
    logs = json.load(f)

# Extract data
t = np.array(logs['Q_t'])
e_Q = np.array(logs['Q_e'])
e_PI = np.array(logs['PID_e'])
u_Q = np.array(logs['Q_u'])
u_PI = np.array(logs['PID_u'])
y_Q = np.array(logs['Q_y'])
y_PI = np.array(logs['PID_y'])
SP = np.array(logs['Q_SP'])
d = np.array(logs['Q_d'])

# Find phase boundaries
# Manual control: first ~5 samples (or T0/dt + extra)
# Then experiment with 3 phases

# Find when SP changes (marks end of manual control + start of Phase 1)
sp_change_idx = np.where(np.diff(SP) != 0)[0]
if len(sp_change_idx) > 0:
    phase1_start = sp_change_idx[0] + 1
    print(f"\nPhase 1 starts at sample {phase1_start}, t={t[phase1_start]:.1f}s (SP change to {SP[phase1_start]:.1f})")
else:
    phase1_start = 5

# Find when disturbance is applied (marks Phase 2)
dist_idx = np.where(np.abs(d) > 0.01)[0]
if len(dist_idx) > 0:
    phase2_start = dist_idx[0]
    phase2_end = dist_idx[-1]
    print(f"Phase 2: samples {phase2_start}-{phase2_end}, t={t[phase2_start]:.1f}-{t[phase2_end]:.1f}s (disturbance d={d[phase2_start]:.2f})")
    phase3_start = phase2_end + 1
    print(f"Phase 3 starts at sample {phase3_start}, t={t[phase3_start]:.1f}s (disturbance removed)")
else:
    phase2_start = len(t) // 3
    phase2_end = 2 * len(t) // 3
    phase3_start = phase2_end + 1

# Calculate errors for each phase
def analyze_phase(name, start_idx, end_idx):
    """Analyze controller agreement in a phase."""
    if end_idx > len(t):
        end_idx = len(t)

    u_diff = np.abs(u_Q[start_idx:end_idx] - u_PI[start_idx:end_idx])
    e_diff = np.abs(e_Q[start_idx:end_idx] - e_PI[start_idx:end_idx])
    y_diff = np.abs(y_Q[start_idx:end_idx] - y_PI[start_idx:end_idx])

    print(f"\n{name}:")
    print(f"  Samples: {start_idx}-{end_idx} (n={end_idx-start_idx})")
    print(f"  Time: {t[start_idx]:.1f}-{t[end_idx-1]:.1f}s")
    print(f"  Control diff:  mean={np.mean(u_diff):.3f}%, std={np.std(u_diff):.3f}%, max={np.max(u_diff):.3f}%")
    print(f"  Error diff:    mean={np.mean(e_diff):.3f}%, std={np.std(e_diff):.3f}%, max={np.max(e_diff):.3f}%")
    print(f"  Output diff:   mean={np.mean(y_diff):.3f}%, std={np.std(y_diff):.3f}%, max={np.max(y_diff):.3f}%")

    return np.mean(u_diff), np.mean(e_diff), np.mean(y_diff)

print("\n" + "="*80)
print("PHASE-BY-PHASE ANALYSIS")
print("="*80)

u1, e1, y1 = analyze_phase("PHASE 1 (SP tracking)", phase1_start, phase2_start)
u2, e2, y2 = analyze_phase("PHASE 2 (Disturbance rejection)", phase2_start, phase2_end)
u3, e3, y3 = analyze_phase("PHASE 3 (Recovery)", phase3_start, len(t))

print("\n" + "="*80)
print("COMPARISON ACROSS PHASES")
print("="*80)

print(f"\nControl signal difference (mean):")
print(f"  Phase 1: {u1:.3f}%")
print(f"  Phase 2: {u2:.3f}%")
print(f"  Phase 3: {u3:.3f}%")

if u2 < u1 or u3 < u1:
    print(f"\n  → FINDING: Phases 2/3 have LOWER error than Phase 1!")
    print(f"  → This suggests the problem is specific to initial conditions or SP change response")
else:
    print(f"\n  → All phases have similar error")

# Visualize all three phases
fig, axes = plt.subplots(3, 1, figsize=(14, 10))

# Control signals
axes[0].plot(t, u_Q, 'b-', label='Q-controller', linewidth=1.5, alpha=0.8)
axes[0].plot(t, u_PI, 'r--', label='PI-controller', linewidth=1.5, alpha=0.8)
axes[0].axvline(t[phase2_start], color='gray', linestyle=':', label='Phase boundaries')
axes[0].axvline(t[phase2_end], color='gray', linestyle=':')
axes[0].set_ylabel('Control u [%]')
axes[0].legend()
axes[0].grid(True, alpha=0.3)
axes[0].set_title('Verification Experiment: Three Phases')

# Outputs
axes[1].plot(t, y_Q, 'b-', label='Q-controller', linewidth=1.5, alpha=0.8)
axes[1].plot(t, y_PI, 'r--', label='PI-controller', linewidth=1.5, alpha=0.8)
axes[1].plot(t, SP, 'k:', label='Setpoint', linewidth=1)
axes[1].axvline(t[phase2_start], color='gray', linestyle=':')
axes[1].axvline(t[phase2_end], color='gray', linestyle=':')
axes[1].set_ylabel('Output y [%]')
axes[1].legend()
axes[1].grid(True, alpha=0.3)

# Errors
axes[2].plot(t, e_Q, 'b-', label='Q error', linewidth=1.5, alpha=0.8)
axes[2].plot(t, e_PI, 'r--', label='PI error', linewidth=1.5, alpha=0.8)
axes[2].axvline(t[phase2_start], color='gray', linestyle=':', label='Phase boundaries')
axes[2].axvline(t[phase2_end], color='gray', linestyle=':')
axes[2].axhline(y=0, color='k', linestyle=':', linewidth=0.5)
axes[2].set_ylabel('Error e [%]')
axes[2].set_xlabel('Time [s]')
axes[2].legend()
axes[2].grid(True, alpha=0.3)

# Add phase labels
for ax in axes:
    ax.text((t[phase1_start] + t[phase2_start])/2, ax.get_ylim()[1]*0.95,
            'Phase 1\n(SP tracking)', ha='center', va='top', fontsize=10,
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    ax.text((t[phase2_start] + t[phase2_end])/2, ax.get_ylim()[1]*0.95,
            'Phase 2\n(Disturbance)', ha='center', va='top', fontsize=10,
            bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.5))
    ax.text((t[phase2_end] + t[-1])/2, ax.get_ylim()[1]*0.95,
            'Phase 3\n(Recovery)', ha='center', va='top', fontsize=10,
            bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.5))

plt.tight_layout()
plt.savefig('verification_phases_analysis.png', dpi=150)
print(f"\n  Visualization saved: verification_phases_analysis.png")

# Check if controllers converge over time
print("\n" + "="*80)
print("TIME EVOLUTION ANALYSIS")
print("="*80)

# Split phase 1 into early and late
phase1_mid = (phase1_start + phase2_start) // 2
u_early, e_early, y_early = analyze_phase("Phase 1 EARLY", phase1_start, phase1_mid)
u_late, e_late, y_late = analyze_phase("Phase 1 LATE", phase1_mid, phase2_start)

if u_late < u_early * 0.8:
    print(f"\n  → Controllers CONVERGE within Phase 1 (error drops by {(1-u_late/u_early)*100:.1f}%)")
elif u_late > u_early * 1.2:
    print(f"\n  → Controllers DIVERGE within Phase 1 (error increases by {(u_late/u_early-1)*100:.1f}%)")
else:
    print(f"\n  → Error remains roughly constant within Phase 1")
