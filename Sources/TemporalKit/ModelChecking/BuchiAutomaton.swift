import Foundation

// Assuming PropositionID or a similar identifier for atomic propositions is defined elsewhere,
// e.g., as part of KripkeStructure or TemporalProposition.

/// Represents a (generalized) Büchi Automaton, a type of ω-automaton used in formal verification,
/// particularly for model checking LTL formulas.
///
/// A Büchi automaton operates on infinite input words (sequences of symbols).
/// It accepts an infinite word if there is a run of the automaton on that word
/// that visits at least one of the accepting states infinitely often.
///
/// A Büchi automaton is typically defined by a tuple (Q, Σ, δ, Q₀, F):
/// - `Q`: A finite set of states.
/// - `Σ`: A finite set called the alphabet. For LTL model checking, an alphabet symbol
///          is often a truth assignment to a set of atomic propositions (i.e., `Set<AtomicPropositionIdentifier>`).
/// - `δ`: A transition relation, `δ ⊆ Q × Σ × Q` (or a function `Q × Σ → 2^Q`).
/// - `Q₀`: A set of initial states, `Q₀ ⊆ Q`.
/// - `F`: A set of accepting states, `F ⊆ Q`.
///
/// For Generalized Büchi Automata (GBA), there can be multiple sets of accepting states,
/// and a run is accepting if it visits states from *each* accepting set infinitely often.
/// Standard Büchi automata are a special case with one set of accepting states.
public struct BuchiAutomaton<StateType: Hashable, AlphabetSymbolType: Hashable> {
    /// The type for states in this automaton.
    public typealias State = StateType
    /// The type for symbols in the alphabet this automaton operates on.
    public typealias AlphabetSymbol = AlphabetSymbolType

    /// A transition in the Büchi automaton.
    public struct Transition: Hashable where StateType: Hashable, AlphabetSymbolType: Hashable {
        public let sourceState: State
        // The condition for taking this transition. For LTL, this is often a set of
        // atomic propositions that must hold, or a more complex boolean expression over them.
        // For simplicity here, we use an AlphabetSymbol directly.
        public let symbol: AlphabetSymbol
        public let destinationState: State

        public init(from source: State, on symbol: AlphabetSymbol, to destination: State) {
            self.sourceState = source
            self.symbol = symbol
            self.destinationState = destination
        }
    }

    /// All states in the automaton.
    public let states: Set<State>

    /// The alphabet of the automaton. For LTL, symbols are typically sets of true atomic propositions.
    public let alphabet: Set<AlphabetSymbol> // Or this could be implicitly defined by transitions

    /// The set of initial states.
    public let initialStates: Set<State>

    /// The set of all transitions in the automaton.
    /// This representation is simple but might not be the most efficient for lookups.
    /// A dictionary `[State: [AlphabetSymbol: Set<State>]]` or similar might be used in practice.
    public let transitions: Set<Transition> // Using Set<Transition> requires Transition to be Hashable

    /// The set of accepting states. For a standard Büchi automaton, a run is accepting
    /// if it visits at least one state in `acceptingStates` infinitely often.
    public let acceptingStates: Set<State>

    // For Generalized Büchi Automata (GBA), we might have multiple acceptance sets:
    // public let acceptanceSets: [Set<State>] // Example for GBA

    /// Initializes a new Büchi Automaton.
    /// - Parameters:
    ///   - states: All states in the automaton.
    ///   - alphabet: The alphabet of the automaton.
    ///   - initialStates: The set of initial states.
    ///   - transitions: The set of all transitions.
    ///   - acceptingStates: The set of accepting states.
    public init(
        states: Set<State>,
        alphabet: Set<AlphabetSymbol>,
        initialStates: Set<State>,
        transitions: Set<Transition>,
        acceptingStates: Set<State>
    ) {
        // Basic validation (can be expanded)
        // assert(initialStates.isSubset(of: states), "Initial states must be a subset of all states.")
        // assert(acceptingStates.isSubset(of: states), "Accepting states must be a subset of all states.")
        // for transition in transitions {
        //     assert(states.contains(transition.sourceState), "Transition source state not in all states.")
        //     assert(states.contains(transition.destinationState), "Transition destination state not in all states.")
        //     assert(alphabet.contains(transition.symbol), "Transition symbol not in alphabet.")
        // }

        self.states = states
        self.alphabet = alphabet
        self.initialStates = initialStates
        self.transitions = transitions
        self.acceptingStates = acceptingStates
    }
}

// Note: For actual model checking, more sophisticated representations of transitions
// (e.g., adjacency lists or matrices indexed by state and symbol) would be needed
// for efficient computation of successor states and for constructing product automata.
// The `alphabet` might also be implicitly defined by the system's propositions rather
// than explicitly enumerated if it's very large (2^AP). 
