# TemporalKit API Reference

This document describes the main APIs of TemporalKit. TemporalKit is a Swift library for formal verification, specifically for verifying system behavior using Linear Temporal Logic (LTL).

## Core Components

### LTLFormula

A type for representing LTL (Linear Temporal Logic) formulas.

```swift
public indirect enum LTLFormula<P: TemporalProposition>: Hashable where P.Value == Bool {
    case booleanLiteral(Bool)
    case atomic(P)
    case not(LTLFormula<P>)
    case and(LTLFormula<P>, LTLFormula<P>)
    case or(LTLFormula<P>, LTLFormula<P>)
    case implies(LTLFormula<P>, LTLFormula<P>)
    
    case next(LTLFormula<P>)
    case eventually(LTLFormula<P>)
    case globally(LTLFormula<P>)
    
    case until(LTLFormula<P>, LTLFormula<P>)
    case weakUntil(LTLFormula<P>, LTLFormula<P>)
    case release(LTLFormula<P>, LTLFormula<P>)
}
```

#### Main Methods

- `normalized()` - Normalizes the formula
- `toNNF()` - Converts the formula to Negation Normal Form (NNF)
- `containsEventually()` - Returns whether the formula contains the "eventually" operator
- `containsGlobally()` - Returns whether the formula contains the "globally" operator
- `containsNext()` - Returns whether the formula contains the "next" operator
- `containsUntil()` - Returns whether the formula contains the "until" operator

#### DSL Operators

- `X(φ)` - "Next" operator
- `F(φ)` - "Eventually" operator
- `G(φ)` - "Globally" operator
- `φ ~>> ψ` - "Until" operator
- `φ ~~> ψ` - "Weak Until" operator
- `φ ~< ψ` - "Release" operator
- `φ ==> ψ` - Implication operator
- `φ && ψ` - Logical AND operator
- `φ || ψ` - Logical OR operator

### KripkeStructure

A protocol for representing a state transition model of a system.

```swift
public protocol KripkeStructure {
    associatedtype State: Hashable
    associatedtype AtomicPropositionIdentifier: Hashable

    var allStates: Set<State> { get }
    var initialStates: Set<State> { get }

    func successors(of state: State) -> Set<State>
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier>
}
```

#### Required Implementations

- `allStates` - The set of all states in the model
- `initialStates` - The set of initial states of the model
- `successors(of:)` - Returns the set of states that can be reached from the specified state
- `atomicPropositionsTrue(in:)` - Returns the set of atomic proposition IDs that are true in the specified state

### TemporalProposition

A protocol for representing propositions that can be evaluated against states.

```swift
public protocol TemporalProposition: Hashable {
    associatedtype Input
    associatedtype Value
    associatedtype ID: Hashable
    
    var id: ID { get }
    var name: String { get }
    
    func evaluate(with context: some EvaluationContext<Input>) throws -> Value
}
```

#### Required Implementations

- `id` - A unique identifier for the proposition
- `name` - A descriptive name for the proposition
- `evaluate(with:)` - Evaluates the proposition against an evaluation context

### LTLModelChecker

A class for checking LTL formulas against Kripke structures.

```swift
public class LTLModelChecker<Model: KripkeStructure> {
    public init()
    
    public func check<P: TemporalProposition>(
        formula: LTLFormula<P>, 
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool
}
```

#### Main Methods

- `check(formula:model:)` - Verifies whether the specified LTL formula holds on the given model

### ModelCheckResult

An enumeration representing the result of model checking.

```swift
public enum ModelCheckResult<State: Hashable> {
    case holds
    case fails(counterexample: Counterexample<State>)
}
```

- `holds` - The formula holds on the model
- `fails(counterexample:)` - The formula does not hold on the model, and a counterexample is provided

### Counterexample

A structure representing a counterexample for when a formula doesn't hold during model checking.

```swift
public struct Counterexample<State: Hashable> {
    public let prefix: [State]
    public let cycle: [State]
    
    public init(prefix: [State], cycle: [State])
}
```

- `prefix` - The prefix part of the counterexample (a finite path from the initial state to the cycle)
- `cycle` - The cycle part of the counterexample (a part that repeats infinitely)

## Helper Classes and Functions

### ClosureTemporalProposition

A helper type for easily creating propositions using closures.

```swift
public struct ClosureTemporalProposition<Input, Output>: TemporalProposition where Output == Bool {
    public typealias ID = PropositionID
    public typealias EvaluationClosure = (Input) throws -> Output
    
    public let id: ID
    public let name: String
    private let evaluationClosure: EvaluationClosure
    
    public init(id: ID, name: String, evaluationClosure: @escaping EvaluationClosure)
}
```

### makeProposition

A helper function for easily creating propositions.

```swift
public func makeProposition<Input>(
    id: String,
    name: String,
    evaluate: @escaping (Input) -> Bool
) -> ClosureTemporalProposition<Input, Bool>
```

### EvaluationContext

A protocol for providing context needed for proposition evaluation.

```swift
public protocol EvaluationContext<Input> {
    associatedtype Input
    
    var input: Input { get }
    var traceIndex: Int? { get }
}
```

## Trace Evaluation

### LTLFormulaTraceEvaluator

A class for evaluating LTL formulas against finite traces.

```swift
public class LTLFormulaTraceEvaluator<P: TemporalProposition> where P.Value == Bool {
    public init()
    
    public func evaluate<S, C: EvaluationContext>(
        formula: LTLFormula<P>,
        trace: [S],
        contextProvider: (S, Int) -> C
    ) throws -> Bool
}
```

#### Main Methods

- `evaluate(formula:trace:contextProvider:)` - Evaluates whether the specified LTL formula holds on the given trace

## Error Types

### TemporalKitError

An enumeration representing possible errors in the TemporalKit library.

```swift
public enum TemporalKitError: Error, LocalizedError {
    case invalidFormula(String)
    case evaluationFailed(String)
    case invalidTraceEvaluation(String)
    case incompatibleTypes(String)
    case unsupportedOperation(String)
}
```

### LTLModelCheckerError

An enumeration representing possible errors during model checking.

```swift
public enum LTLModelCheckerError: Error, LocalizedError {
    case algorithmsNotImplemented(String)
    case internalProcessingError(String)
}
```

## Usage Example

```swift
// Define states
enum SystemState: Hashable {
    case s0, s1, s2
}

// Define system model
struct MySystemModel: KripkeStructure {
    typealias State = SystemState
    typealias AtomicPropositionIdentifier = String
    
    let allStates: Set<State> = [.s0, .s1, .s2]
    let initialStates: Set<State> = [.s0]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .s0: return [.s1]
        case .s1: return [.s2]
        case .s2: return [.s0]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .s0: return ["isInitial"]
        case .s1: return ["isProcessing"]
        case .s2: return ["isCompleted"]
        }
    }
}

// Define propositions
let initialProp = makeProposition(
    id: "isInitial",
    name: "Is in initial state",
    evaluate: { (state: SystemState) -> Bool in
        return state == .s0
    }
)

let processingProp = makeProposition(
    id: "isProcessing",
    name: "Is in processing state",
    evaluate: { (state: SystemState) -> Bool in
        return state == .s1
    }
)

let completedProp = makeProposition(
    id: "isCompleted",
    name: "Is in completed state",
    evaluate: { (state: SystemState) -> Bool in
        return state == .s2
    }
)

// Create LTL formula
// "Whenever the system is in the initial state, 
// it will eventually reach the completed state"
let formula = G(.implies(
    .atomic(initialProp),
    F(.atomic(completedProp))
))

// Create model checker
let modelChecker = LTLModelChecker<MySystemModel>()

// Check the formula
let model = MySystemModel()
let result = try modelChecker.check(formula: formula, model: model)

// Process the result
switch result {
case .holds:
    print("The formula holds on the model.")
case .fails(let counterexample):
    print("The formula does not hold on the model.")
    print("Counterexample prefix: \(counterexample.prefix)")
    print("Counterexample cycle: \(counterexample.cycle)")
}
```

## Additional APIs

### LTLFormula Extensions

```swift
extension LTLFormula {
    // Creates a formula that is always true
    public static var trueFormula: LTLFormula<P>
    
    // Creates a formula that is always false
    public static var falseFormula: LTLFormula<P>
    
    // Negates a formula
    public static prefix func ! (formula: LTLFormula<P>) -> LTLFormula<P>
    
    // Simplifies a formula
    public func simplified() -> LTLFormula<P>
    
    // Gets all atomic propositions in a formula
    public var atomicPropositions: Set<P>
}
```

### ModelChecking Algorithms

```swift
public enum ModelCheckingAlgorithm {
    case tableau
    case automaton
    case onTheFly
    case optimized
}

extension LTLModelChecker {
    // Creates a model checker with a specific algorithm
    public init(algorithm: ModelCheckingAlgorithm)
}
```

### Proposition Combinators

```swift
// Combine two propositions with AND
public func and<Input, P1, P2>(_ p1: P1, _ p2: P2) -> ClosureTemporalProposition<Input, Bool>
    where P1: TemporalProposition, P2: TemporalProposition, 
          P1.Input == Input, P2.Input == Input, 
          P1.Value == Bool, P2.Value == Bool

// Combine two propositions with OR
public func or<Input, P1, P2>(_ p1: P1, _ p2: P2) -> ClosureTemporalProposition<Input, Bool>
    where P1: TemporalProposition, P2: TemporalProposition, 
          P1.Input == Input, P2.Input == Input, 
          P1.Value == Bool, P2.Value == Bool

// Negate a proposition
public func not<Input, P>(_ p: P) -> ClosureTemporalProposition<Input, Bool>
    where P: TemporalProposition, 
          P.Input == Input, 
          P.Value == Bool
```

For more detailed information on each API and advanced usage examples, see the [TemporalKit GitHub repository](https://github.com/example/TemporalKit) and the in-code documentation. 
