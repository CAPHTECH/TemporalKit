# Getting Started with TemporalKit

This tutorial introduces the basic usage of TemporalKit, a Swift library for system verification using Linear Temporal Logic (LTL).

## Objectives

By the end of this tutorial, you will be able to:

- Create basic LTL expressions
- Define propositions
- Create a simple system model
- Perform model checking

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- TemporalKit installed via Swift Package Manager

## Step 1: Setting Up Your Project

First, create a Swift project and import TemporalKit.

```swift
import TemporalKit
```

## Step 2: Modeling a Simple System State

Let's first create an enumeration to represent the states of the system we want to verify. As an example, we'll create a traffic light model.

```swift
// Traffic light states
enum TrafficLightState: Hashable {
    case red
    case yellow
    case green
}
```

## Step 3: Defining Propositions

Next, define propositions that can be evaluated against the system states. Each proposition returns a boolean value when evaluated against a state.

```swift
// Traffic light propositions
let isRed = TemporalKit.makeProposition(
    id: "isRed",
    name: "Light is red",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .red
    }
)

let isYellow = TemporalKit.makeProposition(
    id: "isYellow",
    name: "Light is yellow",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .yellow
    }
)

let isGreen = TemporalKit.makeProposition(
    id: "isGreen",
    name: "Light is green",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .green
    }
)
```

## Step 4: Implementing a Kripke Structure

Now, implement a Kripke structure to represent the state transition model of your system. This model defines which states can transition to which other states.

```swift
// Traffic light model
struct TrafficLightModel: KripkeStructure {
    typealias State = TrafficLightState
    typealias AtomicPropositionIdentifier = String
    
    // All possible states
    let allStates: Set<State> = [.red, .yellow, .green]
    
    // Initial state (starting with red)
    let initialStates: Set<State> = [.red]
    
    // State transition function
    func successors(of state: State) -> Set<State> {
        switch state {
        case .red:
            return [.green]  // red → green
        case .green:
            return [.yellow] // green → yellow
        case .yellow:
            return [.red]    // yellow → red
        }
    }
    
    // Atomic propositions true in each state
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .red:
            return ["isRed"]
        case .yellow:
            return ["isYellow"]
        case .green:
            return ["isGreen"]
        }
    }
}
```

## Step 5: Creating LTL Expressions

Next, express the properties you want to verify as LTL expressions. For example, we can verify properties such as:

1. "After yellow, the light always becomes red"
2. "The light will always eventually become red"
3. "After red, the light becomes green"

```swift
// "After yellow, the light always becomes red"
let yellowThenRed = LTLFormula<ClosureTemporalProposition<TrafficLightState, Bool>>.globally(
    .implies(
        .atomic(isYellow),
        .next(.atomic(isRed))
    )
)

// "The light will always eventually become red" (using DSL notation)
let eventuallyRed = G(F(.atomic(isRed)))

// "After red, the light becomes green"
let redThenGreen = G(.implies(.atomic(isRed), X(.atomic(isGreen))))
```

## Step 6: Performing Model Checking

Finally, verify the LTL expressions against your model.

```swift
// Create a model checker
let modelChecker = LTLModelChecker<TrafficLightModel>()
let model = TrafficLightModel()

do {
    // Verify each property
    let result1 = try modelChecker.check(formula: yellowThenRed, model: model)
    let result2 = try modelChecker.check(formula: eventuallyRed, model: model)
    let result3 = try modelChecker.check(formula: redThenGreen, model: model)
    
    // Display results
    print("After yellow, the light always becomes red: \(result1.holds ? "holds" : "does not hold")")
    print("The light will always eventually become red: \(result2.holds ? "holds" : "does not hold")")
    print("After red, the light becomes green: \(result3.holds ? "holds" : "does not hold")")
    
    // Display counterexample if any
    if case .fails(let counterexample) = result1 {
        print("Counterexample: \(counterexample)")
    }
} catch {
    print("Verification error: \(error)")
}
```

## Step 7: Analyzing Results

Analyze the model checking results to determine whether the properties hold and understand the meaning of any counterexamples. For example, you might expect output like:

```
After yellow, the light always becomes red: holds
The light will always eventually become red: holds
After red, the light becomes green: holds
```

This indicates that our model is functioning correctly. If any result "does not hold", you can analyze the counterexample to identify the issue.

## Complete Code Example

Here's a complete code example that combines all the steps we've covered:

```swift
import TemporalKit

// Traffic light states
enum TrafficLightState: Hashable {
    case red
    case yellow
    case green
}

// Traffic light model
struct TrafficLightModel: KripkeStructure {
    typealias State = TrafficLightState
    typealias AtomicPropositionIdentifier = String
    
    let allStates: Set<State> = [.red, .yellow, .green]
    let initialStates: Set<State> = [.red]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .red:
            return [.green]
        case .green:
            return [.yellow]
        case .yellow:
            return [.red]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .red:
            return ["isRed"]
        case .yellow:
            return ["isYellow"]
        case .green:
            return ["isGreen"]
        }
    }
}

// Define propositions
let isRed = TemporalKit.makeProposition(
    id: "isRed",
    name: "Light is red",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .red
    }
)

let isYellow = TemporalKit.makeProposition(
    id: "isYellow",
    name: "Light is yellow",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .yellow
    }
)

let isGreen = TemporalKit.makeProposition(
    id: "isGreen",
    name: "Light is green",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .green
    }
)

// Define LTL expressions
let yellowThenRed = LTLFormula<ClosureTemporalProposition<TrafficLightState, Bool>>.globally(
    .implies(
        .atomic(isYellow),
        .next(.atomic(isRed))
    )
)

let eventuallyRed = G(F(.atomic(isRed)))

let redThenGreen = G(.implies(.atomic(isRed), X(.atomic(isGreen))))

// Run model checking
func runTrafficLightVerification() {
    let modelChecker = LTLModelChecker<TrafficLightModel>()
    let model = TrafficLightModel()
    
    do {
        let result1 = try modelChecker.check(formula: yellowThenRed, model: model)
        let result2 = try modelChecker.check(formula: eventuallyRed, model: model)
        let result3 = try modelChecker.check(formula: redThenGreen, model: model)
        
        print("After yellow, the light always becomes red: \(result1.holds ? "holds" : "does not hold")")
        print("The light will always eventually become red: \(result2.holds ? "holds" : "does not hold")")
        print("After red, the light becomes green: \(result3.holds ? "holds" : "does not hold")")
        
        if case .fails(let counterexample) = result1 {
            print("Counterexample 1: \(counterexample)")
        }
        
        if case .fails(let counterexample) = result2 {
            print("Counterexample 2: \(counterexample)")
        }
        
        if case .fails(let counterexample) = result3 {
            print("Counterexample 3: \(counterexample)")
        }
    } catch {
        print("Verification error: \(error)")
    }
}

// Run verification
runTrafficLightVerification()
```

## Next Steps

Now that you've learned the basics of TemporalKit, challenge yourself with:

- Modeling more complex systems
- Creating more complex LTL expressions
- Integrating with real-world applications
- Moving on to [Intermediate Tutorial: Model Checking Details](./SimpleModelChecking.md)

## Summary

In this tutorial, you learned the basic usage of TemporalKit, including:

- How to model system states
- How to define propositions
- How to implement a Kripke structure
- How to create LTL expressions
- How to perform model checking

Understanding these basic elements will enable you to proceed to verify more complex systems. 
