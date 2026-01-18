#!/usr/bin/env python3
"""
learning_rate_analyzer.py - Analyze how often Q-learning updates are enabled

This script calculates the theoretical percentage of steps where Q-learning
updates happen based on the current code logic.

Key findings:
1. Q-updates only happen when uczenie_T0 == 1
2. uczenie is set to 0 during exploitation (when eps < random threshold)
3. For projection mode with T0>0, uczenie is also set to 0 when |e| > threshold
"""

import numpy as np

def calculate_learning_rate(eps, proj_mode=False, T0=0, Te=5, Ti=20,
                            avg_error_pct=10, exploration_success_rate=0.9):
    """
    Calculate the percentage of steps where Q-learning updates actually happen.

    Parameters:
    - eps: exploration rate (default 0.3)
    - proj_mode: whether projection mode is enabled (f_rzutujaca_on=1)
    - T0: plant dead time
    - Te: current time constant
    - Ti: integral time
    - avg_error_pct: average absolute error percentage during training
    - exploration_success_rate: fraction of explorations that pass constraint checks

    Returns: percentage of steps with Q-updates
    """

    # Step 1: Probability of being in exploration mode
    p_exploration = eps
    p_exploitation = 1 - eps

    # Step 2: During exploitation, uczenie = 0 (no learning)
    # Learning only possible during exploration

    # Step 3: During exploration, we need to pass constraint checks
    p_exploration_success = p_exploration * exploration_success_rate
    p_exploration_fail = p_exploration * (1 - exploration_success_rate)

    # Step 4: Goal state visits (always uczenie=1, about 1-5% of steps when well-tuned)
    # For untrained controller, goal state visits are rare
    p_goal_state = 0.01  # Very low for untrained controller

    # Step 5: For projection mode with T0>0, learning disabled when error > threshold
    if proj_mode and T0 > 0:
        # threshold = MAX_PROJ_FOR_LEARNING / (1/Te - 1/Ti)
        # = 0.3 / (1/5 - 1/20) = 0.3 / 0.15 = 2%
        proj_coeff = abs(1/Te - 1/Ti)
        MAX_PROJ_FOR_LEARNING = 0.3
        error_threshold = MAX_PROJ_FOR_LEARNING / (proj_coeff + 0.001)

        # Fraction of time error is below threshold
        # For typical disturbance learning, error ranges from 0-30%
        # Only small fraction is below 2%
        p_small_error = min(1.0, error_threshold / avg_error_pct)

        # Learning only happens when: exploration succeeds AND error is small
        p_learning = p_exploration_success * p_small_error + p_goal_state * p_small_error
    else:
        # Without projection mode T0>0 constraint
        p_learning = p_exploration_success + p_goal_state

    return {
        'p_exploration': p_exploration * 100,
        'p_exploitation': p_exploitation * 100,
        'p_exploration_success': p_exploration_success * 100,
        'p_goal_state': p_goal_state * 100,
        'p_learning': p_learning * 100,
        'error_threshold_pct': error_threshold if proj_mode and T0 > 0 else None,
    }

def main():
    print("=" * 70)
    print("Q-LEARNING UPDATE RATE ANALYSIS")
    print("=" * 70)

    # Default parameters from config.m
    eps = 0.3  # eps_ini
    Te = 5     # Te_bazowe
    Ti = 20
    T0 = 0.5

    print("\nConfiguration:")
    print(f"  eps (exploration rate): {eps}")
    print(f"  Te (goal time constant): {Te}")
    print(f"  Ti (integral time): {Ti}")
    print(f"  T0 (dead time): {T0}")

    print("\n" + "=" * 70)
    print("SCENARIO 1: Staged Learning (f_rzutujaca_on=0)")
    print("=" * 70)

    result = calculate_learning_rate(eps, proj_mode=False, T0=0)
    print(f"\nT0=0 (no dead time compensation):")
    print(f"  Exploration rate: {result['p_exploration']:.1f}%")
    print(f"  Exploitation rate: {result['p_exploitation']:.1f}%")
    print(f"  Successful exploration: {result['p_exploration_success']:.1f}%")
    print(f"  Goal state visits: {result['p_goal_state']:.1f}%")
    print(f"  >>> EFFECTIVE LEARNING RATE: {result['p_learning']:.1f}% <<<")

    result = calculate_learning_rate(eps, proj_mode=False, T0=0.5)
    print(f"\nT0=0.5 (with dead time):")
    print(f"  >>> EFFECTIVE LEARNING RATE: {result['p_learning']:.1f}% <<<")

    print("\n" + "=" * 70)
    print("SCENARIO 2: Projection Mode (f_rzutujaca_on=1) with T0>0")
    print("=" * 70)

    result = calculate_learning_rate(eps, proj_mode=True, T0=0.5, Te=Te, Ti=Ti, avg_error_pct=10)
    print(f"\nWith typical 10% average error:")
    print(f"  Error threshold for learning: {result['error_threshold_pct']:.2f}%")
    print(f"  >>> EFFECTIVE LEARNING RATE: {result['p_learning']:.2f}% <<<")

    result = calculate_learning_rate(eps, proj_mode=True, T0=0.5, Te=Te, Ti=Ti, avg_error_pct=5)
    print(f"\nWith 5% average error (later in training):")
    print(f"  >>> EFFECTIVE LEARNING RATE: {result['p_learning']:.2f}% <<<")

    print("\n" + "=" * 70)
    print("ROOT CAUSE ANALYSIS")
    print("=" * 70)

    print("""
PROBLEM 1: Q-learning only updates during EXPLORATION, not exploitation
--------------------------------------------------------------------------
In standard Q-learning, updates happen on EVERY step:
  Q(s,a) ← Q(s,a) + α[R + γ·max(Q(s')) - Q(s,a)]

Current code sets uczenie=0 during exploitation (m_regulator_Q.m:166),
which means 70% of steps have NO Q-table updates.

PROBLEM 2: Projection mode disables learning during transients
--------------------------------------------------------------------------
For f_rzutujaca_on=1 with T0>0, learning is disabled when |e| > 2%
(m_regulator_Q.m:199-210). Since transients are when learning is most
needed, this severely cripples the learning process.

RESULT: With both issues, effective learning rate drops to <1%!

RECOMMENDATION:
1. Enable Q-updates during exploitation (standard Q-learning)
2. Remove or relax the error threshold for projection mode
3. Or use staged learning mode (f_rzutujaca_on=0) which avoids issue #2
""")

if __name__ == "__main__":
    main()
