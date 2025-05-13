# Troubleshooting

This document contains solutions to common issues you may encounter when using TemporalKit, as well as general debugging tips.

## Table of Contents

- [Common Errors](#common-errors)
- [Performance Issues](#performance-issues)
- [State Space Explosion](#state-space-explosion)
- [Incorrect Modeling Problems](#incorrect-modeling-problems)
- [Debugging Counterexamples](#debugging-counterexamples)
- [Integration Problems](#integration-problems)
- [Advanced Debugging Techniques](#advanced-debugging-techniques)

## Common Errors

### Error: "Infinite Trace Detected"

**Problem**: The model checker reports an "Infinite Trace Detected" error.

**Cause**: This typically occurs when your model contains a cycle without a way to progress toward acceptance or rejection of a formula.

**Solution**:

```swift
// Check for cycles in your model
for state in model.allStates {
    if model.successors(of: state).contains(state) {
        print("Self-loop detected at state: \(state)")
        // Ensure there's a way to exit this loop
    }
}

// Ensure liveness properties are correctly specified
// Incorrect:
let badProperty = LTLFormula<MyProposition>.eventually(.atomic(someProposition))

// Better:
let goodProperty = LTLFormula<MyProposition>.eventually(.and(
    .atomic(someProposition),
    .globally(.implies(.atomic(someProposition), .eventually(.atomic(nextProposition))))
))
```

### Error: "Model Size Too Large"

**Problem**: You encounter a "Model Size Too Large" or memory limits when verifying a model.

**Cause**: The state space of your model is too large for verification.

**Solution**:

1. Reduce the model's complexity:

```swift
// Use abstraction to reduce state space
struct AbstractedModel: KripkeStructure {
    // Collapse similar states
    // Focus only on relevant state variables
}

// Or use on-the-fly verification which generates states as needed
let onTheFlyModelChecker = OnTheFlyLTLModelChecker<MyModel>()
```

2. Use bounded model checking to limit the depth of verification.

### Error: "Proposition Not Found"

**Problem**: You encounter a "Proposition Not Found" error during verification.

**Cause**: A proposition used in the formula doesn't exist in the model.

**Solution**:

```swift
// List all propositions in your model
let propositions = model.allStates.flatMap { state in
    model.atomicPropositionsTrue(in: state)
}
print("Available propositions: \(Set(propositions))")

// Ensure your formula uses only available propositions
let validProposition = TemporalKit.makeProposition(
    id: "validID", // Use an ID that exists in your model
    name: "Valid Proposition",
    evaluate: { /* ... */ }
)
```

### Error: "Invalid Temporal Logic Formula"

**Problem**: Formula construction errors or validation failures.

**Cause**: Incorrect formula construction or invalid operators.

**Solution**:

```swift
// Break down complex formulas into smaller parts
let subFormula1 = LTLFormula<MyProposition>.eventually(.atomic(prop1))
let subFormula2 = LTLFormula<MyProposition>.globally(.atomic(prop2))
let combinedFormula = LTLFormula<MyProposition>.and(subFormula1, subFormula2)

// Use the DSL helpers for cleaner syntax
let formula = eventually(p1) && globally(p2)
```

## Performance Issues

### Slow Verification

**Problem**: Verification takes too long to complete.

**Cause**: Large state space, complex formulas, or inefficient model representation.

**Solution**:

1. Simplify your formulas:

```swift
// Overly complex formula
let complexFormula = LTLFormula<MyProposition>.globally(
    .implies(
        .atomic(p1),
        .and(
            .eventually(.atomic(p2)),
            .not(.until(.atomic(p3), .atomic(p4)))
        )
    )
)

// Equivalent but potentially more efficient
let simpleFormula1 = LTLFormula<MyProposition>.globally(.implies(.atomic(p1), .eventually(.atomic(p2))))
let simpleFormula2 = LTLFormula<MyProposition>.globally(.implies(.atomic(p1), .not(.until(.atomic(p3), .atomic(p4)))))
// Verify each separately
```

2. Use compositional verification:

```swift
// Verify components separately
let result1 = try modelChecker.check(formula: formula1, model: subModel1)
let result2 = try modelChecker.check(formula: formula2, model: subModel2)
```

3. Enable optimizations:

```swift
let modelChecker = LTLModelChecker<MyModel>(options: [
    .enablePartialOrderReduction,
    .useSymbolicRepresentation,
    .cacheIntermediateResults
])
```

## State Space Explosion

### Handling Large Models

**Problem**: Your model has too many states to verify efficiently.

**Cause**: Complex system with many variables or components.

**Solution**:

1. Use abstraction:

```swift
// Abstract only relevant parts of your state
struct AbstractState: Hashable {
    // Only include state variables relevant to your property
    let relevantVar1: Bool
    let relevantVar2: Int
}

struct AbstractModel: KripkeStructure {
    // Implement abstraction mapping from concrete to abstract states
}
```

2. Use compositional verification:

```swift
// Divide system into components
let component1 = Component1Model()
let component2 = Component2Model()

// Verify properties specific to each component
try modelChecker.check(formula: component1Property, model: component1)
try modelChecker.check(formula: component2Property, model: component2)

// Then verify interaction properties with a reduced model
```

3. Use bounded model checking:

```swift
// Verify up to a certain depth
let boundedChecker = BoundedLTLModelChecker<MyModel>(bound: 10)
try boundedChecker.check(formula: property, model: model)
```

## Incorrect Modeling Problems

### False Positives/Negatives

**Problem**: Verification results don't match expected behavior.

**Cause**: Incorrect model, incorrect formula, or mismatched abstractions.

**Solution**:

1. Validate your model independently:

```swift
// Test basic properties that should always hold
let sanityCheck = LTLFormula<MyProposition>.globally(.or(.atomic(p1), .atomic(p2)))
try modelChecker.check(formula: sanityCheck, model: model)
```

2. Use trace evaluation to test specific scenarios:

```swift
// Create a known trace
let trace: [MyState] = [state1, state2, state3]

// Evaluate formula on this trace
let evaluator = LTLFormulaTraceEvaluator<MyState, MyProposition>()
let result = try evaluator.evaluate(formula: formula, trace: trace)
```

3. Start with minimum models and incrementally add complexity:

```swift
// Start with a minimal model
let minimalModel = createMinimalModel()
try modelChecker.check(formula: property, model: minimalModel)

// Incrementally add more states and transitions
let extendedModel = extendModel(minimalModel)
try modelChecker.check(formula: property, model: extendedModel)
```

## Debugging Counterexamples

### Understanding Counterexamples

**Problem**: Difficulty interpreting counterexamples provided by the model checker.

**Cause**: Complex state representation or counterintuitive formula behavior.

**Solution**:

1. Visualize the counterexample:

```swift
// Print counterexample trace
if case .fails(let counterexample) = result {
    for (index, state) in counterexample.enumerated() {
        print("State \(index): \(state)")
        print("  Props: \(model.atomicPropositionsTrue(in: state))")
    }
}
```

2. Evaluate subformulas on the counterexample:

```swift
if case .fails(let counterexample) = result {
    let evaluator = LTLFormulaTraceEvaluator<MyState, MyProposition>()
    
    // Evaluate each subformula
    for subformula in formula.subformulas {
        let subResult = try evaluator.evaluate(formula: subformula, trace: counterexample)
        print("Subformula \(subformula): \(subResult)")
    }
}
```

3. Check specific states in the counterexample:

```swift
// Focus on the critical points in the counterexample
if case .fails(let counterexample) = result {
    // Check loop entry point (if it exists)
    if let loopStart = counterexample.loopEntryPoint {
        print("Loop starts at state \(loopStart): \(counterexample[loopStart])")
    }
    
    // Check first state where a key proposition becomes true
    if let index = counterexample.firstIndex(where: { model.atomicPropositionsTrue(in: $0).contains("key") }) {
        print("Key proposition first true at state \(index): \(counterexample[index])")
    }
}
```

## Integration Problems

### Integrating with SwiftUI

**Problem**: Difficulty integrating TemporalKit verification with SwiftUI application code.

**Solution**:

```swift
class VerifiedViewModel: ObservableObject {
    @Published var state: AppState = .initial
    
    private let stateModel: AppStateModel
    private let modelChecker: LTLModelChecker<AppStateModel>
    
    init() {
        stateModel = AppStateModel()
        modelChecker = LTLModelChecker<AppStateModel>()
        
        // Verify critical properties during initialization
        do {
            let result = try modelChecker.check(formula: safetyProperty, model: stateModel)
            if !result.holds {
                print("Warning: Safety property does not hold in the app model")
            }
        } catch {
            print("Verification error: \(error)")
        }
    }
    
    func transition(to newState: AppState) {
        // Only allow valid transitions
        guard stateModel.successors(of: state).contains(newState) else {
            print("Invalid transition attempted from \(state) to \(newState)")
            return
        }
        
        state = newState
    }
}
```

### Integration with Asynchronous Code

**Problem**: Verifying properties in asynchronous code.

**Solution**:

```swift
// Create an observable model that can be verified
class VerifiableAsyncProcessor {
    private let operationQueue = OperationQueue()
    private let model: AsyncOperationModel
    private let modelChecker: LTLModelChecker<AsyncOperationModel>
    
    var statePublisher: AnyPublisher<AsyncOperationState, Never> { /* ... */ }
    
    init() {
        model = AsyncOperationModel()
        modelChecker = LTLModelChecker<AsyncOperationModel>()
        
        // Verify properties
        verifyProperties()
    }
    
    private func verifyProperties() {
        do {
            // Verify eventually completes
            let completionProperty = LTLFormula<MyProposition>.globally(
                .implies(
                    .atomic(isStarted),
                    .eventually(.or(.atomic(isCompleted), .atomic(isFailed)))
                )
            )
            
            try modelChecker.check(formula: completionProperty, model: model)
        } catch {
            print("Verification error: \(error)")
        }
    }
}
```

## Advanced Debugging Techniques

### Using Logging and Visualization

Enable detailed logging to understand what's happening during verification:

```swift
// Create a model checker with logging
let modelChecker = LTLModelChecker<MyModel>(options: [.enableVerboseLogging])

// Or create a custom model checker with logging
struct LoggingModelChecker<Model: KripkeStructure>: LTLModelCheckingAlgorithm {
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // Log the verification process
        print("Starting verification of formula: \(formula)")
        print("Model states: \(model.allStates.count)")
        
        // Track visited states
        var visitedStates = Set<Model.State>()
        
        // ... verification logic with logging
    }
}

// Export model for visualization
func exportModelToDOT<Model: KripkeStructure>(model: Model, filename: String) {
    var dotContent = "digraph G {\n"
    
    // Add states
    for state in model.allStates {
        let stateLabel = "\(state)"
        let stateProps = model.atomicPropositionsTrue(in: state).joined(separator: ", ")
        dotContent += "  \"\(state.hashValue)\" [label=\"\(stateLabel)\\n{\(stateProps)}\"]\n"
    }
    
    // Add transitions
    for state in model.allStates {
        for successor in model.successors(of: state) {
            dotContent += "  \"\(state.hashValue)\" -> \"\(successor.hashValue)\"\n"
        }
    }
    
    dotContent += "}\n"
    
    // Write to file
    try? dotContent.write(toFile: filename, atomically: true, encoding: .utf8)
}
```

### Breaking Down Formulas

If you're having trouble with a complex formula, break it down into simpler parts:

```swift
// Complex formula
let complexFormula = LTLFormula<MyProposition>.globally(
    .implies(
        .atomic(p1),
        .until(
            .atomic(p2),
            .and(
                .atomic(p3),
                .not(.atomic(p4))
            )
        )
    )
)

// Break down into parts
let part1 = LTLFormula<MyProposition>.until(.atomic(p2), .and(.atomic(p3), .not(.atomic(p4))))
let part2 = LTLFormula<MyProposition>.implies(.atomic(p1), part1)
let simplifiedFormula = LTLFormula<MyProposition>.globally(part2)

// Verify each part
let result1 = try modelChecker.check(formula: part1, model: model)
print("Part 1: \(result1)")

// Try with bounded model checking for complex parts
let boundedChecker = BoundedLTLModelChecker<MyModel>(bound: 10)
let boundedResult = try boundedChecker.check(formula: complexFormula, model: model)
```

### Using Testing to Validate Models

Before full verification, use testing to validate your models:

```swift
// Test coverage of state space
func testStateSpaceCoverage<Model: KripkeStructure>(model: Model) {
    var visited = Set<Model.State>()
    var queue = Array(model.initialStates)
    
    while !queue.isEmpty {
        let state = queue.removeFirst()
        visited.insert(state)
        
        for successor in model.successors(of: state) {
            if !visited.contains(successor) {
                queue.append(successor)
            }
        }
    }
    
    // Check coverage
    let unreachableStates = model.allStates.subtracting(visited)
    if !unreachableStates.isEmpty {
        print("Warning: Found unreachable states: \(unreachableStates)")
    }
}

// Test specific scenarios
func testScenario<Model: KripkeStructure>(model: Model, initialState: Model.State, actions: [Action]) -> Bool {
    var currentState = initialState
    
    for action in actions {
        let nextStates = model.successors(of: currentState)
        let matchingState = nextStates.first { state in
            // Check if state matches the expected result of the action
            return matchesAction(state, action)
        }
        
        guard let next = matchingState else {
            print("Action \(action) cannot be applied from state \(currentState)")
            return false
        }
        
        currentState = next
    }
    
    return true
}
```

## Summary

When troubleshooting issues with TemporalKit:

1. Start with small models and simple formulas, then incrementally add complexity
2. Use logging and visualization to understand the model and verification process
3. Break down complex formulas into smaller parts
4. Validate models with testing before verification
5. Use abstraction and bounded model checking for large models
6. Carefully analyze counterexamples to understand why properties don't hold

If you continue to experience problems, consider submitting an issue on the TemporalKit GitHub repository with a minimal reproducible example. 
