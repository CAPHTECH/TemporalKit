import Foundation
import TemporalKit

print("TemporalKit Demo Application")

// 1. Define Propositions
let isLoggedIn = IsUserLoggedInProposition()
let hasMessages = HasUnreadMessagesProposition()
let cartHasItems = CartHasItemsProposition()
let cartHasMoreThanTwoItems = CartItemCountExceedsProposition(threshold: 2)

// 2. Create a Trace (a sequence of AppStates)
let trace: [AppState] = [
    AppState(isUserLoggedIn: false, hasUnreadMessages: false, cartItemCount: 0), // time 0
    AppState(isUserLoggedIn: true,  hasUnreadMessages: false, cartItemCount: 0), // time 1
    AppState(isUserLoggedIn: true,  hasUnreadMessages: true,  cartItemCount: 1), // time 2
    AppState(isUserLoggedIn: true,  hasUnreadMessages: false, cartItemCount: 3), // time 3
    AppState(isUserLoggedIn: false, hasUnreadMessages: false, cartItemCount: 0)  // time 4
]

// Helper to wrap AppState in AppEvaluationContext
func contextFor(appState: AppState, at index: Int) -> AppEvaluationContext {
    return AppEvaluationContext(appState: appState, index: index)
}

// 3. Define LTL Formulas
// Example 1: "Eventually, the user is logged in"
// F (isLoggedIn)
let eventuallyLoggedIn: LTLFormula<AppProposition> = .eventually(.atomic(isLoggedIn))

// Example 2: "Globally, if the user is logged in, they eventually have messages"
// G (isLoggedIn -> F hasMessages)
let loggedInImpliesEventuallyMessages: LTLFormula<AppProposition> = .globally(
    .implies(.atomic(isLoggedIn), .eventually(.atomic(hasMessages)))
)

// Example 3: "The user is logged in UNTIL the cart has more than two items"
// isLoggedIn U cartHasMoreThanTwoItems
let loggedInUntilCartFull: LTLFormula<AppProposition> = .until(.atomic(isLoggedIn), .atomic(cartHasMoreThanTwoItems))

// Example 4: "Next, the cart will have items"
// X cartHasItems
let nextCartHasItems: LTLFormula<AppProposition> = .next(.atomic(cartHasItems))

// Example 5: "Always (the cart has items implies Next (cart has items or not logged in))"
// G (cartHasItems -> X (cartHasItems \/ !isLoggedIn))
let complexFormula: LTLFormula<AppProposition> = .globally(
    .implies(
        .atomic(cartHasItems),
        .next(
            .or(.atomic(cartHasItems), .not(.atomic(isLoggedIn)))
        )
    )
)


// 4. Evaluate formulas on the trace
let evaluator = LTLFormulaTraceEvaluator<AppProposition>()

print("\n--- Evaluating Formulas ---")

let formulasToTest: [(String, LTLFormula<AppProposition>)] = [
    ("Eventually Logged In (F isLoggedIn)", eventuallyLoggedIn),
    ("Logged In -> F Has Messages (G (isLoggedIn -> F hasMessages))", loggedInImpliesEventuallyMessages),
    ("Logged In Until Cart Full (isLoggedIn U cartHasMoreThanTwoItems)", loggedInUntilCartFull),
    ("Next Cart Has Items (X cartHasItems)", nextCartHasItems),
    ("Complex Formula (G (cartHasItems -> X (cartHasItems \\/ !isLoggedIn)))", complexFormula)
]

for (description, formula) in formulasToTest {
    do {
        let result = try evaluator.evaluate(formula: formula, trace: trace, contextProvider: contextFor)
        print("\"\(description)\" is \(result)")
    } catch {
        print("Error evaluating \"\(description)\": \(error)")
    }
}

print("\n--- Manual Proposition Evaluation at specific states ---")
if let firstStateContext = trace.first.map({ contextFor(appState: $0, at: 0) }) {
    print("At time 0, isLoggedIn: \(isLoggedIn.evaluate(in: firstStateContext))")
}
if trace.count > 1 {
    let secondStateContext = contextFor(appState: trace[1], at: 1)
    print("At time 1, isLoggedIn: \(isLoggedIn.evaluate(in: secondStateContext))")
    print("At time 1, cartHasItems: \(cartHasItems.evaluate(in: secondStateContext))")
}


// Example using the renamed '~>>' operator (implies)
// G (isLoggedIn ~>> F hasMessages)
let formulaWithCustomOperator: LTLFormula<AppProposition> = .globally(
    .implies(.atomic(isLoggedIn), .eventually(.atomic(hasMessages))) // Assuming ~>> is implemented via .implies for LTLFormula
)
do {
    let result = try evaluator.evaluate(formula: formulaWithCustomOperator, trace: trace, contextProvider: contextFor)
    print("\"G (isLoggedIn ~>> F hasMessages)\" is \(result)")
} catch {
    print("Error evaluating formula with custom operator: \(error)")
}

print("\nDemo finished.")
