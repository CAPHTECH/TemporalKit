import Foundation

/// Represents the outcome of an LTL (Linear Temporal Logic) model checking procedure.
///
/// Model checking determines if a given system model satisfies a specified LTL formula.
public enum ModelCheckResult<State: Hashable> {
    /// Indicates that the LTL formula holds true for all possible behaviors of the model.
    case holds

    /// Indicates that the LTL formula does not hold for the model.
    /// This case includes a `counterexample`, which is a specific execution trace (path)
    /// in the model that violates the formula.
    case fails(counterexample: Counterexample<State>)
}

/// Represents a counterexample for an LTL formula that fails in a model.
///
/// A counterexample is an infinite path (behavior) in the Kripke structure (model)
/// that demonstrates how the LTL formula is violated. It is typically represented
/// as a finite sequence of states (the prefix) leading to a state from which
/// another finite sequence of states (the cycle) repeats infinitely.
///
/// For example, if a formula `G p` (globally `p`) fails, the counterexample
/// would show a path leading to a state where `p` is false.
public struct Counterexample<State: Hashable> {
    /// The finite sequence of states from an initial state of the model
    /// to the beginning of the repeating cycle.
    public let prefix: [State]

    /// The finite sequence of states that forms the infinitely repeating cycle.
    /// The system transitions from the last state of `prefix` to the first state of `cycle`,
    /// and then repeatedly traverses the `cycle` states.
    public let cycle: [State]

    /// A textual description of the infinite path represented by this counterexample.
    /// The cycle part is typically denoted with parentheses and an infinity symbol (∞).
    /// Example: `s0 -> s1 -> (s2 -> s3 -> s2)∞` where `s2 -> s3 -> s2` is the cycle.
    public var infinitePathDescription: String {
        let prefixStatesString = prefix.map { "\($0)" }.joined(separator: " -> ")
        let cycleStatesString = cycle.map { "\($0)" }.joined(separator: " -> ")

        if cycle.isEmpty {
            // This case might represent a finite path violating a safety property,
            // or if the prefix itself forms a complete lasso leading to an accepting state
            // in the product automaton.
            return prefixStatesString
        }

        if prefix.isEmpty {
            // The counterexample starts directly with a cycle from an initial state.
            return "(\(cycleStatesString))∞"
        }

        // Standard representation: prefix leading into a cycle.
        return "\(prefixStatesString) -> (\(cycleStatesString))∞"
    }

    /// Initializes a new counterexample.
    /// - Parameters:
    ///   - prefix: The sequence of states leading up to the cycle. Must not be empty
    ///             if `cycle` is empty and represents a finite violating path.
    ///   - cycle: The sequence of states forming the repeating cycle. Can be empty
    ///            only if the `prefix` itself constitutes the full counterexample (rare for LTL).
    public init(prefix: [State], cycle: [State]) {
        // Basic validation: A counterexample should not be entirely empty.
        // A more robust validation might depend on the specific model checking algorithm used.
        // For LTL, counterexamples are infinite paths, so a cycle is generally expected.
        // However, some algorithms might produce a finite prefix that implies a violation.
        // assert(!prefix.isEmpty || !cycle.isEmpty, "A counterexample cannot be entirely empty.")
        self.prefix = prefix
        self.cycle = cycle
    }
}
