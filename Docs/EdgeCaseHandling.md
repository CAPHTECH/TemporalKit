# Edge Case Handling in TemporalKit

This document describes how TemporalKit handles various edge cases in LTL model checking, particularly focusing on challenging scenarios that can cause unexpected behavior.

## Self-Loop States

Self-loops occur when a state has a transition to itself, creating a cycle of length 1.

### Behavior and Handling

- **Self-loops with true propositions**: When a state with a self-loop has propositions required by liveness formulas (e.g., G(p) where p is true in the self-loop state), the model checking correctly identifies this as an accepting run.
- **Self-loops with false propositions**: When a state with a self-loop lacks propositions required by liveness formulas (e.g., G(p) where p is false in the self-loop state), the model checking correctly identifies this as a rejecting run.

### Implementation Details

The NestedDFS algorithm has been improved to properly detect cycles including self-loops. When exploring states, the algorithm checks for a direct transition back to the current state, which correctly handles self-loops.

```swift
// Direct cycle detection (simplified example)
for nextState in successors {
    // Check for a direct transition back to the starting state (self-loop)
    if nextState == start {
        cyclePath.append(nextState) // Close the cycle
        return true  // Successfully found a cycle
    }
    
    // ... other cycle detection code ...
}
```

## Terminal States

Terminal states have no outgoing transitions, which can be problematic for liveness properties.

### Known Limitation

- **Liveness formulas with terminal states**: Formulas like G(F(p)) should technically fail on structures with terminal states (since "eventually p" cannot be satisfied infinitely often if execution stops). However, in the current implementation, these formulas may pass due to how terminal states are handled.

### Current Handling

- For non-liveness properties, terminal states are correctly handled. For example, F(q) correctly passes when q is true in a terminal state.
- For liveness properties like G(F(p)), the model checking algorithm currently has a limitation where terminal states may lead to incorrect acceptance. This is documented in the tests.

```swift
// Example from EdgeCaseTests.swift
// NOTE: In the current implementation, G(F(p)) actually HOLDS on a terminal state, 
// even though ideally it should FAIL. 
// This is a known limitation of the current algorithm.
```

This behavior occurs because the current NestedDFS algorithm treats terminal states as not violating liveness properties - as there is no infinite path through them, they don't disprove the formula.

## Multiple Acceptance Paths

When a Kripke structure has multiple possible paths that could satisfy a formula, the model checker should find a satisfying run if one exists.

### Behavior and Handling

- The NestedDFS algorithm has been enhanced to efficiently explore multiple paths, finding acceptance paths even in complex structures with multiple branches.
- For Until formulas like "p U q", the algorithm can find paths where p holds until q is reached, even when there are multiple possible paths.

### Implementation Details

The improved algorithm uses a breadth-first search approach to explore multiple paths, ensuring that if any path satisfies the formula, it will be found.

## Special Case Handling for Release Operators

The Release operator (p R q) has special semantic cases that require custom handling.

### Optimizations in GBAConditionGenerator

1. **False Release (false R q)**:
   - Equivalent to G(q) (globally q)
   - Requires a different acceptance condition than general Release
   - States holding q are included in the acceptance set

2. **True Release (true R q)**:
   - Simplifies to just q with no liveness constraint
   - All states can be in the acceptance set

### Implementation Details

The GBAConditionGenerator includes specialized handling for these cases:

```swift
// Special case: if A is false, R becomes G(B)
if lhsR.isBooleanLiteralFalse() {
    // For false R B (equivalent to G B), a node contributes if it contains B
    conditionMet = tableauNode.currentFormulas.contains(rhsR) ||
                 !tableauNode.currentFormulas.contains(livenessFormula)
}

// Special case: if A is true, R becomes just B, no liveness constraint needed
if lhsR.isBooleanLiteralTrue() {
    conditionMet = true // All states can be in acceptance set
}
```

## Empty Liveness Subformulas

When an LTL formula has no liveness subformulas (Until, Release, Eventually, Globally), special handling is required for acceptance conditions.

### Implementation

The GBAConditionGenerator creates a single acceptance set containing all states when no liveness subformulas are present, ensuring correct results for formulas without temporal operators.

```swift
// If no liveness subformulas, all states are implicitly accepting
if livenessSubformulas.isEmpty {
    // Create a single acceptance set containing all states
    var allStatesSet = Set<FormulaAutomatonState>()
    for tableauNode in tableauNodes {
        if let nodeID = nodeToStateIDMap[tableauNode] {
            allStatesSet.insert(nodeID)
        }
    }
    if !allStatesSet.isEmpty {
        gbaAcceptanceSets.append(allStatesSet)
    }
}
```

## Nested Formulas

Deeply nested formulas (e.g., p U (q R (r U (s R t)))) can be particularly challenging for model checking.

### Behavior and Handling

- The TemporalKit model checker correctly processes deeply nested formulas, maintaining proper semantics.
- The improved tableau construction and acceptance condition generation ensure consistent results even for complex formulas.
- Performance optimizations in the GBAConditionGenerator help maintain efficiency even with deep nesting levels.

## Conclusion

While TemporalKit handles most edge cases correctly, users should be aware of the known limitation regarding terminal states and liveness properties. Future improvements will address this limitation.

For detailed examples of these edge cases, refer to the test files in `Tests/TemporalKitTests/ModelChecking/EdgeCaseTests.swift` and `Tests/TemporalKitTests/ModelChecking/ComplexLTLTests.swift`. 
