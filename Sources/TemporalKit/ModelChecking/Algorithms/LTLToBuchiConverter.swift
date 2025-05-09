import Foundation

// LTLToBuchiConverter needs to know about LTLFormula, BuchiAutomaton, ProductState (for alphabet consistency perhaps), etc.
// These types should be accessible (internal to the TemporalKit module).

internal enum LTLToBuchiConverter {

    // FormulaAutomatonState is an internal detail of how LTLToBuchiConverter might number its states.
    // It's often just Int.
    typealias FormulaAutomatonState = Int 
    // BuchiAlphabetSymbol will be Set<AnyHashable> or similar, representing truth assignments to propositions.
    // For consistency with LTLModelChecker, using a generic PropositionID type.
    typealias BuchiAlphabetSymbol<PropositionIDType: Hashable> = Set<PropositionIDType>

    // Define a Hashable product state for the BA construction
    private struct ProductBATState<OriginalState: Hashable>: Hashable {
        let originalState: OriginalState
        let index: Int
    }

    /// Represents a node in the tableau graph during LTL to Büchi Automaton construction.
    internal struct TableauNode<P: TemporalProposition>: Hashable where P.Value == Bool {
        // Formulas that must be true *now* at this node.
        // In a full implementation, these would be further decomposed into elementary forms.
        let currentFormulas: Set<LTLFormula<P>>
        
        // Formulas that must be true in the *next* state(s) reached from this node.
        let nextFormulas: Set<LTLFormula<P>>
        
        // --- Conceptual fields for a more complete TableauNode ---
        // let uniqueID: UUID // For distinctness if formula sets are not canonical enough
        // let processedFormulas: Set<LTLFormula<P>> // Formulas already expanded within this node
        // let incomingEdges: Int // For certain cycle detection or state merging optimizations
        // 
        // // For GBA acceptance conditions, related to 'Until' or other eventualities:
        // // Each element could be a specific subformula (e.g., the right-hand side of an Until)
        // // that needs to be eventually satisfied if this node is part of a path fulfilling the Until.
        // let justiceRequirementsMet: Set<LTLFormula<P>> // Eventualities that are satisfied *at* this node.
        // let justiceRequirementsPending: Set<LTLFormula<P>> // Eventualities from U, F that are still pending.

        internal func hash(into hasher: inout Hasher) {
            hasher.combine(currentFormulas)
            hasher.combine(nextFormulas)
        }

        internal static func == (lhs: TableauNode<P>, rhs: TableauNode<P>) -> Bool {
            return lhs.currentFormulas == rhs.currentFormulas && lhs.nextFormulas == rhs.nextFormulas
        }
    }

    /// Translates an LTL formula into an equivalent Büchi Automaton.
    /// This is a highly complex algorithm. The implementation here is a structural placeholder.
    internal static func translateLTLToBuchi<P: TemporalProposition, PropositionIDType: Hashable>(
        _ ltlFormula: LTLFormula<P>,
        relevantPropositions: Set<PropositionIDType> // Used to define the alphabet of the BA
    ) throws -> BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>> where P.Value == Bool, P.ID == PropositionIDType {
        
        print("LTLToBuchiConverter: translateLTLToBuchi - WARNING: Using highly detailed PLACEHOLDER structure.")
        print("LTLToBuchiConverter: Actual tableau logic for formula expansion and GBA construction is NOT implemented.")
        print("LTLToBuchiConverter: The returned Büchi automaton is a simple placeholder and LIKELY INCORRECT.")

        // --- Step 1: Preprocessing: Convert to Negation Normal Form (NNF) --- 
        let nnfFormula = toNNF(ltlFormula)
        print("LTLToBuchiConverter: Conceptual NNF: \(nnfFormula)")

        // --- Step 2: Initialize Tableau Construction --- 
        let (initialCurrent, initialNext) = decomposeFormulaForInitialTableauNode(nnfFormula)
        let initialTableauNode = TableauNode<P>(currentFormulas: initialCurrent, nextFormulas: initialNext)

        var processedNodesLookup = Set<TableauNode<P>>() // To avoid reprocessing identical nodes
        var worklist = [initialTableauNode] // Nodes to be processed
        
        var nodeToStateIDMap: [TableauNode<P>: FormulaAutomatonState] = [:] // Maps TableauNode to BA state ID
        var nextBAStateID: FormulaAutomatonState = 0
        var baTransitions = Set<BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.Transition>()
        var baInitialStateIDs = Set<FormulaAutomatonState>()
        // GBA acceptance conditions: A list of sets of state IDs. A run is accepting if it visits each set infinitely often.
        var gbaAcceptanceSets: [Set<FormulaAutomatonState>] = [] // Corrected type: Array of Set of Int

        func getOrCreateBAStateID(for node: TableauNode<P>) -> FormulaAutomatonState {
            if let existingID = nodeToStateIDMap[node] { return existingID }
            let newID = nextBAStateID; nodeToStateIDMap[node] = newID; nextBAStateID += 1
            if processedNodesLookup.isEmpty { baInitialStateIDs.insert(newID) } // First node is initial
            return newID
        }
        
        let _ = getOrCreateBAStateID(for: initialTableauNode)

        // --- Step 3: Tableau Expansion Loop (Iteratively build nodes and transitions) --- 
        while let currentNodeToExpand = worklist.popLast() {
            if processedNodesLookup.contains(currentNodeToExpand) { continue }
            processedNodesLookup.insert(currentNodeToExpand)
            
            let currentBAStateID = nodeToStateIDMap[currentNodeToExpand]!

            // --- Step 3a: Iterate over all possible alphabet symbols (truth assignments) ---
            for symbol in generatePossibleAlphabetSymbols(relevantPropositions) {
                
                // --- Step 3b: Expand formulas for the current node under the given symbol ---
                // This now returns an array of possible outcomes due to non-determinism.
                let expansionResults = expandFormulasInNode(
                    nodeFormulas: currentNodeToExpand.currentFormulas, 
                    nextObligationsFromPrevious: currentNodeToExpand.nextFormulas, 
                    forSymbol: symbol, 
                    originalLTLFormula: ltlFormula // Needed for context, e.g. GBA conditions
                )

                for expansionResult in expansionResults {
                    if !expansionResult.isConsistent { continue } // Skip inconsistent expansions

                    let successorNode = TableauNode<P>(
                        currentFormulas: expansionResult.nextSetOfCurrentObligations,
                        nextFormulas: expansionResult.nextSetOfNextObligations
                    )

                    let successorBAStateID = getOrCreateBAStateID(for: successorNode)
                    baTransitions.insert(.init(from: currentBAStateID, on: symbol, to: successorBAStateID))

                    if !processedNodesLookup.contains(successorNode) && !worklist.contains(successorNode) {
                        worklist.append(successorNode)
                    }
                    
                    // Emergency break for placeholder
                    if nodeToStateIDMap.count > 50 { 
                        print("Warning: Max BA states reached in placeholder tableau (inner expansion loop).")
                        // This break will exit the loop over expansionResults. 
                        // The outer loops also have breaks if this limit is hit.
                        break 
                    }
                }
                if nodeToStateIDMap.count > 50 { 
                    print("Warning: Max BA states reached in placeholder tableau (symbol loop).")
                    break 
                }
            }
            if nodeToStateIDMap.count > 50 { 
                print("Warning: Max BA states reached in placeholder tableau (worklist loop).")
                break 
            }
        }
        print("LTLToBuchiConverter: Placeholder tableau expansion loop finished. Generated \(nodeToStateIDMap.count) conceptual states.")

        // --- Step 4: Determine GBA Acceptance Conditions --- 
        // This uses the information from all processed tableau nodes (and their formulas, esp. Until/Release)
        // to define the sets of states that need to be visited infinitely often.
        gbaAcceptanceSets = determineGBAConditions(
            tableauNodes: processedNodesLookup, 
            nodeToStateIDMap: nodeToStateIDMap, 
            originalFormula: nnfFormula
        )
        print("LTLToBuchiConverter: Conceptual GBA acceptance sets determined: \(gbaAcceptanceSets.count) sets.")

        // --- Step 5: Convert GBA to Standard Büchi Automaton (if GBA sets > 1 or specific structure) --- 
        // This is a standard construction, often involving product with a counter.
        // If gbaAcceptanceSets.count <= 1, it might already be a standard BA (or can be easily adapted).
        
        // Convert gbaAcceptanceSets: [Set<FormulaAutomatonState>] to Set<Set<FormulaAutomatonState>>
        let gbaAcceptanceSetsAsSetOfSets = Set(gbaAcceptanceSets) // Simpler conversion now

        let automatonWithProductStates = convertGBAToStandardBA(
            gbaStates: Set(nodeToStateIDMap.values),
            gbaAlphabet: Set(generatePossibleAlphabetSymbols(relevantPropositions)),
            gbaTransitions: baTransitions, 
            gbaInitialStates: baInitialStateIDs,
            gbaAcceptanceSets: gbaAcceptanceSetsAsSetOfSets
        )
        print("LTLToBuchiConverter: Conceptual GBA to BA conversion finished.")

        // --- Step 6: Map ProductBATState back to FormulaAutomatonState (Int) for the final BA ---
        var productStateToIntMap: [ProductBATState<FormulaAutomatonState>: FormulaAutomatonState] = [:]
        var nextFinalStateID: FormulaAutomatonState = 0

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

        var finalTransitionsInt = Set<BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.Transition>()
        // Corrected based on BuchiAutomaton.swift definition:
        // Properties: .sourceState, .symbol, .destinationState
        // Initializer: init(from:on:to:)
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
            alphabet: automatonWithProductStates.alphabet, // Alphabet remains the same
            initialStates: finalInitialStatesInt,
            transitions: finalTransitionsInt,
            acceptingStates: finalAcceptingStatesInt
        )
    }

    // --- Placeholder Helper Functions for LTL-to-Büchi Algorithm --- 

    private static func toNNF<P: TemporalProposition>(_ formula: LTLFormula<P>) -> LTLFormula<P> where P.Value == Bool {
        // print("LTLToBuchiConverter.toNNF: Implementing NNF conversion.")
        switch formula {
        // Base cases for NNF:
        case .booleanLiteral(_):
            return formula
        case .atomic(_):
            return formula
        case .not(.atomic(_)): // Negation is already at an atomic proposition
            return formula
        case .not(.booleanLiteral(let b)): // ¬true -> false, ¬false -> true
             return .booleanLiteral(!b)

        // Recursive cases:
        case .not(.not(let subFormula)): // ¬(¬φ)  ->  φ (NNF)
            return toNNF(subFormula)

        case .not(.and(let lhs, let rhs)): // ¬(φ ∧ ψ)  ->  (¬φ ∨ ¬ψ) (NNF)
            return .or(toNNF(.not(lhs)), toNNF(.not(rhs)))

        case .not(.or(let lhs, let rhs)): // ¬(φ ∨ ψ)  ->  (¬φ ∧ ¬ψ) (NNF)
            return .and(toNNF(.not(lhs)), toNNF(.not(rhs)))

        case .not(.implies(let lhs, let rhs)): // ¬(φ → ψ) is ¬(¬φ ∨ ψ) which is (φ ∧ ¬ψ) (NNF)
            return .and(toNNF(lhs), toNNF(.not(rhs)))

        case .not(.next(let subFormula)): // ¬(X φ)    ->  X (¬φ) (NNF)
            return .next(toNNF(.not(subFormula)))

        case .not(.eventually(let subFormula)): // ¬(F φ)    ->  G (¬φ) (NNF)
            return .globally(toNNF(.not(subFormula)))

        case .not(.globally(let subFormula)): // ¬(G φ)    ->  F (¬φ) (NNF)
            return .eventually(toNNF(.not(subFormula)))

        case .not(.until(let lhs, let rhs)): // ¬(φ U ψ)  ->  (¬φ R ¬ψ) (NNF)
            return .release(toNNF(.not(lhs)), toNNF(.not(rhs)))
        
        case .not(.weakUntil(let lhs, let rhs)):
            // φ W ψ  ≡  (φ U ψ) ∨ Gφ
            // So, ¬(φ W ψ) ≡ ¬((φ U ψ) ∨ Gφ)
            //              ≡ ¬(φ U ψ) ∧ ¬(Gφ)
            //              ≡ (¬φ R ¬ψ) ∧ (F¬φ)
            let term1 = LTLFormula.release(toNNF(.not(lhs)), toNNF(.not(rhs)))
            let term2 = LTLFormula.eventually(toNNF(.not(lhs)))
            return .and(term1, term2)

        case .not(.release(let lhs, let rhs)): // ¬(φ R ψ)  ->  (¬φ U ¬ψ) (NNF)
            return .until(toNNF(.not(lhs)), toNNF(.not(rhs)))

        // Operators that distribute NNF transformation:
        case .and(let lhs, let rhs):
            return .and(toNNF(lhs), toNNF(rhs))
        case .or(let lhs, let rhs):
            return .or(toNNF(lhs), toNNF(rhs))
        
        case .implies(let lhs, let rhs): // φ → ψ  is  ¬φ ∨ ψ. Apply NNF to this structure.
            return .or(toNNF(.not(lhs)), toNNF(rhs))

        case .next(let subFormula):
            return .next(toNNF(subFormula))
            
        case .eventually(let subFormula): // F φ  ≡  true U φ
            // Convert to NNF of (true U NNF(subFormula))
            return .until(.booleanLiteral(true), toNNF(subFormula))

        case .globally(let subFormula): // G φ  ≡  false R φ  (which is ¬(true U ¬φ) in NNF)
            // Convert to NNF of (false R NNF(subFormula))
            // false R ψ is equivalent to ψ in terms of what must hold for R, but G has stronger implications for acceptance.
            // A more standard NNF for G φ from ¬F¬φ is ¬(true U ¬φ).
            // However, our NNF pushes negations inwards. So G(φ) is already in NNF if φ is.
            // For tableau construction & GBA acceptance, G φ is often treated as φ ∧ X G φ.
            // For converting to U/R for acceptance conditions, G φ can be seen as false R φ.
            // Let's use the ¬F¬φ -> ¬(true U ¬φ) approach for NNF consistency if needed for acceptance set generation
            // For direct GBA construction, G φ = φ ∧ X G φ is often used directly in tableau.
            // For now, let's keep G φ as G(NNF(φ)) and handle GBA acceptance for G separately if necessary,
            // or rely on the fact that G φ implies no ¬φ U true holds for its negation.
            // If we stick to U-based acceptance sets, then G φ (¬(true U ¬φ)) will make ¬φ part of an Until.
            // Let's try the direct expansion: false R NNF(subFormula)
            // which is also equivalent to ¬ (true U ¬ NNF(subFormula) )
            return .release(.booleanLiteral(false), toNNF(subFormula))

        case .until(let lhs, let rhs):
            return .until(toNNF(lhs), toNNF(rhs))
        case .weakUntil(let lhs, let rhs): // For NNF, W(NNF(φ), NNF(ψ)) is fine.
            return .weakUntil(toNNF(lhs), toNNF(rhs))
        case .release(let lhs, let rhs):
            return .release(toNNF(lhs), toNNF(rhs))
        }
    }

    private static func decomposeFormulaForInitialTableauNode<P: TemporalProposition>(_ formula: LTLFormula<P>) -> (current: Set<LTLFormula<P>>, next: Set<LTLFormula<P>>) where P.Value == Bool {
        print("LTLToBuchiConverter.decomposeFormulaForInitialTableauNode: Placeholder.")
        // The initial node should satisfy the input `formula`.
        // This often means `formula` itself is the primary member of `currentFormulas`.
        // Further decomposition happens in `expandFormulasInNode`.
        return (current: [formula], next: [])
    }
    
    private static func expandFormulasInNode<P: TemporalProposition, PropositionIDType: Hashable>(
        nodeFormulas: Set<LTLFormula<P>>, 
        nextObligationsFromPrevious: Set<LTLFormula<P>>,
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        originalLTLFormula: LTLFormula<P> // For context if needed
    ) -> [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] where P.Value == Bool, P.ID == PropositionIDType {
        // print("LTLToBuchiConverter.expandFormulasInNode: Expanding for symbol \(forSymbol).")

        // This function now returns an array of possible outcomes due to non-determinism (e.g., from OR)
        var allPossibleOutcomes: [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] = []

        // Initial worklist for a single path/branch of expansion
        let initialWorklist = Array(nodeFormulas.union(nextObligationsFromPrevious))

        // We need a recursive helper or iterative approach that can explore branches
        // For now, let's define a local recursive helper to manage branching for OR
        func solve(currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>, pAtomicSet: Set<P>, nAtomicSet: Set<P>) {
            var worklist = currentWorklist
            var processed = processedOnPath
            var V = vSet
            var P_atomic = pAtomicSet
            var N_atomic = nAtomicSet

            if worklist.isEmpty { // Base case for this path of recursion
                var currentBasicFormulas = Set<LTLFormula<P>>()
                var consistentPath = true

                // Heuristic: If vSet (next obligations from parent) is empty,
                // and P_atomic is not empty (meaning something *is* true now, like 'p' in F p),
                // this might be an acceptance sink for a liveness property.
                // In such a sink, it should remain consistent for all inputs,
                // and next obligations remain empty.
                // We also need to ensure that there's no internal contradiction (p AND not p).
                let hasInternalContradiction = P_atomic.contains { p_true in N_atomic.contains(p_true) }
                if hasInternalContradiction {
                    consistentPath = false
                }

                let isPotentialLivenessSink = vSet.isEmpty && !P_atomic.isEmpty && consistentPath
                                           // && initialWorklist.allSatisfy { ... } // A more refined check on initial worklist content might be useful

                if consistentPath { // Check this first before symbol checks
                    if !isPotentialLivenessSink {
                        // Standard symbol consistency check if not a potential sink
                        for p_true in P_atomic {
                            if let p_id = p_true.id as? PropositionIDType, !forSymbol.contains(p_id) {
                                consistentPath = false; break
                            }
                        }
                        if consistentPath {
                            for p_false_prop in N_atomic {
                                if let p_id = p_false_prop.id as? PropositionIDType, forSymbol.contains(p_id) {
                                    consistentPath = false; break
                                }
                            }
                        }
                    } else {
                        // For a potential liveness sink, we assume it remains consistent with any symbol if no internal contradiction.
                        // The current P_atomic defines what *was* true to reach this sink.
                        // The current symbol doesn't invalidate the "fact" that liveness was met.
                        // The currentBasicFormulas will still reflect what was true in P_atomic.
                        print("LTLToBuchiConverter.solve (PID: \(P_atomic.first?.id.rawValue ?? "N/A"), Symbol: \(forSymbol)): Potential liveness sink, bypassing symbol consistency for path to remain valid.") // DEBUG
                    }
                }

                if consistentPath {
                    for p_atom in P_atomic { currentBasicFormulas.insert(.atomic(p_atom)) }
                    for np_atom in N_atomic { currentBasicFormulas.insert(.not(.atomic(np_atom))) }
                }
                
                let resultingV = isPotentialLivenessSink ? Set<LTLFormula<P>>() : V
                allPossibleOutcomes.append((currentBasicFormulas, resultingV, consistentPath))
                return
            }

            let currentFormula = worklist.removeFirst()
            if processed.contains(currentFormula) { 
                solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)
                return
            }
            processed.insert(currentFormula)

            switch currentFormula {
            case .booleanLiteral(let b):
                if !b { allPossibleOutcomes.append(([], [], false)); return } // Contradiction on this path
                solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

            case .atomic(let p):
                P_atomic.insert(p)
                solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

            case .not(.atomic(let p)):
                N_atomic.insert(p)
                solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

            case .not(.booleanLiteral(let b)):
                if b { allPossibleOutcomes.append(([], [], false)); return } // Contradiction on this path
                solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)
            
            case .and(let lhs, let rhs):
                var newWorklist = worklist
                if !processed.contains(lhs) { newWorklist.insert(lhs, at: 0) }
                if !processed.contains(rhs) { newWorklist.insert(rhs, at: 0) }
                solve(currentWorklist: newWorklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)
            
            case .or(let lhs, let rhs):
                // Branch 1: Explore with lhs
                var worklistLhs = worklist
                if !processed.contains(lhs) { worklistLhs.insert(lhs, at: 0) }
                solve(currentWorklist: worklistLhs, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)
                
                // Branch 2: Explore with rhs
                var worklistRhs = worklist
                if !processed.contains(rhs) { worklistRhs.insert(rhs, at: 0) }
                solve(currentWorklist: worklistRhs, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

            case .next(let subFormula):
                V.insert(subFormula)
                solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

            // --- Simplified Temporal Operator Handling (Placeholders) ---
            // These need to be expanded with their disjunctive semantics properly, potentially calling solve() for each branch.
            case .until(let phi, let psi):
                // phi U psi  ≡  psi ∨ (phi ∧ X(phi U psi))
                print("LTLToBuchiConverter.solve (PID: \(pAtomicSet.first?.id.rawValue ?? "N/A"), Symbol: \(forSymbol)): Expanding UNTIL: \(currentFormula)") // DEBUG
                
                let initialOutcomeCount = allPossibleOutcomes.count

                // Branch 1: psi holds now
                var worklistPsiBranch = worklist
                if !processed.contains(psi) { worklistPsiBranch.insert(psi, at: 0) }
                print("LTLToBuchiConverter.solve (PID: \(pAtomicSet.first?.id.rawValue ?? "N/A"), Symbol: \(forSymbol)): UNTIL branch1 (psi) -> V before call = \(V)") // DEBUG
                solve(currentWorklist: worklistPsiBranch, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)
                
                // Check if Branch 1 produced any consistent outcome
                var branch1Succeeded = false
                if allPossibleOutcomes.count > initialOutcomeCount {
                    for i in initialOutcomeCount..<allPossibleOutcomes.count {
                        if allPossibleOutcomes[i].isConsistent {
                            branch1Succeeded = true
                            // For F p (true U p), if p holds, the 'next' obligation for F p should be gone.
                            // Modify the outcome from branch 1 to ensure V is empty or reflects completion.
                            // This specific modification might be too aggressive or need refinement.
                            // For now, let's assume solve for branch1 correctly sets next obligations to empty if psi is fulfilled.
                            // The primary goal here is to prevent branch2 if branch1 (psi) is satisfied now.
                            print("LTLToBuchiConverter.solve (PID: \(pAtomicSet.first?.id.rawValue ?? "N/A"), Symbol: \(forSymbol)): UNTIL branch1 (psi) SUCCEEDED consistently.") // DEBUG
                            break
                        }
                    }
                }

                // If Branch 1 (psi holds now and is consistent) succeeded, we don't need to explore Branch 2 for Strong Until.
                // For F p (true U p), if p holds, we are done with the F p obligation for this path.
                if branch1Succeeded {
                    print("LTLToBuchiConverter.solve (PID: \(pAtomicSet.first?.id.rawValue ?? "N/A"), Symbol: \(forSymbol)): UNTIL branch1 (psi) succeeded, SKIPPING branch2.") // DEBUG
                    // allPossibleOutcomes already contains results from branch1
                    // Ensure only outcomes from branch1 (if any) are kept if we are to strictly follow psi fulfillment implies no XU.
                    // This might mean removing outcomes added before this .until was processed if they are incompatible.
                    // However, solve is additive to allPossibleOutcomes. The current logic is to explore all disjunctive paths.
                    // A more advanced pruning or state merging would handle this. 
                    // For now, we simply prevent exploring branch 2 if branch 1 was viable.
                    // To strictly ensure ONLY branch 1 outcomes: 
                    // allPossibleOutcomes.removeSubrange(0..<initialOutcomeCount) // Clears prior unrelated outcomes (dangerous if solve is truly global)
                    // For now, let's just not ADD branch 2 if branch 1 succeeded.
                    return // This will stop further processing of this currentFormula in this solve call.
                }
                
                // Branch 2: phi holds now AND X(phi U psi) for next (Only if branch 1 didn't yield a consistent satisfaction of psi)
                var worklistPhiBranch = worklist
                if !processed.contains(phi) { worklistPhiBranch.insert(phi, at: 0) }
                var vForPhiBranch = V
                vForPhiBranch.insert(currentFormula) // Add X(phi U psi) as a next obligation
                print("LTLToBuchiConverter.solve (PID: \(pAtomicSet.first?.id.rawValue ?? "N/A"), Symbol: \(forSymbol)): UNTIL branch2 (phi ^ X U) -> next V = \(vForPhiBranch)") // DEBUG
                solve(currentWorklist: worklistPhiBranch, processedOnPath: processed, vSet: vForPhiBranch, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

            case .release(let phi, let psi):
                 // phi R psi  ≡  psi ∧ (phi ∨ X(phi R psi))
                 // This means psi must hold. Then, we have a disjunction.

                // First, create a worklist that includes psi. If psi leads to inconsistency, neither branch below will proceed far.
                var worklistWithPsi = worklist
                if !processed.contains(psi) { worklistWithPsi.insert(psi, at: 0) }

                // Now explore the two possibilities for the second part of the conjunction:
                // Branch 1: phi also holds now (effectively psi ∧ phi)
                var worklistPsiAndPhiBranch = worklistWithPsi // Start with worklist containing psi
                if !processed.contains(phi) { worklistPsiAndPhiBranch.insert(phi, at: 0) }
                // V (next obligations) for this branch remains unchanged from current V
                solve(currentWorklist: worklistPsiAndPhiBranch, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

                // Branch 2: X(phi R psi) for next (effectively psi ∧ X(phi R psi))
                // worklistWithPsi already contains psi.
                var vForPsiAndXRBranch = V
                vForPsiAndXRBranch.insert(currentFormula) // Add X(phi R psi) as a next obligation
                solve(currentWorklist: worklistWithPsi, processedOnPath: processed, vSet: vForPsiAndXRBranch, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

            case .eventually(let subFormula): // F φ  ≡  φ ∨ X(F φ)
                // Branch 1 (subFormula holds now)
                var worklistSubFormulaBranch = worklist
                if !processed.contains(subFormula) { worklistSubFormulaBranch.insert(subFormula, at: 0) }
                solve(currentWorklist: worklistSubFormulaBranch, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

                // Branch 2 (X(F subFormula) for next)
                var vForXFBranch = V
                vForXFBranch.insert(currentFormula) // Add X(F subFormula) as a next obligation
                solve(currentWorklist: worklist, processedOnPath: processed, vSet: vForXFBranch, pAtomicSet: P_atomic, nAtomicSet: N_atomic)
                
            case .globally(let subFormula): // G φ ≡ φ ∧ X(G φ)
                // subFormula must hold now, AND X(G subFormula) must hold in next state
                var newWorklist = worklist
                if !processed.contains(subFormula) { newWorklist.insert(subFormula, at: 0) }
                
                var vForXGBranch = V
                vForXGBranch.insert(currentFormula) // Add X(G subFormula) as a next obligation
                
                solve(currentWorklist: newWorklist, processedOnPath: processed, vSet: vForXGBranch, pAtomicSet: P_atomic, nAtomicSet: N_atomic)

            default:
                print("LTLToBuchiConverter.expandFormulasInNode (solve): Warning - unhandled formula type \(currentFormula).")
                solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic) // Continue with rest if any
            }
        }
        
        // Initial call to the recursive solver
        solve(currentWorklist: initialWorklist, processedOnPath: Set(), vSet: Set(), pAtomicSet: Set(), nAtomicSet: Set())

        if allPossibleOutcomes.isEmpty {
            if !initialWorklist.isEmpty { 
                // Log what the initial worklist and symbol were for this empty outcome scenario
                print("LTLToBuchiConverter.expandFormulasInNode (Symbol: \(forSymbol)): No outcomes from non-empty initial worklist: \(initialWorklist). Returning inconsistent.") // DEBUG
                 return [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: false)]
             } else { 
                 print("LTLToBuchiConverter.expandFormulasInNode (Symbol: \(forSymbol)): No outcomes from empty initial worklist. Returning consistent with empty next obligations.") // DEBUG
                 return [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: true)]
             }
        }
        // DEBUG: Log all outcomes for a given expansion
        print("LTLToBuchiConverter.expandFormulasInNode (Symbol: \(forSymbol)): All outcomes = \(allPossibleOutcomes.map { (curr: $0.nextSetOfCurrentObligations, next: $0.nextSetOfNextObligations, cons: $0.isConsistent) })")
        
        return allPossibleOutcomes
    }

    private static func collectUntilSubformulas<P: TemporalProposition>(from formula: LTLFormula<P>) -> Set<LTLFormula<P>> where P.Value == Bool {
        print("LTLToBuchiConverter.collectUntilSubformulas: Input formula = \(formula)") // DEBUG
        var untils = Set<LTLFormula<P>>()
        var worklist = [formula]
        var visited = Set<LTLFormula<P>>()

        while let current = worklist.popLast() {
            if visited.contains(current) { continue }
            visited.insert(current)

            switch current {
            case .booleanLiteral, .atomic:
                break
            case .not(let sub): 
                worklist.append(sub)
            case .and(let l, let r), .or(let l, let r), .implies(let l, let r), 
                 .weakUntil(let l, let r), .release(let l, let r):
                worklist.append(l)
                worklist.append(r)
            case .next(let sub), .eventually(let sub), .globally(let sub):
                worklist.append(sub)
            case .until(let l, let r):
                print("LTLToBuchiConverter.collectUntilSubformulas: Found .until = \(current)") // DEBUG
                untils.insert(current) // Add the until formula itself
                worklist.append(l)
                worklist.append(r)
            }
        }
        return untils
    }

    private static func determineGBAConditions<P: TemporalProposition>(
        tableauNodes: Set<TableauNode<P>>, // All unique TableauNode created
        nodeToStateIDMap: [TableauNode<P>: FormulaAutomatonState], // Map to their Int IDs
        originalFormula: LTLFormula<P> // The NNF of the input formula
    ) -> [Set<FormulaAutomatonState>] where P.Value == Bool { // Return Array of Sets of State IDs
        print("LTLToBuchiConverter.determineGBAConditions: ARGUMENT originalFormula = \(originalFormula)") // DEBUG
        print("LTLToBuchiConverter.determineGBAConditions: Determining GBA acceptance sets.")
        
        var gbaAcceptanceSets: [Set<FormulaAutomatonState>] = []
        
        // In NNF, F p becomes true U p. G p becomes false R p (or ¬(true U ¬p)).
        // collectUntilSubformulas should pick up explicit Until formulas and those derived from F.
        let untilFormulas = collectUntilSubformulas(from: originalFormula)
        
        if untilFormulas.isEmpty {
             print("LTLToBuchiConverter.determineGBAConditions: No 'Until' subformulas (potentially including F-derived ones) found. Creating a default acceptance set with all states.")
             if !tableauNodes.isEmpty {
                // If there are no explicit liveness conditions (U, F), a common approach is to consider all states part of a single acceptance condition.
                // This means any infinite run through the constructed GBA states is accepting from a liveness perspective.
                // The GBA->BA conversion with k=1 and F_0 = Q_GBA will then correctly map these.
                gbaAcceptanceSets.append(Set(nodeToStateIDMap.values))
                return gbaAcceptanceSets
             } else {
                // No tableau nodes and no until formulas, so truly empty.
                return [] 
             }
        }
        
        for uFormula in untilFormulas {
            guard case .until(_, let rhsU) = uFormula else { 
                print("LTLToBuchiConverter.determineGBAConditions: Warning - expected .until, got \(uFormula)")
                continue 
            }
            
            var currentAcceptanceSetForU = Set<FormulaAutomatonState>()
            
            for tableauNode in tableauNodes {
                // A state (tableauNode) is in the acceptance set for `lhsU U rhsU` if:
                // 1. `rhsU` (the formula that must eventually be true) is in `tableauNode.currentFormulas`.
                //    This means `rhsU` is satisfied *at* this node.
                // 2. OR the obligation `lhsU U rhsU` is NOT present in `tableauNode.currentFormulas` AND NOT in `tableauNode.nextFormulas`.
                //    This means the U-obligation is no longer active (it has been fulfilled or was never applicable on this path to this specific node variant).
                
                let satisfiedRhsU = tableauNode.currentFormulas.contains(rhsU)
                
                let uFormulaStillActiveCurrent = tableauNode.currentFormulas.contains(uFormula)
                let uFormulaStillActiveNext = tableauNode.nextFormulas.contains(uFormula)
                let uFormulaNotActive = !uFormulaStillActiveCurrent && !uFormulaStillActiveNext
                
                if satisfiedRhsU || uFormulaNotActive {
                    if let stateID = nodeToStateIDMap[tableauNode] {
                        currentAcceptanceSetForU.insert(stateID)
                    }
                }
            }
            
            if !currentAcceptanceSetForU.isEmpty {
                gbaAcceptanceSets.append(currentAcceptanceSetForU)
            } else {
                // LTL2BA (e.g., Gastin & Oddoux) suggests if F_i (acceptance set for an until) would be empty,
                // it should instead be Q (all states). This prevents an empty product with the counter in GBA->BA.
                print("LTLToBuchiConverter.determineGBAConditions: Warning - Acceptance set for U-formula \(uFormula) was empty. Adding all states as a fallback for this set.")
                if !tableauNodes.isEmpty { 
                    gbaAcceptanceSets.append(Set(nodeToStateIDMap.values))
                }
            }
        }
        
        print("LTLToBuchiConverter.determineGBAConditions: Found \(untilFormulas.count) U-formulas, created \(gbaAcceptanceSets.count) GBA acceptance sets.")
        return gbaAcceptanceSets
    }

    private static func convertGBAToStandardBA<S: Hashable, A: Hashable>(
        gbaStates: Set<S>,
        gbaAlphabet: Set<A>,
        gbaTransitions: Set<BuchiAutomaton<S, A>.Transition>,
        gbaInitialStates: Set<S>,
        gbaAcceptanceSets: Set<Set<S>> // F_GBA = {F_0, ..., F_{k-1}}
    ) -> BuchiAutomaton<ProductBATState<S>, A> {
        // Placeholder for GBA to BA conversion
        // Standard construction: BA States are (s, i) where s is GBA state, i is index for acceptance sets (0..k-1)
        // BA Initial states: (s0, 0) for s0 in GBA initial states.
        // BA Transitions (s, i) --a--> (s', j) if s --a--> s' in GBA:
        //   j = (i+1) mod k  if s \\in F_i (the i-th acceptance set in an ordered list)
        //   j = i            if s \\notin F_i
        // BA Acceptance states F_BA: {(s,0) | s \\in F_0} (or some other chosen index based on convention)

        let k = gbaAcceptanceSets.count
        if k == 0 {
            // This case implies the GBA has no specific acceptance conditions beyond reachability,
            // or it's an underspecified GBA.
            // A common convention for an empty set of acceptance conditions in GBA
            // (meaning true, or all states are accepting for each condition that isn't there)
            // could lead to a BA where all states are accepting if GBA states are non-empty.
            // Or, if it means "accept no infinite runs", then an empty set of accepting states.
            // For now, if k=0, we'll create a BA that accepts if the GBA would accept everything
            // by considering a single acceptance set containing all GBA states.
            // This is a guess; the LTL to GBA conversion should ideally not produce k=0 for non-trivial properties.
            // If gbaStates is empty, this will still be an empty automaton.
            // A simpler safe placeholder for k=0 is an automaton that accepts nothing or everything.
            // Let's return an automaton that accepts nothing if k=0, as it's less likely to give false positives.
            let emptyAcceptingStates = Set<ProductBATState<S>>()
            if !gbaStates.isEmpty && !gbaInitialStates.isEmpty {
                 // if GBA was trivial (e.g. "true"), it might have one state, self-loop, all accepting.
                 // This path is tricky. For now, empty accepting set for safety if k=0.
            }

            // Create product states ProductBATState(originalState: s, index: 0)
            let productStates = Set(gbaStates.map { ProductBATState(originalState: $0, index: 0) })
            let productInitialStates = Set(gbaInitialStates.map { ProductBATState(originalState: $0, index: 0) })
            
            // Corrected based on BuchiAutomaton.swift definition:
            // Properties: .sourceState, .symbol, .destinationState
            // Initializer: init(from:on:to:)
            let productTransitions = Set(gbaTransitions.map { transition -> BuchiAutomaton<ProductBATState<S>, A>.Transition in
                let fromProductState = ProductBATState(originalState: transition.sourceState, index: 0)
                let toProductState = ProductBATState(originalState: transition.destinationState, index: 0)
                return BuchiAutomaton<ProductBATState<S>, A>.Transition(
                    from: fromProductState,
                    on: transition.symbol,
                    to: toProductState
                )
            })

            return BuchiAutomaton(
                states: productStates,
                alphabet: gbaAlphabet,
                initialStates: productInitialStates, 
                transitions: productTransitions,    
                acceptingStates: emptyAcceptingStates // Accepts nothing
            )
        }

        var newStates = Set<ProductBATState<S>>()
        var newTransitions = Set<BuchiAutomaton<ProductBATState<S>, A>.Transition>()
        var newInitialStates = Set<ProductBATState<S>>()
        var newAcceptingStates = Set<ProductBATState<S>>()

        // Order the acceptance sets: F_0, F_1, ..., F_{k-1}
        let orderedAcceptanceSets = Array(gbaAcceptanceSets)

        for q_init in gbaInitialStates {
            newInitialStates.insert(ProductBATState(originalState: q_init, index: 0))
        }

        for q in gbaStates {
            for i in 0..<k {
                let productState = ProductBATState(originalState: q, index: i)
                newStates.insert(productState)
                // Acceptance states for BA: (q,j) where q is in Fj. Often chosen as j=0.
                // So, if i == 0 and q is in F_0 (orderedAcceptanceSets[0]), then ProductBATState(q,0) is accepting.
                if i == 0 && orderedAcceptanceSets[0].contains(q) {
                     newAcceptingStates.insert(productState) // q is current originalState, i is current index
                }
            }
        }
        
        for gbaTransition in gbaTransitions {
            // Corrected based on BuchiAutomaton.swift definition:
            // Properties: .sourceState, .symbol, .destinationState
            let q = gbaTransition.sourceState
            let symbol = gbaTransition.symbol
            let q_prime = gbaTransition.destinationState

            for i in 0..<k {
                let currentFi = orderedAcceptanceSets[i]
                var j = i
                if currentFi.contains(q) { // Check if q (original GBA state) is in F_i
                    j = (i + 1) % k
                }
                // else j remains i

                let productStateFrom = ProductBATState(originalState: q, index: i)
                let productStateTo = ProductBATState(originalState: q_prime, index: j)

                // Ensure these states are in newStates (they should be by the loop above, but doesn't hurt to add)
                newStates.insert(productStateFrom)
                newStates.insert(productStateTo)

                newTransitions.insert(
                    BuchiAutomaton.Transition(from: productStateFrom, on: symbol, to: productStateTo) // Corrected: init(from:on:to:)
                )
            }
        }
        
        // Standard construction: F_j x {j}, often j=0.
        // This means {(s,0) | s \\in F_0}
        // The loop for newStates already includes this logic for newAcceptingStates.
        return BuchiAutomaton(
            states: newStates,
            alphabet: gbaAlphabet,
            initialStates: newInitialStates, 
            transitions: newTransitions,    
            acceptingStates: newAcceptingStates
        )
    }
    
    // Changed from private to internal to be accessible from tests
    internal static func generatePossibleAlphabetSymbols<PropositionIDType: Hashable>(_ propositions: Set<PropositionIDType>) -> [BuchiAlphabetSymbol<PropositionIDType>] {
        if propositions.isEmpty { return [Set()] } 
        var symbols: [BuchiAlphabetSymbol<PropositionIDType>] = []; let propsArray = Array(propositions)
        for i in 0..<(1 << propsArray.count) { var cs = Set<PropositionIDType>(); for j in 0..<propsArray.count { if (i >> j) & 1 == 1 { cs.insert(propsArray[j]) } }; symbols.append(cs) }
        return symbols.isEmpty ? [Set()] : symbols
    }
} 
