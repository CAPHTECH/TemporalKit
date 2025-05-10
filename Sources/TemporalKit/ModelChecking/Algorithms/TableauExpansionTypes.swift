import Foundation

internal typealias FormulaAutomatonState = Int
internal typealias BuchiAlphabetSymbol<PropositionIDType: Hashable> = Set<PropositionIDType>

/// Represents a state in the product automaton constructed during GBA to BA conversion.
/// It combines an original state from the GBA with an index related to GBA acceptance sets.
internal struct ProductBATState<OriginalState: Hashable>: Hashable {
    let originalState: OriginalState
    let index: Int
} 
