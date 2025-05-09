// Sources/TemporalKit/ModelChecking/ProductStateRepresentation.swift

import Foundation

/// Represents a state in a product automaton, typically formed by combining states
/// from two other automata (e.g., a model automaton and a formula automaton).
///
/// - Parameters:
///   - S1: The type of the state from the first automaton.
///   - S2: The type of the state from the second automaton.
internal struct ProductState<S1: Hashable, S2: Hashable>: Hashable {
    internal let s1: S1
    internal let s2: S2

    internal init(_ s1: S1, _ s2: S2) {
        self.s1 = s1
        self.s2 = s2
    }

    // Explicit Hashable conformance is often good for clarity with generics,
    // though Swift can synthesize it if S1 and S2 are Hashable.
    internal func hash(into hasher: inout Hasher) {
        hasher.combine(s1)
        hasher.combine(s2)
    }

    // Explicit Equatable conformance (required by Hashable)
    internal static func == (lhs: ProductState<S1, S2>, rhs: ProductState<S1, S2>) -> Bool {
        return lhs.s1 == rhs.s1 && lhs.s2 == rhs.s2
    }
} 
