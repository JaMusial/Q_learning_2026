#!/usr/bin/env python3
"""
projection_credit_analysis.py - Analyze credit assignment in projection mode

The fundamental problem: Q selects action A, but control applied is A - projection.
How do we correctly credit action A for outcomes caused by (A - projection)?
"""

import numpy as np

def analyze_credit_assignment(Te=5, Ti=20):
    """
    Analyze the relationship between Q-action, projection, and effective control.
    """
    print("=" * 70)
    print("CREDIT ASSIGNMENT ANALYSIS FOR PROJECTION MODE")
    print("=" * 70)
    print(f"\nParameters: Te={Te}, Ti={Ti}")
    print(f"Projection coefficient: 1/Te - 1/Ti = {1/Te - 1/Ti:.4f}")

    print("\n" + "=" * 70)
    print("MATHEMATICAL RELATIONSHIPS")
    print("=" * 70)

    print("""
For Q2d state: s = de + e/Te

With identity Q-matrix:
  action_value ≈ state_value = de + e/Te

Projection:
  projection = e * (1/Te - 1/Ti)

Effective control (what's actually applied):
  effective = action_value - projection
            = (de + e/Te) - e*(1/Te - 1/Ti)
            = de + e/Te - e/Te + e/Ti
            = de + e/Ti

This is exactly PI control! (Kp*dt*(de + e/Ti))
""")

    print("=" * 70)
    print("CREDIT RATIO ANALYSIS")
    print("=" * 70)

    # The ratio of effective to action at steady state (de=0)
    # effective = e/Ti, action = e/Te
    # ratio = (e/Ti) / (e/Te) = Te/Ti
    ratio = Te / Ti
    print(f"\nAt steady state (de=0):")
    print(f"  action = e/Te")
    print(f"  effective = e/Ti")
    print(f"  ratio = effective/action = Te/Ti = {ratio:.2f}")
    print(f"\n  This means only {ratio*100:.0f}% of Q-action's 'intention' is executed!")
    print(f"  The other {(1-ratio)*100:.0f}% is subtracted by projection.")

    print("\n" + "-" * 70)
    print("Example with e=30%:")
    e = 30
    de = 0  # steady state
    action = de + e/Te
    projection = e * (1/Te - 1/Ti)
    effective = action - projection
    print(f"  action = {action:.2f}")
    print(f"  projection = {projection:.2f}")
    print(f"  effective = {effective:.2f}")
    print(f"  ratio = {effective/action:.2f}")

    print("\n" + "=" * 70)
    print("ON-TRAJECTORY CASE (Critical!)")
    print("=" * 70)

    print("""
When system follows target trajectory: de = -e/Te

  state_value = de + e/Te = -e/Te + e/Te = 0
  Q selects goal action (value = 0)

  But projection still acts:
  projection = e * (1/Te - 1/Ti) ≠ 0

  effective = 0 - projection = -projection

PROBLEM: Q-action = 0, but outcome is caused by projection!
If we credit action=0 for this outcome, we're crediting the wrong thing.
""")

    print("Example: e=30%, on trajectory (de=-6):")
    e = 30
    de = -e/Te  # on trajectory
    action = de + e/Te  # = 0
    projection = e * (1/Te - 1/Ti)
    effective = action - projection
    print(f"  state_value = de + e/Te = {de} + {e/Te} = {action:.2f} (goal state!)")
    print(f"  Q selects action = 0 (goal action)")
    print(f"  projection = {projection:.2f}")
    print(f"  effective = {effective:.2f}")
    print(f"\n  Q did NOTHING, but effective control = {effective:.2f}!")
    print(f"  All control came from projection, not Q.")

    print("\n" + "=" * 70)
    print("WHY BUG #11 FIX DOESN'T WORK")
    print("=" * 70)

    print(f"""
Bug #11 disabled learning when |e| > threshold (≈2%).

The idea: when error is large, projection dominates, so don't learn.
The problem: the credit ratio Te/Ti = {ratio:.2f} is CONSTANT!

Whether e=2% or e=30%, the ratio of effective/action is always {ratio:.2f}.
The error threshold doesn't improve credit assignment - it just reduces
learning opportunities.

What we SHOULD check: is Q-action significant or near zero?
- If action ≈ 0 (on trajectory), projection does all work → don't learn
- If action is significant, apply credit with scaling factor
""")

    print("\n" + "=" * 70)
    print("PROPOSED SOLUTIONS")
    print("=" * 70)

    print("""
SOLUTION A: Don't learn when Q-action ≈ 0
--------------------------------------------
When |action_value| < threshold (e.g., smallest_action_step):
    uczenie = 0  # Q-action too small, projection dominates

This specifically targets the on-trajectory problem where Q=0 but
projection does all the work.


SOLUTION B: Scale TD-error by credit ratio (Te/Ti)
--------------------------------------------
When action is significant:
    credit_ratio = Te / Ti
    Q_update = alpha * TD_error * credit_ratio

This gives proportionally correct credit: if only 25% of the action's
intention was executed, give 25% credit.


SOLUTION C: Buffer effective action instead of Q-action
--------------------------------------------
Instead of buffering Q-action, buffer effective_action:
    effective_idx = find_action(effective_value)
    [old_effective, bufor] = f_bufor(effective_idx, bufor)

Then update Q(state, effective_action) instead of Q(state, Q_action).

This credits the action that was ACTUALLY applied.


SOLUTION D: Combined approach (Recommended)
--------------------------------------------
1. Check if Q-action is near zero → don't learn (projection does all work)
2. Otherwise, buffer EFFECTIVE action and credit that
3. No scaling needed because we're crediting what was actually done
""")

    return {
        'credit_ratio': ratio,
        'projection_coeff': 1/Te - 1/Ti
    }

if __name__ == "__main__":
    result = analyze_credit_assignment(Te=5, Ti=20)
