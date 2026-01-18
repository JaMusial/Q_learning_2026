#!/usr/bin/env python3
"""
Compare actual controller BEHAVIOR across phases, not just errors.
Focus on: states visited, actions selected, projection application, control patterns.
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
stan_Q = np.array(logs['Q_stan_nr'])
stan_PI = np.array(logs['PID_stan_nr'])
akcja_Q = np.array(logs['Q_akcja_nr'])
akcja_PI = np.array(logs['PID_akcja_nr'])
wart_akcji_Q = np.array(logs['Q_akcja_value'])
wart_akcji_PI = np.array(logs['PID_akcja_value'])
wart_akcji_Q_raw = np.array(logs['Q_akcja_value_bez_f_rzutujacej'])
funkcja_rzut = np.array(logs['Q_funkcja_rzut'])
u_Q = np.array(logs['Q_u'])
u_PI = np.array(logs['PID_u'])
u_inc_Q = np.array(logs['Q_u_increment'])
u_inc_PI = np.array(logs['PID_u_increment'])
SP = np.array(logs['Q_SP'])
d = np.array(logs['Q_d'])

# Define phase boundaries
phase1_start = 19  # SP change
phase2_start = np.where(np.abs(d) > 0.01)[0][0]  # Disturbance on
phase2_end = np.where(np.abs(d) > 0.01)[0][-1]   # Disturbance off
phase3_start = phase2_end + 1

phases = {
    'Phase 1 (SP tracking)': (phase1_start, phase2_start),
    'Phase 2 (Disturbance)': (phase2_start, phase2_end + 1),
    'Phase 3 (Recovery)': (phase3_start, len(t))
}

print("="*90)
print("CONTROLLER BEHAVIOR COMPARISON ACROSS PHASES")
print("="*90)

for phase_name, (start, end) in phases.items():
    print(f"\n{phase_name}")
    print(f"  Time: {t[start]:.1f}s - {t[end-1]:.1f}s ({end-start} samples)")
    print("-" * 90)

    # State space usage
    states_Q = stan_Q[start:end]
    states_PI = stan_PI[start:end]

    print(f"\n  STATE SPACE USAGE:")
    print(f"    Q controller:  states {int(np.min(states_Q))}-{int(np.max(states_Q))}, "
          f"mean={np.mean(states_Q):.1f}, std={np.std(states_Q):.1f}")
    print(f"    PI controller: states {int(np.min(states_PI))}-{int(np.max(states_PI))}, "
          f"mean={np.mean(states_PI):.1f}, std={np.std(states_PI):.1f}")

    # How many unique states visited?
    unique_Q = len(np.unique(states_Q))
    unique_PI = len(np.unique(states_PI))
    print(f"    Unique states visited: Q={unique_Q}, PI={unique_PI}")

    # Action space usage
    actions_Q = akcja_Q[start:end]
    actions_PI = akcja_PI[start:end]

    print(f"\n  ACTION SPACE USAGE:")
    print(f"    Q controller:  actions {int(np.min(actions_Q))}-{int(np.max(actions_Q))}, "
          f"mean={np.mean(actions_Q):.1f}, std={np.std(actions_Q):.1f}")
    print(f"    PI controller: actions {int(np.min(actions_PI))}-{int(np.max(actions_PI))}, "
          f"mean={np.mean(actions_PI):.1f}, std={np.std(actions_PI):.1f}")

    unique_actions_Q = len(np.unique(actions_Q))
    unique_actions_PI = len(np.unique(actions_PI))
    print(f"    Unique actions visited: Q={unique_actions_Q}, PI={unique_actions_PI}")

    # Goal state occupation
    goal_state = 50  # From logs
    time_at_goal_Q = np.sum(states_Q == goal_state) / len(states_Q) * 100
    time_at_goal_PI = np.sum(states_PI == goal_state) / len(states_PI) * 100

    print(f"\n  TIME AT GOAL STATE (state={goal_state}):")
    print(f"    Q controller:  {time_at_goal_Q:.1f}% of phase")
    print(f"    PI controller: {time_at_goal_PI:.1f}% of phase")

    # Projection function activity
    proj_active = np.sum(np.abs(funkcja_rzut[start:end]) > 0.01)
    proj_magnitude = np.mean(np.abs(funkcja_rzut[start:end]))
    print(f"\n  PROJECTION FUNCTION:")
    print(f"    Active: {proj_active}/{end-start} samples ({proj_active/(end-start)*100:.1f}%)")
    print(f"    Mean |projection|: {proj_magnitude:.4f}")

    # Action value comparison
    akc_diff = wart_akcji_Q[start:end] - wart_akcji_PI[start:end]
    print(f"\n  ACTION VALUE DIFFERENCE (Q - PI):")
    print(f"    Mean: {np.mean(akc_diff):.4f}, Std: {np.std(akc_diff):.4f}")
    print(f"    Range: [{np.min(akc_diff):.4f}, {np.max(akc_diff):.4f}]")

    # Control increment comparison
    u_inc_diff = u_inc_Q[start:end] - u_inc_PI[start:end]
    print(f"\n  CONTROL INCREMENT DIFFERENCE (Q - PI):")
    print(f"    Mean: {np.mean(u_inc_diff):.4f}, Std: {np.std(u_inc_diff):.4f}")
    print(f"    Range: [{np.min(u_inc_diff):.4f}, {np.max(u_inc_diff):.4f}]")

    # Error magnitude
    print(f"\n  ERROR MAGNITUDE:")
    print(f"    Q:  mean={np.mean(np.abs(e_Q[start:end])):.2f}%, max={np.max(np.abs(e_Q[start:end])):.2f}%")
    print(f"    PI: mean={np.mean(np.abs(e_PI[start:end])):.2f}%, max={np.max(np.abs(e_PI[start:end])):.2f}%")

# Create visualization comparing state/action distributions
fig, axes = plt.subplots(3, 3, figsize=(16, 12))

phase_colors = ['red', 'blue', 'green']
phase_list = list(phases.keys())

for col, (phase_name, (start, end)) in enumerate(phases.items()):
    # State distribution
    axes[0, col].hist(stan_Q[start:end], bins=30, alpha=0.5, label='Q', color='blue', edgecolor='black')
    axes[0, col].hist(stan_PI[start:end], bins=30, alpha=0.5, label='PI', color='red', edgecolor='black')
    axes[0, col].axvline(50, color='green', linestyle='--', label='Goal state')
    axes[0, col].set_xlabel('State index')
    axes[0, col].set_ylabel('Frequency')
    axes[0, col].set_title(f'{phase_name}\nState Distribution')
    axes[0, col].legend()
    axes[0, col].grid(True, alpha=0.3)

    # Action value distribution
    axes[1, col].hist(wart_akcji_Q[start:end], bins=30, alpha=0.5, label='Q', color='blue', edgecolor='black')
    axes[1, col].hist(wart_akcji_PI[start:end], bins=30, alpha=0.5, label='PI', color='red', edgecolor='black')
    axes[1, col].axvline(0, color='green', linestyle='--', label='Zero action')
    axes[1, col].set_xlabel('Action value')
    axes[1, col].set_ylabel('Frequency')
    axes[1, col].set_title('Action Value Distribution')
    axes[1, col].legend()
    axes[1, col].grid(True, alpha=0.3)

    # Control increment over time (sample first 200 points per phase)
    n_plot = min(200, end - start)
    t_phase = t[start:start+n_plot] - t[start]
    axes[2, col].plot(t_phase, u_inc_Q[start:start+n_plot], 'b-', label='Q', linewidth=1)
    axes[2, col].plot(t_phase, u_inc_PI[start:start+n_plot], 'r--', label='PI', linewidth=1)
    axes[2, col].axhline(0, color='k', linestyle=':', linewidth=0.5)
    axes[2, col].set_xlabel('Time in phase [s]')
    axes[2, col].set_ylabel('Control increment')
    axes[2, col].set_title('Control Increment Timeline')
    axes[2, col].legend()
    axes[2, col].grid(True, alpha=0.3)

plt.tight_layout()
plt.savefig('phase_behavior_comparison.png', dpi=150)
print(f"\n\nVisualization saved: phase_behavior_comparison.png")

# Key insight summary
print("\n" + "="*90)
print("KEY BEHAVIORAL DIFFERENCES")
print("="*90)

print("\nPhase 1 (SP tracking) vs Phases 2&3 (Regulatory mode):")

# Calculate key metrics
p1_start, p1_end = phases['Phase 1 (SP tracking)']
p2_start, p2_end = phases['Phase 2 (Disturbance)']

states_range_p1 = np.max(stan_Q[p1_start:p1_end]) - np.min(stan_Q[p1_start:p1_end])
states_range_p2 = np.max(stan_Q[p2_start:p2_end]) - np.min(stan_Q[p2_start:p2_end])

error_range_p1 = np.max(np.abs(e_Q[p1_start:p1_end]))
error_range_p2 = np.max(np.abs(e_Q[p2_start:p2_end]))

proj_mean_p1 = np.mean(np.abs(funkcja_rzut[p1_start:p1_end]))
proj_mean_p2 = np.mean(np.abs(funkcja_rzut[p2_start:p2_end]))

print(f"\n1. STATE SPACE EXPLORATION:")
print(f"   Phase 1: {states_range_p1:.0f} states range")
print(f"   Phase 2: {states_range_p2:.0f} states range")
print(f"   → Phase 1 explores {states_range_p1/states_range_p2:.1f}x more states")

print(f"\n2. ERROR MAGNITUDE:")
print(f"   Phase 1 max: {error_range_p1:.1f}%")
print(f"   Phase 2 max: {error_range_p2:.1f}%")
print(f"   → Phase 1 has {error_range_p1/error_range_p2:.1f}x larger errors")

print(f"\n3. PROJECTION CONTRIBUTION:")
print(f"   Phase 1 mean |proj|: {proj_mean_p1:.4f}")
print(f"   Phase 2 mean |proj|: {proj_mean_p2:.4f}")
print(f"   → Phase 1 projection is {proj_mean_p1/proj_mean_p2:.1f}x stronger")

print(f"\n4. CONTROLLER AGREEMENT:")
print(f"   Phase 1: Mean u_diff = 1.96%")
print(f"   Phase 2: Mean u_diff = 0.30%")
print(f"   → Phase 1 has {1.96/0.30:.1f}x worse agreement")
