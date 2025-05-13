# Simple Model Checking

This tutorial teaches you how to perform model checking on a simple system using TemporalKit.

## Objectives

By the end of this tutorial, you will be able to:

- Model a system using Kripke structures
- Express properties to verify as LTL formulas
- Execute model checking and interpret the results
- Identify issues when counterexamples are found

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts (see [Getting Started with TemporalKit](./BasicUsage.md))

## Step 1: Modeling a Simple State Machine

First, let's model the state machine we want to verify. As an example, we'll model a simple door state system.

```swift
import TemporalKit

// Door states
enum DoorState: Hashable, CustomStringConvertible {
    case closed
    case opening
    case open
    case closing
    case locked
    
    var description: String {
        switch self {
        case .closed: return "Closed"
        case .opening: return "Opening"
        case .open: return "Open"
        case .closing: return "Closing"
        case .locked: return "Locked"
        }
    }
}
```

## Step 2: Defining Propositions

Next, let's define propositions related to the door states.

```swift
// Define propositions
let isClosed = TemporalKit.makeProposition(
    id: "isClosed",
    name: "Door is closed",
    evaluate: { (state: DoorState) -> Bool in state == .closed }
)

let isOpen = TemporalKit.makeProposition(
    id: "isOpen",
    name: "Door is open",
    evaluate: { (state: DoorState) -> Bool in state == .open }
)

let isMoving = TemporalKit.makeProposition(
    id: "isMoving",
    name: "Door is moving",
    evaluate: { (state: DoorState) -> Bool in 
        return state == .opening || state == .closing 
    }
)

let isLocked = TemporalKit.makeProposition(
    id: "isLocked",
    name: "Door is locked",
    evaluate: { (state: DoorState) -> Bool in state == .locked }
)
```

## Step 3: Implementing a Kripke Structure

Now, implement the door state transitions as a Kripke structure.

```swift
struct DoorModel: KripkeStructure {
    typealias State = DoorState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State> = Set(arrayLiteral: .closed, .opening, .open, .closing, .locked)
    let initialStates: Set<State> = [.closed]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .closed:
            return [.opening, .locked]
        case .opening:
            return [.open]
        case .open:
            return [.closing]
        case .closing:
            return [.closed]
        case .locked:
            return [.closed]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .closed:
            trueProps.insert(isClosed.id)
        case .opening:
            trueProps.insert(isMoving.id)
        case .open:
            trueProps.insert(isOpen.id)
        case .closing:
            trueProps.insert(isMoving.id)
        case .locked:
            trueProps.insert(isLocked.id)
            trueProps.insert(isClosed.id) // A locked door is considered closed
        }
        
        return trueProps
    }
}
```

## Step 4: Defining LTL Formulas for Properties to Verify

Next, define the properties we want to verify as LTL formulas.

```swift
// Define verification properties
// 1. "When the door opens, it will eventually close"
let eventuallyCloses = LTLFormula<ClosureTemporalProposition<DoorState, Bool>>.globally(
    .implies(
        .atomic(isOpen),
        .eventually(.atomic(isClosed))
    )
)

// 2. "When the door is locked, it cannot open immediately"
let lockedStaysClosed = LTLFormula<ClosureTemporalProposition<DoorState, Bool>>.globally(
    .implies(
        .atomic(isLocked),
        .not(.next(.atomic(isOpen)))
    )
)

// 3. "From a closed state, the door can always eventually open"
let canEventuallyOpen = LTLFormula<ClosureTemporalProposition<DoorState, Bool>>.globally(
    .implies(
        .atomic(isClosed),
        .eventually(.atomic(isOpen))
    )
)

// Alternative expression using DSL notation
let alwaysEventuallyCloses = G(F(.atomic(isClosed)))
```

## Step 5: Running Model Checking

Now, execute model checking to verify whether the model satisfies the properties.

```swift
// Initialize model checker
let modelChecker = LTLModelChecker<DoorModel>()
let doorModel = DoorModel()

// Verify properties
do {
    let result1 = try modelChecker.check(formula: eventuallyCloses, model: doorModel)
    let result2 = try modelChecker.check(formula: lockedStaysClosed, model: doorModel)
    let result3 = try modelChecker.check(formula: canEventuallyOpen, model: doorModel)
    let result4 = try modelChecker.check(formula: alwaysEventuallyCloses, model: doorModel)
    
    print("When the door opens, it will eventually close: \(result1.holds ? "holds" : "does not hold")")
    print("When the door is locked, it cannot open immediately: \(result2.holds ? "holds" : "does not hold")")
    print("From a closed state, the door can always eventually open: \(result3.holds ? "holds" : "does not hold")")
    print("The door always eventually closes: \(result4.holds ? "holds" : "does not hold")")
    
    // Check for counterexamples
    if case .fails(let counterexample) = result3 {
        print("Counterexample for property 3:")
        print("  Prefix: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("  Cycle: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
} catch {
    print("Verification error: \(error)")
}
```

## Step 6: Interpreting Results and Fixing Issues

After running the model checking, we found that property 3, "From a closed state, the door can always eventually open," does not hold. This is because the door cannot open when it is locked.

Let's examine the counterexample:
- Prefix: Closed -> Locked
- Cycle: Locked -> Closed -> Locked

This counterexample shows that when the door is locked, it can only alternate between locked and closed states, but cannot open.

To resolve this issue, let's modify our model:

```swift
struct ImprovedDoorModel: KripkeStructure {
    typealias State = DoorState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State> = Set(arrayLiteral: .closed, .opening, .open, .closing, .locked)
    let initialStates: Set<State> = [.closed]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .closed:
            return [.opening, .locked]
        case .opening:
            return [.open]
        case .open:
            return [.closing]
        case .closing:
            return [.closed]
        case .locked:
            return [.closed, .opening] // Modified to allow opening from locked state
        }
    }
    
    // atomicPropositionsTrue method remains the same
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .closed:
            trueProps.insert(isClosed.id)
        case .opening:
            trueProps.insert(isMoving.id)
        case .open:
            trueProps.insert(isOpen.id)
        case .closing:
            trueProps.insert(isMoving.id)
        case .locked:
            trueProps.insert(isLocked.id)
            trueProps.insert(isClosed.id)
        }
        
        return trueProps
    }
}
```

Let's run the verification again with our improved model:

```swift
let improvedDoorModel = ImprovedDoorModel()

do {
    let result3_improved = try modelChecker.check(formula: canEventuallyOpen, model: improvedDoorModel)
    print("From a closed state, the door can always eventually open (improved): \(result3_improved.holds ? "holds" : "does not hold")")
} catch {
    print("Verification error: \(error)")
}
```

## Summary

In this tutorial, you learned how to model a simple state machine and perform model checking using TemporalKit. Specifically, you learned:

1. How to model a state machine as a Kripke structure
2. How to express properties to verify as LTL formulas
3. How to execute model checking and interpret the results
4. How to analyze counterexamples and fix issues in the model

Model checking is a powerful technique for mathematically verifying that systems satisfy required properties. With TemporalKit, you can easily perform such verification in Swift.

## Next Steps

- Read [Working with Propositions](./WorkingWithPropositions.md) to learn how to create and use more complex propositions
- Try modeling and verifying more complex systems
- Learn about [Advanced LTL Formulas](./AdvancedLTLFormulas.md) to express more complex properties 
