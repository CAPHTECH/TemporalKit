import Foundation
@testable import TemporalKit

/// Utility functions for common test patterns to eliminate code duplication.
/// This provides reusable components for test classes.
struct TestKripkeStructureHelper {
    
    /// Creates a proposition evaluation closure that uses a pre-computed state mapping.
    /// This ensures thread safety by avoiding self-capture in @Sendable closures.
    static func createPropositionEvaluator(
        stateMapping: [String: [String]]
    ) -> @Sendable (String, String) -> Bool {
        return { state, propositionId in
            guard let propositions = stateMapping[state] else { return false }
            return propositions.contains(propositionId)
        }
    }
    
    /// Creates a thread-safe proposition using a pre-computed state mapping.
    static func makeProposition(
        id: String,
        stateMapping: [String: [String]]
    ) -> ClosureTemporalProposition<String, Bool> {
        let evaluator = createPropositionEvaluator(stateMapping: stateMapping)
        
        return TemporalKit.makeProposition(
            id: id,
            name: id,
            evaluate: { (state: String) -> Bool in
                evaluator(state, id)
            }
        )
    }
}