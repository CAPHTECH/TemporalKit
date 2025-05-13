# TemporalKit by Example

This tutorial demonstrates how to apply TemporalKit to real-world use cases. Through concrete scenarios, you'll learn practical applications of formal verification.

## Objectives

By the end of this tutorial, you will be able to:

- Apply TemporalKit to practical applications
- Explore examples from various domains (UI, network, state management, etc.)
- Integrate TemporalKit into your everyday development processes

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts
- Completion of the [Basic Usage](./BasicUsage.md) tutorial

## Example 1: Authentication Flow Verification

Let's look at how to verify a user authentication flow using TemporalKit.

```swift
import TemporalKit

// User authentication states
enum AuthState: Hashable, CustomStringConvertible {
    case loggedOut
    case loggingIn
    case loginFailed(reason: String)
    case loggedIn(user: String)
    
    var description: String {
        switch self {
        case .loggedOut: return "Logged Out"
        case .loggingIn: return "Logging In"
        case .loginFailed(let reason): return "Login Failed: \(reason)"
        case .loggedIn(let user): return "Logged In: \(user)"
        }
    }
}

// Authentication flow events
enum AuthEvent: Hashable {
    case attemptLogin(username: String, password: String)
    case loginSucceeded(user: String)
    case loginFailed(reason: String)
    case logout
}

// Authentication system Kripke structure
struct AuthSystem: KripkeStructure {
    typealias State = AuthState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State> = [.loggedOut]
    
    var allStates: Set<State> {
        // In a real application, states would be generated dynamically
        [.loggedOut, .loggingIn, .loginFailed(reason: "Authentication failed"), .loggedIn(user: "user123")]
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .loggedOut:
            return [.loggedOut, .loggingIn]
            
        case .loggingIn:
            return [.loggingIn, .loggedIn(user: "user123"), .loginFailed(reason: "Authentication failed")]
            
        case .loginFailed:
            return [.loginFailed(reason: "Authentication failed"), .loggedOut, .loggingIn]
            
        case .loggedIn:
            return [.loggedIn(user: "user123"), .loggedOut]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .loggedOut:
            props.insert("isLoggedOut")
            
        case .loggingIn:
            props.insert("isLoggingIn")
            
        case .loginFailed(let reason):
            props.insert("isLoginFailed")
            props.insert("loginFailedReason_\(reason)")
            
        case .loggedIn(let user):
            props.insert("isLoggedIn")
            props.insert("loggedInUser_\(user)")
        }
        
        return props
    }
}

// Authentication propositions
let isLoggedOut = TemporalKit.makeProposition(
    id: "isLoggedOut",
    name: "User is logged out",
    evaluate: { (state: AuthState) -> Bool in
        if case .loggedOut = state { return true }
        return false
    }
)

let isLoggingIn = TemporalKit.makeProposition(
    id: "isLoggingIn",
    name: "Login in progress",
    evaluate: { (state: AuthState) -> Bool in
        if case .loggingIn = state { return true }
        return false
    }
)

let isLoginFailed = TemporalKit.makeProposition(
    id: "isLoginFailed",
    name: "Login failed",
    evaluate: { (state: AuthState) -> Bool in
        if case .loginFailed = state { return true }
        return false
    }
)

let isLoggedIn = TemporalKit.makeProposition(
    id: "isLoggedIn",
    name: "User is logged in",
    evaluate: { (state: AuthState) -> Bool in
        if case .loggedIn = state { return true }
        return false
    }
)

// LTL formulas for authentication flow
typealias AuthProp = ClosureTemporalProposition<AuthState, Bool>
typealias AuthLTL = LTLFormula<AuthProp>

// Property 1: "After a login attempt, eventually either login succeeds or fails"
let loginEventuallyResolves = AuthLTL.implies(
    .atomic(isLoggingIn),
    .eventually(
        .or(
            .atomic(isLoggedIn),
            .atomic(isLoginFailed)
        )
    )
)

// Property 2: "Once logged in, the user remains logged in until logging out"
let loginStateMaintained = AuthLTL.implies(
    .atomic(isLoggedIn),
    .until(
        .atomic(isLoggedIn),
        .atomic(isLoggedOut)
    )
)

// Property 3: "After login failure, the user can retry logging in or go back to logged out state"
let canRetryAfterFailure = AuthLTL.implies(
    .atomic(isLoginFailed),
    .next(
        .or(
            .atomic(isLoggingIn),
            .atomic(isLoggedOut)
        )
    )
)

// Run verification
let authSystem = AuthSystem()
let modelChecker = LTLModelChecker<AuthSystem>()

do {
    let result1 = try modelChecker.check(formula: loginEventuallyResolves, model: authSystem)
    let result2 = try modelChecker.check(formula: loginStateMaintained, model: authSystem)
    let result3 = try modelChecker.check(formula: canRetryAfterFailure, model: authSystem)
    
    print("Authentication Flow Verification Results:")
    print("1. Login attempts resolve: \(result1.holds ? "Valid" : "Invalid")")
    print("2. Login state maintenance: \(result2.holds ? "Valid" : "Invalid")")
    print("3. Retry after failure: \(result3.holds ? "Valid" : "Invalid")")
} catch {
    print("Verification error: \(error)")
}
```

## Example 2: Network Request State Management

Let's explore how to verify the lifecycle of network requests using TemporalKit.

```swift
import TemporalKit

// Network request states
enum NetworkRequestState: Hashable, CustomStringConvertible {
    case idle
    case loading
    case success(data: String)
    case failure(error: String)
    case cancelled
    
    var description: String {
        switch self {
        case .idle: return "Idle"
        case .loading: return "Loading"
        case .success(let data): return "Success: \(data)"
        case .failure(let error): return "Failure: \(error)"
        case .cancelled: return "Cancelled"
        }
    }
}

// Network request Kripke structure
struct NetworkRequestSystem: KripkeStructure {
    typealias State = NetworkRequestState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State> = [.idle]
    
    var allStates: Set<State> {
        [.idle, .loading, .success(data: "Response Data"), .failure(error: "Network Error"), .cancelled]
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .idle:
            return [.idle, .loading]
            
        case .loading:
            return [.loading, .success(data: "Response Data"), .failure(error: "Network Error"), .cancelled]
            
        case .success:
            return [.success(data: "Response Data"), .idle]
            
        case .failure:
            return [.failure(error: "Network Error"), .idle, .loading]
            
        case .cancelled:
            return [.cancelled, .idle]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .idle:
            props.insert("isIdle")
            
        case .loading:
            props.insert("isLoading")
            
        case .success:
            props.insert("isSuccess")
            
        case .failure:
            props.insert("isFailure")
            
        case .cancelled:
            props.insert("isCancelled")
        }
        
        return props
    }
}

// Network request propositions
let isIdle = TemporalKit.makeProposition(
    id: "isIdle",
    name: "Idle state",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .idle = state { return true }
        return false
    }
)

let isLoading = TemporalKit.makeProposition(
    id: "isLoading",
    name: "Loading in progress",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .loading = state { return true }
        return false
    }
)

let isSuccess = TemporalKit.makeProposition(
    id: "isSuccess",
    name: "Success state",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .success = state { return true }
        return false
    }
)

let isFailure = TemporalKit.makeProposition(
    id: "isFailure",
    name: "Failure state",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .failure = state { return true }
        return false
    }
)

let isCancelled = TemporalKit.makeProposition(
    id: "isCancelled",
    name: "Cancelled state",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .cancelled = state { return true }
        return false
    }
)

// LTL formulas for network requests
typealias NetworkProp = ClosureTemporalProposition<NetworkRequestState, Bool>
typealias NetworkLTL = LTLFormula<NetworkProp>

// Property 1: "From loading state, the request eventually reaches success, failure, or cancellation"
let loadingEventuallyCompletes = NetworkLTL.implies(
    .atomic(isLoading),
    .eventually(
        .or(
            .atomic(isSuccess),
            .atomic(isFailure),
            .atomic(isCancelled)
        )
    )
)

// Property 2: "After success or failure, the system can return to idle state"
let canRestartAfterCompletion = NetworkLTL.implies(
    .or(
        .atomic(isSuccess),
        .atomic(isFailure)
    ),
    .eventually(.atomic(isIdle))
)

// Property 3: "Requests always start from idle state"
let alwaysStartsFromIdle = NetworkLTL.implies(
    .atomic(isLoading),
    .previously(.atomic(isIdle))
)

// Run verification
let networkSystem = NetworkRequestSystem()
let networkModelChecker = LTLModelChecker<NetworkRequestSystem>()

do {
    let result1 = try networkModelChecker.check(formula: loadingEventuallyCompletes, model: networkSystem)
    let result2 = try networkModelChecker.check(formula: canRestartAfterCompletion, model: networkSystem)
    
    print("\nNetwork Request Verification Results:")
    print("1. Loading state completion: \(result1.holds ? "Valid" : "Invalid")")
    print("2. Restart after completion: \(result2.holds ? "Valid" : "Invalid")")
} catch {
    print("Verification error: \(error)")
}
```

## Example 3: Shopping Cart Workflow

Let's verify the state transitions of a shopping cart in an e-commerce application.

```swift
import TemporalKit

// Cart state
struct CartState: Hashable, CustomStringConvertible {
    let items: [String]
    let isCheckingOut: Bool
    let isPaymentProcessing: Bool
    let orderCompleted: Bool
    let hasError: Bool
    
    var description: String {
        let itemsDesc = items.isEmpty ? "empty" : items.joined(separator: ", ")
        var stateDesc = "Cart[\(itemsDesc)]"
        
        if isCheckingOut { stateDesc += ", checking out" }
        if isPaymentProcessing { stateDesc += ", processing payment" }
        if orderCompleted { stateDesc += ", order completed" }
        if hasError { stateDesc += ", error occurred" }
        
        return stateDesc
    }
}

// Shopping cart Kripke structure
struct ShoppingCartSystem: KripkeStructure {
    typealias State = CartState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State> = [CartState(
        items: [],
        isCheckingOut: false,
        isPaymentProcessing: false,
        orderCompleted: false,
        hasError: false
    )]
    
    var allStates: Set<State> {
        // In a real application, states would be generated dynamically
        // Here we return sample states for simplicity
        [
            CartState(items: [], isCheckingOut: false, isPaymentProcessing: false, orderCompleted: false, hasError: false),
            CartState(items: ["Product A"], isCheckingOut: false, isPaymentProcessing: false, orderCompleted: false, hasError: false),
            CartState(items: ["Product A"], isCheckingOut: true, isPaymentProcessing: false, orderCompleted: false, hasError: false),
            CartState(items: ["Product A"], isCheckingOut: true, isPaymentProcessing: true, orderCompleted: false, hasError: false),
            CartState(items: ["Product A"], isCheckingOut: false, isPaymentProcessing: false, orderCompleted: true, hasError: false),
            CartState(items: ["Product A"], isCheckingOut: false, isPaymentProcessing: false, orderCompleted: false, hasError: true)
        ]
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Add product (maximum of 2)
        if state.items.count < 2 && !state.isCheckingOut && !state.isPaymentProcessing && !state.orderCompleted {
            var newItems = state.items
            newItems.append("New Product")
            nextStates.insert(CartState(
                items: newItems,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // Remove product
        if !state.items.isEmpty && !state.isCheckingOut && !state.isPaymentProcessing && !state.orderCompleted {
            var newItems = state.items
            newItems.removeLast()
            nextStates.insert(CartState(
                items: newItems,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // Start checkout
        if !state.items.isEmpty && !state.isCheckingOut && !state.isPaymentProcessing && !state.orderCompleted && !state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: true,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // Start payment processing
        if state.isCheckingOut && !state.isPaymentProcessing && !state.orderCompleted && !state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: true,
                isPaymentProcessing: true,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // Complete order
        if state.isPaymentProcessing && !state.orderCompleted && !state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: true,
                hasError: false
            ))
        }
        
        // Error occurrence
        if (state.isCheckingOut || state.isPaymentProcessing) && !state.orderCompleted && !state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: true
            ))
        }
        
        // Reset error
        if state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // Include current state in successors
        nextStates.insert(state)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        if state.items.isEmpty {
            props.insert("cartEmpty")
        } else {
            props.insert("hasItems")
        }
        
        if state.isCheckingOut {
            props.insert("isCheckingOut")
        }
        
        if state.isPaymentProcessing {
            props.insert("isPaymentProcessing")
        }
        
        if state.orderCompleted {
            props.insert("orderCompleted")
        }
        
        if state.hasError {
            props.insert("hasError")
        }
        
        return props
    }
}

// Cart propositions
let cartEmpty = TemporalKit.makeProposition(
    id: "cartEmpty",
    name: "Cart is empty",
    evaluate: { (state: CartState) -> Bool in
        state.items.isEmpty
    }
)

let hasItems = TemporalKit.makeProposition(
    id: "hasItems",
    name: "Cart has items",
    evaluate: { (state: CartState) -> Bool in
        !state.items.isEmpty
    }
)

let isCheckingOut = TemporalKit.makeProposition(
    id: "isCheckingOut",
    name: "Checking out",
    evaluate: { (state: CartState) -> Bool in
        state.isCheckingOut
    }
)

let isPaymentProcessing = TemporalKit.makeProposition(
    id: "isPaymentProcessing",
    name: "Processing payment",
    evaluate: { (state: CartState) -> Bool in
        state.isPaymentProcessing
    }
)

let orderCompleted = TemporalKit.makeProposition(
    id: "orderCompleted",
    name: "Order completed",
    evaluate: { (state: CartState) -> Bool in
        state.orderCompleted
    }
)

let hasError = TemporalKit.makeProposition(
    id: "hasError",
    name: "Error occurred",
    evaluate: { (state: CartState) -> Bool in
        state.hasError
    }
)

// LTL formulas for cart
typealias CartProp = ClosureTemporalProposition<CartState, Bool>
typealias CartLTL = LTLFormula<CartProp>

// Property 1: "Payment processing must be preceded by checkout"
let paymentRequiresCheckout = CartLTL.implies(
    .atomic(isPaymentProcessing),
    .previously(.atomic(isCheckingOut))
)

// Property 2: "Order completion must be preceded by payment processing"
let orderRequiresPayment = CartLTL.implies(
    .atomic(orderCompleted),
    .previously(.atomic(isPaymentProcessing))
)

// Property 3: "After an error occurs, checkout can be attempted again"
let canRecoverFromError = CartLTL.implies(
    .atomic(hasError),
    .eventually(.atomic(isCheckingOut))
)

// Property 4: "Empty cart cannot proceed to checkout"
let emptyCartCannotCheckout = CartLTL.implies(
    .atomic(cartEmpty),
    .globally(.not(.atomic(isCheckingOut)))
)

// Run verification
let cartSystem = ShoppingCartSystem()
let cartModelChecker = LTLModelChecker<ShoppingCartSystem>()

do {
    let result1 = try cartModelChecker.check(formula: paymentRequiresCheckout, model: cartSystem)
    let result2 = try cartModelChecker.check(formula: orderRequiresPayment, model: cartSystem)
    let result3 = try cartModelChecker.check(formula: canRecoverFromError, model: cartSystem)
    let result4 = try cartModelChecker.check(formula: emptyCartCannotCheckout, model: cartSystem)
    
    print("\nShopping Cart Verification Results:")
    print("1. Payment requires checkout: \(result1.holds ? "Valid" : "Invalid")")
    print("2. Order requires payment: \(result2.holds ? "Valid" : "Invalid")")
    print("3. Recovery from error: \(result3.holds ? "Valid" : "Invalid")")
    print("4. Empty cart checkout prevention: \(result4.holds ? "Valid" : "Invalid")")
} catch {
    print("Verification error: \(error)")
}
```

## Example 4: Push Notification Permission Flow

Let's verify the push notification permission request flow.

```swift
import TemporalKit

// Notification permission states
enum NotificationPermissionState: Hashable, CustomStringConvertible {
    case notRequested
    case requesting
    case allowed
    case denied
    
    var description: String {
        switch self {
        case .notRequested: return "Not Requested"
        case .requesting: return "Requesting"
        case .allowed: return "Allowed"
        case .denied: return "Denied"
        }
    }
}

// Notification permission Kripke structure
struct NotificationPermissionSystem: KripkeStructure {
    typealias State = NotificationPermissionState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State> = [.notRequested]
    
    var allStates: Set<State> {
        [.notRequested, .requesting, .allowed, .denied]
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .notRequested:
            return [.notRequested, .requesting]
            
        case .requesting:
            return [.requesting, .allowed, .denied]
            
        case .allowed, .denied:
            // Once permission is decided, it cannot be changed (ignoring system settings)
            return [state]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .notRequested:
            props.insert("notRequested")
            
        case .requesting:
            props.insert("requesting")
            
        case .allowed:
            props.insert("allowed")
            
        case .denied:
            props.insert("denied")
        }
        
        return props
    }
}

// Permission propositions
let notRequested = TemporalKit.makeProposition(
    id: "notRequested",
    name: "Permission not requested",
    evaluate: { (state: NotificationPermissionState) -> Bool in
        state == .notRequested
    }
)

let requesting = TemporalKit.makeProposition(
    id: "requesting",
    name: "Requesting permission",
    evaluate: { (state: NotificationPermissionState) -> Bool in
        state == .requesting
    }
)

let allowed = TemporalKit.makeProposition(
    id: "allowed",
    name: "Permission allowed",
    evaluate: { (state: NotificationPermissionState) -> Bool in
        state == .allowed
    }
)

let denied = TemporalKit.makeProposition(
    id: "denied",
    name: "Permission denied",
    evaluate: { (state: NotificationPermissionState) -> Bool in
        state == .denied
    }
)

// LTL formulas for permissions
typealias PermissionProp = ClosureTemporalProposition<NotificationPermissionState, Bool>
typealias PermissionLTL = LTLFormula<PermissionProp>

// Property 1: "Permission requests can only be initiated from not requested state"
let requestOnlyFromNotRequested = PermissionLTL.implies(
    .atomic(requesting),
    .previously(.atomic(notRequested))
)

// Property 2: "From requesting state, the permission is eventually allowed or denied"
let requestEventuallyResolves = PermissionLTL.implies(
    .atomic(requesting),
    .eventually(
        .or(
            .atomic(allowed),
            .atomic(denied)
        )
    )
)

// Property 3: "Once allowed or denied, the permission state persists"
let permissionStateIsPersistent = PermissionLTL.implies(
    .or(
        .atomic(allowed),
        .atomic(denied)
    ),
    .globally(
        .or(
            .atomic(allowed),
            .atomic(denied)
        )
    )
)

// Run verification
let permissionSystem = NotificationPermissionSystem()
let permissionModelChecker = LTLModelChecker<NotificationPermissionSystem>()

do {
    let result1 = try permissionModelChecker.check(formula: requestOnlyFromNotRequested, model: permissionSystem)
    let result2 = try permissionModelChecker.check(formula: requestEventuallyResolves, model: permissionSystem)
    let result3 = try permissionModelChecker.check(formula: permissionStateIsPersistent, model: permissionSystem)
    
    print("\nNotification Permission Flow Verification Results:")
    print("1. Request initiation condition: \(result1.holds ? "Valid" : "Invalid")")
    print("2. Request resolution guarantee: \(result2.holds ? "Valid" : "Invalid")")
    print("3. Permission state persistence: \(result3.holds ? "Valid" : "Invalid")")
} catch {
    print("Verification error: \(error)")
}
```

## Summary

In this tutorial, we explored how to apply TemporalKit to real-world use cases. We learned through these examples:

1. Authentication Flow Verification - Verifying login state transitions and maintenance
2. Network Request State Management - Guaranteeing asynchronous process completion
3. Shopping Cart Workflow - Verifying e-commerce ordering processes
4. Push Notification Permission Flow - Verifying permission requests and outcomes

These examples demonstrate that TemporalKit can be effectively used across various application domains, particularly for:

- User interface state transitions
- Asynchronous process lifecycle management
- Complex business logic verification
- Security flows like permissions and authentication

By incorporating formal verification into your development process, you can detect edge cases and logical errors that might be difficult to discover through testing alone, leading to more robust applications.

## Next Steps

- Learn how to efficiently verify large models in [Optimizing Performance](./OptimizingPerformance.md).
- Discover how to integrate TemporalKit verification into your CI pipeline in [Integrating with Tests](./IntegratingWithTests.md). 
