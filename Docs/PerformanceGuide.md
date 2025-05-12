# TemporalKit Performance Guide

This document provides detailed information about the performance characteristics of TemporalKit's model checking algorithms, along with optimization strategies and known limitations.

## Performance Overview

TemporalKit's performance is primarily determined by the following factors:

1. **State Space Size**: The number of states in the Kripke structure
2. **Formula Complexity**: The nesting depth and number of operators in the LTL formula
3. **Algorithm Efficiency**: The optimizations applied to core algorithms

## Benchmark Results

### NestedDFS Algorithm

The NestedDFS algorithm is used for the emptiness check of Büchi automata, a critical step in LTL model checking. Performance varies with state space size:

| Structure Size | States | Transitions per State | Average Time (ms) | Relative Std Dev |
|----------------|--------|------------------------|------------------|------------------|
| Small          | 10     | 2                      | 6.0              | 8.3%             |
| Medium         | 50     | 3                      | 25.0             | 13.1%            |
| Large          | 100    | 2                      | 73.0             | 6.8%             |

These results show:
- The algorithm scales roughly linearly with state space size
- Handling 100 states takes only about 12x longer than handling 10 states
- Variability (standard deviation) remains reasonably low

### GBAConditionGenerator

The GBAConditionGenerator creates acceptance conditions for Generalized Büchi Automata:

| Formula Complexity | Operators                           | Average Time (ms) | Relative Std Dev |
|-------------------|-------------------------------------|------------------|------------------|
| Simple            | G(p)                                | 0.01             | 82.6%            |
| Medium            | G(p → F q)                          | 0.03             | 31.4%            |
| Complex           | G(p → X(q R (r U s)))               | 0.20             | 18.9%            |

These results show:
- GBAConditionGenerator is extremely efficient (sub-millisecond)
- Highly optimized special case handling contributes to performance
- Higher variability in simple cases due to small absolute times

## Performance Bottlenecks

Analysis of the benchmark results reveals these primary performance bottlenecks:

1. **Product Automaton Construction**: Creating the product of the model and formula automaton
2. **State Space Exploration**: Searching through large state spaces during emptiness checking
3. **Acceptance Cycle Detection**: Finding accepting cycles in complex automata

The GBA acceptance condition generation is **not** a bottleneck, even for complex formulas.

## Optimization Strategies

### Implemented Optimizations

TemporalKit includes these performance optimizations:

1. **Direct Cycle Detection**: The NestedDFS algorithm has been optimized to detect cycles directly when possible:
   ```swift
   // Direct cycle detection optimization
   if inStack.contains(nextState) && automaton.acceptingStates.contains(nextState) {
       // Found a path back to an accepting state in our stack
       // ...
   }
   ```

2. **Special Case Handling for Release Operators**: The GBAConditionGenerator includes optimized handling for special cases:
   ```swift
   // Special case optimizations for Release operators
   if lhsR.isBooleanLiteralTrue() {
       conditionMet = true // All states can be in acceptance set
   }
   ```

3. **Empty Liveness Detection**: Optimized handling for formulas without liveness operators:
   ```swift
   // If no liveness subformulas, all states are implicitly accepting
   if livenessSubformulas.isEmpty {
       // Create a single acceptance set containing all states
       // ...
   }
   ```

### Recommended Usage Patterns

For optimal performance:

1. **Limit State Space Size**: Keep models as small as possible while capturing the relevant behavior
2. **Use Proposition Optimizations**: Minimize the number of atomic propositions
3. **Avoid Extremely Deep Nesting**: While TemporalKit handles deep nesting well, excessive nesting can impact performance
4. **Consider Formula Equivalences**: Use formula equivalences to simplify complex formulas

Example of formula simplification:
```swift
// Instead of this (more complex to evaluate)
let formula1: LTLFormula<P> = .until(.not(.atomic(p)), .atomic(q))

// Consider this equivalent formula (simpler to evaluate)
let formula2: LTLFormula<P> = .release(.atomic(q), .and(.atomic(q), .not(.atomic(p))))
```

## Scalability Limits

Based on benchmark results, TemporalKit can handle:

- Kripke structures with hundreds of states
- LTL formulas with nesting depths of 5+
- Multiple acceptance sets and complex path conditions

Beyond these limits, performance may degrade. For extremely large state spaces (1000+ states), consider abstraction techniques or decomposition.

## Performance Comparison to State Space Size

The relationship between state space size and execution time shows a roughly linear trend for practical model sizes:

```
Execution Time (ms)
^
|                                                 *
|                                                    
|                                      
|                             *                     
|                  
|       *                                           
+----------------------------------------------> States
   10            50            100
```

This indicates efficient scaling for reasonable model sizes.

## Memory Usage Considerations

Memory usage primarily depends on:

1. **Product Automaton Size**: Proportional to the product of model states and formula states
2. **Path Storage**: Memory needed to store paths and cycles during exploration
3. **Automaton Representation**: Storage of states, transitions, and acceptance sets

For very large models, consider:
- Using memory-efficient data structures
- Processing states incrementally where possible
- Releasing references to intermediate data structures when no longer needed

## Known Performance Limitations

1. **Terminal States with Liveness Formulas**: As documented in edge case handling, terminal states with liveness formulas have a known limitation that can affect both correctness and performance.

2. **Deeply Nested Release Operators**: While optimized, deeply nested Release operators can still be computationally intensive.

3. **Large Strongly Connected Components**: State spaces with large strongly connected components can increase cycle detection time.

## Measuring and Monitoring Performance

To measure performance in your own applications:

```swift
import XCTest

// Add time measurement
let startTime = CFAbsoluteTimeGetCurrent()
let result = try modelChecker.check(formula: formula, model: kripke)
let executionTime = CFAbsoluteTimeGetCurrent() - startTime
print("Model checking took \(executionTime) seconds")
```

## Future Optimizations

Planned future performance improvements include:

1. **Parallel Processing**: Exploring multiple paths concurrently
2. **Symbolic Representation**: Using symbolic techniques for state space reduction
3. **On-the-fly Model Checking**: Building the product automaton incrementally during checking

## Conclusion

TemporalKit provides efficient model checking for practical model sizes and formula complexities. The current implementation balances correctness, feature richness, and performance, with particular attention to optimizing common cases.

For specific performance questions or to report performance issues, see the [GitHub repository](https://github.com/yourusername/TemporalKit). 
