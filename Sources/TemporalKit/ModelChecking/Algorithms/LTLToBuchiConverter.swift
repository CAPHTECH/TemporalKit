import Foundation

// LTLToBuchiConverter needs to know about LTLFormula, BuchiAutomaton, ProductState (for alphabet consistency perhaps), etc.
// These types should be accessible (internal to the TemporalKit module).

internal enum LTLToBuchiConverter {

    // FormulaAutomatonState is an internal detail of how LTLToBuchiConverter might number its states.
    // It's often just Int.
    // typealias FormulaAutomatonState = Int // Moved to TableauExpansionTypes.swift
    // BuchiAlphabetSymbol will be Set<AnyHashable> or similar, representing truth assignments to propositions.
    // For consistency with LTLModelChecker, using a generic PropositionID type.
    // typealias BuchiAlphabetSymbol<PropositionIDType: Hashable> = Set<PropositionIDType> // Moved to TableauExpansionTypes.swift

    // Define a Hashable product state for the BA construction
    /* Moved to TableauExpansionTypes.swift
    private struct ProductBATState<OriginalState: Hashable>: Hashable {
        let originalState: OriginalState
        let index: Int
    }
    */

    /// Represents a node in the tableau graph during LTL to Büchi Automaton construction.
    /* Moved to TableauNode.swift
    internal struct TableauNode<P: TemporalProposition>: Hashable where P.Value == Bool {
        // ... content ...
    }
    */

    /// Translates an LTL formula into an equivalent Büchi Automaton.
    internal static func translateLTLToBuchi<P: TemporalProposition, PropositionIDType: Hashable>(
        _ ltlFormula: LTLFormula<P>,
        relevantPropositions: Set<PropositionIDType> // Used to define the alphabet of the BA
    ) throws -> BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>> where P.Value == Bool, P.ID == PropositionIDType {
        
        // print("LTLToBuchiConverter: translateLTLToBuchi - WARNING: Using highly detailed PLACEHOLDER structure.")
        // print("LTLToBuchiConverter: Actual tableau logic for formula expansion and GBA construction is NOT implemented.")
        // print("LTLToBuchiConverter: The returned Büchi automaton is a simple placeholder and LIKELY INCORRECT.")

        // --- Step 1: Preprocessing: Convert to Negation Normal Form (NNF) --- 
        let nnfFormula = LTLFormulaNNFConverter.convert(ltlFormula)
        // print("LTLToBuchiConverter: Conceptual NNF: \(nnfFormula)")

        // --- Step 2 & 3: Tableau Construction (GBA states, initial states, transitions) ---
        let tableauConstructor = TableauGraphConstructor<P, PropositionIDType>(
            nnfFormula: nnfFormula,
            originalPreNNFFormula: ltlFormula, // Pass original for heuristics in solve
            relevantPropositions: relevantPropositions
        )
        tableauConstructor.buildGraph()

        let constructedTableauNodes = tableauConstructor.constructedTableauNodes
        let nodeToGBAStateIDMap = tableauConstructor.gbaStateIDMap
        let gbaTransitions = tableauConstructor.resultingGBATransitions
        let gbaInitialStateIDs = tableauConstructor.resultingGBAInitialStateIDs
        let gbaStates = Set(nodeToGBAStateIDMap.values) // All GBA state IDs generated
        
        // The alphabet for the GBA (and final BA) is derived from all possible truth assignments to relevant propositions.
        let gbaAlphabet = Set(Self.generatePossibleAlphabetSymbols(relevantPropositions)) 

        // print("LTLToBuchiConverter: Placeholder tableau expansion loop finished. Generated \(nodeToGBAStateIDMap.count) conceptual states.")

        // --- Step 4: Determine GBA Acceptance Conditions --- 
        let gbaAcceptanceConditionsArray = GBAConditionGenerator<P>.determineConditions(
            tableauNodes: constructedTableauNodes, 
            nodeToStateIDMap: nodeToGBAStateIDMap, 
            originalNNFFormula: nnfFormula
        )
        // print("LTLToBuchiConverter: Conceptual GBA acceptance sets determined: \(gbaAcceptanceConditionsArray.count) sets.")

        // Convert gbaAcceptanceConditions: [Set<FormulaAutomatonState>] to Set<Set<FormulaAutomatonState>> for the converter
        let gbaAcceptanceSets = Set(gbaAcceptanceConditionsArray)

        // --- Step 5: Convert GBA to Standard Büchi Automaton --- 
        let automatonWithProductStates = GBAToBAConverter.convert(
            gbaStates: gbaStates,
            gbaAlphabet: gbaAlphabet,
            gbaTransitions: gbaTransitions, 
            gbaInitialStates: gbaInitialStateIDs,
            gbaAcceptanceSets: gbaAcceptanceSets
        )
        // print("LTLToBuchiConverter: Conceptual GBA to BA conversion finished.")

        // --- Step 6: Map ProductBATState back to FormulaAutomatonState (Int) for the final BA ---
        var productStateToIntMap: [ProductBATState<FormulaAutomatonState>: FormulaAutomatonState] = [:]
        var nextFinalStateID: FormulaAutomatonState = 0

        // Helper to ensure unique Int IDs for product states
        func mapProductStateToFinalInt(_ productState: ProductBATState<FormulaAutomatonState>) -> FormulaAutomatonState {
            if let existingID = productStateToIntMap[productState] {
                return existingID
            }
            let newID = nextFinalStateID
            productStateToIntMap[productState] = newID
            nextFinalStateID += 1
            return newID
        }

        let finalStatesInt: Set<FormulaAutomatonState> = Set(automatonWithProductStates.states.map(mapProductStateToFinalInt))
        let finalInitialStatesInt: Set<FormulaAutomatonState> = Set(automatonWithProductStates.initialStates.map(mapProductStateToFinalInt))
        let finalAcceptingStatesInt: Set<FormulaAutomatonState> = Set(automatonWithProductStates.acceptingStates.map(mapProductStateToFinalInt))

        // ---- START DEBUG LOG FOR automatonWithProductStates.transitions ----
        print("[LTLToBuchiConverter DEBUG] Transitions from GBAToBAConverter (before final mapping) for formula: \(String(describing: ltlFormula))")
        // Sort for consistent logging if possible, based on ProductBATState's components
        let sortedIntermediateTransitions = automatonWithProductStates.transitions.sorted { (t1, t2) -> Bool in
            let t1SourceOrig = String(describing: t1.sourceState.originalState)
            let t2SourceOrig = String(describing: t2.sourceState.originalState)
            if t1SourceOrig != t2SourceOrig { return t1SourceOrig < t2SourceOrig }
            if t1.sourceState.index != t2.sourceState.index { return t1.sourceState.index < t2.sourceState.index }
            
            let t1DestOrig = String(describing: t1.destinationState.originalState)
            let t2DestOrig = String(describing: t2.destinationState.originalState)
            if t1DestOrig != t2DestOrig { return t1DestOrig < t2DestOrig }
            if t1.destinationState.index != t2.destinationState.index { return t1.destinationState.index < t2.destinationState.index }
            return String(describing: t1.symbol).count < String(describing: t2.symbol).count
        }
        for prodTransition in sortedIntermediateTransitions {
            print("    BA_ProductState_Trans: ProductState(orig:\(prodTransition.sourceState.originalState),idx:\(prodTransition.sourceState.index)) -- \(String(describing: prodTransition.symbol)) --> ProductState(orig:\(prodTransition.destinationState.originalState),idx:\(prodTransition.destinationState.index))")
        }
        print("[LTLToBuchiConverter DEBUG] ---- END INTERMEDIATE TRANSITIONS LOG ----")
        // ---- END DEBUG LOG ----

        var finalTransitionsInt = Set<BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.Transition>()
        for prodTransition in automatonWithProductStates.transitions {
            let fromInt = mapProductStateToFinalInt(prodTransition.sourceState)
            let toInt = mapProductStateToFinalInt(prodTransition.destinationState)
            finalTransitionsInt.insert(.init(
                from: fromInt, 
                on: prodTransition.symbol, // Symbol type is BuchiAlphabetSymbol<PropositionIDType>
                to: toInt
            ))
        }

        print("[LTLToBuchiConverter] Final BA for formula \(ltlFormula): States=\(finalStatesInt.count), Initial=\(finalInitialStatesInt.count), Transitions=\(finalTransitionsInt.count), Accepting=\(finalAcceptingStatesInt.count)")

        // ---- START DEBUG LOG FOR FINAL BA TRANSITIONS ----
        print("[LTLToBuchiConverter DEBUG] Final BA Transitions for formula: \(String(describing: ltlFormula))")
        for t in finalTransitionsInt.sorted(by: { (t1, t2) -> Bool in 
            if t1.sourceState != t2.sourceState { return t1.sourceState < t2.sourceState }
            if t1.destinationState != t2.destinationState { return t1.destinationState < t2.destinationState }
            // Symbol comparison is hard, just sort by source/dest for now
            return String(describing: t1.symbol).count < String(describing: t2.symbol).count // Heuristic sort for symbols
        }) {
            print("    \(t.sourceState) -- \(String(describing: t.symbol)) --> \(t.destinationState) (Accepting states: \(finalAcceptingStatesInt))")
        }
        print("[LTLToBuchiConverter DEBUG] ---- END DEBUG LOG ----")
        // ---- END DEBUG LOG ----

        return BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>(
            states: finalStatesInt,
            alphabet: automatonWithProductStates.alphabet, // Alphabet remains the same type
            initialStates: finalInitialStatesInt,
            transitions: finalTransitionsInt,
            acceptingStates: finalAcceptingStatesInt
        )
    }

    // --- Placeholder Helper Functions for LTL-to-Büchi Algorithm --- 

    /* Moved to LTLFormulaNNFConverter.swift
    private static func toNNF<P: TemporalProposition>(_ formula: LTLFormula<P>) -> LTLFormula<P> where P.Value == Bool {
        // ... content ...
    }
    */

    /* Moved to TableauGraphConstructor.swift
    private static func decomposeFormulaForInitialTableauNode<P: TemporalProposition>(_ formula: LTLFormula<P>) -> (current: Set<LTLFormula<P>>, next: Set<LTLFormula<P>>) where P.Value == Bool {
        // ... content ...
    }
    */
    
    /* Moved to TableauGraphConstructor.swift (as instance method with helper `solve`)
    private static func expandFormulasInNode<P: TemporalProposition, PropositionIDType: Hashable>(
        // ... signature ...
    ) -> [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] where P.Value == Bool, P.ID == PropositionIDType {
        // ... content ...
    }
    */

    /* Moved to GBAConditionGenerator.swift
    private static func collectUntilSubformulas<P: TemporalProposition>(from formula: LTLFormula<P>) -> Set<LTLFormula<P>> where P.Value == Bool {
        // ... content ...
    }
    */

    /* Moved to GBAConditionGenerator.swift
    private static func determineGBAConditions<P: TemporalProposition>(
        // ... signature ...
    ) -> [Set<FormulaAutomatonState>] where P.Value == Bool {
        // ... content ...
    }
    */

    /* Moved to GBAToBAConverter.swift
    private static func convertGBAToStandardBA<S: Hashable, A: Hashable>(
        // ... signature ...
    ) -> BuchiAutomaton<ProductBATState<S>, A> {
        // ... content ...
    }
    */
    
    /// Generates all possible truth assignments (alphabet symbols) for the given propositions.
    /// This is a general utility for the LTL to Büchi conversion process.
    internal static func generatePossibleAlphabetSymbols<PropositionIDType: Hashable>(_ propositions: Set<PropositionIDType>) -> [BuchiAlphabetSymbol<PropositionIDType>] {
        if propositions.isEmpty { return [Set()] } // An empty set of propositions means one alphabet symbol: the empty set of true propositions.
        
        var symbols: [BuchiAlphabetSymbol<PropositionIDType>] = []
        let propsArray = Array(propositions)
        
        // Iterate from 0 to 2^N - 1 (where N is the number of propositions)
        // Each integer `i` represents a subset of propositions.
        for i in 0..<(1 << propsArray.count) { 
            var currentSymbolSubset = Set<PropositionIDType>()
            for j in 0..<propsArray.count { 
                // If the j-th bit of i is set, include the j-th proposition in the current subset.
                if (i >> j) & 1 == 1 { 
                    currentSymbolSubset.insert(propsArray[j])
                }
            }
            symbols.append(currentSymbolSubset)
        }
        // This explicit check for emptiness handles the 0 propositions case correctly via the initial check.
        // If propositions is non-empty, symbols will not be empty.
        return symbols // symbols.isEmpty ? [Set()] : symbols -> This was the original, but first check covers it.
    }
} 
