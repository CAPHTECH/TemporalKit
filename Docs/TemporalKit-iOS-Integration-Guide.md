# TemporalKit iOS Integration Guide

This guide provides detailed information on how to integrate and leverage TemporalKit in iOS application development. TemporalKit enables formal verification of application behavior through temporal logic, helping developers build more robust, predictable, and bug-free applications.

## Table of Contents

- [TemporalKit iOS Integration Guide](#temporalkit-ios-integration-guide)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Use Cases](#use-cases)
    - [Application State Management](#application-state-management)
      - [Example: Authentication States](#example-authentication-states)
    - [User Flow Verification](#user-flow-verification)
      - [Key Properties to Verify](#key-properties-to-verify)
    - [SwiftUI State Machine Validation](#swiftui-state-machine-validation)
    - [Network Layer Reliability](#network-layer-reliability)
      - [Properties to Verify](#properties-to-verify)
    - [Concurrency and Async Operation Verification](#concurrency-and-async-operation-verification)
    - [Animation and Transition Sequences](#animation-and-transition-sequences)
  - [Implementation Guide](#implementation-guide)
    - [Basic Setup](#basic-setup)
    - [Defining Application States](#defining-application-states)
    - [Creating a Kripke Structure](#creating-a-kripke-structure)
    - [Defining Temporal Properties](#defining-temporal-properties)
    - [Performing Verification](#performing-verification)
  - [Real-World Examples](#real-world-examples)
    - [Authentication Flow](#authentication-flow)
    - [E-commerce Checkout Process](#e-commerce-checkout-process)
    - [Content Loading and Caching](#content-loading-and-caching)
  - [Integration with Testing](#integration-with-testing)
    - [Unit Testing](#unit-testing)
    - [UI Testing](#ui-testing)
    - [CI/CD Integration](#cicd-integration)
  - [Best Practices](#best-practices)
  - [Performance Considerations](#performance-considerations)
  - [Troubleshooting](#troubleshooting)
    - [Common Issues](#common-issues)
  - [Advanced Topics](#advanced-topics)
    - [Parameterized Models](#parameterized-models)
    - [Combined Model Checking and Runtime Verification](#combined-model-checking-and-runtime-verification)
    - [Domain-Specific Property Patterns](#domain-specific-property-patterns)

## Introduction

TemporalKit brings formal verification techniques to iOS development through Linear Temporal Logic (LTL). Instead of relying solely on traditional testing methods, TemporalKit allows developers to express and verify temporal properties of their application - statements about how the application should behave over time.

For iOS applications, this means:

- Verifying that UI states transition correctly
- Ensuring user flows follow expected paths
- Validating that async operations complete as expected
- Confirming that error recovery works correctly in all scenarios
- Preventing subtle state-based bugs before they happen

## Use Cases

### Application State Management

iOS applications typically have complex state management requirements. TemporalKit can verify state transitions and ensure critical properties hold across your application.

#### Example: Authentication States

```swift
// Define application authentication states
enum AuthState: Hashable {
    case loggedOut
    case loggingIn
    case loggedIn
    case authError
    case refreshingToken
}

// Model the authentication subsystem as a Kripke structure
struct AuthStateModel: KripkeStructure {
    typealias State = AuthState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.loggedOut]
    let allStates: Set<State> = [.loggedOut, .loggingIn, .loggedIn, .authError, .refreshingToken]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .loggedOut:
            return [.loggingIn]
        case .loggingIn:
            return [.loggedIn, .authError]
        case .loggedIn:
            return [.loggedIn, .refreshingToken, .loggedOut]
        case .authError:
            return [.loggedOut, .loggingIn]
        case .refreshingToken:
            return [.loggedIn, .loggedOut]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .loggedOut:
            return ["isLoggedOut"]
        case .loggingIn:
            return ["isTransitioning"]
        case .loggedIn:
            return ["isAuthenticated", "canAccessContent"]
        case .authError:
            return ["hasError"]
        case .refreshingToken:
            return ["isAuthenticated", "isTransitioning"]
        }
    }
}

// Define temporal propositions
let isLoggedOut = TemporalKit.makeProposition(
    id: "isLoggedOut",
    name: "User is logged out",
    evaluate: { (state: AuthState) -> Bool in state == .loggedOut }
)

let isAuthenticated = TemporalKit.makeProposition(
    id: "isAuthenticated",
    name: "User is authenticated",
    evaluate: { (state: AuthState) -> Bool in state == .loggedIn || state == .refreshingToken }
)

let isTransitioning = TemporalKit.makeProposition(
    id: "isTransitioning",
    name: "System is in transition state",
    evaluate: { (state: AuthState) -> Bool in state == .loggingIn || state == .refreshingToken }
)

let hasError = TemporalKit.makeProposition(
    id: "hasError",
    name: "Authentication error occurred",
    evaluate: { (state: AuthState) -> Bool in state == .authError }
)

// Define temporal properties to verify
typealias AuthProp = TemporalKit.ClosureTemporalProposition<AuthState, Bool>

// 1. Authentication errors should always lead back to login screen
let errorRecovery: LTLFormula<AuthProp> = .globally(
    .implies(.atomic(hasError), .eventually(.atomic(isLoggedOut)))
)

// 2. Transitioning states should always eventually lead to stable states
let transitionCompletion: LTLFormula<AuthProp> = .globally(
    .implies(.atomic(isTransitioning), .eventually(.or(.atomic(isAuthenticated), .atomic(isLoggedOut))))
)

// 3. User should be able to log out from any authenticated state
let logoutAccessibility: LTLFormula<AuthProp> = .globally(
    .implies(.atomic(isAuthenticated), .eventually(.atomic(isLoggedOut)))
)

// Perform verification
let modelChecker = LTLModelChecker<AuthStateModel>()
let authModel = AuthStateModel()

do {
    let errorRecoveryResult = try modelChecker.check(formula: errorRecovery, model: authModel)
    print("Error recovery property: \(errorRecoveryResult.holds ? "HOLDS" : "FAILS")")
    
    let transitionResult = try modelChecker.check(formula: transitionCompletion, model: authModel)
    print("Transition completion property: \(transitionResult.holds ? "HOLDS" : "FAILS")")
    
    let logoutResult = try modelChecker.check(formula: logoutAccessibility, model: authModel)
    print("Logout accessibility property: \(logoutResult.holds ? "HOLDS" : "FAILS")")
} catch {
    print("Verification error: \(error)")
}
```

### User Flow Verification

Complex user flows like onboarding, registration, or checkout processes can be modeled and verified with TemporalKit.

#### Key Properties to Verify

- Users cannot access certain screens without completing prerequisites
- Every error state has a recovery path
- Users can always cancel or exit a flow
- Session timeouts correctly interrupt and recover flows
- Required information is always collected before flow completion

```swift
// Example: Verifying an onboarding flow
enum OnboardingState: Hashable {
    case welcome
    case permissions
    case accountCreation
    case profileSetup
    case tutorial
    case complete
    case skipped
}

// Define a property ensuring users can't reach "complete" without passing through permissions
let permissionsRequired: LTLFormula<OnboardingProp> = .globally(
    .implies(
        .atomic(isWelcomeState),
        .not(.until(.not(.atomic(isPermissionsState)), .atomic(isCompleteState)))
    )
)
```

### SwiftUI State Machine Validation

SwiftUI applications are fundamentally state machines. TemporalKit can verify that your view state transitions are correct and prevent issues like getting stuck in loading states.

```swift
// Model a SwiftUI view state machine
enum ViewState: Hashable {
    case initial
    case loading
    case loaded(Data)
    case empty
    case error(Error)
}

struct ViewStateModel: KripkeStructure {
    // Implementation details omitted for brevity
}

// Define a property ensuring loading always eventually leads to loaded or error
let loadingCompletes: LTLFormula<ViewProp> = .globally(
    .implies(.atomic(isLoading), .eventually(.or(.atomic(isLoaded), .atomic(isError))))
)
```

### Network Layer Reliability

Verify network operations, retry logic, and caching behavior with TemporalKit.

#### Properties to Verify

- Network failures always lead to retry or graceful error handling
- Cached data is used when appropriate
- Authentication headers are refreshed when needed
- Rate limiting does not cause deadlocks
- Offline operations are properly queued and executed when connectivity returns

```swift
// Example: Verifying a network layer with caching and retry logic
enum NetworkRequestState: Hashable {
    case initial
    case checkingCache
    case usingCachedData
    case fetching
    case retrying
    case succeeded
    case failed
}

// Define a property ensuring all network operations eventually succeed or fail finitely
let networkOperationsTerminate: LTLFormula<NetworkProp> = .globally(
    .implies(
        .atomic(isFetching),
        .eventually(.or(.atomic(isSucceeded), .atomic(isFailed)))
    )
)

// Ensure retry logic is bounded
let boundedRetries: LTLFormula<NetworkProp> = .globally(
    .implies(
        .atomic(isRetrying), 
        .or(.next(.atomic(isSucceeded)), .next(.atomic(isFailed)), .next(.atomic(isRetrying)))
    )
)
```

### Concurrency and Async Operation Verification

Validate the behavior of async/await code, tasks, and operations to prevent race conditions and deadlocks.

```swift
// Model states in an async operation flow
enum AsyncOperationState: Hashable {
    case idle
    case inProgress
    case completed
    case cancelled
    case failed
}

// Ensure operations can be cancelled
let cancellationWorks: LTLFormula<AsyncProp> = .globally(
    .implies(
        .and(.atomic(isInProgress), .next(.atomic(isCancelled))),
        .not(.next(.atomic(isCompleted)))
    )
)

// Verify that operations don't get stuck
let noDeadlocks: LTLFormula<AsyncProp> = .globally(
    .implies(.atomic(isInProgress), .eventually(.or(.atomic(isCompleted), .atomic(isCancelled), .atomic(isFailed))))
)
```

### Animation and Transition Sequences

Verify that complex animation sequences follow the expected order and that UI states transition correctly.

```swift
// Model animation states
enum AnimationState: Hashable {
    case initial
    case fadeOutBegin
    case fadeOutComplete
    case fadeInBegin
    case fadeInComplete
}

// Ensure animations follow the correct sequence
let animationSequence: LTLFormula<AnimationProp> = .globally(
    .implies(
        .atomic(isFadeOutBegin),
        .next(.until(.atomic(isFadeOutComplete), .atomic(isFadeInBegin)))
    )
)
```

## Implementation Guide

### Basic Setup

1. Add TemporalKit to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/CAPHTECH/TemporalKit.git", from: "0.1.0")
]
```

2. Import TemporalKit in your source files:

```swift
import TemporalKit
```

### Defining Application States

Start by identifying and defining the states your application or component can be in:

```swift
enum AppState: Hashable {
    case startup
    case onboarding
    case main(MainState)
    case settings
    case error(ErrorType)
}

enum MainState: Hashable {
    case feedLoading
    case feedLoaded
    case feedEmpty
    case feedError
}

enum ErrorType: Hashable {
    case network
    case authentication
    case unknown
}
```

### Creating a Kripke Structure

Implement the `KripkeStructure` protocol to model how your application transitions between states:

```swift
struct AppStateModel: KripkeStructure {
    typealias State = AppState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.startup]
    let allStates: Set<State>
    
    init() {
        // Define all possible states
        var states: Set<State> = [.startup, .onboarding, .settings]
        
        // Add main states
        states.insert(.main(.feedLoading))
        states.insert(.main(.feedLoaded))
        states.insert(.main(.feedEmpty))
        states.insert(.main(.feedError))
        
        // Add error states
        states.insert(.error(.network))
        states.insert(.error(.authentication))
        states.insert(.error(.unknown))
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .startup:
            return [.onboarding, .main(.feedLoading)]
        case .onboarding:
            return [.main(.feedLoading), .error(.unknown)]
        case .main(let mainState):
            switch mainState {
            case .feedLoading:
                return [.main(.feedLoaded), .main(.feedEmpty), .main(.feedError), .error(.network)]
            case .feedLoaded:
                return [.main(.feedLoading), .settings]
            case .feedEmpty:
                return [.main(.feedLoading)]
            case .feedError:
                return [.main(.feedLoading), .error(.unknown)]
            }
        case .settings:
            return [.main(.feedLoaded), .main(.feedLoading)]
        case .error(let errorType):
            switch errorType {
            case .network:
                return [.main(.feedLoading)]
            case .authentication:
                return [.startup, .onboarding]
            case .unknown:
                return [.startup]
            }
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props: Set<AtomicPropositionIdentifier> = []
        
        switch state {
        case .startup:
            props.insert("isStartup")
        case .onboarding:
            props.insert("isOnboarding")
        case .main(let mainState):
            props.insert("isMain")
            switch mainState {
            case .feedLoading:
                props.insert("isLoading")
            case .feedLoaded:
                props.insert("hasContent")
            case .feedEmpty:
                props.insert("isEmpty")
            case .feedError:
                props.insert("hasError")
            }
        case .settings:
            props.insert("isSettings")
        case .error(let errorType):
            props.insert("isError")
            switch errorType {
            case .network:
                props.insert("isNetworkError")
            case .authentication:
                props.insert("isAuthError")
            case .unknown:
                props.insert("isUnknownError")
            }
        }
        
        return props
    }
}
```

### Defining Temporal Properties

Create propositions to describe conditions in your app, then compose them into LTL formulas:

```swift
// Define propositions
let isStartup = TemporalKit.makeProposition(
    id: "isStartup",
    name: "Application is in startup state",
    evaluate: { (state: AppState) -> Bool in
        if case .startup = state { return true }
        return false
    }
)

let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "Application is in error state",
    evaluate: { (state: AppState) -> Bool in
        if case .error = state { return true }
        return false
    }
)

let isLoading = TemporalKit.makeProposition(
    id: "isLoading",
    name: "Application is loading content",
    evaluate: { (state: AppState) -> Bool in
        if case .main(.feedLoading) = state { return true }
        return false
    }
)

typealias AppProp = TemporalKit.ClosureTemporalProposition<AppState, Bool>

// Define temporal properties as LTL formulas
let errorRecovery: LTLFormula<AppProp> = .globally(
    .implies(.atomic(isError), .eventually(.not(.atomic(isError))))
)

let loadingCompletes: LTLFormula<AppProp> = .globally(
    .implies(.atomic(isLoading), .eventually(.not(.atomic(isLoading))))
)

let startupEventuallyMain: LTLFormula<AppProp> = .implies(
    .atomic(isStartup),
    .eventually(.or(
        .atomic(TemporalKit.makeProposition(
            id: "isMain",
            name: "In main screen",
            evaluate: { (state: AppState) -> Bool in
                if case .main = state { return true }
                return false
            }
        )),
        .atomic(isError)
    ))
)
```

### Performing Verification

Use the `LTLModelChecker` to verify your properties against your model:

```swift
func verifyAppBehavior() {
    let modelChecker = LTLModelChecker<AppStateModel>()
    let appModel = AppStateModel()
    
    do {
        // Verify error recovery
        let errorRecoveryResult = try modelChecker.check(formula: errorRecovery, model: appModel)
        if errorRecoveryResult.holds {
            print("✅ Error recovery property holds")
        } else {
            print("❌ Error recovery property fails")
            if case .fails(let counterexample) = errorRecoveryResult {
                print("Counterexample: \(counterexample.infinitePathDescription)")
            }
        }
        
        // Verify loading completion
        let loadingResult = try modelChecker.check(formula: loadingCompletes, model: appModel)
        if loadingResult.holds {
            print("✅ Loading completion property holds")
        } else {
            print("❌ Loading completion property fails")
            if case .fails(let counterexample) = loadingResult {
                print("Counterexample: \(counterexample.infinitePathDescription)")
            }
        }
        
        // Verify startup flow
        let startupResult = try modelChecker.check(formula: startupEventuallyMain, model: appModel)
        if startupResult.holds {
            print("✅ Startup flow property holds")
        } else {
            print("❌ Startup flow property fails")
            if case .fails(let counterexample) = startupResult {
                print("Counterexample: \(counterexample.infinitePathDescription)")
            }
        }
    } catch {
        print("Verification error: \(error)")
    }
}
```

## Real-World Examples

### Authentication Flow

This example models an authentication flow with multiple states and verifies critical properties:

```swift
enum AuthFlowState: Hashable {
    case initial
    case enterCredentials
    case authenticating
    case biometricPrompt
    case biometricVerifying
    case mfaRequired
    case mfaVerifying
    case authenticated
    case authError(AuthErrorType)
    case locked
}

enum AuthErrorType: Hashable {
    case invalidCredentials
    case networkFailure
    case biometricFailure
    case mfaFailure
    case accountLocked
}

// Model and verify properties like:
// 1. Authentication attempts should be rate-limited to prevent brute force
// 2. Users should always be able to get back to the login screen
// 3. Biometric verification should time out if inactive
// 4. Multiple failed attempts should trigger account locking
// 5. Network failures should allow retry without losing credentials
```

### E-commerce Checkout Process

Model a checkout flow and verify properties like order completion, inventory checking, and payment processing:

```swift
enum CheckoutState: Hashable {
    case cart
    case addressEntry
    case shippingOptions
    case paymentEntry
    case processingPayment
    case orderConfirmation
    case orderComplete
    case error(CheckoutError)
}

enum CheckoutError: Hashable {
    case paymentFailure
    case inventoryUnavailable
    case shippingUnavailable
    case addressValidationFailed
}

// Model and verify properties like:
// 1. Payment should only be processed after address and shipping are confirmed
// 2. Inventory check should happen before payment processing
// 3. Users can always return to previous checkout steps
// 4. Payment failures should not lose customer data
// 5. Order should not be marked complete until payment is successful
```

### Content Loading and Caching

Model content loading with caching and pagination, verifying properties about data freshness and loading states:

```swift
enum ContentLoadingState: Hashable {
    case idle
    case checkingCache
    case usingCachedData
    case fetchingFirstPage
    case fetchingNextPage
    case refreshing
    case loaded(hasMore: Bool)
    case empty
    case error(ContentLoadingError)
}

enum ContentLoadingError: Hashable {
    case network
    case parsing
    case serverError
}

// Model and verify properties like:
// 1. Initial loads should check cache before network
// 2. Pagination should preserve existing content
// 3. Refresh should invalidate cache
// 4. Error states should allow retry
// 5. Empty state should be distinguishable from error states
```

## Integration with Testing

### Unit Testing

Integrate TemporalKit verification into your unit tests:

```swift
func testAuthenticationFlow() {
    let modelChecker = LTLModelChecker<AuthStateModel>()
    let authModel = AuthStateModel()
    
    // Define critical properties
    let errorRecovery: LTLFormula<AuthProp> = .globally(
        .implies(.atomic(hasError), .eventually(.atomic(isLoggedOut)))
    )
    
    // Verify and assert
    do {
        let result = try modelChecker.check(formula: errorRecovery, model: authModel)
        XCTAssertTrue(result.holds, "Authentication error recovery property should hold")
    } catch {
        XCTFail("Verification failed with error: \(error)")
    }
}
```

### UI Testing

Use TemporalKit to define expected behavior for UI tests:

```swift
// Define a model of expected UI state transitions
struct LoginScreenModel: KripkeStructure {
    // Implementation details omitted for brevity
}

// In UI test:
func testLoginScreenBehavior() {
    // Perform UI testing...
    
    // Verify model properties
    let modelChecker = LTLModelChecker<LoginScreenModel>()
    let screenModel = LoginScreenModel()
    
    do {
        let result = try modelChecker.check(formula: loginButtonEnablement, model: screenModel)
        XCTAssertTrue(result.holds, "Login button should only be enabled when credentials are valid")
    } catch {
        XCTFail("Verification failed with error: \(error)")
    }
}
```

### CI/CD Integration

Incorporate TemporalKit verification into your CI/CD pipeline:

```swift
// Create a verification suite
struct AppVerificationSuite {
    static func verifyAllProperties() throws -> VerificationReport {
        var report = VerificationReport()
        
        // Authentication properties
        report.authResults = try verifyAuthFlow()
        
        // Navigation properties
        report.navResults = try verifyNavigation()
        
        // Network properties
        report.networkResults = try verifyNetworkBehavior()
        
        return report
    }
    
    // Implementation details omitted for brevity
}

// In CI script:
do {
    let report = try AppVerificationSuite.verifyAllProperties()
    if !report.allPropertiesHold {
        throw Error("Critical temporal properties failed verification")
    }
} catch {
    print("Verification failed: \(error)")
    exit(1)
}
```

## Best Practices

1. **Start Small**: Begin by modeling and verifying small, critical components before tackling the entire application.

2. **Focus on Critical Properties**: Not everything needs formal verification. Focus on:
   - Error recovery paths
   - Authentication and security flows
   - Financial transactions
   - Data persistence guarantees
   - Critical user journeys

3. **Incremental Adoption**: Add TemporalKit verification gradually:
   - Start with a single feature or component
   - Add to critical path testing first
   - Gradually expand coverage

4. **Keep Models Updated**: When application behavior changes, update your Kripke structures and formulas.

5. **Use Clear Naming**: Name propositions and formulas clearly to make counterexamples understandable.

6. **Separate Models from Implementation**: Your verification model should describe expected behavior, not duplicate implementation details.

7. **Consider Performance**: For large state spaces, verify subcomponents separately.

## Performance Considerations

1. **State Space Size**: The number of states in your model significantly impacts verification performance. Start with abstract models that focus on essential states.

2. **Formula Complexity**: Complex nested formulas can slow down verification. Break complex properties into smaller, composable formulas.

3. **Incremental Verification**: Verify simple properties first, then add complexity.

4. **Developer Loop**: Run verification as part of your tests, not in production code.

5. **Counterexample Analysis**: When a property fails, analyze the counterexample carefully. It often reveals subtle bugs or missing requirements.

## Troubleshooting

### Common Issues

1. **Verification Taking Too Long**:
   - Your state space may be too large
   - Try simplifying your model or breaking it into smaller components
   - Focus on critical subsets of behavior

2. **Unexpected Counterexamples**:
   - Carefully review your model transitions
   - Check that your property correctly expresses the desired behavior
   - Ensure your propositions evaluate correctly

3. **Formula Expression Challenges**:
   - Start with simple patterns (safety, liveness, fairness)
   - Build more complex formulas incrementally
   - Use helper functions to construct common patterns

## Advanced Topics

### Parameterized Models

Create models that can be configured for different scenarios:

```swift
struct ConfigurableAuthFlow: KripkeStructure {
    let maxLoginAttempts: Int
    let requiresMFA: Bool
    let supportsBiometrics: Bool
    
    // Implementation using these parameters
}
```

### Combined Model Checking and Runtime Verification

Use TemporalKit both for static verification and runtime monitoring:

```swift
// Define your properties once
let criticalProperty: LTLFormula<AppProp> = // ...

// Use for static verification
let modelChecker = LTLModelChecker<AppModel>()
let staticResult = try modelChecker.check(formula: criticalProperty, model: appModel)

// Also use for runtime monitoring
let traceEvaluator = LTLFormulaTraceEvaluator<AppProp>()
let runtime = appStateRecorder.captureStates() // Your state capturing mechanism
let runtimeResult = try traceEvaluator.evaluate(formula: criticalProperty, trace: runtime)
```

### Domain-Specific Property Patterns

Create helper functions for common patterns in your domain:

```swift
// Helper for "this state always leads to that state"
func alwaysLeadsTo<P: TemporalProposition>(
    from: P, 
    to: P
) -> LTLFormula<P> {
    return .globally(.implies(.atomic(from), .eventually(.atomic(to))))
}

// Helper for "these states should alternate"
func alternating<P: TemporalProposition>(
    first: P,
    second: P
) -> LTLFormula<P> {
    return .globally(.implies(
        .atomic(first),
        .next(.until(.not(.atomic(first)), .atomic(second)))
    ))
}

// Using these helpers
let buttonToConfirmation = alwaysLeadsTo(from: isSubmitButtonPressed, to: isConfirmationShown)
```

By following this guide, iOS developers can leverage TemporalKit to formally verify critical behaviors in their applications, resulting in more robust and reliable software.
