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
        
        let nnfFormula = LTLFormulaNNFConverter.convert(ltlFormula)
        // print("LTLToBuchiConverter: Conceptual NNF: \(nnfFormula)")

        let tableauConstructor = TableauGraphConstructor<P, PropositionIDType>(
            nnfFormula: nnfFormula,
            originalPreNNFFormula: ltlFormula, 
            relevantPropositions: relevantPropositions
        )
        tableauConstructor.buildGraph()

        let constructedTableauNodes = tableauConstructor.constructedTableauNodes
        let nodeToGBAStateIDMap = tableauConstructor.gbaStateIDMap
        let gbaTransitions = tableauConstructor.resultingGBATransitions
        let gbaInitialStateIDs = tableauConstructor.resultingGBAInitialStateIDs
        let gbaStates = Set(nodeToGBAStateIDMap.values) 
        
        let gbaAlphabet = Set(Self.generatePossibleAlphabetSymbols(relevantPropositions)) 

        // print("LTLToBuchiConverter: Placeholder tableau expansion loop finished. Generated \(nodeToGBAStateIDMap.count) conceptual states.")

        let gbaAcceptanceConditionsArray = GBAConditionGenerator<P>.determineConditions(
            tableauNodes: constructedTableauNodes, 
            nodeToStateIDMap: nodeToGBAStateIDMap, 
            originalNNFFormula: nnfFormula
        )
        // print("LTLToBuchiConverter: Conceptual GBA acceptance sets determined: \(gbaAcceptanceConditionsArray.count) sets.")
        
        let _ = Set(gbaAcceptanceConditionsArray) // Corrected: gbaAcceptanceSets was unused, replaced with _

        // Corrected type for gbaAcceptanceSets based on GBAToBAConverter's expectation
        let automatonWithProductStates = GBAToBAConverter.convert(
            gbaStates: gbaStates,
            gbaInitialStates: gbaInitialStateIDs, 
            gbaTransitions: gbaTransitions, 
            gbaAcceptanceSets: gbaAcceptanceConditionsArray, // Pass the array directly
            alphabet: gbaAlphabet 
        )
        // print("LTLToBuchiConverter: Conceptual GBA to BA conversion finished.")

        var productStateToIntMap: [GBAToBAConverter<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.ProductBATState<FormulaAutomatonState>: FormulaAutomatonState] = [:]
        var nextFinalStateID: FormulaAutomatonState = 0

        func mapProductStateToFinalInt(_ productState: GBAToBAConverter<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.ProductBATState<FormulaAutomatonState>) -> FormulaAutomatonState {
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

        // ---- REMOVED LTLToBuchiConverter DEBUG for intermediate transitions ----
        // print("[LTLToBuchiConverter DEBUG] Transitions from GBAToBAConverter (before final mapping) for formula: \(String(describing: ltlFormula))")
        // let sortedIntermediateTransitions = automatonWithProductStates.transitions.sorted { (t1, t2) -> Bool in
        //     // ... sorting logic ...
        // }
        // for prodTransition in sortedIntermediateTransitions {
        //     print("    BA_ProductState_Trans: ProductState(orig:\(prodTransition.sourceState.originalState),idx:\(prodTransition.sourceState.index)) -- \(String(describing: prodTransition.symbol)) --> ProductState(orig:\(prodTransition.destinationState.originalState),idx:\(prodTransition.destinationState.index))")
        // }
        // print("[LTLToBuchiConverter DEBUG] ---- END INTERMEDIATE TRANSITIONS LOG ----")

        var finalTransitionsInt = Set<BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.Transition>()
        for prodTransition in automatonWithProductStates.transitions {
            let fromInt = mapProductStateToFinalInt(prodTransition.sourceState)
            let toInt = mapProductStateToFinalInt(prodTransition.destinationState)
            finalTransitionsInt.insert(.init(
                from: fromInt, 
                on: prodTransition.symbol, 
                to: toInt
            ))
        }

        // ---- REMOVED LTLToBuchiConverter DEBUG for final BA ----
        // print("[LTLToBuchiConverter] Final BA for formula \(ltlFormula): States=\(finalStatesInt.count), Initial=\(finalInitialStatesInt.count), Transitions=\(finalTransitionsInt.count), Accepting=\(finalAcceptingStatesInt.count)")
        // print("[LTLToBuchiConverter DEBUG] Final BA Transitions for formula: \(String(describing: ltlFormula))")
        // for t in finalTransitionsInt.sorted(by: { (t1, t2) -> Bool in 
        //     // ... sorting logic ...
        // }) {
        //     print("    \(t.sourceState) -- \(String(describing: t.symbol)) --> \(t.destinationState) (Accepting states: \(finalAcceptingStatesInt))")
        // }
        // print("[LTLToBuchiConverter DEBUG] ---- END DEBUG LOG ----")

        return BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>(
            states: finalStatesInt,
            alphabet: automatonWithProductStates.alphabet, 
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
        if propositions.isEmpty { return [Set()] } 
        
        var symbols: [BuchiAlphabetSymbol<PropositionIDType>] = []
        let propsArray = Array(propositions)
        
        for i in 0..<(1 << propsArray.count) { 
            var currentSymbolSubset = Set<PropositionIDType>()
            for j in 0..<propsArray.count { 
                if (i >> j) & 1 == 1 { 
                    currentSymbolSubset.insert(propsArray[j])
                }
            }
            symbols.append(currentSymbolSubset)
        }
        return symbols
    }
} 
