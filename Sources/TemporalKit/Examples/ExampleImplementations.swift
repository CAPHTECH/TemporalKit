import Foundation

/// An example application state to demonstrate how to use TemporalKit.
/// This represents the state of a system at a specific point in time.
public struct AppState {
    public let isUserLoggedIn: Bool
    public let hasUnreadMessages: Bool
    public let cartItemCount: Int
    public let lastNotificationTime: Date?
    
    public init(isUserLoggedIn: Bool, hasUnreadMessages: Bool, cartItemCount: Int, lastNotificationTime: Date? = nil) {
        self.isUserLoggedIn = isUserLoggedIn
        self.hasUnreadMessages = hasUnreadMessages
        self.cartItemCount = cartItemCount
        self.lastNotificationTime = lastNotificationTime
    }
}

/// An implementation of EvaluationContext that wraps an AppState.
/// This provides access to the application state for proposition evaluation.
public struct AppEvaluationContext: EvaluationContext {
    private let appState: AppState
    private let index: Int
    
    public init(appState: AppState, index: Int) {
        self.appState = appState
        self.index = index
    }
    
    /// Returns the current state as the specified type, if possible.
    public func currentStateAs<T>(_ type: T.Type) -> T? {
        return appState as? T
    }
    
    /// Returns the raw AppState.
    public var state: AppState {
        return appState
    }
    
    /// Returns the index of this state in the trace.
    public var traceIndex: Int? {
        return index
    }
}

/// A base class for propositions related to the AppState.
/// This makes it easier to implement propositions that evaluate against AppState.
public class AppProposition: TemporalProposition {
    public typealias Value = Bool
    
    public let id: PropositionID
    public let name: String
    
    public init(id: String, name: String) {
        self.id = PropositionID(rawValue: id)
        self.name = name
    }
    
    /// Base implementation that attempts to get the AppState from the context.
    /// Subclasses should override this method to perform their specific evaluation.
    public func evaluate(in context: EvaluationContext) -> Bool {
        guard let appContext = context as? AppEvaluationContext else {
            return false
        }
        
        return evaluateWithAppState(appContext.state)
    }
    
    /// Method to be overridden by subclasses to evaluate against the AppState.
    /// - Parameter state: The current application state.
    /// - Returns: Whether the proposition holds in the given state.
    open func evaluateWithAppState(_ state: AppState) -> Bool {
        // This should be overridden by subclasses
        fatalError("Subclasses must override evaluateWithAppState(_:)")
    }
}

/// A proposition that checks if the user is logged in.
public class IsUserLoggedInProposition: AppProposition {
    public init() {
        super.init(id: "isUserLoggedIn", name: "User is logged in")
    }
    
    override public func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.isUserLoggedIn
    }
}

/// A proposition that checks if the user has unread messages.
public class HasUnreadMessagesProposition: AppProposition {
    public init() {
        super.init(id: "hasUnreadMessages", name: "User has unread messages")
    }
    
    override public func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.hasUnreadMessages
    }
}

/// A proposition that checks if the cart has items.
public class CartHasItemsProposition: AppProposition {
    public init() {
        super.init(id: "cartHasItems", name: "Cart has items")
    }
    
    override public func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.cartItemCount > 0
    }
}

/// A proposition that checks if the cart has a specific number of items or more.
public class CartItemCountProposition: AppProposition {
    private let threshold: Int
    
    public init(threshold: Int) {
        self.threshold = threshold
        super.init(id: "cartItemCount_\(threshold)", name: "Cart has \(threshold) or more items")
    }
    
    override public func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.cartItemCount >= threshold
    }
}

/// A proposition that checks if a notification was received within the last N seconds.
public class RecentNotificationProposition: AppProposition {
    private let windowSeconds: TimeInterval
    
    public init(windowSeconds: TimeInterval) {
        self.windowSeconds = windowSeconds
        super.init(id: "recentNotification_\(Int(windowSeconds))", name: "Notification received within the last \(Int(windowSeconds)) seconds")
    }
    
    override public func evaluateWithAppState(_ state: AppState) -> Bool {
        guard let lastNotificationTime = state.lastNotificationTime else {
            return false
        }
        
        let now = Date()
        let secondsSinceNotification = now.timeIntervalSince(lastNotificationTime)
        return secondsSinceNotification <= windowSeconds
    }
}

/// Example usage of the TemporalKit library.
/// This demonstrates how to create and evaluate LTL formulas.
public enum TemporalKitExamples {
    
    /// Creates a trace (sequence of states) for demonstration purposes.
    public static func createExampleTrace() -> [AppEvaluationContext] {
        let states: [AppState] = [
            AppState(isUserLoggedIn: false, hasUnreadMessages: false, cartItemCount: 0),
            AppState(isUserLoggedIn: true, hasUnreadMessages: false, cartItemCount: 0),
            AppState(isUserLoggedIn: true, hasUnreadMessages: true, cartItemCount: 0),
            AppState(isUserLoggedIn: true, hasUnreadMessages: true, cartItemCount: 2),
            AppState(isUserLoggedIn: true, hasUnreadMessages: false, cartItemCount: 3),
            AppState(isUserLoggedIn: false, hasUnreadMessages: false, cartItemCount: 0)
        ]
        
        return states.enumerated().map { index, state in
            AppEvaluationContext(appState: state, index: index)
        }
    }
    
    /// Creates example formulas and evaluates them over the trace.
    public static func demonstrateFormulaEvaluation() throws {
        let trace = createExampleTrace()
        
        // Create propositions
        let isLoggedIn = IsUserLoggedInProposition()
        let hasUnread = HasUnreadMessagesProposition()
        let cartHasItems = CartHasItemsProposition()
        
        // Create LTL formulas
        let loggedInFormula: LTLFormula<AppProposition> = .atomic(isLoggedIn)
        let hasUnreadFormula: LTLFormula<AppProposition> = .atomic(hasUnread)
        let cartHasItemsFormula: LTLFormula<AppProposition> = .atomic(cartHasItems)
        
        // Formula 1: Eventually, the user is logged in
        let eventually_loggedIn = LTLFormula.F(loggedInFormula)
        
        // Formula 2: Once logged in, the user eventually has unread messages
        let loggedIn_implies_eventually_hasUnread = loggedInFormula ==> LTLFormula.F(hasUnreadFormula)
        
        // Formula 3: Always, if the user has unread messages, they are logged in
        let always_hasUnread_implies_loggedIn = LTLFormula.G(hasUnreadFormula ==> loggedInFormula)
        
        // Formula 4: The user is logged in until they have items in their cart
        let loggedIn_until_cartHasItems = loggedInFormula ~>> cartHasItemsFormula
        
        // Evaluate formulas
        do {
            let result1 = try eventually_loggedIn.evaluate(over: trace, produceDetailedOutput: true)
            print("Formula 1 (Eventually logged in) holds: \(result1)")
            
            let result2 = try loggedIn_implies_eventually_hasUnread.evaluate(over: trace)
            print("Formula 2 (Logged in implies eventually has unread) holds: \(result2)")
            
            let result3 = try always_hasUnread_implies_loggedIn.evaluate(over: trace)
            print("Formula 3 (Always: has unread implies logged in) holds: \(result3)")
            
            let result4 = try loggedIn_until_cartHasItems.evaluate(over: trace)
            print("Formula 4 (Logged in until cart has items) holds: \(result4)")
        } catch {
            print("Error evaluating formula: \(error)")
            throw error
        }
    }
    
    /// Demonstrates formula normalization.
    public static func demonstrateFormulaNormalization() {
        let isLoggedIn = IsUserLoggedInProposition()
        let hasUnread = HasUnreadMessagesProposition()
        
        // Create some complex formulas
        let formula1: LTLFormula<AppProposition> = !(!.atomic(isLoggedIn))
        let normalizedFormula1 = formula1.normalized()
        print("Original formula: \(formula1)")
        print("Normalized formula: \(normalizedFormula1)")
        
        let formula2: LTLFormula<AppProposition> = .and(.booleanLiteral(true), .atomic(hasUnread))
        let normalizedFormula2 = formula2.normalized()
        print("Original formula: \(formula2)")
        print("Normalized formula: \(normalizedFormula2)")
    }
    
    /// Runs all the demos.
    public static func runAllDemos() {
        print("===== Demonstrating Formula Normalization =====")
        demonstrateFormulaNormalization()
        
        print("\n===== Demonstrating Formula Evaluation =====")
        do {
            try demonstrateFormulaEvaluation()
        } catch {
            print("Error in formula evaluation: \(error)")
        }
    }
}
