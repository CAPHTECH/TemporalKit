# Common LTL Patterns

This tutorial introduces common Linear Temporal Logic (LTL) patterns that are useful for expressing properties in TemporalKit. These patterns provide a structured way to specify commonly needed temporal properties.

## Prerequisites

Before starting this tutorial, make sure you have:

- Completed the [Basic Usage](./BasicUsage.md) tutorial
- Understood the concept of LTL from the [Core Concepts](../CoreConcepts.md) document
- Imported TemporalKit in your project

## Understanding LTL Patterns

LTL formulas can be complex and difficult to read or write. To simplify this process, the software verification community has identified common patterns of properties that appear frequently in specifications. These patterns can be expressed as LTL formula templates that you can adapt to your specific verification needs.

## 1. Safety Patterns

Safety properties express that "nothing bad happens." These are properties that, if violated, can be demonstrated with a finite counterexample.

### Always Property

The most basic safety pattern is that some condition always holds:

```swift
// "p is always true"
let alwaysP = LTLFormula<MyProposition>.globally(.atomic(p))

// Example: A user must always be authenticated to access protected resources
let alwaysAuthenticated = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(accessingProtectedResource),
        .atomic(isAuthenticated)
    )
)
```

### Never Property

The complement of "always" is "never":

```swift
// "p is never true" (equivalent to "always not p")
let neverP = LTLFormula<MyProposition>.globally(.not(.atomic(p)))

// Example: A user should never see an error without a message
let neverErrorWithoutMessage = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(errorOccurred),
        .atomic(errorMessageDisplayed)
    )
)
```

### Before Property

Express that a property holds before another property becomes true:

```swift
// "p always holds before q becomes true"
let pBeforeQ = LTLFormula<MyProposition>.until(
    .atomic(p),
    .atomic(q)
)

// Example: User must agree to terms before proceeding
let agreeBeforeProceed = LTLFormula<AppProposition>.until(
    .not(.atomic(proceedToNextStep)),
    .atomic(termsAgreed)
)
```

### Absence with Scope

Express that a property does not occur within a specific scope:

```swift
// "p does not occur between q and r"
let pAbsentBetweenQandR = LTLFormula<MyProposition>.globally(
    .implies(
        .and(.atomic(q), .not(.atomic(r))),
        .not(.atomic(p))
    )
)

// Example: No notifications while in do-not-disturb mode
let noNotificationsInDND = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(doNotDisturbEnabled),
        .not(.atomic(notificationDisplayed))
    )
)
```

## 2. Liveness Patterns

Liveness properties express that "something good eventually happens." These properties require an infinite trace to demonstrate violations.

### Eventually Property

The basic liveness pattern is that something eventually happens:

```swift
// "p eventually becomes true"
let eventuallyP = LTLFormula<MyProposition>.eventually(.atomic(p))

// Example: Every request eventually gets a response
let requestEventuallyResponded = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(requestSent),
        .eventually(.atomic(responseReceived))
    )
)
```

### Response Property

Express that if something happens, something else must happen in response:

```swift
// "If p occurs, q eventually occurs"
let pRespondsToQ = LTLFormula<MyProposition>.globally(
    .implies(
        .atomic(p),
        .eventually(.atomic(q))
    )
)

// Example: Every form submission is eventually either accepted or rejected
let formSubmissionResponded = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(formSubmitted),
        .eventually(.or(.atomic(formAccepted), .atomic(formRejected)))
    )
)
```

### Progress Property

Express that a process makes progress by eventually reaching a certain state:

```swift
// "The system always eventually reaches state p"
let alwaysEventuallyP = LTLFormula<MyProposition>.globally(
    .eventually(.atomic(p))
)

// Example: App always eventually returns to the home screen
let alwaysReturnsHome = LTLFormula<AppProposition>.globally(
    .eventually(.atomic(homeScreenDisplayed))
)
```

### Fairness Property

Express that if something occurs infinitely often, something else also occurs infinitely often:

```swift
// "If p occurs infinitely often, q occurs infinitely often"
let fairnessProperty = LTLFormula<MyProposition>.implies(
    .globally(.eventually(.atomic(p))),
    .globally(.eventually(.atomic(q)))
)

// Example: If user attempts login infinitely often, they eventually succeed
let loginFairness = LTLFormula<AppProposition>.implies(
    .globally(.eventually(.atomic(loginAttempted))),
    .globally(.eventually(.atomic(loginSucceeded)))
)
```

## 3. Precedence Patterns

Precedence patterns express ordering relationships between events.

### Precedence Property

Express that an event must be preceded by another event:

```swift
// "q only occurs after p has occurred"
let qPrecededByP = LTLFormula<MyProposition>.globally(
    .implies(
        .atomic(q),
        .or(.atomic(p), LTLFormula.once(.atomic(p)))
    )
)

// Example: Payment confirmation only after payment processing
let confirmationAfterProcessing = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(paymentConfirmed),
        .or(.atomic(paymentProcessed), LTLFormula.once(.atomic(paymentProcessed)))
    )
)
```

### Chain Precedence

Express that a sequence of events must occur in a specific order:

```swift
// "r occurs only after q, which occurs only after p"
let chainPrecedence = LTLFormula<MyProposition>.globally(
    .implies(
        .atomic(r),
        .once(
            .and(.atomic(q), .once(.atomic(p)))
        )
    )
)

// Example: Order processing stages must occur in sequence
let orderProcessSequence = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(orderShipped),
        .once(
            .and(.atomic(orderPacked), .once(.atomic(orderProcessed)))
        )
    )
)
```

## 4. Real-World Application Patterns

Let's look at some patterns commonly needed in real applications.

### Authentication Flow

For an authentication flow, you might want to verify:

```swift
// 1. Unauthenticated users can't access protected resources
let protectedResourcesSecured = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(accessingProtectedResource),
        .atomic(isAuthenticated)
    )
)

// 2. After logout, user remains logged out until login
let logoutUntilLogin = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(loggedOut),
        .until(
            .atomic(loggedOut),
            .atomic(loginSucceeded)
        )
    )
)

// 3. After too many failed attempts, account is locked
let lockAfterFailedAttempts = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(tooManyFailedAttempts),
        .next(.atomic(accountLocked))
    )
)
```

### Shopping Cart Flow

For an e-commerce shopping cart, you might verify:

```swift
// 1. Items remain in cart until explicitly removed or purchased
let itemsRemainInCart = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(itemAdded),
        .until(
            .atomic(itemInCart),
            .or(.atomic(itemRemoved), .atomic(checkoutCompleted))
        )
    )
)

// 2. Checkout only possible with items in cart
let checkoutRequiresItems = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(checkoutStarted),
        .atomic(cartHasItems)
    )
)

// 3. Order confirmation only after payment completion
let confirmationAfterPayment = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(orderConfirmed),
        .once(.atomic(paymentSuccessful))
    )
)
```

### Form Validation

For form validation scenarios:

```swift
// 1. Form can only be submitted when valid
let submitRequiresValid = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(formSubmitted),
        .atomic(formIsValid)
    )
)

// 2. Validation errors disappear once fixed
let errorsDisappearWhenFixed = LTLFormula<AppProposition>.globally(
    .implies(
        .and(.atomic(validationErrorShown), .next(.atomic(errorFieldCorrected))),
        .next(.not(.atomic(validationErrorShown)))
    )
)

// 3. Form resets after successful submission
let formResetsAfterSubmission = LTLFormula<AppProposition>.globally(
    .implies(
        .and(.atomic(formSubmitted), .next(.atomic(submissionSuccessful))),
        .next(.next(.atomic(formReset)))
    )
)
```

## 5. Combining Patterns

Complex requirements often need combinations of multiple patterns:

```swift
// "If a user requests data, they should eventually receive it,
// but only if they are authenticated throughout the waiting period"
let secureDataAccessPattern = LTLFormula<AppProposition>.globally(
    .implies(
        .and(.atomic(dataRequested), .atomic(isAuthenticated)),
        .and(
            .eventually(.atomic(dataReceived)),
            .until(.atomic(isAuthenticated), .atomic(dataReceived))
        )
    )
)

// "After submitting an order, the user eventually sees either a
// confirmation or an error, and cannot submit another order until then"
let orderSubmissionPattern = LTLFormula<AppProposition>.globally(
    .implies(
        .atomic(orderSubmitted),
        .and(
            .eventually(.or(.atomic(confirmationShown), .atomic(errorShown))),
            .until(
                .not(.atomic(canSubmitOrder)),
                .or(.atomic(confirmationShown), .atomic(errorShown))
            )
        )
    )
)
```

## 6. Creating Reusable Pattern Functions

To make these patterns more reusable, you can create utility functions:

```swift
// Create a response pattern: "globally, if trigger then eventually response"
func responsePattern<P: TemporalProposition>(
    trigger: LTLFormula<P>,
    response: LTLFormula<P>
) -> LTLFormula<P> where P.Value == Bool {
    return .globally(
        .implies(trigger, .eventually(response))
    )
}

// Create a precedence pattern: "globally, if consequence then once antecedent"
func precedencePattern<P: TemporalProposition>(
    antecedent: LTLFormula<P>,
    consequence: LTLFormula<P>
) -> LTLFormula<P> where P.Value == Bool {
    return .globally(
        .implies(consequence, .once(antecedent))
    )
}

// Create a bounded existence pattern: "between start and end, event occurs at most once"
func atMostOncePattern<P: TemporalProposition>(
    start: LTLFormula<P>,
    event: LTLFormula<P>,
    end: LTLFormula<P>
) -> LTLFormula<P> where P.Value == Bool {
    return .globally(
        .implies(
            .and(start, .not(end), .eventually(end)),
            .until(
                .or(.not(event), .and(event, .next(.until(.not(event), end)))),
                end
            )
        )
    )
}

// Usage examples:
let responseExample = responsePattern(
    trigger: .atomic(buttonPressed),
    response: .atomic(actionPerformed)
)

let precedenceExample = precedencePattern(
    antecedent: .atomic(authenticated),
    consequence: .atomic(resourceAccessed)
)

let atMostOnceExample = atMostOncePattern(
    start: .atomic(sessionStarted),
    event: .atomic(errorOccurred),
    end: .atomic(sessionEnded)
)
```

## 7. Building a Pattern Library

For complex applications, consider building a library of domain-specific patterns:

```swift
// Authentication pattern library
struct AuthPatterns {
    static func requiresAuthentication<P: TemporalProposition>(
        resource: LTLFormula<P>,
        authenticated: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(.implies(resource, authenticated))
    }
    
    static func sessionIntegrity<P: TemporalProposition>(
        loggedIn: LTLFormula<P>,
        loggedOut: LTLFormula<P>,
        loginAction: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(
            .implies(loggedOut, .until(loggedOut, loginAction))
        )
    }
    
    static func preventConcurrentSessions<P: TemporalProposition>(
        sessionStarted: LTLFormula<P>,
        existingSession: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(
            .implies(existingSession, .not(sessionStarted))
        )
    }
}

// E-commerce pattern library
struct ECommercePatterns {
    static func cartIntegrity<P: TemporalProposition>(
        itemAdded: LTLFormula<P>,
        itemInCart: LTLFormula<P>,
        itemRemoved: LTLFormula<P>,
        checkout: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(
            .implies(
                itemAdded,
                .until(itemInCart, .or(itemRemoved, checkout))
            )
        )
    }
    
    static func orderProcessFlow<P: TemporalProposition>(
        orderPlaced: LTLFormula<P>,
        orderProcessed: LTLFormula<P>,
        orderShipped: LTLFormula<P>,
        orderDelivered: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .and(
            precedencePattern(antecedent: orderPlaced, consequence: orderProcessed),
            precedencePattern(antecedent: orderProcessed, consequence: orderShipped),
            precedencePattern(antecedent: orderShipped, consequence: orderDelivered)
        )
    }
}

// Usage example
let authRequirement = AuthPatterns.requiresAuthentication(
    resource: .atomic(viewingPrivateData),
    authenticated: .atomic(userAuthenticated)
)

let cartRequirement = ECommercePatterns.cartIntegrity(
    itemAdded: .atomic(productAddedToCart),
    itemInCart: .atomic(productInCart),
    itemRemoved: .atomic(productRemovedFromCart),
    checkout: .atomic(checkoutCompleted)
)
```

## 8. Scope-based Pattern System

A more structured approach is to organize patterns by their scope:

```swift
// Global scope: Pattern applies to entire execution
struct GlobalScope {
    static func universality<P: TemporalProposition>(
        p: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(p)
    }
    
    static func absence<P: TemporalProposition>(
        p: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(.not(p))
    }
    
    static func existence<P: TemporalProposition>(
        p: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .eventually(p)
    }
}

// Before scope: Pattern applies before a given condition
struct BeforeScope {
    static func universality<P: TemporalProposition>(
        p: LTLFormula<P>,
        condition: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .until(p, condition)
    }
    
    static func absence<P: TemporalProposition>(
        p: LTLFormula<P>,
        condition: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .until(.not(p), condition)
    }
}

// Between scope: Pattern applies between two conditions
struct BetweenScope {
    static func universality<P: TemporalProposition>(
        p: LTLFormula<P>,
        start: LTLFormula<P>,
        end: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(
            .implies(
                .and(start, .not(end), .eventually(end)),
                .until(p, end)
            )
        )
    }
    
    static func absence<P: TemporalProposition>(
        p: LTLFormula<P>,
        start: LTLFormula<P>,
        end: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(
            .implies(
                .and(start, .not(end), .eventually(end)),
                .until(.not(p), end)
            )
        )
    }
}

// After scope: Pattern applies after a condition
struct AfterScope {
    static func universality<P: TemporalProposition>(
        p: LTLFormula<P>,
        condition: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(
            .implies(condition, .next(.globally(p)))
        )
    }
    
    static func existence<P: TemporalProposition>(
        p: LTLFormula<P>,
        condition: LTLFormula<P>
    ) -> LTLFormula<P> where P.Value == Bool {
        return .globally(
            .implies(condition, .eventually(p))
        )
    }
}

// Usage example
let alwaysLogged = GlobalScope.universality(
    p: .atomic(userIsLoggedIn)
)

let noErrorsUntilLogout = BeforeScope.absence(
    p: .atomic(errorOccurred),
    condition: .atomic(userLoggedOut)
)

let dataValidBetweenChecks = BetweenScope.universality(
    p: .atomic(dataIsValid),
    start: .atomic(validationPerformed),
    end: .atomic(dataModified)
)

let eventuallyHomeAfterLogin = AfterScope.existence(
    p: .atomic(homeScreenShown),
    condition: .atomic(loginSucceeded)
)
```

## Conclusion

LTL patterns provide a structured approach to expressing common properties for verification. By leveraging these patterns, you can:

1. Express complex requirements more easily
2. Improve readability of your specifications
3. Reuse common verification logic
4. Build domain-specific property libraries

As you gain experience with TemporalKit, you'll develop a catalog of patterns specific to your application domain, making formal verification more accessible and practical for your development workflow.

In the next tutorial, we'll explore how to understand and debug counterexamples when verification fails. 
