import Foundation

// Assumes BuchiAutomaton, ProductBATState, BuchiAlphabetSymbol, and FormulaAutomatonState (implicitly via S) are defined and accessible.

internal struct GBAToBAConverter {

    /// Converts a Generalized Büchi Automaton (GBA) to a standard Büchi Automaton (BA).
    /// - Parameters:
    ///   - gbaStates: Set of states in the GBA.
    ///   - gbaAlphabet: Alphabet of the GBA.
    ///   - gbaTransitions: Set of transitions in the GBA.
    ///   - gbaInitialStates: Set of initial states in the GBA.
    ///   - gbaAcceptanceSets: A set of sets of GBA states. `F_GBA = {F_0, ..., F_{k-1}}`.
    ///     A run in the GBA is accepting if it visits states from each `F_i` infinitely often.
    /// - Returns: An equivalent standard Büchi Automaton.
    internal static func convert<S: Hashable, A: Hashable>(
        gbaStates: Set<S>,
        gbaAlphabet: Set<A>,
        gbaTransitions: Set<BuchiAutomaton<S, A>.Transition>,
        gbaInitialStates: Set<S>,
        gbaAcceptanceSets: Set<Set<S>> // F_GBA = {F_0, ..., F_{k-1}}
    ) -> BuchiAutomaton<ProductBATState<S>, A> {
        // Standard construction: BA States are (s, i) where s is GBA state, i is an index (0..k-1) for acceptance sets.
        // BA Initial states: (s0, 0) for s0 in GBA initial states.
        // BA Transitions (q, i) --a--> (q', j) if q --a--> q' in GBA:
        //   j = (i+1) mod k  if q ∈ F_i (the i-th acceptance set in an ordered list of GBA acceptance sets)
        //   j = i            if q ∉ F_i
        // BA Acceptance states F_BA: {(q,0) | q ∈ F_0} (or commonly, any {(q,j) | q ∈ F_j} for a fixed j, often j=0 or j=k-1).
        // We use the convention that F_BA = {(q,0) | q ∈ F_0}, assuming F_0 is the target for the counter to reset.

        let k = gbaAcceptanceSets.count

        if k == 0 {
            // If there are no acceptance conditions (k=0), it means the GBA accepts all infinite runs ( vacuously true for "for each F_i").
            // This translates to a BA where all states are accepting if they are part of some cycle.
            // A simpler interpretation is that all states reachable become accepting. If the LTL formula was `true`.
            // For safety, if k=0 and GBA is non-empty, often implies GBA accepts everything. The BA should reflect this.
            // The standard construction with k=0 would lead to index always being 0.
            // Transitions (q,0) -> (q',0). Accepting states would be (q,0) if q in F_0 (which is empty/non-existent here).
            // So, if k=0, it implies all states might as well be accepting in the BA if the GBA has any states.
            // However, if the LTL was `false`, GBA might be empty or have no accepting runs. 
            // Let's follow the structure: if k=0, the modulo logic for `j` is ill-defined. 
            // A common fallback for k=0 (GBA accepts all its languages) is BA where all states are accepting.
            // If gbaStates is empty, it correctly results in an empty BA.

            var productStates = Set<ProductBATState<S>>()
            var productInitialStates = Set<ProductBATState<S>>()
            var productTransitions = Set<BuchiAutomaton<ProductBATState<S>, A>.Transition>()
            // If k=0, all product states (s,0) could be considered accepting if GBA was non-empty.
            // This matches the behavior if there was one F_i = Q_GBA.
            var productAcceptingStates = Set<ProductBATState<S>>()

            for s_init in gbaInitialStates {
                productInitialStates.insert(ProductBATState(originalState: s_init, index: 0))
            }
            for s in gbaStates {
                let prodState = ProductBATState(originalState: s, index: 0)
                productStates.insert(prodState)
                productAcceptingStates.insert(prodState) // All states accepting if k=0 and GBA non-empty
            }
            for gbaTrans in gbaTransitions {
                let fromProd = ProductBATState(originalState: gbaTrans.sourceState, index: 0)
                let toProd = ProductBATState(originalState: gbaTrans.destinationState, index: 0)
                productTransitions.insert(.init(from: fromProd, on: gbaTrans.symbol, to: toProd))
            }
            
            if gbaStates.isEmpty { productAcceptingStates = [] } // No states, no accepting states.

            return BuchiAutomaton(
                states: productStates,
                alphabet: gbaAlphabet,
                initialStates: productInitialStates,
                transitions: productTransitions,
                acceptingStates: productAcceptingStates
            )
        }

        var newStates = Set<ProductBATState<S>>()
        var newTransitions = Set<BuchiAutomaton<ProductBATState<S>, A>.Transition>()
        var newInitialStates = Set<ProductBATState<S>>()
        var newAcceptingStates = Set<ProductBATState<S>>()

        // Order the acceptance sets: F_0, F_1, ..., F_{k-1}
        // The order can matter for which F_i is chosen for the BA's acceptance condition.
        // Sorting them (e.g., by hash value or a canonical representation if Set<S> isn't directly comparable)
        // might provide a deterministic order, but Array(Set) is sufficient if the choice of F_0 is arbitrary but consistent.
        let orderedAcceptanceSets = Array(gbaAcceptanceSets)

        // ---- GBAToBAConverter DEBUG ----
        if k > 0 && !orderedAcceptanceSets.isEmpty { // k > 0 implies orderedAcceptanceSets is not empty
            print("[GBAToBAConverter DEBUG] Number of GBA acceptance sets (k): \(k)")
            // Assuming S is CustomStringConvertible or has a reasonable description for logging
            let f0Content = orderedAcceptanceSets[0].map { String(describing: $0) }.sorted().joined(separator: ", ")
            print("[GBAToBAConverter DEBUG] F_0 (orderedAcceptanceSets[0]): {\(f0Content)}")
        } else if k > 0 {
             print("[GBAToBAConverter DEBUG] k = \(k) but orderedAcceptanceSets is empty. This is unexpected.")
        } else { // k == 0, handled by the if k == 0 block earlier
             print("[GBAToBAConverter DEBUG] k = 0, GBA to BA conversion uses simplified logic (all states accepting if GBA non-empty).")
        }
        // ---- END DEBUG ----

        // Populate initial product states: (s0, 0)
        for q_init in gbaInitialStates {
            newInitialStates.insert(ProductBATState(originalState: q_init, index: 0))
        }

        // Populate all product states (q, i) and determine BA accepting states
        for q_gba in gbaStates {
            for i in 0..<k {
                let productState = ProductBATState(originalState: q_gba, index: i)
                newStates.insert(productState)
                
                // BA Acceptance states F_BA: e.g., {(s,0) | s ∈ F_0 from GBA}
                // The counter aims to cycle through 0, 1, ..., k-1, and acceptance happens when it hits 0
                // *and* the GBA state q_gba is in the GBA acceptance set F_0 that F_BA targets.
                if i == 0 && orderedAcceptanceSets[0].contains(q_gba) {
                     newAcceptingStates.insert(productState)
                }
            }
        }
        
        // Create product transitions
        for gbaTransition in gbaTransitions {
            let q_source_gba = gbaTransition.sourceState
            let symbol = gbaTransition.symbol
            let q_dest_gba = gbaTransition.destinationState

            for i in 0..<k { // For each current index of the counter
                let current_Fi = orderedAcceptanceSets[i] // This is F_i
                var j_next_index = i // Next index for the counter
                
                let isIn_current_Fi = current_Fi.contains(q_source_gba)
                if isIn_current_Fi {
                    j_next_index = (i + 1) % k
                }

                // ---- GBAToBAConverter DEBUG for specific GBA state ----
                let qSourceDesc = String(describing: q_source_gba)
                let pDemoLikeRawValue = "p_demo_like" // Target proposition for F(!p_demo_like)
                var isPotentiallyProblematicFNotPSinkTransition = false
                // A simple heuristic: if the GBA state description is short (e.g. just an Int ID) 
                // and it's involved with symbols related to p_demo_like or empty set.
                if qSourceDesc.count < 5 { // Arbitrary short length for typical Int IDs
                    let symbolDescription = String(describing: symbol)
                    // Check if symbol involves p_demo_like or is an empty set representation
                    if symbolDescription.contains(pDemoLikeRawValue) || symbolDescription == "[]" || symbolDescription == "Set([])" {
                        isPotentiallyProblematicFNotPSinkTransition = true
                    }
                }

                if isPotentiallyProblematicFNotPSinkTransition {
                    let f0ContentForLog = (k > 0 && !orderedAcceptanceSets.isEmpty) ? orderedAcceptanceSets[0].map { String(describing: $0) }.sorted().joined(separator: ", ") : "N/A (k=\(k))"
                    print("[GBAToBAConverter Transition DEBUG]")
                    print("    GBA Trans: \(q_source_gba) --\(String(describing: symbol))--> \(q_dest_gba)")
                    print("    Current BA index i=\(i). q_source_gba (\(q_source_gba)) \(isIn_current_Fi ? "IS" : "is NOT") in F_\(i) (F_\(i) = \(current_Fi.map{String(describing:$0)}.sorted().joined(separator:", ")).")
                    print("    Calculated next BA index j=\(j_next_index).")
                    print("    (Debug context: F_0 = {\(f0ContentForLog)}) ")
                }
                // ---- END DEBUG ----

                let productStateFrom = ProductBATState(originalState: q_source_gba, index: i)
                let productStateTo = ProductBATState(originalState: q_dest_gba, index: j_next_index)

                newTransitions.insert(
                    BuchiAutomaton.Transition(from: productStateFrom, on: symbol, to: productStateTo)
                )

                // Log for GBA self-loops and their BA counterparts
                if q_source_gba == q_dest_gba {
                    let gbaAcceptingInfo = current_Fi.contains(q_source_gba) ? "(in F_\(i))" : "(not in F_\(i))"
                    // Reduce verbosity of this existing log if new detailed log above is active
                    if !isPotentiallyProblematicFNotPSinkTransition { // Avoid duplicate detailed logging for same transition
                        print("[GBAToBAConverter Self-Loop Check] GBA: \(q_source_gba) \(gbaAcceptingInfo) --\(String(describing: symbol))--> \(q_dest_gba)")
                        print("    Converted to BA: ProductState(orig:\(productStateFrom.originalState),idx:\(productStateFrom.index)) --\(String(describing: symbol))--> ProductState(orig:\(productStateTo.originalState),idx:\(productStateTo.index))")
                        if productStateFrom == productStateTo {
                            print("        BA transition IS a self-loop.")
                        } else {
                            print("        BA transition IS NOT a self-loop. FromIdx=\(i), ToIdx=\(j_next_index)")
                        }
                    }
                }
            }
        }
        
        // Ensure initial states are also in the main state set (should be by construction)
        newInitialStates.forEach { newStates.insert($0) }

        return BuchiAutomaton(
            states: newStates,
            alphabet: gbaAlphabet,
            initialStates: newInitialStates, 
            transitions: newTransitions,    
            acceptingStates: newAcceptingStates
        )
    }
} 
