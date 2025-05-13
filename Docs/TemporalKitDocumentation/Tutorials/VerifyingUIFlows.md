# Verifying UI Flows

This tutorial teaches you how to verify user interface (UI) flows in iOS applications using TemporalKit.

## Objectives

By the end of this tutorial, you will be able to:

- Express UI flows as state transition models
- Describe user interaction sequences using temporal logic formulas
- Integrate UI flow verification into application testing
- Identify and fix common UI flow issues

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts
- Basic knowledge of SwiftUI is helpful but not required

## Step 1: Modeling UI Flows

First, let's model the UI flow we want to verify. As an example, we'll represent a simple shopping app flow.

```swift
import TemporalKit

// UI flow states
enum ShoppingAppScreen: Hashable, CustomStringConvertible {
    case productList
    case productDetail
    case cart
    case checkout
    case paymentMethod
    case orderConfirmation
    case error
    
    var description: String {
        switch self {
        case .productList: return "Product List"
        case .productDetail: return "Product Detail"
        case .cart: return "Cart"
        case .checkout: return "Checkout"
        case .paymentMethod: return "Payment Method"
        case .orderConfirmation: return "Order Confirmation"
        case .error: return "Error"
        }
    }
}

// Additional information for UI flow states
struct ShoppingAppState: Hashable {
    let currentScreen: ShoppingAppScreen
    let cartItemCount: Int
    let isLoggedIn: Bool
    let hasSelectedPaymentMethod: Bool
    
    // Factory method for the initial state
    static func initial() -> ShoppingAppState {
        return ShoppingAppState(
            currentScreen: .productList,
            cartItemCount: 0,
            isLoggedIn: false,
            hasSelectedPaymentMethod: false
        )
    }
}
```

## Step 2: Defining UI Flow Propositions

Next, let's define propositions to evaluate the UI flow states.

```swift
// Current screen propositions
let isOnProductList = TemporalKit.makeProposition(
    id: "isOnProductList",
    name: "Displaying product list screen",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .productList }
)

let isOnProductDetail = TemporalKit.makeProposition(
    id: "isOnProductDetail",
    name: "Displaying product detail screen",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .productDetail }
)

let isOnCart = TemporalKit.makeProposition(
    id: "isOnCart",
    name: "Displaying cart screen",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .cart }
)

let isOnCheckout = TemporalKit.makeProposition(
    id: "isOnCheckout",
    name: "Displaying checkout screen",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .checkout }
)

let isOnPaymentMethod = TemporalKit.makeProposition(
    id: "isOnPaymentMethod",
    name: "Displaying payment method screen",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .paymentMethod }
)

let isOnOrderConfirmation = TemporalKit.makeProposition(
    id: "isOnOrderConfirmation",
    name: "Displaying order confirmation screen",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .orderConfirmation }
)

let isOnErrorScreen = TemporalKit.makeProposition(
    id: "isOnErrorScreen",
    name: "Displaying error screen",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .error }
)

// App state propositions
let hasItemsInCart = TemporalKit.makeProposition(
    id: "hasItemsInCart",
    name: "Has items in cart",
    evaluate: { (state: ShoppingAppState) -> Bool in state.cartItemCount > 0 }
)

let isUserLoggedIn = TemporalKit.makeProposition(
    id: "isUserLoggedIn",
    name: "User is logged in",
    evaluate: { (state: ShoppingAppState) -> Bool in state.isLoggedIn }
)

let hasSelectedPayment = TemporalKit.makeProposition(
    id: "hasSelectedPayment",
    name: "Payment method is selected",
    evaluate: { (state: ShoppingAppState) -> Bool in state.hasSelectedPaymentMethod }
)
```

## Step 3: Implementing the UI Flow as a Kripke Structure

Next, let's implement the Kripke structure that represents the UI flow state transitions.

```swift
struct ShoppingAppFlow: KripkeStructure {
    typealias State = ShoppingAppState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State> = [ShoppingAppState.initial()]
    
    init() {
        // Enumerate all possible states
        // Note: In a real app, the number of states could be much larger (we're simplifying here)
        var states: Set<State> = []
        
        // Add combinations of screens and app states
        let screens: [ShoppingAppScreen] = [.productList, .productDetail, .cart, .checkout, .paymentMethod, .orderConfirmation, .error]
        let cartCounts: [Int] = [0, 1, 3]
        let loginStates: [Bool] = [false, true]
        let paymentStates: [Bool] = [false, true]
        
        for screen in screens {
            for count in cartCounts {
                for isLoggedIn in loginStates {
                    for hasPayment in paymentStates {
                        // Some combinations are invalid (e.g., empty cart and checkout screen)
                        if screen == .checkout && count == 0 { continue }
                        if screen == .orderConfirmation && !hasPayment { continue }
                        
                        states.insert(ShoppingAppState(
                            currentScreen: screen,
                            cartItemCount: count,
                            isLoggedIn: isLoggedIn,
                            hasSelectedPaymentMethod: hasPayment
                        ))
                    }
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Determine possible transitions based on current state
        switch state.currentScreen {
        case .productList:
            // Product list to product detail
            nextStates.insert(ShoppingAppState(
                currentScreen: .productDetail,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // Product list to cart (if cart has items)
            if state.cartItemCount > 0 {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .cart,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
        case .productDetail:
            // Product detail back to product list
            nextStates.insert(ShoppingAppState(
                currentScreen: .productList,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // Add product to cart from product detail
            nextStates.insert(ShoppingAppState(
                currentScreen: .productDetail,
                cartItemCount: state.cartItemCount + 1,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // Product detail to cart (if cart has items)
            if state.cartItemCount > 0 {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .cart,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
        case .cart:
            // Cart back to product list
            nextStates.insert(ShoppingAppState(
                currentScreen: .productList,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // Cart to checkout (if cart has items)
            if state.cartItemCount > 0 {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .checkout,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
        case .checkout:
            // Checkout to payment method selection
            nextStates.insert(ShoppingAppState(
                currentScreen: .paymentMethod,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // Checkout back to cart
            nextStates.insert(ShoppingAppState(
                currentScreen: .cart,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // If not logged in, transition to error
            if !state.isLoggedIn {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .error,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
        case .paymentMethod:
            // Select a payment method
            nextStates.insert(ShoppingAppState(
                currentScreen: .paymentMethod,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: true
            ))
            
            // Payment method back to checkout
            nextStates.insert(ShoppingAppState(
                currentScreen: .checkout,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // Payment method to order confirmation (if payment method selected)
            if state.hasSelectedPaymentMethod || state.currentScreen == .paymentMethod {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .orderConfirmation,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: true
                ))
            }
            
        case .orderConfirmation:
            // Order confirmation to product list (start over)
            nextStates.insert(ShoppingAppState(
                currentScreen: .productList,
                cartItemCount: 0, // Cart is emptied after order
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: false // Reset payment method
            ))
            
        case .error:
            // Error to product list
            nextStates.insert(ShoppingAppState(
                currentScreen: .productList,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // Error to login (set isLoggedIn to true) and back to checkout
            nextStates.insert(ShoppingAppState(
                currentScreen: .checkout,
                cartItemCount: state.cartItemCount,
                isLoggedIn: true,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
        }
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // Screen propositions
        switch state.currentScreen {
        case .productList:
            trueProps.insert(isOnProductList.id)
        case .productDetail:
            trueProps.insert(isOnProductDetail.id)
        case .cart:
            trueProps.insert(isOnCart.id)
        case .checkout:
            trueProps.insert(isOnCheckout.id)
        case .paymentMethod:
            trueProps.insert(isOnPaymentMethod.id)
        case .orderConfirmation:
            trueProps.insert(isOnOrderConfirmation.id)
        case .error:
            trueProps.insert(isOnErrorScreen.id)
        }
        
        // State propositions
        if state.cartItemCount > 0 {
            trueProps.insert(hasItemsInCart.id)
        }
        
        if state.isLoggedIn {
            trueProps.insert(isUserLoggedIn.id)
        }
        
        if state.hasSelectedPaymentMethod {
            trueProps.insert(hasSelectedPayment.id)
        }
        
        return trueProps
    }
}
```

## Step 4: Defining Properties to Verify

Let's define temporal logic formulas that represent important properties we want to verify in our UI flow.

```swift
// Aliases for better readability
typealias ShoppingProp = ClosureTemporalProposition<ShoppingAppState, Bool>
typealias ShoppingLTL = LTLFormula<ShoppingProp>

// Property 1: "Cannot access checkout without items in cart"
let noCheckoutWithoutItems = ShoppingLTL.globally(
    .implies(
        .atomic(isOnCheckout),
        .atomic(hasItemsInCart)
    )
)

// Property 2: "Cannot reach order confirmation without being logged in"
let noOrderConfirmationWithoutLogin = ShoppingLTL.globally(
    .implies(
        .atomic(isOnOrderConfirmation),
        .atomic(isUserLoggedIn)
    )
)

// Property 3: "Cannot reach order confirmation without selecting a payment method"
let noOrderConfirmationWithoutPayment = ShoppingLTL.globally(
    .implies(
        .atomic(isOnOrderConfirmation),
        .atomic(hasSelectedPayment)
    )
)

// Property 4: "From any screen, we can eventually get back to the product list"
let canAlwaysReturnToProductList = ShoppingLTL.globally(
    .eventually(.atomic(isOnProductList))
)

// Property 5: "A complete purchasing workflow is possible"
let completeWorkflowIsPossible = ShoppingLTL.eventually(
    .and(
        .atomic(isOnProductList),
        .eventually(
            .and(
                .atomic(isOnProductDetail),
                .eventually(
                    .and(
                        .atomic(isOnCart),
                        .eventually(
                            .and(
                                .atomic(isOnCheckout),
                                .eventually(
                                    .and(
                                        .atomic(isOnPaymentMethod),
                                        .eventually(.atomic(isOnOrderConfirmation))
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

// Property 6: "After ordering, the cart is always empty"
let cartEmptyAfterOrder = ShoppingLTL.globally(
    .implies(
        .atomic(isOnOrderConfirmation),
        .next(
            .implies(
                .atomic(isOnProductList),
                .not(.atomic(hasItemsInCart))
            )
        )
    )
)
```

## Step 5: Verifying the UI Flow

Now let's verify our UI flow against these properties.

```swift
// Create the model and model checker
let shoppingAppFlow = ShoppingAppFlow()
let modelChecker = LTLModelChecker<ShoppingAppFlow>()

// Perform verification
do {
    print("Verifying shopping app UI flow properties...")
    
    let result1 = try modelChecker.check(formula: noCheckoutWithoutItems, model: shoppingAppFlow)
    print("Property 1 (No checkout without items): \(result1.holds ? "Holds" : "Does not hold")")
    
    let result2 = try modelChecker.check(formula: noOrderConfirmationWithoutLogin, model: shoppingAppFlow)
    print("Property 2 (No order confirmation without login): \(result2.holds ? "Holds" : "Does not hold")")
    
    let result3 = try modelChecker.check(formula: noOrderConfirmationWithoutPayment, model: shoppingAppFlow)
    print("Property 3 (No order confirmation without payment): \(result3.holds ? "Holds" : "Does not hold")")
    
    let result4 = try modelChecker.check(formula: canAlwaysReturnToProductList, model: shoppingAppFlow)
    print("Property 4 (Can always return to product list): \(result4.holds ? "Holds" : "Does not hold")")
    
    let result5 = try modelChecker.check(formula: completeWorkflowIsPossible, model: shoppingAppFlow)
    print("Property 5 (Complete workflow is possible): \(result5.holds ? "Holds" : "Does not hold")")
    
    let result6 = try modelChecker.check(formula: cartEmptyAfterOrder, model: shoppingAppFlow)
    print("Property 6 (Cart empty after order): \(result6.holds ? "Holds" : "Does not hold")")
    
    // Check for counterexamples
    if !result1.holds, case .fails(let counterexample) = result1 {
        print("\nCounterexample for Property 1:")
        print("Prefix: \(counterexample.prefix.map { $0.currentScreen }.joined(separator: " -> "))")
        print("Cycle: \(counterexample.cycle.map { $0.currentScreen }.joined(separator: " -> "))")
    }
    
} catch {
    print("Verification error: \(error)")
}
```

## Step 6: Integration with UI Tests

Finally, let's integrate our UI flow verification with XCTest to create automated UI flow tests.

```swift
import XCTest
import TemporalKit

class ShoppingAppUIFlowTests: XCTestCase {
    
    func testUIFlowProperties() {
        let shoppingAppFlow = ShoppingAppFlow()
        let modelChecker = LTLModelChecker<ShoppingAppFlow>()
        
        // Helper function to check a property
        func checkProperty(_ formula: ShoppingLTL, name: String) throws -> Bool {
            let result = try modelChecker.check(formula: formula, model: shoppingAppFlow)
            return result.holds
        }
        
        do {
            // Verify critical properties
            XCTAssertTrue(try checkProperty(noCheckoutWithoutItems, name: "No checkout without items"), "Users should not be able to access checkout with an empty cart")
            
            XCTAssertTrue(try checkProperty(noOrderConfirmationWithoutLogin, name: "No order confirmation without login"), "Users must be logged in to complete an order")
            
            XCTAssertTrue(try checkProperty(noOrderConfirmationWithoutPayment, name: "No order confirmation without payment"), "Users must select a payment method to complete an order")
            
            XCTAssertTrue(try checkProperty(canAlwaysReturnToProductList, name: "Can always return to product list"), "Users should be able to return to the product list from any screen")
            
            XCTAssertTrue(try checkProperty(completeWorkflowIsPossible, name: "Complete workflow is possible"), "A complete purchase workflow should be possible")
            
            XCTAssertTrue(try checkProperty(cartEmptyAfterOrder, name: "Cart empty after order"), "The cart should be empty after completing an order")
            
        } catch {
            XCTFail("Verification failed with error: \(error)")
        }
    }
    
    func testRealUIFlow() {
        // In a real app, you would use XCUITest to navigate through the app
        // and then verify that the state transitions match your model
        
        // This is a simplified example:
        let app = XCUIApplication()
        app.launch()
        
        // Record the actual UI flow as a trace
        var stateTrace: [ShoppingAppState] = []
        
        // Initial state
        stateTrace.append(ShoppingAppState.initial())
        
        // Navigate to product detail
        app.tables["productList"].cells.firstMatch.tap()
        stateTrace.append(ShoppingAppState(
            currentScreen: .productDetail,
            cartItemCount: 0,
            isLoggedIn: false,
            hasSelectedPaymentMethod: false
        ))
        
        // Add to cart
        app.buttons["addToCart"].tap()
        stateTrace.append(ShoppingAppState(
            currentScreen: .productDetail,
            cartItemCount: 1,
            isLoggedIn: false,
            hasSelectedPaymentMethod: false
        ))
        
        // Go to cart
        app.buttons["viewCart"].tap()
        stateTrace.append(ShoppingAppState(
            currentScreen: .cart,
            cartItemCount: 1,
            isLoggedIn: false,
            hasSelectedPaymentMethod: false
        ))
        
        // Verify the trace using TemporalKit
        let contextProvider: (ShoppingAppState, Int) -> EvaluationContext = { (state, index) in
            return SimpleEvaluationContext(state: state, traceIndex: index)
        }
        
        let evaluator = LTLFormulaTraceEvaluator()
        
        // Define a simple property for the trace
        let cartAccessProperty = ShoppingLTL.eventually(
            .and(
                .atomic(isOnProductDetail),
                .eventually(.atomic(isOnCart))
            )
        )
        
        do {
            let result = try evaluator.evaluate(
                formula: cartAccessProperty,
                trace: stateTrace,
                contextProvider: contextProvider
            )
            
            XCTAssertTrue(result, "Users should be able to access the cart after viewing product details")
            
        } catch {
            XCTFail("Trace evaluation failed: \(error)")
        }
    }
    
    // Simple evaluation context for trace evaluation
    class SimpleEvaluationContext: EvaluationContext {
        let state: ShoppingAppState
        let traceIndex: Int?
        
        init(state: ShoppingAppState, traceIndex: Int? = nil) {
            self.state = state
            self.traceIndex = traceIndex
        }
        
        func currentStateAs<T>(_ type: T.Type) -> T? {
            return state as? T
        }
    }
}
```

## Summary

In this tutorial, you learned how to:

1. Model UI flows as state transition systems
2. Define temporal properties that express correct UI behavior
3. Verify UI flows using model checking
4. Find potential issues in UI flows before they reach users
5. Integrate UI flow verification with XCTest

By formally verifying UI flows, you can ensure that your app provides a consistent and error-free user experience, preventing situations where users might reach invalid states or get stuck in the UI.

## Next Steps

- Apply these techniques to verify your own iOS application flows
- Explore [Working with Propositions](./WorkingWithPropositions.md) to create more expressive UI flow properties
- Learn about [Concurrent System Verification](./ConcurrentSystemVerification.md) to verify more complex UI interactions
- Try [Optimizing Performance](./OptimizingPerformance.md) for verifying larger UI models 
