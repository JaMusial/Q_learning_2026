%% ========================================================================
%% run_all_tests - Master test runner for exploration fixes
%% ========================================================================
% PURPOSE:
%   Execute all test suites to verify exploration constraint fixes:
%   - Fix #1: Corrected inverted constraint logic (m_losowanie_nowe.m)
%   - Fix #2: Disable Q-updates on failed exploration (m_regulator_Q.m)
%
% TEST SUITES:
%   1. test_constraint_logic.m - Unit tests for constraint logic
%   2. test_exploration_behavior.m - Integration tests for exploration
%
% USAGE:
%   Run in MATLAB command window: run_all_tests
%
% EXPECTED OUTPUT:
%   All tests should PASS if fixes are correctly implemented
%% ========================================================================

function run_all_tests()
    fprintf('\n');
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                                                            ║\n');
    fprintf('║       Q2d Exploration Fixes - Comprehensive Test Suite     ║\n');
    fprintf('║                                                            ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');
    fprintf('\n');

    % Track overall test results
    start_time = tic;
    all_tests_passed = true;

    %% Test Suite 1: Constraint Logic
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║ TEST SUITE 1: Constraint Logic Unit Tests                 ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');

    try
        test_constraint_logic();
        fprintf('✓ Test Suite 1: Completed\n\n');
    catch ME
        fprintf('✗ Test Suite 1: FAILED with error\n');
        fprintf('   Error: %s\n\n', ME.message);
        all_tests_passed = false;
    end

    %% Test Suite 2: Exploration Behavior
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║ TEST SUITE 2: Exploration Behavior Integration Tests      ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n');

    try
        test_exploration_behavior();
        fprintf('✓ Test Suite 2: Completed\n\n');
    catch ME
        fprintf('✗ Test Suite 2: FAILED with error\n');
        fprintf('   Error: %s\n\n', ME.message);
        all_tests_passed = false;
    end

    %% Final Summary
    elapsed_time = toc(start_time);

    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    FINAL SUMMARY                           ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n\n');

    fprintf('Total test execution time: %.2f seconds\n\n', elapsed_time);

    if all_tests_passed
        fprintf('╔════════════════════════════════════════════════════════════╗\n');
        fprintf('║                                                            ║\n');
        fprintf('║                ✓✓✓ ALL TESTS PASSED ✓✓✓                   ║\n');
        fprintf('║                                                            ║\n');
        fprintf('║  Exploration constraint fixes are working correctly!       ║\n');
        fprintf('║                                                            ║\n');
        fprintf('╚════════════════════════════════════════════════════════════╝\n\n');

        fprintf('Next Steps:\n');
        fprintf('  1. Run a short training experiment (500 epochs)\n');
        fprintf('  2. Check logs for improved exploration in states 51-100\n');
        fprintf('  3. Verify Q-values converge correctly\n');
        fprintf('  4. Compare performance before/after fixes\n\n');
    else
        fprintf('╔════════════════════════════════════════════════════════════╗\n');
        fprintf('║                                                            ║\n');
        fprintf('║                ✗✗✗ SOME TESTS FAILED ✗✗✗                  ║\n');
        fprintf('║                                                            ║\n');
        fprintf('║  Review error messages above and fix issues               ║\n');
        fprintf('║                                                            ║\n');
        fprintf('╚════════════════════════════════════════════════════════════╝\n\n');
    end

    %% Documentation
    fprintf('╔════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    FIXES APPLIED                           ║\n');
    fprintf('╚════════════════════════════════════════════════════════════╝\n\n');

    fprintf('Fix #1: Corrected inverted constraint logic\n');
    fprintf('  File: m_losowanie_nowe.m (lines 54-56)\n');
    fprintf('  Change: Flipped state-action relationship\n');
    fprintf('  Before: (action > 50 && state > 50) || (action < 50 && state < 50)\n');
    fprintf('  After:  (action < 50 && state > 50) || (action > 50 && state < 50)\n');
    fprintf('  Impact: Enables correct exploration in states 51-100\n\n');

    fprintf('Fix #2: Disable Q-updates on failed exploration\n');
    fprintf('  File: m_regulator_Q.m (lines 157-164)\n');
    fprintf('  Change: Set uczenie=0 when exploration fails\n');
    fprintf('  Before: Always uczenie=1 during exploration phase\n');
    fprintf('  After:  uczenie=0 if constraint rejects 10 times\n');
    fprintf('  Impact: Prevents reinforcing wrong policy on failed exploration\n\n');

    fprintf('Documentation:\n');
    fprintf('  - EXPLORATION_ANALYSIS.md: Detailed analysis of bugs\n');
    fprintf('  - logi.md: Empirical evidence from training logs\n');
    fprintf('  - CLAUDE.md: Updated with fix details\n\n');
end
