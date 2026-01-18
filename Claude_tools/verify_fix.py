#!/usr/bin/env python3
"""
Verify that the initialization fix works by analyzing new logi_before_learning.json
Compare to baseline stored in logi_before_learning_OLD.json (if available)
"""

import json
import numpy as np
from pathlib import Path

def analyze_phase_performance(logs, phase_name, start, end):
    """Calculate performance metrics for a phase."""
    u_Q = np.array(logs['Q_u'][start:end])
    u_PI = np.array(logs['PID_u'][start:end])

    u_diff = np.abs(u_Q - u_PI)

    return {
        'mean': np.mean(u_diff),
        'std': np.std(u_diff),
        'max': np.max(u_diff),
        'samples': end - start
    }

def main():
    log_file = Path(__file__).parent.parent / 'logi_before_learning.json'

    if not log_file.exists():
        print("ERROR: logi_before_learning.json not found!")
        print("Please run the verification experiment first (main.m in MATLAB)")
        return

    print("="*80)
    print("VERIFICATION FIX ANALYSIS")
    print("="*80)

    with open(log_file, 'r') as f:
        logs = json.load(f)

    # Find phase boundaries
    d = np.array(logs['Q_d'])
    phase2_start = np.where(np.abs(d) > 0.01)[0][0] if np.any(np.abs(d) > 0.01) else 2000
    phase2_end = np.where(np.abs(d) > 0.01)[0][-1] + 1 if np.any(np.abs(d) > 0.01) else 4000

    # Define phases
    phases = {
        'Phase 1 (SP tracking)': (19, phase2_start),
        'Phase 2 (Disturbance)': (phase2_start, phase2_end),
        'Phase 3 (Recovery)': (phase2_end, len(logs['Q_t']))
    }

    print("\nCurrent Performance (with fix):")
    print("-" * 80)

    results = {}
    for phase_name, (start, end) in phases.items():
        metrics = analyze_phase_performance(logs, phase_name, start, end)
        results[phase_name] = metrics

        print(f"\n{phase_name}:")
        print(f"  Mean control difference: {metrics['mean']:.3f}%")
        print(f"  Std deviation:           {metrics['std']:.3f}%")
        print(f"  Max control difference:  {metrics['max']:.3f}%")
        print(f"  Samples:                 {metrics['samples']}")

    # Expected performance
    print("\n" + "="*80)
    print("EXPECTED PERFORMANCE")
    print("="*80)

    print("\nPhase 1 (SP tracking):")
    print("  Target: mean < 0.5%, max < 2.0%")
    p1_pass = results['Phase 1 (SP tracking)']['mean'] < 0.5 and results['Phase 1 (SP tracking)']['max'] < 2.0
    print(f"  Status: {'✓ PASS' if p1_pass else '✗ FAIL'}")

    print("\nPhase 2 (Disturbance):")
    print("  Target: mean < 0.5%, max < 1.0%")
    p2_pass = results['Phase 2 (Disturbance)']['mean'] < 0.5 and results['Phase 2 (Disturbance)']['max'] < 1.0
    print(f"  Status: {'✓ PASS' if p2_pass else '✗ FAIL'}")

    print("\nPhase 3 (Recovery):")
    print("  Target: mean < 0.5%, max < 1.0%")
    p3_pass = results['Phase 3 (Recovery)']['mean'] < 0.5 and results['Phase 3 (Recovery)']['max'] < 1.0
    print(f"  Status: {'✓ PASS' if p3_pass else '✗ FAIL'}")

    # Overall assessment
    print("\n" + "="*80)
    print("OVERALL ASSESSMENT")
    print("="*80)

    if p1_pass and p2_pass and p3_pass:
        print("\n✓✓✓ FIX SUCCESSFUL! All phases meet bumpless transfer criteria.")
    elif p1_pass:
        print("\n✓ Phase 1 improved! Fix is working for initialization.")
        if not (p2_pass and p3_pass):
            print("⚠ Phases 2&3 performance degraded - unexpected issue.")
    else:
        print("\n✗ Phase 1 still has issues. Further investigation needed.")
        print(f"\n  Phase 1 performance: mean={results['Phase 1 (SP tracking)']['mean']:.3f}%, max={results['Phase 1 (SP tracking)']['max']:.3f}%")

    # Check if projection was applied
    funkcja_rzut = np.array(logs['Q_funkcja_rzut'])
    proj_active = np.sum(np.abs(funkcja_rzut[19:phase2_start]) > 0.01)
    proj_total = phase2_start - 19

    print(f"\nProjection function activity in Phase 1:")
    print(f"  Active in {proj_active}/{proj_total} samples ({proj_active/proj_total*100:.1f}%)")
    print(f"  Mean |projection|: {np.mean(np.abs(funkcja_rzut[19:phase2_start])):.4f}")

    if proj_active < proj_total * 0.1:
        print("  ⚠ WARNING: Projection rarely active! Check if f_rzutujaca_on=1")

if __name__ == '__main__':
    main()
