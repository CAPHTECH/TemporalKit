# Working with Propositions

This tutorial covers how to define and use temporal propositions in TemporalKit in detail.

## Objectives

By the end of this tutorial, you will be able to:

- Define various types of temporal propositions
- Create custom proposition classes
- Combine propositions to form complex conditions
- Use propositions in trace evaluation and model checking

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts (see [Getting Started with TemporalKit](./BasicUsage.md))

## Step 1: Basics of Temporal Propositions

In TemporalKit, propositions are represented as objects that conform to the `TemporalProposition` protocol. These propositions evaluate system states and return true or false values.

```swift
import TemporalKit

// Simple state definition
struct AppState {
    let isUserLoggedIn: Bool
    let hasNewNotifications: Bool
    let isNetworkAvailable: Bool
    let currentScreen: Screen
    
    enum Screen {
        case login
        case home
        case settings
        case profile
    }
}
```

## Step 2: Defining Propositions Using Closures

The simplest way to define propositions is using the `makeProposition` factory function.

```swift
// Proposition to check if user is logged in
let isLoggedIn = TemporalKit.makeProposition(
    id: "isLoggedIn",
    name: "User is logged in",
    evaluate: { (state: AppState) -> Bool in
        return state.isUserLoggedIn
    }
)

// Proposition to check if there are new notifications
let hasNotifications = TemporalKit.makeProposition(
    id: "hasNotifications",
    name: "Has new notifications",
    evaluate: { (state: AppState) -> Bool in
        return state.hasNewNotifications
    }
)

// Proposition to check if the home screen is displayed
let isOnHomeScreen = TemporalKit.makeProposition(
    id: "isOnHomeScreen",
    name: "Home screen is displayed",
    evaluate: { (state: AppState) -> Bool in
        return state.currentScreen == .home
    }
)
```

## Step 3: Using `ClosureTemporalProposition` Directly

For more detailed control, you can use the `ClosureTemporalProposition` class directly.

```swift
// Proposition to check if network is available and user is logged in
let isConnectedAndLoggedIn = ClosureTemporalProposition<AppState, Bool>(
    id: "isConnectedAndLoggedIn",
    name: "Connected and logged in",
    evaluate: { state in
        // You can perform more complex logic here if needed
        let isConnected = state.isNetworkAvailable
        let isLoggedIn = state.isUserLoggedIn
        
        // Log debug information, etc.
        print("Connection status: \(isConnected), Login status: \(isLoggedIn)")
        
        return isConnected && isLoggedIn
    }
)
```

## Step 4: Creating Custom Proposition Classes

For more complex cases, you can create your own classes that conform to the `TemporalProposition` protocol.

```swift
// Base class for app-specific propositions
class AppProposition: TemporalProposition {
    public typealias Value = Bool
    
    public let id: PropositionID
    public let name: String
    
    init(id: String, name: String) {
        self.id = PropositionID(rawValue: id)
        self.name = name
    }
    
    public func evaluate(in context: EvaluationContext) throws -> Bool {
        guard let appContext = context as? AppEvaluationContext else {
            throw TemporalKitError.stateTypeMismatch(
                expected: "AppEvaluationContext",
                actual: String(describing: type(of: context)),
                propositionID: id,
                propositionName: name
            )
        }
        return evaluateWithAppState(appContext.state)
    }
    
    // Override in subclasses
    func evaluateWithAppState(_ state: AppState) -> Bool {
        fatalError("Must be implemented by subclasses")
    }
}

// Custom proposition to check login status
class IsLoggedInProposition: AppProposition {
    init() {
        super.init(id: "customIsLoggedIn", name: "User is logged in (custom)")
    }
    
    override func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.isUserLoggedIn
    }
}

// Custom proposition to check if a specific screen is displayed
class IsOnScreenProposition: AppProposition {
    private let targetScreen: AppState.Screen
    
    init(screen: AppState.Screen) {
        self.targetScreen = screen
        super.init(
            id: "isOnScreen_\(screen)",
            name: "Current screen is \(screen)"
        )
    }
    
    override func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.currentScreen == targetScreen
    }
}

// Instantiating custom propositions
let customIsLoggedIn = IsLoggedInProposition()
let isOnSettingsScreen = IsOnScreenProposition(screen: .settings)
let isOnProfileScreen = IsOnScreenProposition(screen: .profile)
```

## Step 5: Creating Evaluation Contexts

To evaluate propositions, you need a context that conforms to the `EvaluationContext` protocol.

```swift
// Evaluation context for application state
class AppEvaluationContext: EvaluationContext {
    let state: AppState
    let traceIndex: Int?
    
    init(state: AppState, traceIndex: Int? = nil) {
        self.state = state
        self.traceIndex = traceIndex
    }
    
    func currentStateAs<T>(_ type: T.Type) -> T? {
        return state as? T
    }
}
```

## Step 6: Using Propositions in Trace Evaluation

Let's evaluate temporal logic formulas against a sequence of states (trace).

```swift
// Create a trace of application states
let trace: [AppState] = [
    AppState(isUserLoggedIn: false, hasNewNotifications: false, isNetworkAvailable: true, currentScreen: .login),
    AppState(isUserLoggedIn: true, hasNewNotifications: false, isNetworkAvailable: true, currentScreen: .home),
    AppState(isUserLoggedIn: true, hasNewNotifications: true, isNetworkAvailable: true, currentScreen: .home),
    AppState(isUserLoggedIn: true, hasNewNotifications: false, isNetworkAvailable: true, currentScreen: .profile)
]

// Create LTL formulas from propositions
let formula1 = LTLFormula<AppProposition>.eventually(.atomic(customIsLoggedIn))
let formula2 = LTLFormula<AppProposition>.globally(.implies(
    .atomic(isOnHomeScreen as! AppProposition),
    .eventually(.atomic(isOnProfileScreen))
))

// Evaluation context provider (associates states with indices)
let contextProvider: (AppState, Int) -> EvaluationContext = { state, index in
    return AppEvaluationContext(state: state, traceIndex: index)
}

// Create a trace evaluator
let evaluator = LTLFormulaTraceEvaluator()

// Evaluate formulas
do {
    let result1 = try evaluator.evaluate(formula: formula1, trace: trace, contextProvider: contextProvider)
    let result2 = try evaluator.evaluate(formula: formula2, trace: trace, contextProvider: contextProvider)
    
    print("Eventually logs in: \(result1)")
    print("From home screen, eventually transitions to profile screen: \(result2)")
} catch {
    print("Evaluation error: \(error)")
}
```

## Step 7: Using Propositions in Model Checking

Here's an example of using propositions for model checking.

```swift
// Application state transition model
struct AppStateModel: KripkeStructure {
    typealias State = AppState.Screen
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State> = [.login, .home, .settings, .profile]
    let initialStates: Set<State> = [.login]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .login:
            return [.home]
        case .home:
            return [.settings, .profile]
        case .settings:
            return [.home]
        case .profile:
            return [.home]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        // Add propositions corresponding to screens
        switch state {
        case .login:
            props.insert(PropositionID(rawValue: "isOnScreen_login"))
        case .home:
            props.insert(PropositionID(rawValue: "isOnScreen_home"))
        case .settings:
            props.insert(PropositionID(rawValue: "isOnScreen_settings"))
        case .profile:
            props.insert(PropositionID(rawValue: "isOnScreen_profile"))
        }
        
        return props
    }
}

// Screen-related propositions
let isOnLoginScreen = TemporalKit.makeProposition(
    id: "isOnScreen_login",
    name: "Login screen is displayed",
    evaluate: { (state: AppState.Screen) -> Bool in state == .login }
)

let isOnHomeScreenForModel = TemporalKit.makeProposition(
    id: "isOnScreen_home",
    name: "Home screen is displayed",
    evaluate: { (state: AppState.Screen) -> Bool in state == .home }
)

// LTL formula for model checking
let formula_home_to_settings = LTLFormula<ClosureTemporalProposition<AppState.Screen, Bool>>.globally(
    .implies(
        .atomic(isOnHomeScreenForModel),
        .eventually(.atomic(TemporalKit.makeProposition(
            id: "isOnScreen_settings",
            name: "Settings screen is displayed",
            evaluate: { (state: AppState.Screen) -> Bool in state == .settings }
        )))
    )
)

// Run model checking
let modelChecker = LTLModelChecker<AppStateModel>()
let appModel = AppStateModel()

do {
    let result = try modelChecker.check(formula: formula_home_to_settings, model: appModel)
    print("From home screen, it's always eventually possible to reach settings screen: \(result.holds ? "holds" : "does not hold")")
    
    if case .fails(let counterexample) = result {
        print("Counterexample:")
        print("  Prefix: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("  Cycle: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
} catch {
    print("Model checking error: \(error)")
}
```

## Step 8: Combining and Reusing Propositions

Here's how to combine propositions to express more complex conditions.

```swift
// Utility functions to combine propositions
func and<StateType>(_ p1: ClosureTemporalProposition<StateType, Bool>, _ p2: ClosureTemporalProposition<StateType, Bool>) -> ClosureTemporalProposition<StateType, Bool> {
    return TemporalKit.makeProposition(
        id: "and_\(p1.id.rawValue)_\(p2.id.rawValue)",
        name: "(\(p1.name) AND \(p2.name))",
        evaluate: { state in
            let context = AppEvaluationContext(state: state as! AppState)
            return try p1.evaluate(in: context) && p2.evaluate(in: context)
        }
    )
}

func or<StateType>(_ p1: ClosureTemporalProposition<StateType, Bool>, _ p2: ClosureTemporalProposition<StateType, Bool>) -> ClosureTemporalProposition<StateType, Bool> {
    return TemporalKit.makeProposition(
        id: "or_\(p1.id.rawValue)_\(p2.id.rawValue)",
        name: "(\(p1.name) OR \(p2.name))",
        evaluate: { state in
            let context = AppEvaluationContext(state: state as! AppState)
            return try p1.evaluate(in: context) || p2.evaluate(in: context)
        }
    )
}

func not<StateType>(_ p: ClosureTemporalProposition<StateType, Bool>) -> ClosureTemporalProposition<StateType, Bool> {
    return TemporalKit.makeProposition(
        id: "not_\(p.id.rawValue)",
        name: "NOT (\(p.name))",
        evaluate: { state in
            let context = AppEvaluationContext(state: state as! AppState)
            return try !p.evaluate(in: context)
        }
    )
}

// Example: Logged in but without notifications
let loggedInWithoutNotifications = and(isLoggedIn, not(hasNotifications))

// Example: On home screen or settings screen
let isOnHomeOrSettings = or(isOnHomeScreen, isOnSettingsScreen as! ClosureTemporalProposition<AppState, Bool>)
```

## Summary

In this tutorial, you learned various ways to define and use temporal propositions in TemporalKit:

1. Defining simple propositions using closures
2. Using `ClosureTemporalProposition` directly
3. Creating and inheriting from custom proposition classes
4. Creating and using evaluation contexts
5. Using propositions in trace evaluation and model checking
6. Combining and reusing propositions

Propositions are the basic building blocks of temporal logic formulas and are used to capture specific aspects of system states. By designing appropriate propositions, you can accurately model and verify complex system behaviors.

## Next Steps

- Learn how to apply propositions to real application scenarios in [Verifying UI Flows](./UserFlows.md)
- Understand how to express more complex properties in [Advanced LTL Formulas](./AdvancedLTLFormulas.md)
- Learn how to write tests using propositions in [Integrating with Tests](./IntegratingWithTests.md) 
