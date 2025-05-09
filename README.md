# TemporalKit

TemporalKit is a Swift library for working with temporal logic, particularly Linear Temporal Logic (LTL). It provides a type-safe, composable, and Swift-idiomatic way to express and evaluate temporal logic formulas.

## Features

- **Type-safe representation** of Linear Temporal Logic (LTL) formulas
- **Swift-idiomatic DSL** for constructing formulas with natural syntax
- **Extensible architecture** designed to support multiple temporal logic systems
- **Evaluation engine** for checking formulas against traces
- **Formula normalization** to simplify and optimize expressions
- **Comprehensive examples** demonstrating real-world usage

## Installation

### Swift Package Manager

Add TemporalKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/TemporalKit.git", from: "1.0.0")
]
```

## Basic Concepts

### Temporal Logic

Temporal logic extends classical logic with operators that refer to time. Linear Temporal Logic (LTL) specifically deals with a linear path of time (a sequence of states).

Key LTL operators:

- `X p`: Next - p holds at the next time step
- `F p`: Eventually - p holds at some future time step
- `G p`: Always - p holds at all future time steps
- `p U q`: Until - p holds until q holds (DSL: `p ~>> q`)
- `p W q`: Weak Until - p holds until q holds, or p holds forever
- `p R q`: Release - q holds until and including when p holds

### Using TemporalKit

#### 1. Define Propositions

First, create propositions that can be evaluated at specific points in time:

```swift
class IsUserLoggedInProposition: TemporalProposition {
    let id = PropositionID(rawValue: "isUserLoggedIn") 
    let name = "User is logged in"
    
    func evaluate(in context: EvaluationContext) -> Bool {
        guard let appContext = context as? AppEvaluationContext else { return false }
        return appContext.state.isUserLoggedIn
    }
}
```

#### 2. Create Evaluation Contexts

Define a context that provides the necessary information to evaluate propositions:

```swift
struct AppEvaluationContext: EvaluationContext {
    let state: AppState
    let index: Int
    
    func currentStateAs<T>(_ type: T.Type) -> T? {
        return state as? T
    }
    
    var traceIndex: Int? { return index }
}
```

#### 3. Construct Formulas

Use the Swift-friendly DSL to construct temporal logic formulas:

```swift
// Create atomic propositions
let isLoggedIn: LTLFormula<MyProposition> = .atomic(IsUserLoggedInProposition())
let hasUnread: LTLFormula<MyProposition> = .atomic(HasUnreadMessagesProposition())

// Build complex formulas
// "Eventually the user is logged in"
let eventuallyLoggedIn = LTLFormula.F(isLoggedIn)

// "Once logged in, eventually has unread messages"
let loggedInLeadsToUnread = isLoggedIn ==> LTLFormula.F(hasUnread)

// "Always, if has unread messages then is logged in"
let unreadImpliesLoggedIn = LTLFormula.G(hasUnread ==> isLoggedIn)

// "Logged in until cart has items"
let loggedInUntilCart = isLoggedIn ~>> cartHasItems
```

#### 4. Evaluate Formulas

Evaluate formulas against a trace (sequence of states):

```swift
let trace: [AppEvaluationContext] = createTraceFromAppStates()

do {
    let result = try eventuallyLoggedIn.evaluate(over: trace)
    print("Formula 'Eventually logged in' holds: \(result)")
} catch {
    print("Error evaluating formula: \(error)")
}
```

## Examples

See the `Sources/TemporalKitDemo` directory for complete examples of using the library.

## Architecture

TemporalKit is designed with the following key components:

- **Core protocols**: `EvaluationContext` and `TemporalProposition` define the interfaces for context and proposition evaluation.
- **Formula representation**: `LTLFormula` enum represents the structure of LTL formulas.
- **DSL**: Operator overloads and helper methods provide a Swift-idiomatic syntax.
- **Evaluation**: Step-wise and trace-based evaluation of formulas.
- **Normalization**: Simplification and standardization of formulas.

## License

TemporalKit is available under the MIT license. See the LICENSE file for more info.

## Future Enhancements

We are considering the following enhancements for the TemporalKit project:

- **Expansion of Supported Logics**:
  - **CTL (Computation Tree Logic) Support**: Support CTL, a branching-time temporal logic, to describe and verify properties related to the "possibility" of system states (e.g., whether a state can be reached, or whether a state can be reached while always maintaining another state).
  - **Introduction of Past LTL Operators**: Introduce past-time operators to LTL (e.g., Yesterday (Y), SoFar (S̅), Triggered (T)) to enhance expressive power.
  - **Consideration of MTL (Metric Temporal Logic) / TPTL (Timed Propositional Temporal Logic)**: Explore the introduction of temporal logics that can handle time constraints more precisely (e.g., "Event B occurs within 5 hours after Event A"), expanding the range of applications to real-time systems and domains where temporal constraints are critical.

- **Implementation of Model Checking Features**:
  - **LTL Model Checking**: In addition to trace evaluation, implement model checking algorithms (e.g., using Büchi automata) to verify if a given state transition system (model) satisfies an LTL formula. This allows verification of properties over the entire behavior of a system, not just finite traces.
  - **State Space Representation**: Define data structures to represent the systems to be model-checked (states, transitions, labeling of atomic propositions, etc.).

- **Enhancement of Usability and DSL**:
  - **Provision of Property Specification Patterns**: Introduce high-level patterns and macros into the DSL to easily describe common properties (e.g., Safety, Liveness, Response).
  - **Enrichment of Diagnostic Information**: Enhance the functionality to present evaluation results and counterexamples from model checking to the user in an understandable way, facilitating the identification of property violation causes.
  - **Expansion of Documentation and Samples**: Provide comprehensive documentation, tutorials, and diverse usage examples to reduce the learning curve.

- **Performance and Extensibility**:
  - **Optimization of Evaluation/Checking Algorithms**: Optimize performance, especially when dealing with large traces or complex state spaces (e.g., consider on-the-fly verification, symbolic model checking techniques).
  - **Architectural Flexibility**: Maintain and improve a modular and extensible architecture that allows for relatively easy integration of new temporal logics and checking algorithms.

- **Expansion of Application Scope**:
  - **Runtime Verification**: Consider supporting functionality to monitor LTL formulas during system execution and detect violations.
  - **Integration with Swift Concurrency**: Explore utilities and integration methods for describing and verifying temporal properties in Swift's Actor model and asynchronous processing.
