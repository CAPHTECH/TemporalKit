# Advanced LTL Formulas

This tutorial teaches you how to write advanced Linear Temporal Logic (LTL) formulas using TemporalKit to express complex system properties.

## Objectives

By the end of this tutorial, you will be able to:

- Create and understand complex LTL formulas
- Express common system property patterns using LTL formulas
- Understand equivalence and containment relationships between LTL formulas
- Create readable LTL formulas using the domain-specific language (DSL)

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts (see [Getting Started with TemporalKit](./BasicUsage.md) and [Simple Model Checking](./SimpleModelChecking.md))

## Step 1: Review of LTL Operators

Let's start by reviewing the basic LTL operators:

```swift
import TemporalKit

// Sample propositions to use in our properties
let isReady = TemporalKit.makeProposition(
    id: "isReady",
    name: "System is ready",
    evaluate: { (state: Bool) -> Bool in state }
)

let isProcessing = TemporalKit.makeProposition(
    id: "isProcessing",
    name: "System is processing",
    evaluate: { (state: Bool) -> Bool in state }
)

let isCompleted = TemporalKit.makeProposition(
    id: "isCompleted",
    name: "System is completed",
    evaluate: { (state: Bool) -> Bool in state }
)

// Basic LTL operators

// 1. Next (X): holds in the next state
let nextReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.next(.atomic(isReady))

// 2. Eventually (F): holds sometime in the future
let eventuallyCompleted = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.eventually(.atomic(isCompleted))

// 3. Globally (G): holds in all future states
let alwaysReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(.atomic(isReady))

// 4. Until (U): first argument holds until the second argument holds
let processingUntilCompleted = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.until(
    .atomic(isProcessing),
    .atomic(isCompleted)
)

// 5. Release (R): second argument holds until "released" by the first argument
let completedReleasedByReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.release(
    .atomic(isReady),
    .atomic(isCompleted)
)

// DSL notation
import TemporalKit.DSL

let dslNextReady = X(.atomic(isReady))
let dslEventuallyCompleted = F(.atomic(isCompleted))
let dslAlwaysReady = G(.atomic(isReady))
let dslProcessingUntilCompleted = U(.atomic(isProcessing), .atomic(isCompleted))
let dslCompletedReleasedByReady = R(.atomic(isReady), .atomic(isCompleted))
```

## Step 2: Building Complex LTL Formulas

Combine the basic operators to express more complex properties:

```swift
// Example: "After the system is ready, it will eventually complete processing"
let readyLeadsToCompletion = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isReady),
        .eventually(.atomic(isCompleted))
    )
)

// With DSL notation:
let dslReadyLeadsToCompletion = G(.implies(.atomic(isReady), F(.atomic(isCompleted))))

// Example: "During processing, the system is not ready"
let noReadyDuringProcessing = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isProcessing),
        .not(.atomic(isReady))
    )
)

// Example: "After completion, the system does not process again until it's ready"
let noProcessingAfterCompletionUntilReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isCompleted),
        .until(
            .not(.atomic(isProcessing)),
            .atomic(isReady)
        )
    )
)

// Example: "The system always eventually returns to the ready state"
let alwaysEventuallyReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .eventually(.atomic(isReady))
)

// With DSL notation:
let dslAlwaysEventuallyReady = G(F(.atomic(isReady)))
```

## Step 3: Expressing Common Property Patterns

Let's look at property patterns commonly used in real systems:

```swift
// Safety: "Bad things never happen"
// Example: "The system never enters an error state"
let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "System is in error state",
    evaluate: { (state: Bool) -> Bool in state }
)

let safety = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .not(.atomic(isError))
)

// Liveness: "Good things eventually happen"
// Example: "A requested task eventually completes"
let isRequested = TemporalKit.makeProposition(
    id: "isRequested",
    name: "Task is requested",
    evaluate: { (state: Bool) -> Bool in state }
)

let liveness = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isRequested),
        .eventually(.atomic(isCompleted))
    )
)

// Fairness: "A certain condition is satisfied infinitely often"
// Example: "The system becomes ready infinitely often"
let fairness = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .eventually(.atomic(isReady))
)

// Responsiveness: "Every stimulus is followed by a response"
// Example: "When a button is pressed, a light eventually turns on"
let buttonPressed = TemporalKit.makeProposition(
    id: "buttonPressed",
    name: "Button is pressed",
    evaluate: { (state: Bool) -> Bool in state }
)

let lightOn = TemporalKit.makeProposition(
    id: "lightOn",
    name: "Light is on",
    evaluate: { (state: Bool) -> Bool in state }
)

let responsiveness = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(buttonPressed),
        .eventually(.atomic(lightOn))
    )
)

// Precedence: "An event only occurs after another event"
// Example: "Access is granted only after successful authentication"
let isAuthenticated = TemporalKit.makeProposition(
    id: "isAuthenticated",
    name: "Authenticated",
    evaluate: { (state: Bool) -> Bool in state }
)

let accessGranted = TemporalKit.makeProposition(
    id: "accessGranted",
    name: "Access granted",
    evaluate: { (state: Bool) -> Bool in state }
)

let precedence = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(accessGranted),
        .or(
            .atomic(isAuthenticated),
            .previously(.atomic(isAuthenticated))
        )
    )
)
```

## Step 4: Nested Operators and Complex Patterns

Build complex patterns with nested operators for more advanced expressions:

```swift
// Example: "When a request arrives, processing begins, then completes, and finally a report is generated"
let isReported = TemporalKit.makeProposition(
    id: "isReported",
    name: "Report completed",
    evaluate: { (state: Bool) -> Bool in state }
)

let complexSequence = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isRequested),
        .eventually(
            .and(
                .atomic(isProcessing),
                .eventually(
                    .and(
                        .atomic(isCompleted),
                        .eventually(.atomic(isReported))
                    )
                )
            )
        )
    )
)

// DSL notation makes it more readable
let dslComplexSequence = G(
    .implies(
        .atomic(isRequested),
        F(
            .and(
                .atomic(isProcessing),
                F(
                    .and(
                        .atomic(isCompleted),
                        F(.atomic(isReported))
                    )
                )
            )
        )
    )
)

// Example: "Once processing starts, it continues until an error occurs or completion"
let processUntilErrorOrCompletion = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isProcessing),
        .until(
            .atomic(isProcessing),
            .or(
                .atomic(isError),
                .atomic(isCompleted)
            )
        )
    )
)

// Example: "The system always follows this cycle: ready→processing→completed→ready"
let cyclicBehavior = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .and(
        .implies(
            .atomic(isReady),
            .eventually(.atomic(isProcessing))
        ),
        .and(
            .implies(
                .atomic(isProcessing),
                .eventually(.atomic(isCompleted))
            ),
            .implies(
                .atomic(isCompleted),
                .eventually(.atomic(isReady))
            )
        )
    )
)
```

## Step 5: Real Example: Verifying a Communication Protocol

As a real-world example, let's express properties of a simple communication protocol:

```swift
// Protocol state type
enum ProtocolState {
    case idle
    case connecting
    case connected
    case transmitting
    case disconnecting
    case error
}

// Communication protocol propositions
let isIdle = TemporalKit.makeProposition(
    id: "isIdle",
    name: "Idle state",
    evaluate: { (state: ProtocolState) -> Bool in state == .idle }
)

let isConnecting = TemporalKit.makeProposition(
    id: "isConnecting",
    name: "Connecting",
    evaluate: { (state: ProtocolState) -> Bool in state == .connecting }
)

let isConnected = TemporalKit.makeProposition(
    id: "isConnected",
    name: "Connected",
    evaluate: { (state: ProtocolState) -> Bool in state == .connected }
)

let isTransmitting = TemporalKit.makeProposition(
    id: "isTransmitting",
    name: "Transmitting data",
    evaluate: { (state: ProtocolState) -> Bool in state == .transmitting }
)

let isDisconnecting = TemporalKit.makeProposition(
    id: "isDisconnecting",
    name: "Disconnecting",
    evaluate: { (state: ProtocolState) -> Bool in state == .disconnecting }
)

let isProtocolError = TemporalKit.makeProposition(
    id: "isProtocolError",
    name: "Error state",
    evaluate: { (state: ProtocolState) -> Bool in state == .error }
)

// Protocol verification properties

// 1. "From idle state, the connected state is always reached through the connecting state"
let properConnectionSequence = LTLFormula<ClosureTemporalProposition<ProtocolState, Bool>>.globally(
    .implies(
        .atomic(isIdle),
        .implies(
            .eventually(.atomic(isConnected)),
            .not(
                .until(
                    .not(.atomic(isConnecting)),
                    .atomic(isConnected)
                )
            )
        )
    )
)

// 2. "Data transmission is only possible in connected state"
let transmitOnlyWhenConnected = LTLFormula<ClosureTemporalProposition<ProtocolState, Bool>>.globally(
    .implies(
        .atomic(isTransmitting),
        .previously(.atomic(isConnected))
    )
)

// 3. "When an error state occurs, the system is always reset to idle"
let errorRecovers = LTLFormula<ClosureTemporalProposition<ProtocolState, Bool>>.globally(
    .implies(
        .atomic(isProtocolError),
        .eventually(.atomic(isIdle))
    )
)

// 4. "Going from connected to idle always involves passing through the disconnecting state"
let properDisconnectionSequence = LTLFormula<ClosureTemporalProposition<ProtocolState, Bool>>.globally(
    .implies(
        .and(
            .atomic(isConnected),
            .next(.eventually(.atomic(isIdle)))
        ),
        .next(
            .until(
                .not(.atomic(isIdle)),
                .atomic(isDisconnecting)
            )
        )
    )
)
```

## Step 6: Customizing and Extending LTL Formulas

Learn how to create more readable and reusable LTL formulas:

```swift
// Use type aliases for conciseness
typealias ProtocolProp = ClosureTemporalProposition<ProtocolState, Bool>
typealias ProtocolLTL = LTLFormula<ProtocolProp>

// Create helper functions to extract patterns
func eventually<State, P: TemporalProposition>(_ prop: P) -> LTLFormula<P> where P.Value == Bool {
    return LTLFormula<P>.eventually(.atomic(prop))
}

func always<State, P: TemporalProposition>(_ prop: P) -> LTLFormula<P> where P.Value == Bool {
    return LTLFormula<P>.globally(.atomic(prop))
}

func followedBy<State, P: TemporalProposition>(_ first: P, _ second: P) -> LTLFormula<P> where P.Value == Bool {
    return LTLFormula<P>.globally(
        .implies(
            .atomic(first),
            .eventually(.atomic(second))
        )
    )
}

// Actual code examples:
let idleLeadsToConnected = followedBy(isIdle, isConnected)
let errorLeadsToIdle = followedBy(isProtocolError, isIdle)
```

## Step 7: Using DSL for LTL Formula Expression

Leverage the DSL to create more expressive and readable LTL formulas:

```swift
import TemporalKit.DSL

// Examples using DSL
let dslProperConnectionSequence = G(
    .implies(
        .atomic(isIdle),
        .implies(
            F(.atomic(isConnected)),
            .not(
                U(
                    .not(.atomic(isConnecting)),
                    .atomic(isConnected)
                )
            )
        )
    )
)

let dslTransmitOnlyWhenConnected = G(
    .implies(
        .atomic(isTransmitting),
        P(.atomic(isConnected))
    )
)

// Helper functions using DSL
func implies<P: TemporalProposition>(_ antecedent: LTLFormula<P>, _ consequent: LTLFormula<P>) -> LTLFormula<P> where P.Value == Bool {
    return .implies(antecedent, consequent)
}

func atomic<P: TemporalProposition>(_ prop: P) -> LTLFormula<P> where P.Value == Bool {
    return .atomic(prop)
}

// More readable DSL expression
let readableFormula = G(
    implies(
        atomic(isConnected),
        F(atomic(isTransmitting))
    )
)
```

## Step 8: LTL Equivalence and Transformation

Learn about equivalent transformations and optimizations of LTL formulas:

```swift
// Examples of LTL formula equivalences

// 1. Double negation elimination: ¬¬φ ≡ φ
let doubleNegation = LTLFormula<ProtocolProp>.not(.not(.atomic(isConnected)))
let simplified = LTLFormula<ProtocolProp>.atomic(isConnected)
// These two formulas are equivalent

// 2. De Morgan's laws: ¬(φ ∧ ψ) ≡ ¬φ ∨ ¬ψ
let notAnd = LTLFormula<ProtocolProp>.not(
    .and(.atomic(isConnected), .atomic(isTransmitting))
)
let orNot = LTLFormula<ProtocolProp>.or(
    .not(.atomic(isConnected)),
    .not(.atomic(isTransmitting))
)
// These two formulas are equivalent

// 3. Some LTL-specific equivalences
// F(F(φ)) ≡ F(φ)
let eventuallyEventually = LTLFormula<ProtocolProp>.eventually(.eventually(.atomic(isConnected)))
let justEventually = LTLFormula<ProtocolProp>.eventually(.atomic(isConnected))
// These two formulas are equivalent

// G(G(φ)) ≡ G(φ)
let alwaysAlways = LTLFormula<ProtocolProp>.globally(.globally(.atomic(isConnected)))
let justAlways = LTLFormula<ProtocolProp>.globally(.atomic(isConnected))
// These two formulas are equivalent

// Difference between FG(φ) and GF(φ)
// "Eventually φ holds forever" vs "φ holds infinitely often"
let eventuallyAlways = LTLFormula<ProtocolProp>.eventually(.globally(.atomic(isConnected)))
let alwaysEventually = LTLFormula<ProtocolProp>.globally(.eventually(.atomic(isConnected)))
// These are generally not equivalent
```

## Summary

In this tutorial, you learned how to write advanced LTL formulas using TemporalKit. Specifically, you learned:

1. How to combine basic LTL operators to build complex formulas
2. How to express common property patterns (safety, liveness, fairness, etc.)
3. How to apply LTL formulas to real systems like communication protocols
4. How to use DSL to write readable LTL formulas
5. How to understand equivalence and optimization of LTL formulas

By effectively using LTL formulas, you can precisely specify complex system behaviors and discover design errors early through model checking.

## Next Steps

- Learn how to apply LTL formulas to state machines in [State Machine Verification](./StateMachines.md)
- Understand how to incorporate LTL verification into test suites in [Integrating with Tests](./IntegratingWithTests.md)
- Learn how to build more complex system models in [Advanced Kripke Structures](./AdvancedKripkeStructures.md) 
