// Sources/TemporalKit/ModelChecking/KripkeStructure.swift

// Assuming PropositionID is defined elsewhere in TemporalKit,
// for example, in a shared Core module or alongside TemporalProposition.
// If TemporalKit is modular, an import might be needed, e.g., import TemporalKitCore

/// Represents a Kripke structure, which is a model of a system's behavior
/// used in formal verification, particularly model checking.
///
/// A Kripke structure formally defines a system in terms of:
/// - A set of states (`State`).
/// - A set of initial states (`initialStates`).
/// - A transition relation defining possible state changes (`successors(of:)`).
/// - A labeling function that maps each state to the set of atomic propositions
///   that are true in that state (`atomicPropositionsTrue(in:)`).
public protocol KripkeStructure {
    /// The type representing a state in the system.
    /// States must be `Hashable` to be used effectively in sets and dictionaries
    /// during model checking algorithms (e.g., for visited sets).
    associatedtype State: Hashable

    /// The type representing an identifier for an atomic proposition.
    /// This should be consistent with the identifier type used in `LTLFormula`'s
    /// `TemporalProposition` (e.g., `PropositionID`).
    associatedtype AtomicPropositionIdentifier: Hashable

    /// A set containing all possible states of the system model.
    /// While not always strictly required by all algorithms if states are discovered
    /// on-the-fly, providing it can be useful for certain optimizations or sanity checks.
    var allStates: Set<State> { get }

    /// A set of states where the system's execution can begin.
    var initialStates: Set<State> { get }

    /// Returns the set of successor states for a given state.
    ///
    /// This function defines the transition relation of the Kripke structure.
    /// For a given `state`, it returns all states `s'` such that there is a
    /// transition from `state` to `s'`.
    ///
    /// - Parameter state: The current state.
    /// - Returns: A set of states reachable in one step from the `state`.
    ///            If a state has no successors (is a terminal state in a finite trace context,
    ///            though LTL is typically about infinite behaviors), it returns an empty set.
    func successors(of state: State) -> Set<State>

    /// Returns the set of atomic proposition identifiers that are true in the given state.
    ///
    /// This function is the labeling function of the Kripke structure. It determines
    /// which basic facts hold at each particular state. These atomic propositions
    /// are the building blocks of the LTL formulas being checked.
    ///
    /// - Parameter state: The state for which to determine true atomic propositions.
    /// - Returns: A set of `AtomicPropositionIdentifier`s that are considered true
    ///            in the specified `state`.
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier>
}
