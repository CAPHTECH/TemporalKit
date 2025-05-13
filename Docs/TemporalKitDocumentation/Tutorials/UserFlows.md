# Verifying User Flows

This tutorial explains how to use TemporalKit to model and verify user flows in iOS applications. User flows represent the paths users can take through your application, and formal verification can help ensure these flows work correctly.

## Prerequisites

Before starting this tutorial, make sure you have:

- Completed the [Basic Usage](./BasicUsage.md) tutorial
- Completed the [Modeling State Machines](./StateMachines.md) tutorial
- Understood the concept of LTL formulas from [Core Concepts](../CoreConcepts.md)
- Imported TemporalKit in your project

## Understanding User Flows

User flows are sequences of screens, interactions, and states that users navigate through to accomplish tasks in your application. Common examples include:

- Registration and login flows
- Checkout processes in e-commerce apps
- Multi-step form completions
- Onboarding sequences
- Navigation through different app sections

Verifying user flows ensures that:

- Users can always accomplish their intended tasks
- No dead ends exist in the user interface
- Required steps cannot be bypassed
- Error states are handled appropriately
- The application behaves consistently

## 1. Modeling User Flow States

First, define the states in your user flow. For a typical iOS app, states often correspond to screens or views:

```swift
import TemporalKit

// Define states for an e-commerce checkout flow
enum CheckoutState: Hashable {
    case cart
    case deliveryAddress
    case paymentMethod
    case orderReview
    case processingPayment
    case orderConfirmation
    case orderFailed
}
```

For more complex flows, you might need additional information:

```swift
// A more detailed state model with context information
struct CheckoutStateWithContext: Hashable {
    enum Screen {
        case cart
        case deliveryAddress
        case paymentMethod
        case orderReview
        case processingPayment
        case orderConfirmation
        case orderFailed
    }
    
    let currentScreen: Screen
    let cartItems: Int
    let hasValidAddress: Bool
    let hasValidPayment: Bool
    let orderTotal: Double
}
```

## 2. Creating a User Flow Model

Next, model the user flow as a Kripke structure:

```swift
struct CheckoutFlowModel: KripkeStructure {
    typealias State = CheckoutState
    typealias AtomicPropositionIdentifier = String
    
    let allStates: Set<CheckoutState> = [
        .cart, .deliveryAddress, .paymentMethod, .orderReview,
        .processingPayment, .orderConfirmation, .orderFailed
    ]
    
    let initialStates: Set<CheckoutState> = [.cart]
    
    func successors(of state: CheckoutState) -> Set<CheckoutState> {
        switch state {
        case .cart:
            // From cart, user can proceed to delivery address or stay in cart
            return [.cart, .deliveryAddress]
            
        case .deliveryAddress:
            // From address, user can go back to cart or proceed to payment
            return [.cart, .paymentMethod]
            
        case .paymentMethod:
            // From payment, user can go back to address or proceed to review
            return [.deliveryAddress, .orderReview]
            
        case .orderReview:
            // From review, user can go back to payment or submit order
            return [.paymentMethod, .processingPayment]
            
        case .processingPayment:
            // Processing can succeed or fail
            return [.orderConfirmation, .orderFailed]
            
        case .orderConfirmation:
            // From confirmation, can go back to cart (for new order)
            return [.cart]
            
        case .orderFailed:
            // From failure, can try again (review) or start over (cart)
            return [.orderReview, .cart]
        }
    }
    
    func atomicPropositionsTrue(in state: CheckoutState) -> Set<String> {
        switch state {
        case .cart:
            return ["inCart", "canModifyOrder"]
        case .deliveryAddress:
            return ["inAddress", "canModifyOrder"]
        case .paymentMethod:
            return ["inPayment", "canModifyOrder"]
        case .orderReview:
            return ["inReview", "canModifyOrder"]
        case .processingPayment:
            return ["processing", "waitingForServer"]
        case .orderConfirmation:
            return ["orderComplete", "orderSuccessful"]
        case .orderFailed:
            return ["orderComplete", "orderFailed"]
        }
    }
}
```

## 3. Creating Propositions

Now define propositions to represent important aspects of the user flow:

```swift
// Create propositions for the checkout flow
let inCart = TemporalKit.makeProposition(
    id: "inCart",
    name: "User is viewing cart",
    evaluate: { (state: CheckoutState) -> Bool in
        return state == .cart
    }
)

let inPaymentProcess = TemporalKit.makeProposition(
    id: "inPaymentProcess",
    name: "User is in payment process",
    evaluate: { (state: CheckoutState) -> Bool in
        return [.paymentMethod, .processingPayment].contains(state)
    }
)

let orderCompleted = TemporalKit.makeProposition(
    id: "orderCompleted",
    name: "Order has been completed",
    evaluate: { (state: CheckoutState) -> Bool in
        return [.orderConfirmation, .orderFailed].contains(state)
    }
)

let canNavigateBack = TemporalKit.makeProposition(
    id: "canNavigateBack",
    name: "User can navigate back",
    evaluate: { (state: CheckoutState) -> Bool in
        return [.deliveryAddress, .paymentMethod, .orderReview].contains(state)
    }
)
```

## 4. Verifying User Flow Properties

Define and verify important properties of your user flow:

```swift
// Create a model checker
let modelChecker = LTLModelChecker<CheckoutFlowModel>()
let model = CheckoutFlowModel()

// Property 1: Users can always complete the checkout process
let canCompleteCheckout = LTLFormula<ClosureTemporalProposition<CheckoutState, Bool>>.globally(
    .implies(
        .atomic(inCart),
        .eventually(.atomic(orderCompleted))
    )
)

// Property 2: Users can always return to the cart
let canReturnToCart = LTLFormula<ClosureTemporalProposition<CheckoutState, Bool>>.globally(
    .eventually(.atomic(inCart))
)

// Property 3: Payment processing always leads to a definitive outcome
let paymentProcessResolution = LTLFormula<ClosureTemporalProposition<CheckoutState, Bool>>.globally(
    .implies(
        .atomic(TemporalKit.makeProposition(
            id: "processing",
            name: "Processing payment",
            evaluate: { $0 == .processingPayment }
        )),
        .eventually(
            .or(
                .atomic(TemporalKit.makeProposition(
                    id: "success",
                    name: "Order succeeded",
                    evaluate: { $0 == .orderConfirmation }
                )),
                .atomic(TemporalKit.makeProposition(
                    id: "failure",
                    name: "Order failed",
                    evaluate: { $0 == .orderFailed }
                ))
            )
        )
    )
)

// Verify the properties
do {
    let result1 = try modelChecker.check(formula: canCompleteCheckout, model: model)
    print("Can complete checkout: \(result1)")
    
    let result2 = try modelChecker.check(formula: canReturnToCart, model: model)
    print("Can return to cart: \(result2)")
    
    let result3 = try modelChecker.check(formula: paymentProcessResolution, model: model)
    print("Payment processing resolves: \(result3)")
} catch {
    print("Verification error: \(error)")
}
```

## 5. Modeling Multi-Screen Navigation Flows

Let's model a more complex app navigation flow:

```swift
// Define states for a social media app navigation flow
enum AppScreen: Hashable {
    case login
    case home
    case profile
    case friendsList
    case settings
    case newPost
    case notifications
    case viewPost(Int) // Post ID as associated value
    case directMessages
    case search
}

struct NavigationFlowModel: KripkeStructure {
    typealias State = AppScreen
    typealias AtomicPropositionIdentifier = String
    
    // Define a limited set of post IDs for the model
    let postIDs = [1, 2, 3]
    
    var allStates: Set<AppScreen> {
        var states: Set<AppScreen> = [
            .login, .home, .profile, .friendsList, .settings,
            .newPost, .notifications, .directMessages, .search
        ]
        
        // Add view post screens for each post ID
        for id in postIDs {
            states.insert(.viewPost(id))
        }
        
        return states
    }
    
    let initialStates: Set<AppScreen> = [.login]
    
    func successors(of state: AppScreen) -> Set<AppScreen> {
        switch state {
        case .login:
            return [.home]
            
        case .home:
            var successors: Set<AppScreen> = [
                .profile, .notifications, .newPost,
                .settings, .search, .directMessages
            ]
            
            // Can view any post from home
            for id in postIDs {
                successors.insert(.viewPost(id))
            }
            
            return successors
            
        case .profile:
            return [.home, .settings, .friendsList]
            
        case .friendsList:
            return [.profile, .home]
            
        case .settings:
            return [.home, .profile, .login] // login = logout action
            
        case .newPost:
            return [.home]
            
        case .notifications:
            var successors: Set<AppScreen> = [.home]
            
            // Notifications can lead to posts or direct messages
            for id in postIDs {
                successors.insert(.viewPost(id))
            }
            successors.insert(.directMessages)
            
            return successors
            
        case .viewPost:
            return [.home, .profile, .newPost]
            
        case .directMessages:
            return [.home, .profile]
            
        case .search:
            var successors: Set<AppScreen> = [.home, .profile]
            
            // Search can lead to viewing posts
            for id in postIDs {
                successors.insert(.viewPost(id))
            }
            
            return successors
        }
    }
    
    func atomicPropositionsTrue(in state: AppScreen) -> Set<String> {
        var props: Set<String> = []
        
        switch state {
        case .login:
            props.insert("isLogin")
            props.insert("isUnauthenticated")
            
        case .home:
            props.insert("isHome")
            props.insert("isAuthenticated")
            props.insert("isMainNavigation")
            
        case .profile:
            props.insert("isProfile")
            props.insert("isAuthenticated")
            props.insert("isMainNavigation")
            
        case .friendsList:
            props.insert("isFriendsList")
            props.insert("isAuthenticated")
            
        case .settings:
            props.insert("isSettings")
            props.insert("isAuthenticated")
            
        case .newPost:
            props.insert("isNewPost")
            props.insert("isAuthenticated")
            props.insert("isCreatingContent")
            
        case .notifications:
            props.insert("isNotifications")
            props.insert("isAuthenticated")
            props.insert("isMainNavigation")
            
        case .viewPost(let id):
            props.insert("isViewingPost")
            props.insert("isAuthenticated")
            props.insert("viewingPost_\(id)")
            
        case .directMessages:
            props.insert("isDirectMessages")
            props.insert("isAuthenticated")
            props.insert("isMainNavigation")
            
        case .search:
            props.insert("isSearch")
            props.insert("isAuthenticated")
            props.insert("isMainNavigation")
        }
        
        return props
    }
}
```

## 6. Verifying Complex Navigation Properties

For complex navigation flows, verify key user experience properties:

```swift
// Create the model and model checker
let navModel = NavigationFlowModel()
let navChecker = LTLModelChecker<NavigationFlowModel>()

// Define key propositions
let isAuthenticated = TemporalKit.makeProposition(
    id: "isAuthenticated",
    name: "User is authenticated",
    evaluate: { (state: AppScreen) -> Bool in
        switch state {
        case .login:
            return false
        default:
            return true
        }
    }
)

let isMainScreen = TemporalKit.makeProposition(
    id: "isMainScreen",
    name: "User is on a main screen",
    evaluate: { (state: AppScreen) -> Bool in
        switch state {
        case .home, .profile, .notifications, .directMessages, .search:
            return true
        default:
            return false
        }
    }
)

// Property 1: Authentication is required for all screens except login
let authRequiredProperty = LTLFormula<ClosureTemporalProposition<AppScreen, Bool>>.globally(
    .implies(
        .not(.atomic(TemporalKit.makeProposition(
            id: "isLogin",
            name: "Is login screen",
            evaluate: { $0 == .login }
        ))),
        .atomic(isAuthenticated)
    )
)

// Property 2: User can always navigate back to home from any authenticated screen
let canReturnHomeProperty = LTLFormula<ClosureTemporalProposition<AppScreen, Bool>>.globally(
    .implies(
        .atomic(isAuthenticated),
        .eventually(.atomic(TemporalKit.makeProposition(
            id: "isHome",
            name: "Is home screen",
            evaluate: { $0 == .home }
        )))
    )
)

// Property 3: User can navigate between main screens without going through intermediary screens
let directMainNavigationProperty = LTLFormula<ClosureTemporalProposition<AppScreen, Bool>>.globally(
    .implies(
        .atomic(isMainScreen),
        .and(
            .next(.eventually(.atomic(TemporalKit.makeProposition(
                id: "isHome",
                name: "Is home screen",
                evaluate: { $0 == .home }
            )))),
            .next(.eventually(.atomic(TemporalKit.makeProposition(
                id: "isProfile",
                name: "Is profile screen",
                evaluate: { $0 == .profile }
            ))))
        )
    )
)

// Verify the properties
do {
    let result1 = try navChecker.check(formula: authRequiredProperty, model: navModel)
    print("Authentication required: \(result1)")
    
    let result2 = try navChecker.check(formula: canReturnHomeProperty, model: navModel)
    print("Can return to home: \(result2)")
    
    let result3 = try navChecker.check(formula: directMainNavigationProperty, model: navModel)
    print("Direct main navigation: \(result3)")
} catch {
    print("Verification error: \(error)")
}
```

## 7. Modeling Form Flows and Validation

Form handling is a common user flow that benefits from verification:

```swift
// Define states for a multi-step form
enum FormState: Hashable {
    case initial
    case step1(isValid: Bool)
    case step2(isValid: Bool)
    case step3(isValid: Bool)
    case submitting
    case success
    case error(message: String)
}

struct FormFlowModel: KripkeStructure {
    typealias State = FormState
    typealias AtomicPropositionIdentifier = String
    
    // Error messages we'll model
    let errorMessages = ["Network error", "Validation error", "Server error"]
    
    var allStates: Set<FormState> {
        var states: Set<FormState> = [
            .initial, 
            .step1(isValid: true), .step1(isValid: false),
            .step2(isValid: true), .step2(isValid: false),
            .step3(isValid: true), .step3(isValid: false),
            .submitting, .success
        ]
        
        // Add error states
        for message in errorMessages {
            states.insert(.error(message: message))
        }
        
        return states
    }
    
    let initialStates: Set<FormState> = [.initial]
    
    func successors(of state: FormState) -> Set<FormState> {
        switch state {
        case .initial:
            return [.step1(isValid: false), .step1(isValid: true)]
            
        case .step1(isValid: true):
            return [.step2(isValid: false), .step2(isValid: true)]
            
        case .step1(isValid: false):
            // Can't proceed until valid
            return [.step1(isValid: true), .step1(isValid: false), .initial]
            
        case .step2(isValid: true):
            return [.step3(isValid: false), .step3(isValid: true), .step1(isValid: true)]
            
        case .step2(isValid: false):
            // Can't proceed until valid
            return [.step2(isValid: true), .step2(isValid: false), .step1(isValid: true)]
            
        case .step3(isValid: true):
            return [.submitting, .step2(isValid: true)]
            
        case .step3(isValid: false):
            // Can't proceed until valid
            return [.step3(isValid: true), .step3(isValid: false), .step2(isValid: true)]
            
        case .submitting:
            var successors: Set<FormState> = [.success]
            
            // Add error states as possible successors
            for message in errorMessages {
                successors.insert(.error(message: message))
            }
            
            return successors
            
        case .success:
            return [.initial] // Can start over
            
        case .error:
            return [.step3(isValid: true), .initial] // Can retry or start over
        }
    }
    
    func atomicPropositionsTrue(in state: FormState) -> Set<String> {
        var props: Set<String> = []
        
        switch state {
        case .initial:
            props.insert("isInitial")
            
        case .step1(let isValid):
            props.insert("isStep1")
            if isValid {
                props.insert("isStep1Valid")
            } else {
                props.insert("isStep1Invalid")
            }
            
        case .step2(let isValid):
            props.insert("isStep2")
            if isValid {
                props.insert("isStep2Valid")
            } else {
                props.insert("isStep2Invalid")
            }
            
        case .step3(let isValid):
            props.insert("isStep3")
            if isValid {
                props.insert("isStep3Valid")
            } else {
                props.insert("isStep3Invalid")
            }
            
        case .submitting:
            props.insert("isSubmitting")
            
        case .success:
            props.insert("isSuccess")
            
        case .error(let message):
            props.insert("isError")
            props.insert("error_\(message.replacingOccurrences(of: " ", with: "_"))")
        }
        
        return props
    }
}
```

## 8. Verifying Form Flow Properties

Check key properties of form flows:

```swift
// Create the model and model checker
let formModel = FormFlowModel()
let formChecker = LTLModelChecker<FormFlowModel>()

// Define key propositions for form validation
let isStep = TemporalKit.makeProposition(
    id: "isStep",
    name: "User is on any form step",
    evaluate: { (state: FormState) -> Bool in
        switch state {
        case .step1, .step2, .step3:
            return true
        default:
            return false
        }
    }
)

let isValid = TemporalKit.makeProposition(
    id: "isValid",
    name: "Current form step is valid",
    evaluate: { (state: FormState) -> Bool in
        switch state {
        case .step1(isValid: true), .step2(isValid: true), .step3(isValid: true):
            return true
        default:
            return false
        }
    }
)

let canSubmit = TemporalKit.makeProposition(
    id: "canSubmit",
    name: "Form can be submitted",
    evaluate: { (state: FormState) -> Bool in
        if case .step3(isValid: true) = state {
            return true
        }
        return false
    }
)

// Property 1: Invalid steps cannot proceed to the next step
let invalidCannotProceedProperty = LTLFormula<ClosureTemporalProposition<FormState, Bool>>.globally(
    .implies(
        .and(
            .atomic(isStep),
            .not(.atomic(isValid))
        ),
        .next(.not(.atomic(TemporalKit.makeProposition(
            id: "nextStep",
            name: "Next form step",
            evaluate: { state in
                switch state {
                case .step1:
                    return false
                case .step2 where isStep.evaluate(SimpleEvaluationContext(input: FormState.step1(isValid: true))):
                    return true
                case .step3 where isStep.evaluate(SimpleEvaluationContext(input: FormState.step2(isValid: true))):
                    return true
                case .submitting where isStep.evaluate(SimpleEvaluationContext(input: FormState.step3(isValid: true))):
                    return true
                default:
                    return false
                }
            }
        ))))
    )
)

// Property 2: Form can always be completed if steps are valid
let canCompleteFormProperty = LTLFormula<ClosureTemporalProposition<FormState, Bool>>.globally(
    .implies(
        .atomic(isValid),
        .eventually(.atomic(TemporalKit.makeProposition(
            id: "formDone",
            name: "Form completed",
            evaluate: { 
                if case .success = $0 { return true }
                return false
            }
        )))
    )
)

// Property 3: Only valid final step can lead to submission
let validSubmissionProperty = LTLFormula<ClosureTemporalProposition<FormState, Bool>>.globally(
    .implies(
        .atomic(TemporalKit.makeProposition(
            id: "isSubmitting",
            name: "Form is submitting",
            evaluate: { 
                if case .submitting = $0 { return true }
                return false
            }
        )),
        .once(.atomic(canSubmit))
    )
)

// Verify the form properties
do {
    let result1 = try formChecker.check(formula: invalidCannotProceedProperty, model: formModel)
    print("Invalid cannot proceed: \(result1)")
    
    let result2 = try formChecker.check(formula: canCompleteFormProperty, model: formModel)
    print("Can complete form: \(result2)")
    
    let result3 = try formChecker.check(formula: validSubmissionProperty, model: formModel)
    print("Valid submission: \(result3)")
} catch {
    print("Verification error: \(error)")
}

// Helper for evaluating propositions with simple context
struct SimpleEvaluationContext<Input>: EvaluationContext {
    let input: Input
}
```

## 9. Integrating with SwiftUI Navigation

Here's how to integrate the verified user flow model with SwiftUI navigation:

```swift
import SwiftUI

// A view model that uses the verified navigation model
class AppNavigationViewModel: ObservableObject {
    @Published var currentScreen: AppScreen = .login
    
    private let navigationModel = NavigationFlowModel()
    
    func navigate(to newScreen: AppScreen) {
        // Get valid next screens from model
        let validNextScreens = navigationModel.successors(of: currentScreen)
        
        guard validNextScreens.contains(newScreen) else {
            print("Error: Invalid navigation from \(currentScreen) to \(newScreen)")
            return
        }
        
        // Perform navigation
        currentScreen = newScreen
    }
    
    func goToHome() {
        navigate(to: .home)
    }
    
    func goToProfile() {
        navigate(to: .profile)
    }
    
    func viewPost(_ id: Int) {
        navigate(to: .viewPost(id))
    }
    
    func logout() {
        navigate(to: .login)
    }
    
    // Additional navigation helpers...
}

// SwiftUI view using the navigation view model
struct AppNavigationView: View {
    @StateObject private var viewModel = AppNavigationViewModel()
    
    var body: some View {
        Group {
            switch viewModel.currentScreen {
            case .login:
                LoginView(onLogin: { viewModel.goToHome() })
                
            case .home:
                HomeView(
                    viewModel: viewModel,
                    onProfileTap: { viewModel.goToProfile() },
                    onPostTap: { id in viewModel.viewPost(id) }
                )
                
            case .profile:
                ProfileView(
                    viewModel: viewModel,
                    onLogout: { viewModel.logout() }
                )
                
            case .viewPost(let id):
                PostDetailView(
                    postID: id,
                    onBack: { viewModel.goToHome() }
                )
                
            // Handle other screens similarly...
                
            default:
                Text("Screen not implemented yet")
                    .onTapGesture {
                        viewModel.goToHome()
                    }
            }
        }
    }
}

// Simplified placeholder views for the example
struct LoginView: View {
    let onLogin: () -> Void
    
    var body: some View {
        VStack {
            Text("Login Screen")
            Button("Log in", action: onLogin)
        }
    }
}

struct HomeView: View {
    let viewModel: AppNavigationViewModel
    let onProfileTap: () -> Void
    let onPostTap: (Int) -> Void
    
    var body: some View {
        VStack {
            Text("Home Screen")
            Button("Go to Profile", action: onProfileTap)
            
            ForEach(1...3, id: \.self) { postID in
                Button("View Post \(postID)") {
                    onPostTap(postID)
                }
            }
        }
    }
}

struct ProfileView: View {
    let viewModel: AppNavigationViewModel
    let onLogout: () -> Void
    
    var body: some View {
        VStack {
            Text("Profile Screen")
            Button("Go Home") {
                viewModel.goToHome()
            }
            Button("Log out", action: onLogout)
        }
    }
}

struct PostDetailView: View {
    let postID: Int
    let onBack: () -> Void
    
    var body: some View {
        VStack {
            Text("Post \(postID) Detail")
            Button("Back", action: onBack)
        }
    }
}
```

## Conclusion

This tutorial has shown how to model and verify user flows in iOS applications using TemporalKit. By formally verifying navigation flows, form processes, and other user interactions, you can:

1. Ensure users can always complete important tasks
2. Guarantee proper validation before proceeding to next steps
3. Verify that error states are handled appropriately
4. Ensure users can always navigate to key screens

Integrating verified user flow models with your SwiftUI views helps build more reliable and user-friendly applications, as the underlying navigation logic has been proven correct through formal verification.

In the next tutorial, we'll learn how to debug counterexamples when verification finds issues in your models. 
