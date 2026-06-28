import Foundation

internal enum LTLToBuchiConverter {


    /// Translates an LTL formula into an equivalent Büchi Automaton.
    internal static func translateLTLToBuchi<P: TemporalProposition, PropositionIDType: Hashable>(
        _ ltlFormula: LTLFormula<P>,
        relevantPropositions: Set<PropositionIDType> // Used to define the alphabet of the BA
    ) throws -> BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>> where P.Value == Bool, P.ID == PropositionIDType {

        let nnfFormula = LTLFormulaNNFConverter.convert(ltlFormula)

        let tableauConstructor = TableauGraphConstructor<P, PropositionIDType>(
            nnfFormula: nnfFormula,
            originalPreNNFFormula: ltlFormula,
            relevantPropositions: relevantPropositions
        )
        try tableauConstructor.buildGraph()

        let constructedTableauNodes = tableauConstructor.constructedTableauNodes
        let nodeToGBAStateIDMap = tableauConstructor.gbaStateIDMap
        let gbaTransitions = tableauConstructor.resultingGBATransitions
        let gbaInitialStateIDs = tableauConstructor.resultingGBAInitialStateIDs
        let gbaStates = Set(nodeToGBAStateIDMap.values)

        let gbaAlphabet = Set(Self.generatePossibleAlphabetSymbols(relevantPropositions))


        let gbaAcceptanceConditionsArray = GBAConditionGenerator<P>.determineConditions(
            tableauNodes: constructedTableauNodes,
            nodeToStateIDMap: nodeToGBAStateIDMap,
            originalNNFFormula: nnfFormula
        )

        _ = Set(gbaAcceptanceConditionsArray) // Corrected: gbaAcceptanceSets was unused, replaced with _

        // Corrected type for gbaAcceptanceSets based on GBAToBAConverter's expectation
        let automatonWithProductStates = GBAToBAConverter.convert(
            gbaStates: gbaStates,
            gbaInitialStates: gbaInitialStateIDs,
            gbaTransitions: gbaTransitions,
            gbaAcceptanceSets: gbaAcceptanceConditionsArray, // Pass the array directly
            alphabet: gbaAlphabet
        )

        var productStateToIntMap: [GBAToBAConverter<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.ProductBATState<FormulaAutomatonState>: FormulaAutomatonState] = [:]
        var nextFinalStateID: FormulaAutomatonState = 0

        func mapProductStateToFinalInt(
            _ productState: GBAToBAConverter<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>
                .ProductBATState<FormulaAutomatonState>
        ) -> FormulaAutomatonState {
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

        return BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>(
            states: finalStatesInt,
            alphabet: automatonWithProductStates.alphabet,
            initialStates: finalInitialStatesInt,
            transitions: finalTransitionsInt,
            acceptingStates: finalAcceptingStatesInt
        )
    }

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
