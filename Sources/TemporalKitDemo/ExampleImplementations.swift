import Foundation
import TemporalKit // TemporalKitの型にアクセスするために必要

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
    public func evaluate(in context: EvaluationContext) throws -> Bool {
        guard let appContext = context as? AppEvaluationContext else {
            throw TemporalKit.TemporalKitError.stateTypeMismatch(
                expected: "AppEvaluationContext (providing AppState)",
                actual: String(describing: type(of: context)),
                propositionID: self.id,
                propositionName: self.name
            )
        }
        return evaluateWithAppState(appContext.state)
    }
    
    /// Method to be overridden by subclasses to evaluate against the AppState.
    /// - Parameter state: The current application state.
    /// - Returns: Whether the proposition holds in the given state.
    open func evaluateWithAppState(_ state: AppState) -> Bool {
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

// Example of a proposition that uses a parameter
public class CartItemCountExceedsProposition: AppProposition {
    private let threshold: Int

    public init(threshold: Int) {
        self.threshold = threshold
        super.init(id: "cartItemCountExceeds_\(threshold)", name: "Cart items > \(threshold)")
    }

    override public func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.cartItemCount > threshold
    }
}

// MARK: - Kripke Structure and Propositions for Model Checking Demo

/// State type for the DemoKripkeStructure.
public enum DemoKripkeModelState: Hashable, CustomStringConvertible {
    case s0, s1, s2
    public var description: String {
        switch self {
        case .s0: return "s0"
        case .s1: return "s1"
        case .s2: return "s2"
        }
    }
}

/// Proposition type for the Kripke structure used in model checking demo.
public typealias KripkeDemoProposition = TemporalKit.ClosureTemporalProposition<DemoKripkeModelState, Bool>

// Define propositions that will label the Kripke structure states.
public let p_kripke = TemporalKit.makeProposition(
    id: "p_kripke", 
    name: "p (for Kripke)", 
    evaluate: { (state: DemoKripkeModelState) -> Bool in state == .s0 || state == .s2 }
)
public let q_kripke = TemporalKit.makeProposition(
    id: "q_kripke", 
    name: "q (for Kripke)", 
    evaluate: { (state: DemoKripkeModelState) -> Bool in state == .s1 }
)
public let r_kripke = TemporalKit.makeProposition(
    id: "r_kripke", 
    name: "r (for Kripke)", 
    evaluate: { (state: DemoKripkeModelState) -> Bool in state == .s2 }
)

/// A simple Kripke Structure for LTL model checking demonstration.
/// States: s0 (initial, {p_kripke}), s1 ({q_kripke}), s2 ({p_kripke, r_kripke})
/// Transitions: s0->s1, s1->s2, s2->s0, s2->s2 (self-loop)
public struct DemoKripkeStructure: KripkeStructure {
    public typealias State = DemoKripkeModelState
    public typealias AtomicPropositionIdentifier = PropositionID

    public let initialStates: Set<State> = [.s0]
    public let allStates: Set<State> = [.s0, .s1, .s2]

    public func successors(of state: State) -> Set<State> {
        switch state {
        case .s0: return [.s1]
        case .s1: return [.s2]
        case .s2: return [.s0, .s2]
        }
    }

    public func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        if state == .s0 || state == .s2 { trueProps.insert(p_kripke.id) }
        if state == .s1 { trueProps.insert(q_kripke.id) }
        if state == .s2 { trueProps.insert(r_kripke.id) }
        return trueProps
    }
}
