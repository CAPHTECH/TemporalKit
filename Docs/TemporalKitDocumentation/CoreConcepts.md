# Core Concepts

This document explains the fundamental concepts of temporal logic and formal verification as implemented in TemporalKit. Understanding these core concepts is essential for effective use of the library.

## Linear Temporal Logic (LTL)

Linear Temporal Logic is a modal logic used to express properties about sequences of states over time. In LTL, time is viewed as a linear path extending infinitely into the future.

### Basic Components of LTL

#### Atomic Propositions

Atomic propositions are the basic building blocks of LTL formulas. They represent statements about the system that can be true or false at any given state.

In TemporalKit, atomic propositions are represented by the `TemporalProposition` protocol:

```swift
let userLoggedIn = TemporalKit.makeProposition(
    id: "userLoggedIn",
    name: "User is logged in",
    evaluate: { (state: AppState) -> Bool in
        return state.authentication.isLoggedIn
    }
)
```

#### Boolean Operators

LTL includes classical boolean operators from propositional logic:

- **Negation (¬)**: `.not(p)` - The proposition p is false
- **Conjunction (∧)**: `.and(p, q)` - Both propositions p and q are true
- **Disjunction (∨)**: `.or(p, q)` - Either proposition p or q (or both) is true
- **Implication (→)**: `.implies(p, q)` - If p is true, then q is true

#### Temporal Operators

What makes LTL powerful are its temporal operators that express properties over time:

- **Next (X)**: `.next(p)` - Property p holds in the next state
- **Eventually (F)**: `.eventually(p)` - Property p holds at some future state
- **Globally (G)**: `.globally(p)` - Property p holds in all future states
- **Until (U)**: `.until(p, q)` - Property p holds until property q holds
- **Weak Until (W)**: `.weakUntil(p, q)` - Property p holds until property q holds, or p holds forever
- **Release (R)**: `.release(p, q)` - Property q holds until and including when property p holds

### Common LTL Patterns

Certain patterns of LTL formulas appear frequently in practice:

#### Safety Properties

Safety properties express that "something bad never happens." They are typically formulated using the Globally operator.

Example: "The system never reaches an invalid state"
```swift
let safetyProperty = G(.not(.atomic(invalidState)))
```

#### Liveness Properties

Liveness properties express that "something good eventually happens." They often use the Eventually operator.

Example: "Every request is eventually acknowledged"
```swift
let livenessProperty = G(.implies(.atomic(request), F(.atomic(acknowledged))))
```

#### Fairness Properties

Fairness properties express constraints on the infinite behavior of a system.

Example: "If a process requests a resource infinitely often, it will be granted the resource infinitely often"
```swift
let fairnessProperty = .implies(
    G(F(.atomic(requested))),
    G(F(.atomic(granted)))
)
```

## Kripke Structures

A Kripke structure is a type of state transition system used to represent the behavior of a system in formal verification. It consists of:

1. A set of states
2. A transition relation that indicates possible state changes
3. A labeling function that assigns atomic propositions to each state

In TemporalKit, Kripke structures are represented by the `KripkeStructure` protocol:

```swift
public struct MyKripkeStructure: KripkeStructure {
    public typealias State = MyState
    public typealias AtomicPropositionIdentifier = PropositionID
    
    public let initialStates: Set<State>
    public let allStates: Set<State>
    
    public func successors(of state: State) -> Set<State> {
        // Define state transitions here
    }
    
    public func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        // Define which propositions are true in each state
    }
}
```

## Model Checking

Model checking is an automated technique for verifying if a system model satisfies a formal specification. It involves systematically exploring all possible states of the system.

### How Model Checking Works

1. **State Space Exploration**: The model checker explores all reachable states of the Kripke structure
2. **Formula Checking**: For each state, it evaluates whether the LTL formula holds
3. **Counterexample Generation**: If the formula doesn't hold, the model checker produces a counterexample

### Automata-Based Model Checking

TemporalKit uses automata-based model checking with the following steps:

1. Convert the negation of the LTL formula to a Büchi automaton
2. Compute the product of the system's Kripke structure and the Büchi automaton
3. Check for accepting runs in the product automaton
4. If an accepting run exists, it represents a counterexample to the original formula

```swift
let modelChecker = LTLModelChecker<MyKripkeStructure>()
let model = MyKripkeStructure()
let result = try modelChecker.check(formula: myFormula, model: model)

switch result {
case .holds:
    print("The property holds for all possible executions.")
case .fails(let counterexample):
    print("The property fails. Counterexample: \(counterexample)")
}
```

## Evaluation Context

In TemporalKit, when evaluating LTL formulas over traces (sequences of states), an evaluation context is needed to provide state-specific information.

The `EvaluationContext` protocol serves this purpose:

```swift
struct AppEvaluationContext: EvaluationContext {
    typealias PropositionValue = Bool
    typealias State = AppState
    
    let state: AppState
    
    func evaluate<P: TemporalProposition>(proposition: P) -> PropositionValue where P.Value == PropositionValue {
        if let appProposition = proposition as? AppProposition {
            return appProposition.evaluate(state)
        }
        fatalError("Unknown proposition type")
    }
}
```

## Trace Evaluation vs. Model Checking

TemporalKit supports two main verification approaches:

### Trace Evaluation

Trace evaluation verifies LTL properties over a finite sequence of states (a trace). This is useful for:
- Analyzing logs and execution histories
- Testing specific scenarios
- Runtime verification

```swift
let trace: [AppState] = [/* sequence of states */]
let evaluator = LTLFormulaTraceEvaluator<AppProposition>()
let result = try evaluator.evaluate(formula: myFormula, trace: trace, contextProvider: contextFor)
```

### Model Checking

Model checking verifies LTL properties over all possible execution paths of a system model. This is more powerful as it:
- Covers all possible behaviors
- Provides stronger guarantees
- Identifies corner cases that might be missed in testing

```swift
let modelChecker = LTLModelChecker<MyKripkeStructure>()
let result = try modelChecker.check(formula: myFormula, model: myModel)
```

## Büchi Automata

Büchi automata are a type of ω-automata (automata over infinite words) that play a crucial role in LTL model checking.

Key concepts:
- **States**: Including initial states and accepting states
- **Transitions**: State transitions labeled with sets of atomic propositions
- **Acceptance Condition**: A run is accepting if it visits at least one accepting state infinitely often

TemporalKit internally converts LTL formulas to Büchi automata for model checking.

## Summary

Understanding these core concepts - Linear Temporal Logic, Kripke structures, model checking, evaluation contexts, and Büchi automata - provides the foundation needed to effectively use TemporalKit for formal verification of your systems.

For practical applications of these concepts, refer to the [Tutorials](./Tutorials/README.md) section. 
