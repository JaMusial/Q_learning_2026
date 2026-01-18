"""
Comprehensive Summary Report Generator
======================================

Runs all analysis tools and generates a unified diagnostic report.

This is the main entry point for debugging Q-learning issues.
It aggregates results from:
- Q-convergence analyzer
- Temporal consistency checker
- Goal state analyzer
- Constraint violation checker
- Projection function analyzer

Usage:
    python summary_report.py [json_file]
    python summary_report.py  # analyzes all available log files

Output:
    - Console report with all findings
    - Prioritized list of issues
    - Recommendations for fixes
"""

import sys
import os
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent))

from json_loader import load_debug_json, get_available_logs, LogData
from q_convergence_analyzer import analyze_convergence
from temporal_checker import analyze_temporal_consistency
from goal_state_analyzer import analyze_goal_state
from constraint_checker import analyze_constraints
from projection_analyzer import analyze_projection


class DiagnosticReport:
    """Aggregates and prioritizes diagnostic results."""

    def __init__(self):
        self.errors = []
        self.warnings = []
        self.info = []
        self.metrics = {}
        self.recommendations = []

    def add_results(self, category: str, results: dict):
        """Add results from an analyzer."""
        for check_name, check_results in results.items():
            status = check_results.get('status', 'OK')
            issues = check_results.get('issues', [])
            metrics = check_results.get('metrics', {})

            # Store metrics
            for key, value in metrics.items():
                self.metrics[f"{category}.{check_name}.{key}"] = value

            # Categorize issues
            for issue in issues:
                entry = {
                    'category': category,
                    'check': check_name,
                    'message': issue
                }

                if status == 'ERROR':
                    self.errors.append(entry)
                elif status == 'WARNING':
                    self.warnings.append(entry)
                else:
                    self.info.append(entry)

    def add_recommendation(self, priority: int, message: str, related_bug: str = None):
        """Add a recommendation."""
        self.recommendations.append({
            'priority': priority,
            'message': message,
            'bug': related_bug
        })

    def generate_recommendations(self):
        """Generate recommendations based on findings."""
        # Check for specific bug patterns
        error_messages = [e['message'] for e in self.errors]
        warning_messages = [w['message'] for w in self.warnings]
        all_issues = error_messages + warning_messages

        # Bug #3/4: Temporal mismatch
        if any('temporal' in m.lower() or 'mismatch' in m.lower() for m in all_issues):
            self.add_recommendation(
                1,
                "Check state-action-reward temporal alignment in m_regulator_Q.m",
                "Bug #3/4"
            )

        # Bug #5: Bootstrap contamination
        if any('bootstrap' in m.lower() or 'decreased' in m.lower() for m in all_issues):
            self.add_recommendation(
                1,
                "Verify bootstrap override for goal→goal transitions (m_regulator_Q.m:178-187)",
                "Bug #5"
            )

        # Bug #6: Constraint violations
        if any('constraint' in m.lower() or 'same-side' in m.lower() for m in all_issues):
            self.add_recommendation(
                1,
                "Check same-side constraint in m_losowanie_nowe.m lines 60-62",
                "Bug #6"
            )

        # Bug #10: Projection issues
        if any('projection' in m.lower() or 'on-trajectory' in m.lower() for m in all_issues):
            self.add_recommendation(
                2,
                "Review projection function conditions in m_regulator_Q.m:250-268",
                "Bug #10"
            )

        # Low goal Q value
        goal_q = self.metrics.get('goal_state.evolution.final_value', 0)
        if goal_q > 0 and goal_q < 90:
            self.add_recommendation(
                1,
                f"Q(goal,goal)={goal_q:.1f} is below expected ~100. Check reward/bootstrap logic.",
                None
            )

        # High violation rate
        violation_rate = self.metrics.get('constraints.same_side.violation_rate', 0)
        if violation_rate > 1:
            self.add_recommendation(
                1,
                f"High constraint violation rate ({violation_rate:.1f}%). Fix exploration logic.",
                "Bug #6"
            )

        # Sort by priority
        self.recommendations.sort(key=lambda x: x['priority'])

    def print_summary(self):
        """Print the diagnostic summary."""
        print("\n" + "=" * 70)
        print("                    DIAGNOSTIC SUMMARY REPORT")
        print("=" * 70)
        print(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print()

        # Issue counts
        print(f"Errors:   {len(self.errors)}")
        print(f"Warnings: {len(self.warnings)}")
        print(f"Info:     {len(self.info)}")
        print()

        # Errors (highest priority)
        if self.errors:
            print("=" * 70)
            print("ERRORS (Must Fix)")
            print("=" * 70)
            for i, err in enumerate(self.errors, 1):
                print(f"{i}. [{err['category']}.{err['check']}]")
                print(f"   {err['message']}")
            print()

        # Warnings
        if self.warnings:
            print("=" * 70)
            print("WARNINGS (Should Review)")
            print("=" * 70)
            for i, warn in enumerate(self.warnings, 1):
                print(f"{i}. [{warn['category']}.{warn['check']}]")
                print(f"   {warn['message']}")
            print()

        # Key metrics
        print("=" * 70)
        print("KEY METRICS")
        print("=" * 70)

        key_metrics = [
            ('goal_state.evolution.final_value', 'Q(goal,goal)', '~100'),
            ('goal_state.evolution.distance_to_100', 'Distance to max', '~0'),
            ('convergence.td_error.improvement_ratio', 'TD error improvement', '>1'),
            ('constraints.same_side.violation_rate', 'Constraint violations', '~0%'),
            ('temporal.reward.reward_1_percentage', 'R=1 percentage', '>0%'),
        ]

        for metric_key, label, expected in key_metrics:
            value = self.metrics.get(metric_key)
            if value is not None:
                if isinstance(value, float):
                    print(f"  {label}: {value:.2f} (expected {expected})")
                else:
                    print(f"  {label}: {value} (expected {expected})")
        print()

        # Recommendations
        self.generate_recommendations()

        if self.recommendations:
            print("=" * 70)
            print("RECOMMENDATIONS")
            print("=" * 70)
            for i, rec in enumerate(self.recommendations, 1):
                bug_str = f" [{rec['bug']}]" if rec['bug'] else ""
                print(f"{i}. [Priority {rec['priority']}]{bug_str}")
                print(f"   {rec['message']}")
            print()

        # Overall status
        print("=" * 70)
        print("OVERALL STATUS")
        print("=" * 70)

        if self.errors:
            print("✗ CRITICAL ISSUES DETECTED")
            print("  Q-learning has bugs that need immediate attention.")
            print("  Review errors above and check CLAUDE.md for bug fix details.")
        elif self.warnings:
            print("⚠ POTENTIAL ISSUES DETECTED")
            print("  Q-learning may have problems. Review warnings above.")
        else:
            print("✓ NO MAJOR ISSUES DETECTED")
            print("  Q-learning appears to be functioning correctly.")

        print()


def run_all_analyzers(data: LogData, verbose: bool = False) -> DiagnosticReport:
    """Run all analyzers and collect results."""
    report = DiagnosticReport()

    # Suppress individual analyzer output
    if not verbose:
        import io
        import contextlib

    print(f"\nAnalyzing: {data.filename}")
    print("-" * 40)

    # Run each analyzer
    analyzers = [
        ('convergence', analyze_convergence),
        ('temporal', analyze_temporal_consistency),
        ('goal_state', analyze_goal_state),
        ('constraints', analyze_constraints),
        ('projection', analyze_projection),
    ]

    for name, analyzer_func in analyzers:
        print(f"  Running {name}...", end=" ")
        try:
            if verbose:
                results = analyzer_func(data)
            else:
                # Capture output
                f = io.StringIO()
                with contextlib.redirect_stdout(f):
                    results = analyzer_func(data)

            report.add_results(name, results)
            print("OK")
        except Exception as e:
            print(f"FAILED: {e}")
            report.errors.append({
                'category': name,
                'check': 'execution',
                'message': f"Analyzer failed: {str(e)}"
            })

    return report


def analyze_single_file(filename: str, verbose: bool = False):
    """Analyze a single log file."""
    try:
        data = load_debug_json(filename)
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found")
        return None

    if not data.has_debug_data:
        print("Warning: Debug data appears empty.")
        print("Make sure debug_logging=1 in config.m before running MATLAB")

    report = run_all_analyzers(data, verbose)
    report.print_summary()
    return report


def analyze_all_files(verbose: bool = False):
    """Analyze all available log files."""
    logs = get_available_logs()

    if not logs:
        print("No log files found!")
        print("Expected files: logi_before_learning.json, logi_training.json, logi_after_learning.json")
        return

    print("=" * 70)
    print("Q-LEARNING DIAGNOSTIC TOOL")
    print("=" * 70)
    print(f"Found {len(logs)} log file(s)")

    reports = {}

    for name, data in logs.items():
        print(f"\n{'='*70}")
        print(f"FILE: {name} ({data.filename})")
        print(f"{'='*70}")

        if not data.has_debug_data:
            print("  Skipping - no debug data")
            continue

        report = run_all_analyzers(data, verbose)
        reports[name] = report

    # Print combined summary
    if reports:
        print("\n" + "=" * 70)
        print("COMBINED ANALYSIS SUMMARY")
        print("=" * 70)

        for name, report in reports.items():
            print(f"\n{name.upper()}:")
            print(f"  Errors: {len(report.errors)}, Warnings: {len(report.warnings)}")

            # Key metric
            goal_q = report.metrics.get('goal_state.evolution.final_value')
            if goal_q:
                print(f"  Q(goal,goal): {goal_q:.2f}")

        # Print most important report
        if 'training' in reports:
            print("\n" + "=" * 70)
            print("TRAINING LOG DETAILS")
            reports['training'].print_summary()
        elif 'after' in reports:
            print("\n" + "=" * 70)
            print("AFTER LEARNING LOG DETAILS")
            reports['after'].print_summary()


def main():
    """Main entry point."""
    verbose = '-v' in sys.argv or '--verbose' in sys.argv

    # Filter out flags
    args = [a for a in sys.argv[1:] if not a.startswith('-')]

    if args:
        # Analyze specific file
        analyze_single_file(args[0], verbose)
    else:
        # Analyze all available files
        analyze_all_files(verbose)


if __name__ == "__main__":
    main()
