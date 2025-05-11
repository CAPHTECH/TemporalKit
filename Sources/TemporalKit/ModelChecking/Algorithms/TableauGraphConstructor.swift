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
        let initialGBAStateID = getOrCreateGBAStateID(for: initialTableauNode) 

        // ---- DEBUG for F p pattern ----
        let isFpPattern = { (formula: LTLFormula<P>) -> Bool in
            if case .until(let lhs, let rhs) = formula,
               case .booleanLiteral(let bVal) = lhs, bVal == true,
               case .atomic = rhs {
                return true
            }
            return false
        }
        let nnfFormulaString = String(describing: self.nnfLTLFormula)
        let logFpDetails = isFpPattern(self.nnfLTLFormula) || (nnfFormulaString.contains("F(") && nnfFormulaString.contains("p")) // Heuristic for original F(p)
        if logFpDetails {
            print("[TGC BUILDGRAPH DEBUG FPAT] Initial Tableau Node for \(nnfFormulaString): ID \(initialGBAStateID)")
            print("[TGC BUILDGRAPH DEBUG FPAT]   Current: \(initialTableauNode.currentFormulas.map{String(describing:$0)}.sorted())")
            print("[TGC BUILDGRAPH DEBUG FPAT]   Next: \(initialTableauNode.nextFormulas.map{String(describing:$0)}.sorted())")
        }
        // ---- END DEBUG ----

        while let currentNodeToExpand = worklist.popLast() {
            if processedNodesLookup.contains(currentNodeToExpand) { continue }
            processedNodesLookup.insert(currentNodeToExpand)
            
            guard let currentGBAStateID = nodeToStateIDMap[currentNodeToExpand] else {
                // This print is an error condition, so it can remain.
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
                    
                    // ---- DEBUG for F p pattern ----
                    if logFpDetails && (nodeToStateIDMap[currentNodeToExpand] == initialGBAStateID || nodeToStateIDMap[currentNodeToExpand] == successorGBAStateID) {
                         print("[TGC BUILDGRAPH DEBUG FPAT] Expanded from Node ID \(currentGBAStateID) for symbol \(symbol)")
                         print("[TGC BUILDGRAPH DEBUG FPAT]   To Successor Node ID \(successorGBAStateID)")
                         print("[TGC BUILDGRAPH DEBUG FPAT]     Current: \(successorNode.currentFormulas.map{String(describing:$0)}.sorted())")
                         print("[TGC BUILDGRAPH DEBUG FPAT]     Next: \(successorNode.nextFormulas.map{String(describing:$0)}.sorted())")
                         print("[TGC BUILDGRAPH DEBUG FPAT]     ExpansionResult Consistent: \(expansionResult.isConsistent)")
                    }
                    // ---- END DEBUG ----

                    gbaTransitions.insert(.init(from: currentGBAStateID, on: symbol, to: successorGBAStateID))

                    if !processedNodesLookup.contains(successorNode) && !worklist.contains(successorNode) {
                        worklist.append(successorNode)
                    }
                    
                    if nodeToStateIDMap.count > 150 { 
                        // This print is a warning, so it can remain.
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
        heuristicOriginalLTLFormula: LTLFormula<P> 
    ) -> [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] {
        
        var foundRelevantReleaseInNodeFormulas = false
        var initialFormulaForDebug: LTLFormula<P>? = nil
        for f_node in nodeFormulas {
            if case .release(let l, let r) = f_node {
                if case .not(let notL) = l, case .atomic(let pL) = notL, String(describing: pL.id).contains("r_kripke"),
                   case .not(let notR) = r, case .atomic(let pR) = notR, String(describing: pR.id).contains("p_kripke") {
                    foundRelevantReleaseInNodeFormulas = true
                    initialFormulaForDebug = f_node
                    break
                }
            }
        }
        
        let symbolIsExactlyPKripke = forSymbol.count == 1 && forSymbol.allSatisfy { String(describing: $0).contains("p_kripke") }
        let symbolIsPrKripke = forSymbol.count == 2 && 
                               forSymbol.contains(where: { String(describing: $0).contains("p_kripke") }) && 
                               forSymbol.contains(where: { String(describing: $0).contains("r_kripke") })

        let shouldLogExpandDetails = foundRelevantReleaseInNodeFormulas && (symbolIsExactlyPKripke || symbolIsPrKripke)

        if shouldLogExpandDetails {
            print("[TGC EXPAND_IN DEBUG REL_NOTPAT] expandFormulasInNode called for \(String(describing: initialFormulaForDebug ?? self.nnfLTLFormula)) and Symbol \(forSymbol.map { String(describing: $0) }.sorted())")
            print("[TGC EXPAND_IN DEBUG REL_NOTPAT]   NodeFormulas: \(nodeFormulas.map{String(describing:$0).prefix(100)})")
            print("[TGC EXPAND_IN DEBUG REL_NOTPAT]   NextObligationsFromPrevious: \(nextObligationsFromPrevious.map{String(describing:$0).prefix(100)})")
        }
        // ---- END DEBUG ----

        var allPossibleOutcomes: [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] = []        
        let initialWorklistForSolve = Array(nodeFormulas.union(nextObligationsFromPrevious))

        solve( 
            currentWorklist: initialWorklistForSolve, 
            processedOnPath: Set(), 
            vSet: Set(), 
            pAtomicSet: Set(), 
            nAtomicSet: Set(), 
            forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, 
            heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, 
            allPossibleOutcomes: &allPossibleOutcomes
        )

        let finalFilteredOutcomes = allPossibleOutcomes.filter { outcome in
            // If outcome.isConsistent is false, solve already determined it's contradictory.
            // If true, it means it was consistent with the symbol OR bypassed the symbol check.
            // No additional filtering here for now, relying on solve's consistency flag.
            return outcome.isConsistent 
        }
        
        // ---- DEBUG for expandFormulasInNode results ----
        if shouldLogExpandDetails {
            print("[TGC EXPAND_OUT DEBUG REL_NOTPAT] Results for \(String(describing: initialFormulaForDebug ?? self.nnfLTLFormula)) and Symbol \(forSymbol.map { String(describing: $0) }.sorted())):")
            if finalFilteredOutcomes.isEmpty && !initialWorklistForSolve.isEmpty {
                print("[TGC EXPAND_OUT DEBUG REL_NOTPAT]   NO consistent outcomes generated.")
            } else {
                for (idx, outcome) in finalFilteredOutcomes.enumerated() {
                    print("[TGC EXPAND_OUT DEBUG REL_NOTPAT]   Outcome \(idx + 1): isConsistent=\(outcome.isConsistent)")
                    print("[TGC EXPAND_OUT DEBUG REL_NOTPAT]     CurrentObligations: \(outcome.nextSetOfCurrentObligations.map{String(describing:$0).prefix(100)})")
                    print("[TGC EXPAND_OUT DEBUG REL_NOTPAT]     NextObligations: \(outcome.nextSetOfNextObligations.map{String(describing:$0).prefix(100)})")
                }
            }
        }
        // ---- END DEBUG ----

        return finalFilteredOutcomes.isEmpty && !initialWorklistForSolve.isEmpty ?
            [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: false)] :
            (finalFilteredOutcomes.isEmpty ? [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: true)] : finalFilteredOutcomes)
    }
    
    // Helper `solve` function, adapted from the original LTLToBuchiConverter.
    // This is a complex part of the tableau method.
    private func solve(
        currentWorklist: [LTLFormula<P>], 
        processedOnPath: Set<LTLFormula<P>>, 
        vSet V: Set<LTLFormula<P>>, 
        pAtomicSet P_atomic: Set<P>, 
        nAtomicSet N_atomic: Set<P>,
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], // For context in debug/heuristics
        heuristicOriginalLTLFormula: LTLFormula<P>, // The original LTL formula before NNF, for context
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        var worklist = currentWorklist
        var processed = processedOnPath
        let V = V
        let P_atomic = P_atomic
        let N_atomic = N_atomic

        if worklist.isEmpty { 
            var currentBasicFormulas = Set<LTLFormula<P>>()
            var consistentPath = true

            let hasInternalContradiction = P_atomic.contains { p_true in N_atomic.contains(p_true) }
            if hasInternalContradiction { consistentPath = false }

            var allowBypassForLivenessSymbolCheck = false 
            var isStickyAcceptingStateOfEventuality = false 

            // ---- DEBUG for Release path consistency ----
            var shouldLogConsistencyCheck = false
            let targetReleaseNNFString = "release(not(atomic(TemporalKit.ClosureTemporalProposition<TemporalKitDemo.DemoKripkeModelState, Swift.Bool>>"
            let initialWorklistStrings = initialWorklistForSolve.map { String(describing: $0) }
            let isTargetFormulaContext = initialWorklistStrings.contains(where: { $0.contains(targetReleaseNNFString) && $0.contains("p_kripke") && $0.contains("r_kripke") })
            
            let symbolIsExactlyPKripke = forSymbol.count == 1 && forSymbol.allSatisfy { pid in String(describing: pid).contains("p_kripke") }
            let symbolIsPrKripke = forSymbol.count == 2 && 
                                   forSymbol.contains(where: { String(describing: $0).contains("p_kripke") }) && 
                                   forSymbol.contains(where: { String(describing: $0).contains("r_kripke") })

            if isTargetFormulaContext && (symbolIsExactlyPKripke || symbolIsPrKripke) {
                shouldLogConsistencyCheck = true
                print("[TGC SOLVE CONSISTENCY PRE-CHECK for (¬r)R(¬p) like with symbol \(forSymbol.map{String(describing:$0)}.sorted())]")
                print("    InitialWorklistForSolve: \(initialWorklistStrings.map{$0.prefix(100)})")
                print("    P_atomic: \(P_atomic.map{String(describing:$0)}), N_atomic: \(N_atomic.map{String(describing:$0)}), initial consistentPath: \(consistentPath)")
            }
            // ---- END DEBUG ----

            if consistentPath { 
                if initialWorklistForSolve.count == 1, let singleObligation = initialWorklistForSolve.first {
                    var isHeuristicAnEventualityEquivalent = false
                    var subFormulaOfEventuality: LTLFormula<P>? = nil

                    if case .eventually(let sub) = heuristicOriginalLTLFormula {
                        isHeuristicAnEventualityEquivalent = true
                        subFormulaOfEventuality = sub
                        // if logHeuristicDetails { print("    Heuristic is F(phi) form.") }
                    } 
                    else if case .not(let innerGlobal) = heuristicOriginalLTLFormula, case .globally(let gSub) = innerGlobal {
                        isHeuristicAnEventualityEquivalent = true
                        subFormulaOfEventuality = LTLFormula.not(gSub)
                        // if logHeuristicDetails { print("    Heuristic is !G(psi) -> F(!psi) form.") }
                    } 
                    
                    if isHeuristicAnEventualityEquivalent, let eventualityTarget = subFormulaOfEventuality {
                        // if logHeuristicDetails { print("    Eventuality target: \(String(describing: eventualityTarget)), NNFd: \(String(describing: LTLFormulaNNFConverter.convert(eventualityTarget))). Single Obligation: \(String(describing: singleObligation))") }
                        if LTLFormulaNNFConverter.convert(eventualityTarget) == singleObligation {
                            isStickyAcceptingStateOfEventuality = true
                        }
                    }
                }
            }

            if isStickyAcceptingStateOfEventuality {
                allowBypassForLivenessSymbolCheck = true
            }
            // if logHeuristicDetails { print("    isSticky: \(isStickyAcceptingStateOfEventuality), allowBypass: \(allowBypassForLivenessSymbolCheck)") }
            
            // if logHeuristicDetails { 
            //     print("    PRE-CHECK: consistentPath=\(consistentPath), allowBypassForLivenessSymbolCheck=\(allowBypassForLivenessSymbolCheck), !allowBypassForLivenessSymbolCheck=\(!allowBypassForLivenessSymbolCheck), combinedCondition (A)=\(consistentPath && !allowBypassForLivenessSymbolCheck), combinedCondition (B)=\(consistentPath && allowBypassForLivenessSymbolCheck)")
            // }

            if consistentPath && !allowBypassForLivenessSymbolCheck { 
                // if logHeuristicDetails { print("    BLOCK A EXECUTED: Performing symbol consistency check.") }
                for p_true in P_atomic {
                    if let p_id = p_true.id as? PropositionIDType, !forSymbol.contains(p_id) {
                        consistentPath = false; /*if logHeuristicDetails { print("        Failed P_atomic check: \(String(describing:p_true)) not in symbol.") }*/ break
                    }
                }
                if consistentPath {
                    for p_false_prop in N_atomic {
                        if let p_id = p_false_prop.id as? PropositionIDType, forSymbol.contains(p_id) {
                            consistentPath = false; /*if logHeuristicDetails { print("        Failed N_atomic check: \(String(describing:p_false_prop)) IS in symbol.") }*/ break
                        }
                    }
                }
            } else if consistentPath && allowBypassForLivenessSymbolCheck { 
                 // if logHeuristicDetails { print("    BLOCK B EXECUTED: BYPASSING symbol consistency check. consistentPath remains \(consistentPath).") }
            } else if !consistentPath { 
                 // if logHeuristicDetails { print("    BLOCK C EXECUTED: Path ALREADY inconsistent (\(consistentPath)) before symbol check/bypass decision.") }
            }
            
            // if logHeuristicDetails { print("    consistentPath (FINAL for this outcome): \(consistentPath)") }
            
            if consistentPath { 
                for p_atom in P_atomic { currentBasicFormulas.insert(.atomic(p_atom)) }
                for np_atom in N_atomic { currentBasicFormulas.insert(.not(.atomic(np_atom))) }
            } else {
                 currentBasicFormulas = Set() 
            }
            
            // ---- DEBUG for Release path consistency ----
            if shouldLogConsistencyCheck {
                print("[TGC SOLVE CONSISTENCY POST-CHECK for (¬r)R(¬p) like with symbol \(forSymbol.map{String(describing:$0)}.sorted())] Final consistentPath: \(consistentPath) for outcome based on P: \(P_atomic.map{String(describing:$0)}), N: \(N_atomic.map{String(describing:$0)})")
            }
            // ---- END DEBUG ----

            let finalV = V // Simplified: V passed through from recursive calls is the next state obligations.
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
            let shouldLogBranchDetails = solltenSieProtokollierenErweiternFallFreigeben(initialWorklistForSolve, forSymbol, currentFormula)

            // Branch 1: psi holds now.
            var worklistBranchPsi = worklist
            if !processed.contains(psi) { worklistBranchPsi.insert(psi, at: 0) }
            var tempOutcomesBranch1: [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] = []
            solve(currentWorklist: worklistBranchPsi, processedOnPath: processed, vSet: V, 
                  pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, 
                  initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, 
                  allPossibleOutcomes: &tempOutcomesBranch1)
            if shouldLogBranchDetails {
                print("[TGC SOLVE DEBUG REL_BRANCH_1] For \(currentFormula) on \(forSymbol.map{String(describing:$0)}.sorted()): psi (\(psi)) branch produced \(tempOutcomesBranch1.count) outcomes. Consistent: \(tempOutcomesBranch1.filter{$0.isConsistent}.count)")
            }
            allPossibleOutcomes.append(contentsOf: tempOutcomesBranch1)

            // Branch 2: phi holds now AND X(phi R psi) holds next.
            var worklistBranchPhi = worklist
            if !processed.contains(phi) { worklistBranchPhi.insert(phi, at: 0) }
            var vSetBranchPhiAndXR = V
            vSetBranchPhiAndXR.insert(currentFormula) // Add X(phi R psi)
            var tempOutcomesBranch2: [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] = []
            solve(currentWorklist: worklistBranchPhi, processedOnPath: processed, vSet: vSetBranchPhiAndXR, 
                  pAtomicSet: P_atomic, nAtomicSet: N_atomic, forSymbol: forSymbol, 
                  initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula, 
                  allPossibleOutcomes: &tempOutcomesBranch2)
            if shouldLogBranchDetails {
                print("[TGC SOLVE DEBUG REL_BRANCH_2] For \(currentFormula) on \(forSymbol.map{String(describing:$0)}.sorted()): phi_XR (\(phi) & X R) branch produced \(tempOutcomesBranch2.count) outcomes. Consistent: \(tempOutcomesBranch2.filter{$0.isConsistent}.count)")
            }
            allPossibleOutcomes.append(contentsOf: tempOutcomesBranch2)

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
            // These should have been resolved by NNF converter.
            // If they appear here, it's an issue with NNF or prior logic.
            print("[TGC SOLVE ERROR] Unexpected NNF-violating formula in solve: \(currentFormula)")
            allPossibleOutcomes.append(([],[], false)); return
        }
    }

    // New helper function, ensure it's within the class or accessible (e.g., fileprivate at file scope if P is also file-scoped or generic)
    private func solltenSieProtokollierenErweiternFallFreigeben(_ initialWorklistForSolvePathContext: [LTLFormula<P>], _ symbol: BuchiAlphabetSymbol<PropositionIDType>, _ currentExpandingFormula: LTLFormula<P>) -> Bool {
        var isTargetReleaseFormula = false
        if case .release(let l, let r) = currentExpandingFormula {
            let lDescCurrent = String(describing: l)
            let rDescCurrent = String(describing: r)
            // Check for release(not(atomic(...r_kripke_Demo...)), not(atomic(...p_kripke_Demo...)))
            if lDescCurrent.contains("not(atomic") && lDescCurrent.contains("r_kripke") && lDescCurrent.contains("DemoKripkeModelState") &&
               rDescCurrent.contains("not(atomic") && rDescCurrent.contains("p_kripke") && rDescCurrent.contains("DemoKripkeModelState") {
                isTargetReleaseFormula = true
            }
        }
        let symbolIsPKripke = symbol.count == 1 && symbol.allSatisfy { String(describing: $0).contains("p_kripke") }
        return isTargetReleaseFormula && symbolIsPKripke
    }
} 

// Helper extensions for LTLFormula to check patterns
// These should ideally be part of LTLFormula or a utility extension file.
fileprivate extension LTLFormula {
    func isFpPattern() -> Bool {
        if case .until(let lhs, let rhs) = self,
           case .booleanLiteral(let bVal) = lhs, bVal == true,
           case .atomic = rhs {
            return true
        }
        return false
    }

    func isReleaseNotNotPattern() -> Bool {
        if case .release(let lhsR, let rhsR) = self,
           case .not(let notLhsSub) = lhsR, case .atomic = notLhsSub,
           case .not(let notRhsSub) = rhsR, case .atomic = notRhsSub {
            return true
        }
        return false
    }
    func isBooleanLiteralTrue() -> Bool {
        if case .booleanLiteral(let bVal) = self, bVal == true {
            return true
        }
        return false
    }
}

// Extension for PropositionIDType should be at file scope or global scope if used across files.
// For now, placing it at file scope.
fileprivate extension RawRepresentable where RawValue == String {
    // This provides a default idDescription for any RawRepresentable with String RawValue,
    // like the PropositionID used in tests.
    // If PropositionIDType itself is this, then $0.idDescription() would work.
    // If PropositionIDType is just String, then $0 itself is the string.
    // If PropositionIDType is some other struct/enum, it needs its own CustomStringConvertible or RawRepresentable.
    // The String(describing: pid) is generally the safest for debug if unsure about specific type conformance.
    func idDescription() -> String { return self.rawValue }
}
