# Integrating with Tests

This tutorial teaches you how to integrate TemporalKit's temporal logic verification with Swift's testing frameworks. By incorporating TemporalKit into your unit and integration tests, you can create more powerful and expressive assertions.

## Objectives

By the end of this tutorial, you will be able to:

- Combine XCTest and TemporalKit to create temporal logic tests
- Apply model checking techniques for test data generation
- Incorporate TemporalKit verification into CI/CD pipelines
- Implement property-based testing using temporal verification

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts
- Basic knowledge of XCTest

## Step 1: Setting Up the Test Environment

First, let's set up a test environment that uses TemporalKit.

```swift
import XCTest
import TemporalKit

// System under test
struct CounterSystem {
    var count: Int = 0
    
    mutating func increment() {
        count += 1
    }
    
    mutating func decrement() {
        count -= 1
    }
    
    mutating func reset() {
        count = 0
    }
}

// Test case class
class TemporalLogicTests: XCTestCase {
    // We'll add test methods shortly
}
```

## Step 2: Creating Basic Temporal Assertions

Let's show how to integrate temporal logic assertions with XCTest.

```swift
extension TemporalLogicTests {
    
    // Test simple trace evaluation
    func testSimpleTraceEvaluation() {
        // Trace of states to test (array of states)
        let trace: [Int] = [0, 1, 2, 3, 2, 1, 0]
        
        // Proposition: "Value is non-negative"
        let isNonNegative = TemporalKit.makeProposition(
            id: "isNonNegative",
            name: "Value is non-negative",
            evaluate: { (state: Int) -> Bool in state >= 0 }
        )
        
        // Proposition: "Value is even"
        let isEven = TemporalKit.makeProposition(
            id: "isEven",
            name: "Value is even",
            evaluate: { (state: Int) -> Bool in state % 2 == 0 }
        )
        
        // LTL formula: "Always non-negative value"
        let alwaysNonNegative = LTLFormula<ClosureTemporalProposition<Int, Bool>>.globally(
            .atomic(isNonNegative)
        )
        
        // LTL formula: "Eventually an even value occurs"
        let eventuallyEven = LTLFormula<ClosureTemporalProposition<Int, Bool>>.eventually(
            .atomic(isEven)
        )
        
        // Evaluation context provider
        let contextProvider: (Int, Int) -> EvaluationContext = { (state, index) in
            return SimpleEvaluationContext(state: state, traceIndex: index)
        }
        
        // Create trace evaluator
        let evaluator = LTLFormulaTraceEvaluator()
        
        do {
            // Evaluate formulas
            let result1 = try evaluator.evaluate(formula: alwaysNonNegative, trace: trace, contextProvider: contextProvider)
            let result2 = try evaluator.evaluate(formula: eventuallyEven, trace: trace, contextProvider: contextProvider)
            
            // Assert results
            XCTAssertTrue(result1, "All values in the trace should be non-negative")
            XCTAssertTrue(result2, "At least one even value should exist in the trace")
            
        } catch {
            XCTFail("Error during evaluation: \(error)")
        }
    }
    
    // Simple evaluation context
    class SimpleEvaluationContext: EvaluationContext {
        let state: Int
        let traceIndex: Int?
        
        init(state: Int, traceIndex: Int? = nil) {
            self.state = state
            self.traceIndex = traceIndex
        }
        
        func currentStateAs<T>(_ type: T.Type) -> T? {
            return state as? T
        }
    }
}
```

## Step 3: Creating Custom Temporal XCT Assertion Functions

Let's create helper functions for commonly used temporal logic assertions.

```swift
// XCTest extensions for temporal logic testing
extension XCTestCase {
    
    // Assert that a trace satisfies an LTL formula
    func XCTAssertTemporalFormula<S, P: TemporalProposition>(
        _ formula: LTLFormula<P>,
        satisfiedBy trace: [S],
        contextProvider: @escaping (S, Int) -> EvaluationContext,
        message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) where P.Value == Bool {
        let evaluator = LTLFormulaTraceEvaluator()
        
        do {
            let result = try evaluator.evaluate(formula: formula, trace: trace, contextProvider: contextProvider)
            XCTAssertTrue(result, message, file: file, line: line)
        } catch {
            XCTFail("Failed to evaluate temporal formula: \(error)", file: file, line: line)
        }
    }
    
    // Assert that a model satisfies an LTL formula
    func XCTAssertModelSatisfies<M: KripkeStructure, P: TemporalProposition>(
        _ formula: LTLFormula<P>,
        model: M,
        message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) where P.Value == Bool {
        let modelChecker = LTLModelChecker<M>()
        
        do {
            let result = try modelChecker.check(formula: formula, model: model)
            
            if !result.holds {
                if case .fails(let counterexample) = result {
                    XCTFail("""
                        Model does not satisfy LTL formula.
                        \(message)
                        Counterexample:
                          Prefix: \(counterexample.prefix.map { "\($0)" }.joined(separator: " -> "))
                          Cycle: \(counterexample.cycle.map { "\($0)" }.joined(separator: " -> "))
                        """, file: file, line: line)
                } else {
                    XCTFail("Model does not satisfy LTL formula. \(message)", file: file, line: line)
                }
            }
        } catch {
            XCTFail("Error during model checking: \(error)", file: file, line: line)
        }
    }
}
```

## Step 4: Testing a Counter System

Let's test the counter system using our custom assertions.

```swift
extension TemporalLogicTests {
    
    func testCounterSystem() {
        // Initialize counter system
        var counter = CounterSystem()
        
        // Sequence of operations
        let operations = [
            { counter.reset() },
            { counter.increment() },
            { counter.increment() },
            { counter.decrement() },
            { counter.reset() }
        ]
        
        // Record states before and after each operation
        var stateTrace: [Int] = [counter.count]
        
        for operation in operations {
            operation()
            stateTrace.append(counter.count)
        }
        
        // Define propositions
        let isZero = TemporalKit.makeProposition(
            id: "isZero",
            name: "Counter is zero",
            evaluate: { (state: Int) -> Bool in state == 0 }
        )
        
        let isPositive = TemporalKit.makeProposition(
            id: "isPositive",
            name: "Counter is positive",
            evaluate: { (state: Int) -> Bool in state > 0 }
        )
        
        // LTL formula: "After reset, counter is always zero"
        // Note: Since we're evaluating state traces, not operation traces,
        // we're focusing on state change patterns rather than operations
        
        let zeroAfterReset = LTLFormula<ClosureTemporalProposition<Int, Bool>>.globally(
            .implies(
                .atomic(isZero),
                .next(
                    .or(
                        .atomic(isZero),
                        .atomic(isPositive)
                    )
                )
            )
        )
        
        // Evaluation context provider
        let contextProvider: (Int, Int) -> EvaluationContext = { (state, index) in
            return SimpleEvaluationContext(state: state, traceIndex: index)
        }
        
        // Use custom assertion
        XCTAssertTemporalFormula(
            zeroAfterReset,
            satisfiedBy: stateTrace,
            contextProvider: contextProvider,
            message: "After initial state or reset, next state should be zero or positive"
        )
    }
}
```

## Step 5: Model-Based Testing Using Kripke Structures

Let's model the counter system as a Kripke structure for more comprehensive testing.

```swift
// Counter system Kripke structure model
struct CounterModel: KripkeStructure {
    typealias State = Int
    typealias AtomicPropositionIdentifier = PropositionID
    
    // Set model constraints (e.g., limit counter values from -5 to 5)
    let minValue: Int
    let maxValue: Int
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init(minValue: Int = -5, maxValue: Int = 5, initialValue: Int = 0) {
        self.minValue = minValue
        self.maxValue = maxValue
        
        // Calculate all possible states
        self.allStates = Set(minValue...maxValue)
        self.initialStates = [initialValue]
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Increment operation
        if state + 1 <= maxValue {
            nextStates.insert(state + 1)
        }
        
        // Decrement operation
        if state - 1 >= minValue {
            nextStates.insert(state - 1)
        }
        
        // Reset operation
        nextStates.insert(0)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // Propositions about counter state
        if state == 0 {
            trueProps.insert(isZero.id)
        }
        
        if state > 0 {
            trueProps.insert(isPositive.id)
        }
        
        if state < 0 {
            trueProps.insert(isNegative.id)
        }
        
        if state % 2 == 0 {
            trueProps.insert(isEven.id)
        } else {
            trueProps.insert(isOdd.id)
        }
        
        if state == minValue {
            trueProps.insert(isAtMinValue.id)
        }
        
        if state == maxValue {
            trueProps.insert(isAtMaxValue.id)
        }
        
        return trueProps
    }
}

// Counter system propositions
let isZero = TemporalKit.makeProposition(
    id: "isZero",
    name: "Counter is zero",
    evaluate: { (state: Int) -> Bool in state == 0 }
)

let isPositive = TemporalKit.makeProposition(
    id: "isPositive",
    name: "Counter is positive",
    evaluate: { (state: Int) -> Bool in state > 0 }
)

let isNegative = TemporalKit.makeProposition(
    id: "isNegative",
    name: "Counter is negative",
    evaluate: { (state: Int) -> Bool in state < 0 }
)

let isEven = TemporalKit.makeProposition(
    id: "isEven",
    name: "Counter is even",
    evaluate: { (state: Int) -> Bool in state % 2 == 0 }
)

let isOdd = TemporalKit.makeProposition(
    id: "isOdd",
    name: "Counter is odd",
    evaluate: { (state: Int) -> Bool in state % 2 != 0 }
)

let isAtMinValue = TemporalKit.makeProposition(
    id: "isAtMinValue",
    name: "Counter is at minimum value",
    evaluate: { (state: Int) -> Bool in state == -5 } // Using direct value for simplicity
)

let isAtMaxValue = TemporalKit.makeProposition(
    id: "isAtMaxValue",
    name: "Counter is at maximum value",
    evaluate: { (state: Int) -> Bool in state == 5 } // Using direct value for simplicity
)
```

## Step 6: Implementing Model-Based Test Cases

Let's implement test cases using the counter model.

```swift
extension TemporalLogicTests {
    
    // Test counter model properties
    func testCounterModelProperties() {
        let model = CounterModel()
        
        // Type aliases (for readability)
        typealias CounterProp = ClosureTemporalProposition<Int, Bool>
        typealias CounterLTL = LTLFormula<CounterProp>
        
        // Property 1: "When at max value, the next state is either 0 or max value - 1"
        let maxValueTransitions = CounterLTL.globally(
            .implies(
                .atomic(isAtMaxValue),
                .next(
                    .or(
                        .atomic(isZero),
                        .atomic(TemporalKit.makeProposition(
                            id: "isMaxValueMinus1",
                            name: "Counter is max value minus 1",
                            evaluate: { (state: Int) -> Bool in state == 4 }
                        ))
                    )
                )
            )
        )
        
        // Property 2: "Starting from 0, we always eventually return to 0"
        let alwaysEventuallyZero = CounterLTL.globally(
            .eventually(.atomic(isZero))
        )
        
        // Property 3: "From any state, we can eventually reach an even state"
        let eventuallyEven = CounterLTL.globally(
            .eventually(.atomic(isEven))
        )
        
        // Property 4: "From any state, we can eventually reach a positive state"
        let eventuallyPositive = CounterLTL.globally(
            .eventually(.atomic(isPositive))
        )
        
        // Test using custom assertions
        XCTAssertModelSatisfies(
            maxValueTransitions,
            model: model,
            message: "Transitions from max value should be to either 0 or max value - 1"
        )
        
        XCTAssertModelSatisfies(
            alwaysEventuallyZero,
            model: model,
            message: "Should always eventually return to 0 from any state"
        )
        
        XCTAssertModelSatisfies(
            eventuallyEven,
            model: model,
            message: "Should be able to reach an even state from any state"
        )
        
        XCTAssertModelSatisfies(
            eventuallyPositive,
            model: model,
            message: "Should be able to reach a positive state from any state"
        )
    }
}
```

## Step 7: Integration with More Complex Systems

Let's show how to apply these techniques to a more complex system such as a simple workflow engine.

```swift
// Workflow states
enum WorkflowState: Hashable, CustomStringConvertible {
    case idle
    case started
    case validating
    case processing
    case completed
    case cancelled
    case error(reason: String)
    
    var description: String {
        switch self {
        case .idle: return "idle"
        case .started: return "started"
        case .validating: return "validating"
        case .processing: return "processing"
        case .completed: return "completed"
        case .cancelled: return "cancelled"
        case let .error(reason): return "error(\(reason))"
        }
    }
    
    // For Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .idle: hasher.combine(0)
        case .started: hasher.combine(1)
        case .validating: hasher.combine(2)
        case .processing: hasher.combine(3)
        case .completed: hasher.combine(4)
        case .cancelled: hasher.combine(5)
        case let .error(reason): 
            hasher.combine(6)
            hasher.combine(reason)
        }
    }
}

// Workflow system Kripke structure
struct WorkflowModel: KripkeStructure {
    typealias State = WorkflowState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init() {
        // Generate all possible states
        var states = Set<State>()
        states.insert(.idle)
        states.insert(.started)
        states.insert(.validating)
        states.insert(.processing)
        states.insert(.completed)
        states.insert(.cancelled)
        states.insert(.error(reason: "validation failed"))
        states.insert(.error(reason: "processing failed"))
        
        self.allStates = states
        self.initialStates = [.idle]
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        switch state {
        case .idle:
            // Can only start from idle
            nextStates.insert(.started)
            
            // Can remain idle
            nextStates.insert(.idle)
            
        case .started:
            // After starting, move to validation
            nextStates.insert(.validating)
            
            // Can cancel anytime after starting
            nextStates.insert(.cancelled)
            
        case .validating:
            // Can complete validation and move to processing
            nextStates.insert(.processing)
            
            // Can fail validation
            nextStates.insert(.error(reason: "validation failed"))
            
            // Can cancel during validation
            nextStates.insert(.cancelled)
            
        case .processing:
            // Can complete processing
            nextStates.insert(.completed)
            
            // Can fail processing
            nextStates.insert(.error(reason: "processing failed"))
            
            // Can cancel during processing
            nextStates.insert(.cancelled)
            
        case .completed, .cancelled:
            // Terminal states, can only restart
            nextStates.insert(.idle)
            
        case .error:
            // From error state, can restart or cancel
            nextStates.insert(.idle)
            nextStates.insert(.cancelled)
        }
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .idle:
            props.insert("isIdle")
        case .started:
            props.insert("isStarted")
        case .validating:
            props.insert("isValidating")
        case .processing:
            props.insert("isProcessing")
        case .completed:
            props.insert("isCompleted")
        case .cancelled:
            props.insert("isCancelled")
        case .error:
            props.insert("isError")
            
            // Add specific error reason
            if case let .error(reason) = state {
                if reason == "validation failed" {
                    props.insert("isValidationError")
                } else if reason == "processing failed" {
                    props.insert("isProcessingError")
                }
            }
        }
        
        // Terminal state group
        if case .completed = state || case .cancelled = state || case .error = state {
            props.insert("isTerminal")
        }
        
        // Active state group
        if case .started = state || case .validating = state || case .processing = state {
            props.insert("isActive")
        }
        
        return props
    }
}

// Test workflow model properties
extension TemporalLogicTests {
    
    func testWorkflowProperties() {
        let model = WorkflowModel()
        
        // Type alias for readability
        typealias WorkflowLTL = LTLFormula<ClosureTemporalProposition<WorkflowState, Bool>>
        
        // Helper function to create workflow propositions
        func makeWorkflowProp(id: String, name: String, predicate: @escaping (WorkflowState) -> Bool) -> ClosureTemporalProposition<WorkflowState, Bool> {
            return TemporalKit.makeProposition(id: id, name: name, evaluate: predicate)
        }
        
        // Define propositions
        let isIdle = makeWorkflowProp(
            id: "isIdle",
            name: "Workflow is idle",
            predicate: { $0 == .idle }
        )
        
        let isStarted = makeWorkflowProp(
            id: "isStarted",
            name: "Workflow is started",
            predicate: { $0 == .started }
        )
        
        let isCompleted = makeWorkflowProp(
            id: "isCompleted",
            name: "Workflow is completed",
            predicate: { $0 == .completed }
        )
        
        let isError = makeWorkflowProp(
            id: "isError",
            name: "Workflow is in error state",
            predicate: { 
                if case .error = $0 {
                    return true
                }
                return false
            }
        )
        
        let isTerminal = makeWorkflowProp(
            id: "isTerminal",
            name: "Workflow is in a terminal state",
            predicate: {
                switch $0 {
                case .completed, .cancelled, .error: return true
                default: return false
                }
            }
        )
        
        // Define LTL properties to verify
        
        // Property 1: "A workflow that starts will eventually reach a terminal state"
        let eventuallyTerminates = WorkflowLTL.globally(
            .implies(
                .atomic(isStarted),
                .eventually(.atomic(isTerminal))
            )
        )
        
        // Property 2: "From any state, we can eventually get back to idle"
        let canRestart = WorkflowLTL.globally(
            .eventually(.atomic(isIdle))
        )
        
        // Property 3: "A completed workflow must have gone through the started state"
        // Note: This requires handling past states which is challenging with pure LTL
        // For this example, we'll verify a related property using Until
        let completionRequiresStart = WorkflowLTL.globally(
            .implies(
                .atomic(isIdle),
                .not(.atomic(isCompleted)).until(.atomic(isStarted))
            )
        )
        
        // Verify properties
        XCTAssertModelSatisfies(
            eventuallyTerminates,
            model: model,
            message: "Workflows that start should eventually terminate"
        )
        
        XCTAssertModelSatisfies(
            canRestart,
            model: model,
            message: "From any state, the workflow should be able to get back to idle"
        )
        
        XCTAssertModelSatisfies(
            completionRequiresStart,
            model: model,
            message: "A workflow cannot be completed without going through started state"
        )
    }
}
```

## Step 8: Integration with CI/CD Pipelines

Here's how to integrate TemporalKit verification into your continuous integration workflows.

```swift
// Command-line test runner
class TemporalVerificationRunner {
    static func runAllTests() -> Bool {
        // Setup
        print("Running temporal verification tests...")
        var allTestsPass = true
        
        // Define models to verify
        let counterModel = CounterModel()
        let workflowModel = WorkflowModel()
        
        // Define critical properties to verify
        let counterProperties: [(String, LTLFormula<ClosureTemporalProposition<Int, Bool>>)] = [
            ("Counter always eventually returns to zero", LTLFormula.globally(.eventually(.atomic(isZero)))),
            ("Counter can always reach positive values", LTLFormula.globally(.eventually(.atomic(isPositive))))
        ]
        
        let workflowProperties: [(String, LTLFormula<ClosureTemporalProposition<WorkflowState, Bool>>)] = [
            ("Workflows always terminate", LTLFormula.globally(.implies(
                .atomic(TemporalKit.makeProposition(
                    id: "isStarted",
                    name: "Started",
                    evaluate: { $0 == .started }
                )),
                .eventually(.atomic(TemporalKit.makeProposition(
                    id: "isTerminal",
                    name: "Terminal state",
                    evaluate: {
                        switch $0 {
                        case .completed, .cancelled, .error: return true
                        default: return false
                        }
                    }
                )))
            )))
        ]
        
        // Create model checkers
        let counterChecker = LTLModelChecker<CounterModel>()
        let workflowChecker = LTLModelChecker<WorkflowModel>()
        
        // Verify counter properties
        print("\nVerifying counter model...")
        for (name, formula) in counterProperties {
            do {
                let result = try counterChecker.check(formula: formula, model: counterModel)
                if result.holds {
                    print("✅ \(name): PASS")
                } else {
                    print("❌ \(name): FAIL")
                    if case .fails(let counterexample) = result {
                        print("   Counterexample: \(counterexample)")
                    }
                    allTestsPass = false
                }
            } catch {
                print("⚠️ \(name): ERROR - \(error)")
                allTestsPass = false
            }
        }
        
        // Verify workflow properties
        print("\nVerifying workflow model...")
        for (name, formula) in workflowProperties {
            do {
                let result = try workflowChecker.check(formula: formula, model: workflowModel)
                if result.holds {
                    print("✅ \(name): PASS")
                } else {
                    print("❌ \(name): FAIL")
                    if case .fails(let counterexample) = result {
                        print("   Counterexample: \(counterexample)")
                    }
                    allTestsPass = false
                }
            } catch {
                print("⚠️ \(name): ERROR - \(error)")
                allTestsPass = false
            }
        }
        
        // Summary
        print("\nVerification summary: \(allTestsPass ? "ALL TESTS PASS" : "TESTS FAILED")")
        return allTestsPass
    }
}

// Example implementation for command-line usage
func runVerificationInCIPipeline() {
    let success = TemporalVerificationRunner.runAllTests()
    if !success {
        print("Verification failed - CI pipeline should fail")
        // In a real CI script, you'd exit with a non-zero status code
    } else {
        print("Verification succeeded - CI pipeline can continue")
    }
}
```

## Summary

In this tutorial, you learned how to integrate temporal logic verification with Swift's testing frameworks. Specifically, you:

1. Set up a testing environment that incorporates TemporalKit
2. Created custom XCTest assertions for temporal properties
3. Implemented trace-based temporal testing for a simple counter system
4. Modeled systems as Kripke structures for comprehensive verification
5. Tested complex workflow systems using LTL formulas
6. Created a framework for integrating verification into CI/CD pipelines

By combining traditional testing with formal verification, you can significantly increase the reliability of your systems by ensuring they behave correctly not just for specific inputs but for all possible behaviors.

## Next Steps

- Apply these testing techniques to your own iOS applications
- Explore [Advanced LTL Formulas](./AdvancedLTLFormulas.md) to express more complex properties
- Learn about [Optimizing Performance](./OptimizingPerformance.md) for verifying larger models
- Integrate with [Swift Testing](https://github.com/apple/swift-testing) as an alternative to XCTest 
