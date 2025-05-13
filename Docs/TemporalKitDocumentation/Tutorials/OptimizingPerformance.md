# Optimizing Performance

This tutorial teaches you how to optimize the performance of model checking using TemporalKit. It introduces techniques to address state explosion problems that may occur when verifying large systems or more complex properties.

## Objectives

By the end of this tutorial, you will be able to:

- Understand and address state space explosion problems
- Apply techniques to improve model checking performance
- Use TemporalKit efficiently for large-scale systems
- Identify and resolve performance bottlenecks

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts
- Completion of the [Simple Model Checking](./SimpleModelChecking.md) tutorial

## Step 1: Understanding State Explosion

State explosion is one of the most common challenges in model checking. It's the phenomenon where the number of system states increases exponentially with the number of variables or concurrent components.

```swift
import TemporalKit

// For a system with n binary variables, the number of states is 2^n
func stateSpaceSize(variableCount: Int) -> Int {
    return Int(pow(2.0, Double(variableCount)))
}

print("Relationship between number of variables and state space size:")
for i in 1...20 {
    print("\(i) variables: \(stateSpaceSize(variableCount: i)) states")
}

// For example, a system with 10 variables could have 1,024 possible states
// With 20 variables, there could be 1,048,576 possible states
```

## Step 2: Techniques for Reducing State Space

Let's look at several techniques for reducing the state space.

### 2.1 Limiting to Reachable States

By considering only states that are actually reachable from the initial state of the system, you can significantly reduce the state space.

```swift
// Example: More efficient Kripke structure implementation
struct OptimizedCounterModel: KripkeStructure {
    typealias State = Int
    typealias AtomicPropositionIdentifier = PropositionID
    
    let minValue: Int
    let maxValue: Int
    let initialState: Int
    
    // Cached state list for lazy computation
    private var _allStates: Set<State>?
    private let _initialStates: Set<State>
    
    init(minValue: Int = 0, maxValue: Int = 100, initialState: Int = 0) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.initialState = initialState
        self._initialStates = [initialState]
    }
    
    var initialStates: Set<State> {
        return _initialStates
    }
    
    var allStates: Set<State> {
        // Compute only when needed, then use the cache
        if let states = _allStates {
            return states
        }
        
        // Compute only states reachable from the initial state
        var states = Set<State>()
        var frontier = [initialState]
        
        while !frontier.isEmpty {
            let state = frontier.removeFirst()
            
            if states.contains(state) {
                continue
            }
            
            states.insert(state)
            
            // Compute next states
            let nextStates = successors(of: state)
            for nextState in nextStates {
                if !states.contains(nextState) {
                    frontier.append(nextState)
                }
            }
        }
        
        _allStates = states
        return states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Increment
        if state + 1 <= maxValue {
            nextStates.insert(state + 1)
        }
        
        // Decrement
        if state - 1 >= minValue {
            nextStates.insert(state - 1)
        }
        
        // Reset
        nextStates.insert(0)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        if state == 0 {
            trueProps.insert("isZero")
        }
        
        if state > 0 {
            trueProps.insert("isPositive")
        }
        
        if state % 2 == 0 {
            trueProps.insert("isEven")
        }
        
        return trueProps
    }
}
```

### 2.2 Leveraging State Symmetry

Many systems have symmetry, and by combining equivalent states, you can reduce the state space.

```swift
// Example: System state definition leveraging symmetry
struct SymmetricSystemState: Hashable {
    let processes: [ProcessState]
    
    // Enumeration representing process states
    enum ProcessState: Int, Hashable {
        case idle
        case active
        case finished
    }
    
    // Hashable implementation considering symmetry
    func hash(into hasher: inout Hasher) {
        // Count process states (ignoring order)
        var counts = [0, 0, 0] // count of idle, active, finished
        for state in processes {
            counts[state.rawValue] += 1
        }
        
        // Hash only the count of each state
        for count in counts {
            hasher.combine(count)
        }
    }
    
    // Equality check considering symmetry
    static func == (lhs: SymmetricSystemState, rhs: SymmetricSystemState) -> Bool {
        guard lhs.processes.count == rhs.processes.count else { return false }
        
        // Count process states
        var lhsCounts = [0, 0, 0]
        var rhsCounts = [0, 0, 0]
        
        for state in lhs.processes {
            lhsCounts[state.rawValue] += 1
        }
        
        for state in rhs.processes {
            rhsCounts[state.rawValue] += 1
        }
        
        // Consider equivalent if counts are the same
        return lhsCounts == rhsCounts
    }
}
```

### 2.3 Abstraction and Model Reduction

You can reduce the state space by creating an abstract model that lowers the level of detail of the system.

```swift
// Example: System model definition using abstraction
enum AbstractTemperature: Hashable {
    case cold    // Below 0°C
    case normal  // 0-30°C
    case hot     // Above 30°C
    
    // Conversion from concrete temperature to abstract value
    static func fromActual(_ temperature: Double) -> AbstractTemperature {
        if temperature < 0 {
            return .cold
        } else if temperature < 30 {
            return .normal
        } else {
            return .hot
        }
    }
}

// Abstract temperature control system
struct AbstractTemperatureControlSystem: KripkeStructure {
    typealias State = AbstractTemperature
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State> = [.cold, .normal, .hot]
    let initialStates: Set<State> = [.normal]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .cold:
            return [.cold, .normal]
        case .normal:
            return [.cold, .normal, .hot]
        case .hot:
            return [.normal, .hot]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .cold:
            props.insert("isCold")
        case .normal:
            props.insert("isNormal")
        case .hot:
            props.insert("isHot")
        }
        
        return props
    }
}
```

## Step 3: Algorithm Optimizations

TemporalKit uses several algorithm optimizations internally, but you can also customize your approach to further improve performance.

### 3.1 Incremental Model Checking

When iteratively developing a system, verify only the parts that have changed.

```swift
// Example: Incremental verification of evolving models
class IncrementalVerifier<M: KripkeStructure> {
    private var modelChecker = LTLModelChecker<M>()
    private var previousResults: [String: ModelCheckResult<M.State>] = [:]
    
    func verify(formula: LTLFormula<ClosureTemporalProposition<M.State, Bool>>, 
                model: M, 
                id: String) throws -> ModelCheckResult<M.State> {
        // Check if model has changed structurally before re-verifying
        if let previousResult = previousResults[id] {
            // In a real implementation, check if the relevant parts 
            // of the model have changed
            let shouldRecompute = true // Replace with actual logic
            
            if !shouldRecompute {
                return previousResult
            }
        }
        
        // Perform full verification
        let result = try modelChecker.check(formula: formula, model: model)
        previousResults[id] = result
        return result
    }
}

// Usage
let incrementalVerifier = IncrementalVerifier<OptimizedCounterModel>()
let model = OptimizedCounterModel(minValue: 0, maxValue: 10)

// Define formula
let isZero = TemporalKit.makeProposition(
    id: "isZero",
    name: "Value is zero",
    evaluate: { (state: Int) -> Bool in state == 0 }
)
let alwaysEventuallyZero = LTLFormula<ClosureTemporalProposition<Int, Bool>>.globally(
    .eventually(.atomic(isZero))
)

// Verify
do {
    let result = try incrementalVerifier.verify(
        formula: alwaysEventuallyZero,
        model: model,
        id: "alwaysEventuallyZero"
    )
    print("Formula holds: \(result.holds)")
} catch {
    print("Verification error: \(error)")
}
```

### 3.2 Partial Order Reduction

For concurrent systems, you can reduce the state space by recognizing that many operation orderings lead to the same result.

```swift
// Example: A model employing partial order reduction concepts
struct ConcurrentSystemWithPOR: KripkeStructure {
    typealias State = (Int, Int)  // Two process states
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State> = [(0, 0)]
    
    init() {
        // Generate all possible states but exclude redundant interleavings
        var states = Set<State>()
        for i in 0...3 {
            for j in 0...3 {
                states.insert((i, j))
            }
        }
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        let (p1, p2) = state
        
        // Independent actions - can move either process
        if p1 < 3 {
            nextStates.insert((p1 + 1, p2))
        }
        
        if p2 < 3 {
            nextStates.insert((p1, p2 + 1))
        }
        
        // For dependent actions, we'd reduce the interleavings
        // This is a simplified example - real POR is more complex
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        let (p1, p2) = state
        
        if p1 == 3 {
            props.insert("p1Finished")
        }
        
        if p2 == 3 {
            props.insert("p2Finished")
        }
        
        return props
    }
}
```

## Step 4: Implementation Optimizations

Let's look at Swift-specific optimizations that can improve the performance of your TemporalKit models.

### 4.1 Efficient Data Structures

Choose appropriate data structures and algorithm implementations.

```swift
// Example: Optimize model checking with better data structures
struct OptimizedLTLModelChecker<M: KripkeStructure> {
    // Use more efficient data structures
    typealias StateSet = Set<M.State>
    
    // Cache for avoiding redundant computations
    private var visitedStates: [M.State: Bool] = [:]
    
    // Simple example of a custom DFS implementation using efficient structures
    func checkFormula(_ formula: LTLFormula<ClosureTemporalProposition<M.State, Bool>>, 
                     in model: M) throws -> Bool {
        // Reset cache
        visitedStates = [:]
        
        // Start verification from initial states
        for initialState in model.initialStates {
            if try !checkState(initialState, formula: formula, model: model) {
                return false
            }
        }
        
        return true
    }
    
    private func checkState(_ state: M.State,
                           formula: LTLFormula<ClosureTemporalProposition<M.State, Bool>>,
                           model: M) throws -> Bool {
        // Check cache first
        if let result = visitedStates[state] {
            return result
        }
        
        // Mark as being visited (to handle cycles)
        visitedStates[state] = true
        
        // Simplified formula evaluation logic
        // In a real implementation, this would be more complex
        let result = true
        
        // Store in cache
        visitedStates[state] = result
        
        return result
    }
}
```

### 4.2 Parallel Processing

Utilize Swift's concurrency features for parallel model checking.

```swift
// Example: Parallel model checking with Swift Concurrency
struct ParallelModelChecker<M: KripkeStructure> {
    // Check multiple formulas concurrently
    func checkAll(formulas: [LTLFormula<ClosureTemporalProposition<M.State, Bool>>], 
                 model: M) async throws -> [Bool] {
        return try await withThrowingTaskGroup(of: (Int, Bool).self) { group in
            // Start tasks for each formula
            for (index, formula) in formulas.enumerated() {
                group.addTask {
                    let checker = LTLModelChecker<M>()
                    let result = try checker.check(formula: formula, model: model)
                    return (index, result.holds)
                }
            }
            
            // Collect results
            var results = Array(repeating: false, count: formulas.count)
            for try await (index, result) in group {
                results[index] = result
            }
            
            return results
        }
    }
}

// Usage example
func verifySystemConcurrently() async {
    let model = OptimizedCounterModel(minValue: 0, maxValue: 10)
    
    // Define propositions
    let isZero = TemporalKit.makeProposition(
        id: "isZero",
        name: "Value is zero",
        evaluate: { (state: Int) -> Bool in state == 0 }
    )
    
    let isPositive = TemporalKit.makeProposition(
        id: "isPositive",
        name: "Value is positive",
        evaluate: { (state: Int) -> Bool in state > 0 }
    )
    
    // Define formulas to check
    let formulas = [
        LTLFormula<ClosureTemporalProposition<Int, Bool>>.globally(.eventually(.atomic(isZero))),
        LTLFormula<ClosureTemporalProposition<Int, Bool>>.globally(.implies(
            .atomic(isPositive),
            .eventually(.atomic(isZero))
        ))
    ]
    
    // Verify concurrently
    do {
        let checker = ParallelModelChecker<OptimizedCounterModel>()
        let results = try await checker.checkAll(formulas: formulas, model: model)
        
        for (index, result) in results.enumerated() {
            print("Formula \(index + 1) holds: \(result)")
        }
    } catch {
        print("Verification error: \(error)")
    }
}
```

## Step 5: Memory Optimizations

Memory usage is often a bottleneck in model checking. Here are some techniques to optimize memory usage.

### 5.1 State Compression

Compress states to reduce memory usage.

```swift
// Example: Compressing states to reduce memory footprint
struct CompressedState: Hashable {
    // Bit-packed representation
    private let packedValue: UInt64
    
    init(values: [Bool]) {
        var packed: UInt64 = 0
        
        // Pack Boolean values into bits
        for (index, value) in values.prefix(64).enumerated() {
            if value {
                packed |= (1 << index)
            }
        }
        
        self.packedValue = packed
    }
    
    // Access individual bits
    func value(at index: Int) -> Bool {
        guard index < 64 else { return false }
        return (packedValue & (1 << index)) != 0
    }
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(packedValue)
    }
    
    static func == (lhs: CompressedState, rhs: CompressedState) -> Bool {
        return lhs.packedValue == rhs.packedValue
    }
}

// Usage in model
struct CompressedStateModel: KripkeStructure {
    typealias State = CompressedState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init() {
        // Example initialization
        self.initialStates = [CompressedState(values: [false, false, false])]
        
        // In a real implementation, this would compute all states
        self.allStates = [
            CompressedState(values: [false, false, false]),
            CompressedState(values: [true, false, false]),
            CompressedState(values: [false, true, false]),
            CompressedState(values: [false, false, true])
        ]
    }
    
    func successors(of state: State) -> Set<State> {
        // Simple example logic
        if state.value(at: 0) && state.value(at: 1) && state.value(at: 2) {
            return [] // Terminal state
        }
        
        // In a real implementation, this would compute actual successors
        return allStates.filter { $0 != state }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        if state.value(at: 0) {
            props.insert("prop1")
        }
        
        if state.value(at: 1) {
            props.insert("prop2")
        }
        
        if state.value(at: 2) {
            props.insert("prop3")
        }
        
        return props
    }
}
```

### 5.2 On-the-fly Model Checking

Generate states as needed rather than storing the entire state space.

```swift
// Example: On-the-fly model checking
struct OnTheFlyModelChecker<M: KripkeStructure> {
    func check(formula: LTLFormula<ClosureTemporalProposition<M.State, Bool>>,
              model: M) throws -> Bool {
        // Set to track visited states (instead of precomputing all states)
        var visitedStates = Set<M.State>()
        
        // Queue for breadth-first exploration
        var queue = Array(model.initialStates)
        
        while !queue.isEmpty {
            let state = queue.removeFirst()
            
            if visitedStates.contains(state) {
                continue
            }
            
            visitedStates.insert(state)
            
            // Evaluate formula on this state
            // This is simplified; actual evaluation would be more complex
            let context = makeEvaluationContext(for: state)
            // if formula doesn't hold, return false
            
            // Enqueue successors
            let successors = model.successors(of: state)
            for successor in successors {
                if !visitedStates.contains(successor) {
                    queue.append(successor)
                }
            }
        }
        
        return true
    }
    
    private func makeEvaluationContext(for state: M.State) -> EvaluationContext {
        // Create an appropriate evaluation context for the state
        // This is just a placeholder for the real implementation
        return DummyEvaluationContext()
    }
}

// Dummy implementation for example purposes
class DummyEvaluationContext: EvaluationContext {
    func currentStateAs<T>(_ type: T.Type) -> T? {
        return nil
    }
}
```

## Step 6: Measuring Performance

It's important to measure and profile your model checking performance.

```swift
// Example: Performance measurement utilities
struct PerformanceMeasurement {
    static func measure<T>(name: String, closure: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try closure()
        let end = Date()
        
        let timeInterval = end.timeIntervalSince(start)
        print("\(name) took \(timeInterval) seconds")
        
        return result
    }
    
    static func comparePerformance<M1: KripkeStructure, M2: KripkeStructure>(
        name: String,
        formula: LTLFormula<ClosureTemporalProposition<M1.State, Bool>>,
        model1: M1,
        model2: M2,
        converter: (LTLFormula<ClosureTemporalProposition<M1.State, Bool>>) -> LTLFormula<ClosureTemporalProposition<M2.State, Bool>>
    ) throws {
        let checker1 = LTLModelChecker<M1>()
        let checker2 = LTLModelChecker<M2>()
        
        let formula2 = converter(formula)
        
        print("Comparing performance for: \(name)")
        
        try measure(name: "Model 1") {
            let result = try checker1.check(formula: formula, model: model1)
            print("Result 1: \(result.holds)")
        }
        
        try measure(name: "Model 2") {
            let result = try checker2.check(formula: formula2, model: model2)
            print("Result 2: \(result.holds)")
        }
    }
}

// Usage example
func compareModelPerformance() throws {
    let model1 = OptimizedCounterModel(minValue: 0, maxValue: 10)
    let model2 = OptimizedCounterModel(minValue: 0, maxValue: 10)
    
    let isZero1 = TemporalKit.makeProposition(
        id: "isZero",
        name: "Value is zero",
        evaluate: { (state: Int) -> Bool in state == 0 }
    )
    
    let alwaysEventuallyZero1 = LTLFormula<ClosureTemporalProposition<Int, Bool>>.globally(
        .eventually(.atomic(isZero1))
    )
    
    // Simple converter that passes through (since models are the same type in this example)
    let converter: (LTLFormula<ClosureTemporalProposition<Int, Bool>>) -> LTLFormula<ClosureTemporalProposition<Int, Bool>> = { formula in
        return formula
    }
    
    try PerformanceMeasurement.comparePerformance(
        name: "Always Eventually Zero",
        formula: alwaysEventuallyZero1,
        model1: model1,
        model2: model2,
        converter: converter
    )
}
```

## Summary

In this tutorial, you learned techniques for optimizing performance when model checking with TemporalKit:

1. Understanding and addressing state space explosion problems
2. Applying state reduction techniques like limiting to reachable states, leveraging symmetry, and using abstraction
3. Using algorithm optimizations like incremental model checking and partial order reduction
4. Implementing Swift-specific optimizations with efficient data structures and parallel processing
5. Optimizing memory usage with state compression and on-the-fly model checking
6. Measuring and comparing performance of different approaches

These techniques will help you apply TemporalKit effectively to larger, more complex systems while maintaining reasonable verification times and memory usage.

## Next Steps

- Apply these optimization techniques to your own models
- Explore [Concurrent System Verification](./ConcurrentSystemVerification.md) for more specific techniques for concurrent systems
- Learn about handling [Debugging Counterexamples](./DebuggingCounterexamples.md) for large systems 
