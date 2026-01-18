#!/usr/bin/env python3
"""
Create visual comparison of the initialization problem.
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
f_rzut = np.array(logs['Q_funkcja_rzut'])

# Plot first 600 samples (60 seconds)
n = 600
t = t[:n]
e_Q = e_Q[:n]
e_PI = e_PI[:n]
u_Q = u_Q[:n]
u_PI = u_PI[:n]
y_Q = y_Q[:n]
y_PI = y_PI[:n]
SP = SP[:n]
f_rzut = f_rzut[:n]

# Create figure
fig = plt.figure(figsize=(14, 10))
gs = fig.add_gridspec(4, 2, hspace=0.3, wspace=0.3)

# Left column: Current behavior (with bug)
ax1 = fig.add_subplot(gs[0, 0])
ax1.plot(t, y_Q, 'b-', label='Q-controller', linewidth=1.5)
ax1.plot(t, y_PI, 'r--', label='PI-controller', linewidth=1.5)
ax1.plot(t, SP, 'k:', label='Setpoint', linewidth=1)
ax1.set_ylabel('Output y [%]')
ax1.legend(loc='upper right')
ax1.grid(True, alpha=0.3)
ax1.set_title('CURRENT (BUG): Controllers Diverge', fontweight='bold', color='red')
ax1.set_xlim([0, 60])

ax2 = fig.add_subplot(gs[1, 0])
ax2.plot(t, u_Q, 'b-', label='Q-controller', linewidth=1.5)
ax2.plot(t, u_PI, 'r--', label='PI-controller', linewidth=1.5)
ax2.set_ylabel('Control u [%]')
ax2.legend(loc='upper right')
ax2.grid(True, alpha=0.3)
ax2.set_xlim([0, 60])

ax3 = fig.add_subplot(gs[2, 0])
ax3.plot(t, e_Q, 'b-', label='Q-controller', linewidth=1.5)
ax3.plot(t, e_PI, 'r--', label='PI-controller', linewidth=1.5)
ax3.axhline(y=0, color='k', linestyle=':', linewidth=0.5)
ax3.set_ylabel('Error e [%]')
ax3.legend(loc='upper right')
ax3.grid(True, alpha=0.3)
ax3.set_xlim([0, 60])

ax4 = fig.add_subplot(gs[3, 0])
ax4.plot(t, f_rzut, 'r-', linewidth=1.5)
ax4.axhline(y=0, color='k', linestyle=':', linewidth=0.5)
ax4.set_ylabel('Projection term')
ax4.set_xlabel('Time [s]')
ax4.grid(True, alpha=0.3)
ax4.set_title('Projection ≠ 0 (Te=5, Ti=20)', fontsize=10)
ax4.set_xlim([0, 60])

# Right column: Expected behavior (with fix)
ax5 = fig.add_subplot(gs[0, 1])
ax5.plot(t, y_PI, 'b-', label='Q-controller (fixed)', linewidth=1.5)
ax5.plot(t, y_PI, 'r--', label='PI-controller', linewidth=1.5, alpha=0.7)
ax5.plot(t, SP, 'k:', label='Setpoint', linewidth=1)
ax5.set_ylabel('Output y [%]')
ax5.legend(loc='upper right')
ax5.grid(True, alpha=0.3)
ax5.set_title('EXPECTED (FIX): Controllers Match', fontweight='bold', color='green')
ax5.set_xlim([0, 60])

ax6 = fig.add_subplot(gs[1, 1])
ax6.plot(t, u_PI, 'b-', label='Q-controller (fixed)', linewidth=1.5)
ax6.plot(t, u_PI, 'r--', label='PI-controller', linewidth=1.5, alpha=0.7)
ax6.set_ylabel('Control u [%]')
ax6.legend(loc='upper right')
ax6.grid(True, alpha=0.3)
ax6.set_xlim([0, 60])

ax7 = fig.add_subplot(gs[2, 1])
ax7.plot(t, e_PI, 'b-', label='Q-controller (fixed)', linewidth=1.5)
ax7.plot(t, e_PI, 'r--', label='PI-controller', linewidth=1.5, alpha=0.7)
ax7.axhline(y=0, color='k', linestyle=':', linewidth=0.5)
ax7.set_ylabel('Error e [%]')
ax7.legend(loc='upper right')
ax7.grid(True, alpha=0.3)
ax7.set_xlim([0, 60])

ax8 = fig.add_subplot(gs[3, 1])
ax8.plot(t, np.zeros_like(t), 'g-', linewidth=1.5)
ax8.axhline(y=0, color='k', linestyle=':', linewidth=0.5)
ax8.set_ylabel('Projection term')
ax8.set_xlabel('Time [s]')
ax8.grid(True, alpha=0.3)
ax8.set_title('Projection = 0 (Te=20, Ti=20)', fontsize=10, color='green')
ax8.set_xlim([0, 60])

# Add main title
fig.suptitle('Initialization Problem: Te=Te_bazowe vs Te=Ti',
             fontsize=14, fontweight='bold')

plt.savefig('initialization_problem_comparison.png', dpi=150, bbox_inches='tight')
print(f"\nVisualization saved to: initialization_problem_comparison.png")

# Print summary statistics
print("\n" + "="*70)
print("SUMMARY STATISTICS (first 100 samples)")
print("="*70)

n_stat = 100
u_diff = u_Q[:n_stat] - u_PI[:n_stat]
e_diff = e_Q[:n_stat] - e_PI[:n_stat]
y_diff = y_Q[:n_stat] - y_PI[:n_stat]

print(f"\nCURRENT BEHAVIOR (with bug):")
print(f"  Control difference:  mean={np.mean(np.abs(u_diff)):.2f}%, max={np.max(np.abs(u_diff)):.2f}%")
print(f"  Error difference:    mean={np.mean(np.abs(e_diff)):.2f}%, max={np.max(np.abs(e_diff)):.2f}%")
print(f"  Output difference:   mean={np.mean(np.abs(y_diff)):.2f}%, max={np.max(np.abs(y_diff)):.2f}%")
print(f"  Projection non-zero: {np.sum(np.abs(f_rzut[:n_stat]) > 0.01)} / {n_stat} samples")

print(f"\nEXPECTED BEHAVIOR (with fix):")
print(f"  Control difference:  ~0% (identical signals)")
print(f"  Error difference:    ~0% (identical signals)")
print(f"  Output difference:   ~0% (identical signals)")
print(f"  Projection non-zero: 0 / {n_stat} samples (always zero)")

print("\n" + "="*70)
print("ROOT CAUSE")
print("="*70)
print(f"\nIn main.m, line 18:")
print(f"  Te = Te_bazowe;  // Sets Te=5 when f_rzutujaca_on=1")
print(f"\nShould be:")
print(f"  Te = Ti;         // Sets Te=20 for bumpless transfer")
print(f"\nThis makes projection term:")
print(f"  CURRENT: e * (1/5 - 1/20) = e * 0.15  (non-zero!)")
print(f"  FIXED:   e * (1/20 - 1/20) = e * 0.0  (zero, as required)")
