#!/usr/bin/env python3
"""
Analyze initialization problem in before_learning verification.
Compares Q-controller vs PI-controller behavior to identify why they differ.
"""

import json
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path

def load_logs(filepath):
    """Load JSON log file."""
    print(f"Loading {filepath}...")
    with open(filepath, 'r') as f:
        data = json.load(f)
    print(f"  Loaded {len(data['Q_t'])} samples")
    return data

def analyze_initialization(logs):
    """Analyze the initialization phase and identify problems."""

    # Convert to numpy arrays for easier analysis
    t = np.array(logs['Q_t'])
    e = np.array(logs['Q_e'])
    e_PID = np.array(logs['PID_e'])
    u = np.array(logs['Q_u'])
    u_PID = np.array(logs['PID_u'])
    y = np.array(logs['Q_y'])
    y_PID = np.array(logs['PID_y'])
    SP = np.array(logs['Q_SP'])

    # Get debug and Q-controller internal fields
    has_debug = True  # Always present based on JSON structure
    wart_akcji = np.array(logs['Q_akcja_value'])
    wart_akcji_bez_f_rzut = np.array(logs['Q_akcja_value_bez_f_rzutujacej'])
    funkcja_rzutujaca = np.array(logs['Q_funkcja_rzut'])
    stan_value = np.array(logs['Q_stan_value'])
    stan = np.array(logs['Q_stan_nr'])
    wyb_akcja = np.array(logs['Q_akcja_nr'])
    u_increment = np.array(logs['Q_u_increment'])

    print("\n" + "="*70)
    print("INITIALIZATION ANALYSIS")
    print("="*70)

    # Analyze first 100 samples (initial behavior)
    n_init = min(100, len(t))

    print(f"\n1. CONTROL SIGNAL COMPARISON (first {n_init} samples)")
    print(f"   Q-controller (u):     mean={np.mean(u[:n_init]):.2f}, std={np.std(u[:n_init]):.2f}")
    print(f"   PI-controller (u_PID): mean={np.mean(u_PID[:n_init]):.2f}, std={np.std(u_PID[:n_init]):.2f}")
    print(f"   Difference (u - u_PID): mean={np.mean(u[:n_init] - u_PID[:n_init]):.2f}, std={np.std(u[:n_init] - u_PID[:n_init]):.2f}")

    print(f"\n2. ERROR COMPARISON (first {n_init} samples)")
    print(f"   Q-controller (e):     mean={np.mean(e[:n_init]):.2f}, std={np.std(e[:n_init]):.2f}")
    print(f"   PI-controller (e_PID): mean={np.mean(e_PID[:n_init]):.2f}, std={np.std(e_PID[:n_init]):.2f}")
    print(f"   Difference (e - e_PID): mean={np.mean(e[:n_init] - e_PID[:n_init]):.2f}, std={np.std(e[:n_init] - e_PID[:n_init]):.2f}")

    print(f"\n3. OUTPUT COMPARISON (first {n_init} samples)")
    print(f"   Q-controller (y):     mean={np.mean(y[:n_init]):.2f}, std={np.std(y[:n_init]):.2f}")
    print(f"   PI-controller (y_PID): mean={np.mean(y_PID[:n_init]):.2f}, std={np.std(y_PID[:n_init]):.2f}")
    print(f"   Difference (y - y_PID): mean={np.mean(y[:n_init] - y_PID[:n_init]):.2f}, std={np.std(y[:n_init] - y_PID[:n_init]):.2f}")

    if has_debug:
        print(f"\n4. Q-CONTROLLER INTERNALS (samples 6-{n_init}, after manual control)")
        manual_end = 5  # ilosc_probek_sterowanie_reczne = 5
        idx_start = manual_end + 1

        print(f"\n   Action values:")
        print(f"   - wart_akcji (with projection):    mean={np.mean(wart_akcji[idx_start:n_init]):.4f}, std={np.std(wart_akcji[idx_start:n_init]):.4f}")
        print(f"   - wart_akcji_bez_f_rzut (no proj): mean={np.mean(wart_akcji_bez_f_rzut[idx_start:n_init]):.4f}, std={np.std(wart_akcji_bez_f_rzut[idx_start:n_init]):.4f}")
        print(f"   - funkcja_rzutujaca:               mean={np.mean(funkcja_rzutujaca[idx_start:n_init]):.4f}, std={np.std(funkcja_rzutujaca[idx_start:n_init]):.4f}")

        print(f"\n   State information:")
        print(f"   - stan_value: mean={np.mean(stan_value[idx_start:n_init]):.4f}, std={np.std(stan_value[idx_start:n_init]):.4f}")
        print(f"   - stan (index): mean={np.mean(stan[idx_start:n_init]):.2f}, std={np.std(stan[idx_start:n_init]):.2f}")
        print(f"   - wyb_akcja (index): mean={np.mean(wyb_akcja[idx_start:n_init]):.2f}, std={np.std(wyb_akcja[idx_start:n_init]):.2f}")

        print(f"\n   Control increment:")
        print(f"   - u_increment: mean={np.mean(u_increment[idx_start:n_init]):.4f}, std={np.std(u_increment[idx_start:n_init]):.4f}")

        # Check if projection is the problem
        print(f"\n5. PROJECTION FUNCTION ANALYSIS")
        print(f"   Is projection being applied? {np.any(np.abs(funkcja_rzutujaca) > 1e-10)}")
        if np.any(np.abs(funkcja_rzutujaca) > 1e-10):
            nonzero_idx = np.abs(funkcja_rzutujaca) > 1e-10
            print(f"   Projection applied in {np.sum(nonzero_idx)} / {len(funkcja_rzutujaca)} samples")
            print(f"   Projection value range: [{np.min(funkcja_rzutujaca):.4f}, {np.max(funkcja_rzutujaca):.4f}]")

        # Sample-by-sample analysis for first few samples
        print(f"\n6. SAMPLE-BY-SAMPLE ANALYSIS (samples 6-15)")
        print(f"{'k':>4} {'e':>8} {'stan_val':>10} {'stan':>5} {'akcja':>6} {'wart_akc_raw':>12} {'f_rzut':>10} {'wart_akc':>10} {'u_inc':>10} {'u':>8}")
        print("-" * 110)
        for i in range(idx_start, min(idx_start + 10, len(t))):
            print(f"{i:4d} {e[i]:8.2f} {stan_value[i]:10.4f} {stan[i]:5.0f} {wyb_akcja[i]:6.0f} "
                  f"{wart_akcji_bez_f_rzut[i]:12.6f} {funkcja_rzutujaca[i]:10.6f} {wart_akcji[i]:10.6f} "
                  f"{u_increment[i]:10.6f} {u[i]:8.2f}")

    # Create visualization
    create_plots(logs, n_init)

    return logs

def create_plots(logs, n_samples=200):
    """Create diagnostic plots."""
    t = np.array(logs['Q_t'][:n_samples])
    e = np.array(logs['Q_e'][:n_samples])
    e_PID = np.array(logs['PID_e'][:n_samples])
    u = np.array(logs['Q_u'][:n_samples])
    u_PID = np.array(logs['PID_u'][:n_samples])
    y = np.array(logs['Q_y'][:n_samples])
    y_PID = np.array(logs['PID_y'][:n_samples])
    SP = np.array(logs['Q_SP'][:n_samples])

    fig, axes = plt.subplots(3, 1, figsize=(12, 10))

    # Output comparison
    axes[0].plot(t, y, 'b-', label='Q-controller', linewidth=1.5)
    axes[0].plot(t, y_PID, 'r--', label='PI-controller', linewidth=1.5)
    axes[0].plot(t, SP, 'k:', label='Setpoint', linewidth=1)
    axes[0].set_ylabel('Output y [%]')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)
    axes[0].set_title('Output Comparison (Before Learning)')

    # Control signal comparison
    axes[1].plot(t, u, 'b-', label='Q-controller', linewidth=1.5)
    axes[1].plot(t, u_PID, 'r--', label='PI-controller', linewidth=1.5)
    axes[1].set_ylabel('Control u [%]')
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)
    axes[1].set_title('Control Signal Comparison')

    # Error comparison
    axes[2].plot(t, e, 'b-', label='Q-controller', linewidth=1.5)
    axes[2].plot(t, e_PID, 'r--', label='PI-controller', linewidth=1.5)
    axes[2].axhline(y=0, color='k', linestyle=':', linewidth=0.5)
    axes[2].set_ylabel('Error e [%]')
    axes[2].set_xlabel('Time [s]')
    axes[2].legend()
    axes[2].grid(True, alpha=0.3)
    axes[2].set_title('Error Comparison')

    plt.tight_layout()
    plt.savefig('initialization_analysis.png', dpi=150)
    print(f"\n  Plot saved to: initialization_analysis.png")

    # Always create detailed debug plots (debug data always present)
    create_debug_plots(logs, n_samples)

def create_debug_plots(logs, n_samples=200):
    """Create detailed debug plots."""
    t = np.array(logs['Q_t'][:n_samples])
    wart_akcji = np.array(logs['Q_akcja_value'][:n_samples])
    wart_akcji_bez_f_rzut = np.array(logs['Q_akcja_value_bez_f_rzutujacej'][:n_samples])
    funkcja_rzutujaca = np.array(logs['Q_funkcja_rzut'][:n_samples])
    e = np.array(logs['Q_e'][:n_samples])
    stan_value = np.array(logs['Q_stan_value'][:n_samples])
    u_increment = np.array(logs['Q_u_increment'][:n_samples])

    fig, axes = plt.subplots(4, 1, figsize=(12, 12))

    # Error
    axes[0].plot(t, e, 'b-', linewidth=1.5)
    axes[0].axhline(y=0, color='k', linestyle=':', linewidth=0.5)
    axes[0].set_ylabel('Error e [%]')
    axes[0].grid(True, alpha=0.3)
    axes[0].set_title('Q-Controller Internal Signals (Before Learning)')

    # State value
    axes[1].plot(t, stan_value, 'g-', linewidth=1.5)
    axes[1].axhline(y=0, color='k', linestyle=':', linewidth=0.5)
    axes[1].set_ylabel('State value s')
    axes[1].grid(True, alpha=0.3)

    # Action values
    axes[2].plot(t, wart_akcji_bez_f_rzut, 'b-', label='Action (raw)', linewidth=1.5)
    axes[2].plot(t, funkcja_rzutujaca, 'r--', label='Projection term', linewidth=1.5)
    axes[2].plot(t, wart_akcji, 'g-', label='Action (with proj)', linewidth=1.5, alpha=0.7)
    axes[2].axhline(y=0, color='k', linestyle=':', linewidth=0.5)
    axes[2].set_ylabel('Action value')
    axes[2].legend()
    axes[2].grid(True, alpha=0.3)

    # Control increment
    axes[3].plot(t, u_increment, 'b-', linewidth=1.5)
    axes[3].axhline(y=0, color='k', linestyle=':', linewidth=0.5)
    axes[3].set_ylabel('Control increment')
    axes[3].set_xlabel('Time [s]')
    axes[3].grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('initialization_debug_analysis.png', dpi=150)
    print(f"  Debug plot saved to: initialization_debug_analysis.png")

def main():
    # Load logs
    log_file = Path(__file__).parent.parent / 'logi_before_learning.json'
    if not log_file.exists():
        print(f"ERROR: Log file not found: {log_file}")
        return

    logs = load_logs(log_file)
    analyze_initialization(logs)

    print("\n" + "="*70)
    print("ANALYSIS COMPLETE")
    print("="*70)

if __name__ == '__main__':
    main()
