import Foundation
import TemporalKit

print("TemporalKit Demo Application")

// 1. Define Propositions using the global factory method from TemporalKit
let isLoggedIn = TemporalKit.makeProposition(
    id: "isUserLoggedInFunc",
    name: "User is logged in (Functional)",
    evaluate: { (appState: AppState) in appState.isUserLoggedIn } // Swift infers StateType=AppState, PropositionResultType=Bool
)

let hasMessages = TemporalKit.makeProposition(
    id: "hasUnreadMessagesFunc",
    name: "User has unread messages (Functional)",
    evaluate: { (appState: AppState) in appState.hasUnreadMessages }
)

let cartHasItems = TemporalKit.makeProposition(
    id: "cartHasItemsFunc",
    name: "Cart has items (Functional)",
    evaluate: { (appState: AppState) in appState.cartItemCount > 0 }
)

let cartHasMoreThanTwoItems = TemporalKit.makeProposition(
    id: "cartItemCountExceeds_2_Func",
    name: "Cart items > 2 (Functional)",
    evaluate: { (appState: AppState) in appState.cartItemCount > 2 }
)

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

// Define a typealias for the specific proposition type used in this demo, for LTL formulas
// This typealias now correctly refers to the type returned by TemporalKit.makeProposition
// when the closure matches AppState -> Bool.
// So, DemoLTLProposition IS TemporalKit.ClosureTemporalProposition<AppState, Bool>
typealias DemoLTLProposition = TemporalKit.ClosureTemporalProposition<AppState, Bool>

// 3. Define LTL Formulas using the typealias (which matches the inferred type of propositions)
let eventuallyLoggedIn: LTLFormula<DemoLTLProposition> = .eventually(.atomic(isLoggedIn))

let loggedInImpliesEventuallyMessages: LTLFormula<DemoLTLProposition> = .globally(
    .implies(.atomic(isLoggedIn), .eventually(.atomic(hasMessages)))
)

let loggedInUntilCartFull: LTLFormula<DemoLTLProposition> = .until(.atomic(isLoggedIn), .atomic(cartHasMoreThanTwoItems))

let nextCartHasItems: LTLFormula<DemoLTLProposition> = .next(.atomic(cartHasItems))

let complexFormula: LTLFormula<DemoLTLProposition> = .globally(
    .implies(
        .atomic(cartHasItems),
        .next(
            .or(.atomic(cartHasItems), .not(.atomic(isLoggedIn)))
        )
    )
)

// 4. Evaluate formulas on the trace
let evaluator = LTLFormulaTraceEvaluator<DemoLTLProposition>()

print("\n--- Evaluating Formulas ---")

let formulasToTest: [(String, LTLFormula<DemoLTLProposition>)] = [
    ("Eventually Logged In (F isLoggedIn)", eventuallyLoggedIn),
    ("Logged In -> F Has Messages (G (isLoggedIn -> F hasMessages))", loggedInImpliesEventuallyMessages),
    ("Logged In Until Cart Full (isLoggedIn U cartHasMoreThanTwoItems)", loggedInUntilCartFull),
    ("Next Cart Has Items (X cartHasItems)", nextCartHasItems),
    ("Complex Formula (G (cartHasItems -> X (cartHasItems or !isLoggedIn)))", complexFormula)
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
    let result = try? isLoggedIn.evaluate(in: firstStateContext)
    let outputString = result.map { String($0) } ?? "N/A (Error)"
    print("At time 0, isLoggedIn: \(outputString)")
}
if trace.count > 1 {
    let secondStateContext = contextFor(appState: trace[1], at: 1)
    let result1 = try? isLoggedIn.evaluate(in: secondStateContext)
    let outputString1 = result1.map { String($0) } ?? "N/A (Error)"
    print("At time 1, isLoggedIn: \(outputString1)")

    let result2 = try? cartHasItems.evaluate(in: secondStateContext)
    let outputString2 = result2.map { String($0) } ?? "N/A (Error)"
    print("At time 1, cartHasItems: \(outputString2)")
}

// Example using the renamed '~>>' operator (implies)
let formulaWithCustomOperator: LTLFormula<DemoLTLProposition> = .globally(
    .implies(.atomic(isLoggedIn), .eventually(.atomic(hasMessages)))
)
do {
    let result = try evaluator.evaluate(formula: formulaWithCustomOperator, trace: trace, contextProvider: contextFor)
    print("\"G (isLoggedIn ~>> F hasMessages)\" is \(result)")
} catch {
    print("Error evaluating formula with custom operator: \(error)")
}

print("\nDemo finished.")
