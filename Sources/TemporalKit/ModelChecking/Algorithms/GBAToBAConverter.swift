import Foundation

// Assumes BuchiAutomaton, ProductBATState, BuchiAlphabetSymbol, and FormulaAutomatonState (implicitly via S) are defined and accessible.

internal struct GBAToBAConverter<S: Hashable, SymbolT: Hashable> {

    internal struct ProductBATState<OriginalState: Hashable>: Hashable, CustomStringConvertible {
        let originalState: OriginalState
        let index: Int
        var description: String { "(s:\(originalState), i:\(index))" }
    }

    /// Converts a Generalized Büchi Automaton (GBA) to a standard Büchi Automaton (BA).
    /// - Parameters:
    ///   - gbaStates: Set of states in the GBA.
    ///   - gbaInitialStates: Set of initial states in the GBA.
    ///   - gbaTransitions: Set of transitions in the GBA.
    ///   - gbaAcceptanceSets: An array of sets of GBA states, representing F_0, F_1, ..., F_{k-1}.
    ///                      A run in the GBA is accepting if it visits states from each `F_i` infinitely often.
    ///   - alphabet: The alphabet of the GBA.
    /// - Returns: An equivalent standard Büchi Automaton.
    internal static func convert(
        gbaStates: Set<S>,
        gbaInitialStates: Set<S>,
        gbaTransitions: Set<BuchiAutomaton<S, SymbolT>.Transition>,
        gbaAcceptanceSets: [Set<S>], // F_0, F_1, ..., F_{k-1}
        alphabet: Set<SymbolT>
    ) -> BuchiAutomaton<ProductBATState<S>, SymbolT> {

        let k = gbaAcceptanceSets.count

        if k == 0 { // No acceptance conditions (e.g., for LTL formula 'true')
            let baStates = Set(gbaStates.map { ProductBATState(originalState: $0, index: 0) })
            let baInitialStates = Set(gbaInitialStates.map { ProductBATState(originalState: $0, index: 0) })
            let baTransitions = Set(gbaTransitions.map { gbaTrans in
                BuchiAutomaton<ProductBATState<S>, SymbolT>.Transition(
                    from: ProductBATState(originalState: gbaTrans.sourceState, index: 0),
                    on: gbaTrans.symbol,
                    to: ProductBATState(originalState: gbaTrans.destinationState, index: 0)
                )
            })
            return BuchiAutomaton(
                states: baStates,
                alphabet: alphabet, // Corrected order
                initialStates: baInitialStates,
                transitions: baTransitions,
                acceptingStates: baStates // All states are accepting
            )
        }

        var productBAStates = Set<ProductBATState<S>>()
        var productBAInitialStates = Set<ProductBATState<S>>()
        var productBATransitions = Set<BuchiAutomaton<ProductBATState<S>, SymbolT>.Transition>()
        var productBAAcceptingStates = Set<ProductBATState<S>>()

        let orderedAcceptanceSets = Array(gbaAcceptanceSets)

        for q_gba in gbaStates {
            for i in 0..<k {
                let productState = ProductBATState(originalState: q_gba, index: i)
                productBAStates.insert(productState)

                if gbaInitialStates.contains(q_gba) && i == 0 {
                    productBAInitialStates.insert(productState)
                }

                if i == 0 && orderedAcceptanceSets[0].contains(q_gba) {
                    productBAAcceptingStates.insert(productState)
                }
            }
        }

        for gbaTransition in gbaTransitions {
            let q_source_gba = gbaTransition.sourceState
            let symbol_on = gbaTransition.symbol
            let q_dest_gba = gbaTransition.destinationState

            for i in 0..<k {
                let current_Fi = orderedAcceptanceSets[i]
                var j_next_index = i

                if current_Fi.contains(q_source_gba) {
                    j_next_index = (i + 1) % k
                }

                let productStateFrom = ProductBATState(originalState: q_source_gba, index: i)
                let productStateTo = ProductBATState(originalState: q_dest_gba, index: j_next_index)

                if productBAStates.contains(productStateFrom) && productBAStates.contains(productStateTo) {
                    productBATransitions.insert(BuchiAutomaton<ProductBATState<S>, SymbolT>.Transition(from: productStateFrom, on: symbol_on, to: productStateTo))

                }
            }
        }


        let finalBuchiAutomaton = BuchiAutomaton(
            states: productBAStates,
            alphabet: alphabet, // Corrected order
            initialStates: productBAInitialStates,
            transitions: productBATransitions,
            acceptingStates: productBAAcceptingStates
        )

        // ---- DEBUG PRINT for GBAToBAConverter output ----
        // Heuristic check: if original state type might be DemoKripkeModelState (by checking string description of one of the original GBA states)
        var isDemoRelated = false
        if let firstGbaState = gbaStates.first, String(describing: firstGbaState).contains("DemoKripkeModelState") {
            isDemoRelated = true
        }

        if isDemoRelated {
            print("[GBAToBAConverter DEBUG OUTPUT for Demo-related Automaton]")
            print("    Input GBA Acceptance Sets (count: \(gbaAcceptanceSets.count)): \(gbaAcceptanceSets.map { $0.map { String(describing: $0) }.sorted() })")
            print("    BA Initial States (count: \(finalBuchiAutomaton.initialStates.count)):")
            finalBuchiAutomaton.initialStates.sorted(by: { String(describing: $0) < String(describing: $1) }).forEach { initState in
                print("        \(initState)")
            }
            print("    BA Accepting States (count: \(finalBuchiAutomaton.acceptingStates.count)):")
            finalBuchiAutomaton.acceptingStates.sorted(by: { String(describing: $0) < String(describing: $1) }).forEach { accState in
                print("        \(accState)")
            }
        }
        // ---- END DEBUG ----
        return finalBuchiAutomaton
    }
}
