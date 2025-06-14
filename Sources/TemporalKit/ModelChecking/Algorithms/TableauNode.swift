import Foundation

// Assumes LTLFormula and TemporalProposition are defined and accessible.

/// Represents a node in the tableau graph during LTL to Büchi Automaton construction.
/// Each node encapsulates a set of formulas that must hold currently and a set for the next state.
internal struct TableauNode<P: TemporalProposition>: Hashable where P.Value == Bool {
    /// Formulas that must be true *now* at this node.
    let currentFormulas: Set<LTLFormula<P>>

    /// Formulas that must be true in the *next* state(s) reached from this node.
    let nextFormulas: Set<LTLFormula<P>>

    // --- Conceptual fields for a more complete TableauNode (from original comments) ---
    // let uniqueID: UUID // For distinctness if formula sets are not canonical enough
    // let processedFormulas: Set<LTLFormula<P>> // Formulas already expanded within this node
    // let incomingEdges: Int // For certain cycle detection or state merging optimizations
    // let justiceRequirementsMet: Set<LTLFormula<P>> // Eventualities that are satisfied *at* this node.
    // let justiceRequirementsPending: Set<LTLFormula<P>> // Eventualities from U, F that are still pending.

    internal func hash(into hasher: inout Hasher) {
        hasher.combine(currentFormulas)
        hasher.combine(nextFormulas)
    }

    internal static func == (lhs: TableauNode<P>, rhs: TableauNode<P>) -> Bool {
        lhs.currentFormulas == rhs.currentFormulas && lhs.nextFormulas == rhs.nextFormulas
    }
}
