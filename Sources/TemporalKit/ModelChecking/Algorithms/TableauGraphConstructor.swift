import Foundation

// Assumes LTLFormula, TemporalProposition, TableauNode, BuchiAlphabetSymbol, 
// FormulaAutomatonState, BuchiAutomaton.Transition are defined and accessible.
// Also assumes LTLToBuchiConverter.generatePossibleAlphabetSymbols is available if not inlined.

internal class TableauGraphConstructor<P: TemporalProposition, PropositionIDType: Hashable> 
    where P.Value == Bool, P.ID == PropositionIDType 
{
    private let nnfLTLFormula: LTLFormula<P>
    private let originalPreNNFLTLFormula: LTLFormula<P> // For heuristics in solve that might need original structure
    private let relevantPropositions: Set<PropositionIDType>

    // Internal state for tableau construction - results are accessed via public getters after buildGraph()
    private var processedNodesLookup: Set<TableauNode<P>> = []
    private var worklist: [TableauNode<P>] = []
    private var nodeToStateIDMap: [TableauNode<P>: FormulaAutomatonState] = [:]
    private var nextGBAStateID: FormulaAutomatonState = 0 // Renamed from nextBAStateID for clarity
    private var gbaTransitions: Set<BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.Transition> = []
    private var gbaInitialStateIDs: Set<FormulaAutomatonState> = [] // Renamed for clarity

    // Public accessors for the results of the construction
    internal var constructedTableauNodes: Set<TableauNode<P>> { processedNodesLookup }
    internal var gbaStateIDMap: [TableauNode<P>: FormulaAutomatonState] { nodeToStateIDMap }
    internal var resultingGBATransitions: Set<BuchiAutomaton<FormulaAutomatonState, BuchiAlphabetSymbol<PropositionIDType>>.Transition> { gbaTransitions }
    internal var resultingGBAInitialStateIDs: Set<FormulaAutomatonState> { gbaInitialStateIDs }

    init(nnfFormula: LTLFormula<P>, originalPreNNFFormula: LTLFormula<P>, relevantPropositions: Set<PropositionIDType>) {
        self.nnfLTLFormula = nnfFormula
        self.originalPreNNFLTLFormula = originalPreNNFFormula
        self.relevantPropositions = relevantPropositions
    }

    /// Decomposes the initial NNF formula to form the first TableauNode.
    private static func decomposeFormulaForInitialTableauNode(_ formula: LTLFormula<P>) -> TableauNode<P> {
        // print("TableauGraphConstructor.decomposeFormulaForInitialTableauNode: Placeholder from original.")
        // The initial node should satisfy the input `formula` (which is NNF here).
        // `formula` itself is the primary member of `currentFormulas`.
        // Further decomposition happens in `expandFormulasInNode`.
        return TableauNode<P>(currentFormulas: [formula], nextFormulas: [])
    }

    /// Generates all possible truth assignments (alphabet symbols) for the given propositions.
    /// Copied from LTLToBuchiConverter for now; consider making it a shared utility.
    private static func generatePossibleAlphabetSymbols(_ propositions: Set<PropositionIDType>) -> [BuchiAlphabetSymbol<PropositionIDType>] {
        if propositions.isEmpty { return [Set()] } 
        var symbols: [BuchiAlphabetSymbol<PropositionIDType>] = []; let propsArray = Array(propositions)
        for i in 0..<(1 << propsArray.count) { 
            var cs = Set<PropositionIDType>()
            for j in 0..<propsArray.count { 
                if (i >> j) & 1 == 1 { cs.insert(propsArray[j]) } 
            }
            symbols.append(cs) 
        }
        return symbols.isEmpty ? [Set()] : symbols // Should not be empty if propositions wasn't, due to initial [Set()]
    }
    
    /// Retrieves or creates a unique integer ID for a given TableauNode.
    /// The first node for which an ID is created is marked as an initial GBA state.
    private func getOrCreateGBAStateID(for node: TableauNode<P>) -> FormulaAutomatonState {
        if let existingID = nodeToStateIDMap[node] { return existingID }
        let newID = nextGBAStateID
        nodeToStateIDMap[node] = newID
        nextGBAStateID += 1
        if nodeToStateIDMap.count == 1 { // The very first node processed
            gbaInitialStateIDs.insert(newID)
        }
        return newID
    }

    /// Builds the tableau graph, populating GBA states, transitions, and initial states.
    internal func buildGraph() {
        let initialTableauNode = Self.decomposeFormulaForInitialTableauNode(self.nnfLTLFormula)
        self.worklist = [initialTableauNode]
        let _ = getOrCreateGBAStateID(for: initialTableauNode) 

        while let currentNodeToExpand = worklist.popLast() {
            if processedNodesLookup.contains(currentNodeToExpand) { continue }
            processedNodesLookup.insert(currentNodeToExpand)
            
            guard let currentGBAStateID = nodeToStateIDMap[currentNodeToExpand] else {
                print("Error: TableauNode on worklist has no mapped GBA state ID.") 
                continue
            }

            for symbol in Self.generatePossibleAlphabetSymbols(relevantPropositions) {
                let expansionResults = expandFormulasInNode(
                    nodeFormulas: currentNodeToExpand.currentFormulas, 
                    nextObligationsFromPrevious: currentNodeToExpand.nextFormulas, 
                    forSymbol: symbol, 
                    heuristicOriginalLTLFormula: self.originalPreNNFLTLFormula
                )

                for expansionResult in expansionResults {
                    if !expansionResult.isConsistent { continue } 

                    let successorNode = TableauNode<P>(
                        currentFormulas: expansionResult.nextSetOfCurrentObligations,
                        nextFormulas: expansionResult.nextSetOfNextObligations
                    )

                    let successorGBAStateID = getOrCreateGBAStateID(for: successorNode)
                    
                    // ---- MODIFIED GBA TRANSITION INSERT LOG ----
                    // Log all GBA transitions being formed, with extra detail for suspected F(!p) sink context
                    let sourceNodeDescForLog = String(describing: currentNodeToExpand)
                    let pDemoLikeRawValueForLog = "p_demo_like"
                    var isPotentiallyFNotPSinkNode = false
                    if currentNodeToExpand.nextFormulas.isEmpty && 
                       currentNodeToExpand.currentFormulas.count == 1, 
                       let singleCurrent = currentNodeToExpand.currentFormulas.first {
                        if case .not(let inner) = singleCurrent, case .atomic(let p) = inner, String(describing: p.id).contains(pDemoLikeRawValueForLog) {
                             if case .not(let topNot) = self.originalPreNNFLTLFormula, case .globally(let gSub) = topNot, case .atomic(let gAtomicP) = gSub, gAtomicP.id == p.id {
                                isPotentiallyFNotPSinkNode = true
                            } else if case .eventually(let fSub) = self.originalPreNNFLTLFormula, case .not(let fInner) = fSub, case .atomic(let fAtomicP) = fInner, fAtomicP.id == p.id {
                                isPotentiallyFNotPSinkNode = true
                            }
                        }
                    }

                    print("[TGC GBA Insert] From GBA ID \(currentGBAStateID) (Node: \(sourceNodeDescForLog)) -- Symbol: \(String(describing: symbol)) --> To GBA ID \(successorGBAStateID) (Node: \(String(describing: successorNode)))")
                    if isPotentiallyFNotPSinkNode {
                        print("    Context: Potentially F(!p) sink node. ExpansionResult: current=\(expansionResult.nextSetOfCurrentObligations.map {String(describing:$0)}), next=\(expansionResult.nextSetOfNextObligations.map {String(describing:$0)}), consistent=\(expansionResult.isConsistent)")
                        if currentGBAStateID == successorGBAStateID {
                            print("    CONFIRMED GBA SELF-LOOP FOR F(!p) SINK CONTEXT.")
                        }
                    }
                    // ---- END MODIFIED GBA TRANSITION INSERT LOG ----

                    gbaTransitions.insert(.init(from: currentGBAStateID, on: symbol, to: successorGBAStateID))

                    if !processedNodesLookup.contains(successorNode) && !worklist.contains(successorNode) {
                        worklist.append(successorNode)
                    }
                    
                    if nodeToStateIDMap.count > 150 { // Increased limit slightly for safety, default was 50
                        print("Warning: Max GBA states (150) reached in tableau. Aborting expansion.")
                        self.worklist.removeAll()
                        break 
                    }
                }
                if nodeToStateIDMap.count > 150 { break } 
            }
            if nodeToStateIDMap.count > 150 { break } 
        }
    }

    /// Expands formulas in a tableau node based on LTL semantics for a given alphabet symbol.
    /// This function applies tableau rules to decompose formulas and determine next state obligations.
    private func expandFormulasInNode(
        nodeFormulas: Set<LTLFormula<P>>, 
        nextObligationsFromPrevious: Set<LTLFormula<P>>,
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        heuristicOriginalLTLFormula: LTLFormula<P> // For context if needed by heuristics (e.g. sticky F states)
    ) -> [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] {
        // print("TableauGraphConstructor.expandFormulasInNode: Expanding for symbol \(forSymbol).")

        var allPossibleOutcomes: [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] = []        
        // Initial formulas to satisfy for the current state under `forSymbol`.
        // This includes formulas that must be true now (`nodeFormulas`)
        // and obligations passed from a previous state that must be true now (`nextObligationsFromPrevious`).
        let initialWorklistForSolve = Array(nodeFormulas.union(nextObligationsFromPrevious))

        // The `solve` function recursively processes formulas according to tableau rules.
        // It determines if the current set of formulas is consistent with `forSymbol`,
        // and what formulas must hold in the next state (`V` set).
        solve( 
            currentWorklist: initialWorklistForSolve, 
            processedOnPath: Set(), 
            vSet: Set(), // Accumulates X-formulas for the next state
            pAtomicSet: Set(), // True atomic propositions implied by current formulas
            nAtomicSet: Set(), // False atomic propositions (¬p) implied
            forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, // For liveness heuristics
            heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, // For liveness heuristics
            allPossibleOutcomes: &allPossibleOutcomes
        )

        if allPossibleOutcomes.isEmpty {
            if !initialWorklistForSolve.isEmpty {
                // print("TableauGraphConstructor.expandFormulasInNode (Symbol: \(forSymbol)): No outcomes from non-empty initial worklist: \(initialWorklistForSolve). Returning inconsistent.")
                return [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: false)]
            } else {
                // print("TableauGraphConstructor.expandFormulasInNode (Symbol: \(forSymbol)): No outcomes from empty initial worklist. Returning consistent with empty next obligations.")
                return [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: true)]
            }
        }
        // print("TableauGraphConstructor.expandFormulasInNode (Symbol: \(forSymbol)): All outcomes = \(allPossibleOutcomes.map { (curr: $0.nextSetOfCurrentObligations, next: $0.nextSetOfNextObligations, cons: $0.isConsistent) })")
        
        // Post-processing: Filter outcomes for consistency with `forSymbol` AFTER `solve` has run.
        // The `solve` function's `allowBypassForLiveness` might skip this for specific liveness sink states.
        // Here, we ensure that for outcomes *not* bypassed, the atomic formulas derived (P_atomic, N_atomic implicitly in currentBasicFormulas)
        // are consistent with the `forSymbol`.
        var finalFilteredOutcomes: [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] = []

        for outcome in allPossibleOutcomes {
            if !outcome.isConsistent { continue } // Already marked inconsistent by solve

            // Re-evaluate consistency based on how `solve` determined `currentBasicFormulas` vs `forSymbol`
            // This depends on the `allowBypassForLiveness` logic within `solve`.
            // If `solve` included atomic formulas in `outcome.nextSetOfCurrentObligations` despite symbol mismatch (due to bypass),
            // that needs to be handled. The current `solve` attempts to clear currentBasicFormulas if bypassed.

            // Heuristic check for bypass (crude approximation):
            // If the outcome's current obligations are empty AND it was a potential liveness sink in `solve`,
            // it might have been bypassed. The `solve` logic is complex here.
            // The key is that `solve` itself sets `isConsistent` and `currentBasicFormulas`.
            // If `allowBypassForLiveness` was true and it was a `isPotentialLivenessSinkCandidate`,
            // `solve` would set `resultingV` to empty, and `currentBasicFormulas` might be empty.
            // The critical check for `forSymbol` consistency happens *inside* `solve` before setting `consistentPath` unless bypassed.

            // Let's refine: `solve` passes back `nextSetOfCurrentObligations` (which are basically atomic or boolean literals)
            // and `isConsistent`. The `isConsistent` flag from `solve` should already account for symbol mismatches
            // *unless* `allowBypassForLiveness` was true.

            // The `solve` function already populates `currentBasicFormulas` based on `P_atomic` and `N_atomic`
            // AND then checks consistency with `forSymbol` (unless `allowBypassForLiveness`).
            // So the `isConsistent` flag from `solve` should be mostly reliable.
            // The additional check here could be if we want to enforce it universally *after* `solve` if there was a bypass.
            // The original `LTLToBuchiConverter` had the symbol check *after* `solve` loop in some iterations.
            // Let's assume `solve` correctly sets `isConsistent` considering the bypass.

            // The current `solve` inside this file: `consistentPath` is set, and `allowBypassForLiveness` guards the check against `forSymbol`.
            // `allPossibleOutcomes.append((currentBasicFormulas, resultingV, consistentPath))`
            // So, `outcome.isConsistent` (which is `consistentPath`) already reflects symbol consistency (or bypass).

            // No further filtering needed here if `solve` handles it correctly.
            finalFilteredOutcomes.append(outcome)
        }

        // return finalFilteredOutcomes.isEmpty && !initialWorklistForSolve.isEmpty ? 
        //         [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: false)] :
        //         finalFilteredOutcomes
        // If all outcomes were filtered out (e.g. due to a stricter post-solve symbol check not implemented here),
        // then return inconsistent. But for now, rely on solve's `isConsistent`.
        return finalFilteredOutcomes.isEmpty && !initialWorklistForSolve.isEmpty ?
            [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: false)] :
            (finalFilteredOutcomes.isEmpty ? [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: true)] : finalFilteredOutcomes)

    }
    
    // Helper `solve` function, adapted from the original LTLToBuchiConverter.
    // This is a complex part of the tableau method.
    private func solve(
        currentWorklist: [LTLFormula<P>], 
        processedOnPath: Set<LTLFormula<P>>, 
        vSet: Set<LTLFormula<P>>, // Accumulates X-formulas for the next state
        pAtomicSet: Set<P>,       // True atomic propositions implied by current formulas
        nAtomicSet: Set<P>,       // False atomic propositions (¬p) implied
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], // Original obligations for this node expansion, for liveness heuristics
        heuristicOriginalLTLFormula: LTLFormula<P>, // The very original LTL formula (pre-NNF), for liveness heuristics
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        var worklist = currentWorklist
        var processed = processedOnPath
        var V = vSet // Make V mutable 
        let P_atomic = pAtomicSet
        let N_atomic = nAtomicSet

        if worklist.isEmpty { // Base case for this path of recursion
            var currentBasicFormulas = Set<LTLFormula<P>>()
            var consistentPath = true

            let hasInternalContradiction = P_atomic.contains { p_true in N_atomic.contains(p_true) }
            if hasInternalContradiction { consistentPath = false }

            var allowBypassForLivenessSymbolCheck = false
            var isStickyAcceptingStateOfEventuality = false 

            let pDemoLikeRawValueForSolveLog = "p_demo_like" 
            var logHeuristicDetails = false
            if initialWorklistForSolve.count == 1, let singleObl = initialWorklistForSolve.first {
                if case .not(let inner) = singleObl, case .atomic(let p) = inner, String(describing: p.id).contains(pDemoLikeRawValueForSolveLog) {
                    logHeuristicDetails = true 
                }
            }
            
            if logHeuristicDetails {
                print(">>> [SolveLivenessDebug] BaseCase for initialWorklist: \(initialWorklistForSolve.map{String(describing:$0)}), Symbol: \(String(describing: forSymbol))")
                print("    V_in: \(V.map{String(describing:$0)}), P_atomic: \(P_atomic.map{String(describing:$0)}), N_atomic: \(N_atomic.map{String(describing:$0)})")
                print("    consistentPath (pre-heuristic): \(consistentPath)")
            }

            if consistentPath { 
                if initialWorklistForSolve.count == 1, let singleObligation = initialWorklistForSolve.first {
                    var isHeuristicAnEventualityEquivalent = false
                    var subFormulaOfEventuality: LTLFormula<P>? = nil

                    // Check for F(phi) form
                    if case .eventually(let sub) = heuristicOriginalLTLFormula {
                        isHeuristicAnEventualityEquivalent = true
                        subFormulaOfEventuality = sub
                        if logHeuristicDetails { print("    Heuristic is F(phi) form.") }
                    } 
                    // Check for not(G(not(phi))) which is also F(phi)
                    // Our negated G(p) becomes F(!p), which is not(G(p)) if we take !p as phi.
                    // Or, if original was G(psi), negated is F(!psi). Here heuristicOriginalLTLFormula = F(!psi).
                    // If original was !F(psi), negated is G(!psi). Heuristic is G(!psi).
                    // We need to ensure that if heuristicOriginalLTLFormula semantically means "eventually X", we detect it.
                    // The F(!p) case: heuristicOriginalLTLFormula = .eventually(.not(.atomic(p)))
                    // NNF of F(!p) is true U !p. This should be handled by .until case if NNF is aggressive.
                    // However, heuristicOriginalLTLFormula is pre-NNF.

                    else if case .not(let innerGlobal) = heuristicOriginalLTLFormula, case .globally(let gSub) = innerGlobal {
                        // This is F(not(gSub))
                        isHeuristicAnEventualityEquivalent = true
                        subFormulaOfEventuality = LTLFormula.not(gSub)
                        if logHeuristicDetails { print("    Heuristic is !G(psi) -> F(!psi) form.") }
                    } 
                    // It's also common to convert F(phi) to true U phi in NNF.
                    // The heuristicOriginalLTLFormula is pre-NNF, so .eventually is the direct case.
                    // The .until(true, ...) case was from the previous more complex heuristic.
                    
                    if isHeuristicAnEventualityEquivalent, let eventualityTarget = subFormulaOfEventuality {
                        if logHeuristicDetails { print("    Eventuality target: \(String(describing: eventualityTarget)), NNFd: \(String(describing: LTLFormulaNNFConverter.convert(eventualityTarget))). Single Obligation: \(String(describing: singleObligation))") }
                        if LTLFormulaNNFConverter.convert(eventualityTarget) == singleObligation {
                            isStickyAcceptingStateOfEventuality = true
                        }
                    }
                }
            }

            if isStickyAcceptingStateOfEventuality {
                allowBypassForLivenessSymbolCheck = true
            }
            if logHeuristicDetails { print("    isSticky: \(isStickyAcceptingStateOfEventuality), allowBypass: \(allowBypassForLivenessSymbolCheck)") }
            
            if logHeuristicDetails { 
                print("    PRE-CHECK: consistentPath=\(consistentPath), allowBypassForLivenessSymbolCheck=\(allowBypassForLivenessSymbolCheck), !allowBypassForLivenessSymbolCheck=\(!allowBypassForLivenessSymbolCheck), combinedCondition (A)=\(consistentPath && !allowBypassForLivenessSymbolCheck), combinedCondition (B)=\(consistentPath && allowBypassForLivenessSymbolCheck)")
            }

            if consistentPath && !allowBypassForLivenessSymbolCheck { // BLOCK A: Perform check
                if logHeuristicDetails { print("    BLOCK A EXECUTED: Performing symbol consistency check.") }
                for p_true in P_atomic {
                    if let p_id = p_true.id as? PropositionIDType, !forSymbol.contains(p_id) {
                        consistentPath = false; if logHeuristicDetails { print("        Failed P_atomic check: \(String(describing:p_true)) not in symbol.") }; break
                    }
                }
                if consistentPath {
                    for p_false_prop in N_atomic {
                        if let p_id = p_false_prop.id as? PropositionIDType, forSymbol.contains(p_id) {
                            consistentPath = false; if logHeuristicDetails { print("        Failed N_atomic check: \(String(describing:p_false_prop)) IS in symbol.") }; break
                        }
                    }
                }
            } else if consistentPath && allowBypassForLivenessSymbolCheck { // BLOCK B: Bypass
                 if logHeuristicDetails { print("    BLOCK B EXECUTED: BYPASSING symbol consistency check. consistentPath remains \(consistentPath).") }
            } else if !consistentPath { // BLOCK C: Already inconsistent
                 if logHeuristicDetails { print("    BLOCK C EXECUTED: Path ALREADY inconsistent (\(consistentPath)) before symbol check/bypass decision.") }
            }
            
            if logHeuristicDetails { print("    consistentPath (FINAL for this outcome): \(consistentPath)") }
            
            if consistentPath { 
                for p_atom in P_atomic { currentBasicFormulas.insert(.atomic(p_atom)) }
                for np_atom in N_atomic { currentBasicFormulas.insert(.not(.atomic(np_atom))) }
            } else {
                 currentBasicFormulas = Set() 
            }
            
            let finalV = isStickyAcceptingStateOfEventuality ? Set<LTLFormula<P>>() : V
            if logHeuristicDetails { 
                print("    OUTCOME TO APPEND: current=\(currentBasicFormulas.map{String(describing:$0)}), next=\(finalV.map{String(describing:$0)}), consistent=\(consistentPath)")
            }

            allPossibleOutcomes.append((currentBasicFormulas, finalV, consistentPath))
            return
        }

        let currentFormula = worklist.removeFirst()
        if processed.contains(currentFormula) {
            solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
            return
        }
        processed.insert(currentFormula)

        switch currentFormula {
        case .booleanLiteral(let b):
            if !b { 
                allPossibleOutcomes.append(([], [], false)); return 
            }
            solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .atomic(let p):
            var new_P_atomic = P_atomic; new_P_atomic.insert(p)
            solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: new_P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .not(.atomic(let p)):
            var new_N_atomic = N_atomic; new_N_atomic.insert(p)
            solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: new_N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .not(.booleanLiteral(let b)):
            if b { 
                allPossibleOutcomes.append(([], [], false)); return
            }
            solve(currentWorklist: worklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
        
        case .and(let lhs, let rhs):
            var newWorklist = worklist
            if !processed.contains(lhs) { newWorklist.insert(lhs, at: 0) } 
            if !processed.contains(rhs) { newWorklist.insert(rhs, at: 0) } 
            solve(currentWorklist: newWorklist, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
        
        case .or(let lhs, let rhs):
            var worklistLhs = worklist
            if !processed.contains(lhs) { worklistLhs.insert(lhs, at: 0) }
            solve(currentWorklist: worklistLhs, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
            
            var worklistRhs = worklist
            if !processed.contains(rhs) { worklistRhs.insert(rhs, at: 0) }
            solve(currentWorklist: worklistRhs, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .next(let subFormula):
            var newV = V; newV.insert(subFormula)
            solve(currentWorklist: worklist, processedOnPath: processed, vSet: newV, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .until(let phi, let psi):
            let initialOutcomeCountForUntil = allPossibleOutcomes.count
            var worklistPsiBranch = worklist
            if !processed.contains(psi) { worklistPsiBranch.insert(psi, at: 0) }
            solve(currentWorklist: worklistPsiBranch, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
            
            var branch1SucceededConsistently = false
            if allPossibleOutcomes.count > initialOutcomeCountForUntil {
                for i in initialOutcomeCountForUntil..<allPossibleOutcomes.count {
                    if allPossibleOutcomes[i].isConsistent {
                        branch1SucceededConsistently = true
                        break
                    }
                }
            }
            if branch1SucceededConsistently {
                return 
            }
            
            var worklistPhiBranch = worklist
            if !processed.contains(phi) { worklistPhiBranch.insert(phi, at: 0) }
            var vForPhiBranch = V; vForPhiBranch.insert(currentFormula) 
            solve(currentWorklist: worklistPhiBranch, processedOnPath: processed, vSet: vForPhiBranch, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .release(let phi, let psi):
            var worklistWithPsi = worklist
            if !processed.contains(psi) { worklistWithPsi.insert(psi, at:0) }

            var worklistPsiAndPhi = worklistWithPsi
            if !processed.contains(phi) { worklistPsiAndPhi.insert(phi, at: 0) } 
            solve(currentWorklist: worklistPsiAndPhi, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

            var vForPsiAndXR = V; vForPsiAndXR.insert(currentFormula) 
            solve(currentWorklist: worklistWithPsi, processedOnPath: processed, vSet: vForPsiAndXR, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
            
        case .eventually(let subFormula): 
            var worklistSubFormulaBranch = worklist
            if !processed.contains(subFormula) { worklistSubFormulaBranch.insert(subFormula, at: 0) }
            solve(currentWorklist: worklistSubFormulaBranch, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

            var vForXFBranch = V; vForXFBranch.insert(currentFormula) 
            solve(currentWorklist: worklist, processedOnPath: processed, vSet: vForXFBranch, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
            
        case .globally(let subFormula): 
            var newWorklistG = worklist
            if !processed.contains(subFormula) { newWorklistG.insert(subFormula, at: 0) }
            var vForXGBranch = V; vForXGBranch.insert(currentFormula) 
            solve(currentWorklist: newWorklistG, processedOnPath: processed, vSet: vForXGBranch, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .weakUntil(let phi, let psi): 
            var worklistPsiWBranch = worklist
            if !processed.contains(psi) { worklistPsiWBranch.insert(psi, at: 0) }
            solve(currentWorklist: worklistPsiWBranch, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
            
            var worklistPhiWBranch = worklist
            if !processed.contains(phi) { worklistPhiWBranch.insert(phi, at: 0) }
            var vForPhiWBranch = V; vForPhiWBranch.insert(currentFormula) 
            solve(currentWorklist: worklistPhiWBranch, processedOnPath: processed, vSet: vForPhiWBranch, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .implies(let lhs, let rhs):
            let orEquivalent = LTLFormula.or(LTLFormula.not(lhs), rhs)
            let nnfOfOrEquivalent = LTLFormulaNNFConverter.convert(orEquivalent) 
            var newWorklistNNFImplies = worklist; newWorklistNNFImplies.insert(nnfOfOrEquivalent, at:0)
            solve(currentWorklist: newWorklistNNFImplies, processedOnPath: processed, vSet: V, pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, allPossibleOutcomes: &allPossibleOutcomes)
        
        case .not(.not(_)), .not(.and(_, _)), .not(.or(_, _)), .not(.implies(_, _)), 
             .not(.next(_)), .not(.eventually(_)), .not(.globally(_)), 
             .not(.until(_, _)), .not(.weakUntil(_, _)), .not(.release(_, _)):
            allPossibleOutcomes.append(([],[], false)); return
        }
    }
} 
