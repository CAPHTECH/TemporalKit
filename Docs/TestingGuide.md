# TemporalKit Testing Guide

This guide describes the testing framework used in TemporalKit, including the types of tests, how to run them, and how to interpret the results.

## Testing Framework Overview

TemporalKit uses XCTest for its testing framework. Tests are organized into several categories:

- **Unit Tests**: For individual components and algorithms
- **Edge Case Tests**: For challenging scenarios such as self-loops and terminal states
- **Complex Formula Tests**: For deeply nested LTL formulas and large state spaces
- **Random Generation Tests**: For robustness testing with randomly generated formulas and structures
- **Performance Tests**: For benchmarking the efficiency of key algorithms

## Test Categories

### Edge Case Tests

Located in `Tests/TemporalKitTests/ModelChecking/EdgeCaseTests.swift`, these tests cover challenging scenarios in model checking:

1. **Self-Loop Tests**:
   - `testSelfLoopAcceptance`: Tests that formulas like G(p) hold when p is true in a self-looping state
   - `testSelfLoopRejection`: Tests that formulas like G(p) fail when p is false in a self-looping state

2. **Terminal State Tests**:
   - `testTerminalStateAcceptance`: Tests that formulas like F(q) hold when q is true in a terminal state
   - `testTerminalStateRejection`: Tests the behavior of liveness formulas like G(F(p)) on terminal states, documenting the current limitation of the algorithm

3. **Multiple Acceptance Path Tests**:
   - `testMultipleAcceptancePaths`: Tests that formulas like p U q can be satisfied when multiple paths exist
   - `testMultipleAcceptancePathsNestedUntil`: Tests nested Until formulas with multiple satisfaction scenarios

### Complex LTL Formula Tests

Located in `Tests/TemporalKitTests/ModelChecking/ComplexLTLTests.swift`, these tests verify the model checking algorithm with complex formulas:

1. **Deeply Nested Formulas**:
   - `testDeeplyNestedUntilRelease`: Tests formulas like p U (q R (r U (s R t)))
   - `testDeepFormulaCombiningAllOperators`: Tests formulas that combine all major LTL operators

2. **Large State Space Tests**:
   - `testLargeKripkeStructure`: Tests model checking on structures with 20+ states
   - `testCyclicKripkeStructureWithNestedFormula`: Tests complex formulas on cyclic structures

### Random Generation Tests

Located in `Tests/TemporalKitTests/ModelChecking/RandomGeneratedTests.swift`, these tests use randomly generated inputs:

1. **Random Inputs**:
   - `testRandomFormulasAndStructures`: Tests diverse randomly generated formulas and structures
   - `testConsistencyOfRandomFormula`: Tests a fixed formula (G(p -> F q)) on different structures to verify consistent results

2. **Utility Functions for Random Generation**:
   - `generateRandomLTLFormula`: Creates random formulas with a specified nesting depth
   - `generateRandomKripkeStructure`: Creates random Kripke structures with a specified state count and transition density

### Performance Tests

Located in `Tests/TemporalKitTests/PerformanceTests.swift`, these benchmark the efficiency of key algorithms:

1. **NestedDFS Performance**:
   - `testNestedDFS_Performance_SmallStructure`: 10 states, 2 transitions per state
   - `testNestedDFS_Performance_MediumStructure`: 50 states, 3 transitions per state
   - `testNestedDFS_Performance_LargeStructure`: 100 states, 2 transitions per state

2. **GBAConditionGenerator Performance**:
   - `testGBAGeneration_Performance_SimpleFormula`: Simple formula G(p)
   - `testGBAGeneration_Performance_MediumFormula`: Medium formula G(p -> F q)
   - `testGBAGeneration_Performance_ComplexFormula`: Complex formula with nested Until and Release operators

## Running Tests

### Running All Tests

To run all tests, use:

```bash
swift test
```

### Running Specific Test Categories

To run specific test categories, use the `--filter` parameter:

```bash
# Run all edge case tests
swift test --filter EdgeCaseTests

# Run all complex formula tests
swift test --filter ComplexLTLTests

# Run all random generation tests
swift test --filter RandomGeneratedTests

# Run all performance tests
swift test --filter PerformanceTests
```

### Running Individual Tests

To run a specific test, use the full test name:

```bash
# Run a specific edge case test
swift test --filter EdgeCaseTests/testSelfLoopAcceptance

# Run a specific performance test
swift test --filter PerformanceTests/testNestedDFS_Performance_MediumStructure
```

## Interpreting Test Results

### Standard Tests

For standard tests, the output indicates whether each test passed or failed:

- ✅ Passed: The test executed successfully
- ❌ Failed: The test encountered an error or an assertion failed

### Performance Tests

Performance tests provide additional information:

- **Average Time**: The average execution time of the measured block
- **Standard Deviation**: The variation in execution times
- **Individual Values**: The execution time for each iteration

Example output:
```
Test Case 'PerformanceTests.testNestedDFS_Performance_MediumStructure' measured [Time, seconds] average: 0.025, relative standard deviation: 13.128%
```

This indicates that the NestedDFS algorithm took an average of 25 milliseconds to verify a medium-sized structure, with a relative standard deviation of 13.128%.

## Current Performance Baselines

Based on recent measurements, these are the current performance baselines:

1. **NestedDFS Algorithm**:
   - Small structures (10 states): ~0.006 seconds (6 ms)
   - Medium structures (50 states): ~0.025 seconds (25 ms)
   - Large structures (100 states): ~0.073 seconds (73 ms)

2. **GBAConditionGenerator**:
   - Simple formulas: ~0.00001 seconds (0.01 ms)
   - Medium formulas: ~0.00003 seconds (0.03 ms)
   - Complex formulas: ~0.0002 seconds (0.2 ms)

These baselines show that:
- The NestedDFS algorithm scales reasonably with increasing state space size
- The GBAConditionGenerator is extremely efficient, even for complex formulas
- State space exploration is the primary performance bottleneck rather than acceptance condition generation

## Adding New Tests

When adding new tests, follow these guidelines:

1. **Categorical Organization**: Add tests to the appropriate test file based on their category
2. **Descriptive Names**: Use descriptive names that indicate the purpose of the test
3. **Documentation**: Include comments explaining the test's purpose and expected behavior
4. **Performance Measurements**: For performance-critical code, include performance tests

## Test Helper Functions

TemporalKit provides several helper functions and types for testing:

- `TestKripkeStructure`: A simple Kripke structure implementation for testing
- `TestProposition`/`ClosureTemporalProposition`: Simple proposition types for testing
- `makeProposition`: Creates test propositions with specified IDs
- `createXxxKripke`: Creates specific Kripke structures for different test scenarios

## Continuous Integration

Tests are automatically run through CI pipelines on each pull request, ensuring that changes don't break existing functionality.

For detailed testing information or to report issues, see the [GitHub repository](https://github.com/yourusername/TemporalKit). 
