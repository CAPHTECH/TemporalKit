import Foundation

// swiftlint:disable file_length type_body_length function_body_length function_parameter_count
// swiftlint:disable cyclomatic_complexity line_length

// Assumes LTLFormula, TemporalProposition, TableauNode, BuchiAlphabetSymbol, 
// FormulaAutomatonState, BuchiAutomaton.Transition are defined and accessible.
// Also assumes LTLToBuchiConverter.generatePossibleAlphabetSymbols is available if not inlined.

internal class TableauGraphConstructor<P: TemporalProposition, PropositionIDType: Hashable>
    where P.Value == Bool, P.ID == PropositionIDType {
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
        TableauNode<P>(currentFormulas: [formula], nextFormulas: [])
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
        _ = getOrCreateGBAStateID(for: initialTableauNode)

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

                // ---- DEBUG for X(¬q) specific expansion ----
                var isXNotQContext = false
                if case .next(let sub) = self.originalPreNNFLTLFormula,
                   case .not(let nSub) = sub,
                   case .atomic(let a) = nSub,
                   String(describing: a.id) == "q" {
                    isXNotQContext = true
                }

                var currentNodeContainsNotQ = false
                for f in currentNodeToExpand.currentFormulas {
                    if case .not(let subF) = f, case .atomic(let atomF) = subF, String(describing: atomF.id) == "q" {
                        currentNodeContainsNotQ = true
                        break
                    }
                }
                let symbolContainsQ = symbol.contains(where: { String(describing: $0).contains("q") })

                if isXNotQContext && currentNodeContainsNotQ && symbolContainsQ {
                    let currentFormulaDescs = currentNodeToExpand.currentFormulas.map { String(describing: $0).prefix(20) }
                    let nextFormulaDescs = currentNodeToExpand.nextFormulas.map { String(describing: $0).prefix(20) }
                    print("[TGC BUILDGRAPH DEBUG XNOTQ] For node (current: \(currentFormulaDescs), next: \(nextFormulaDescs)) with symbol \(symbol):")
                    print("    expandFormulasInNode produced \(expansionResults.count) outcomes:")
                    for (idx, outcome) in expansionResults.enumerated() {
                        let currObligations = outcome.nextSetOfCurrentObligations.map { String(describing: $0).prefix(20) }
                        let nextObligations = outcome.nextSetOfNextObligations.map { String(describing: $0).prefix(20) }
                        print("      Outcome \(idx): consistent=\(outcome.isConsistent), currO=\(currObligations), nextO=\(nextObligations) ")
                    }
                }
                // ---- END DEBUG ----

                for expansionResult in expansionResults {
                    if !expansionResult.isConsistent { continue }

                    let successorNode = TableauNode<P>(
                        currentFormulas: expansionResult.nextSetOfCurrentObligations,
                        nextFormulas: expansionResult.nextSetOfNextObligations
                    )

                    let successorGBAStateID = getOrCreateGBAStateID(for: successorNode)

                    gbaTransitions.insert(.init(from: currentGBAStateID, on: symbol, to: successorGBAStateID))

                    if !processedNodesLookup.contains(successorNode) && !worklist.contains(successorNode) {
                        worklist.append(successorNode)
                    }

                    if nodeToStateIDMap.count > 150 {
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
            outcome.isConsistent
        }

        return finalFilteredOutcomes.isEmpty && !initialWorklistForSolve.isEmpty ?
            [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: false)] :
            (finalFilteredOutcomes.isEmpty ? [(nextSetOfCurrentObligations: [], nextSetOfNextObligations: [], isConsistent: true)] : finalFilteredOutcomes)
    }

    // Helper `solve` function, adapted from the original LTLToBuchiConverter.
    // This is a complex part of the tableau method.
    private func solve(
        currentWorklist: [LTLFormula<P>],
        processedOnPath: Set<LTLFormula<P>>,
        vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>,
        nAtomicSet: Set<P>,
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], // For context in debug/heuristics
        heuristicOriginalLTLFormula: LTLFormula<P>, // The original LTL formula before NNF, for context
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        // Debug initialization
        let isTargetFormulaContextForSolve = shouldDebugFormula(heuristicOriginalLTLFormula)
        var worklist = currentWorklist
        var processed = processedOnPath
        let vSet = vSet
        let pAtomic = pAtomicSet
        let nAtomic = nAtomicSet

        if isTargetFormulaContextForSolve {
            printDebugInfo(
                heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                currentWorklist: currentWorklist,
                processedOnPath: processedOnPath,
                vSet: vSet,
                pAtomic: pAtomic,
                nAtomic: nAtomic,
                forSymbol: forSymbol
            )
        }

        // Handle empty worklist case
        if worklist.isEmpty {
            handleEmptyWorklist(
                pAtomic: pAtomic,
                nAtomic: nAtomic,
                vSet: vSet,
                forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve,
                heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                isTargetFormulaContextForSolve: isTargetFormulaContextForSolve,
                allPossibleOutcomes: &allPossibleOutcomes
            )
            return
        }

        // Process current formula
        let currentFormula = worklist.removeFirst()
        if processed.contains(currentFormula) {
            solve(
                currentWorklist: worklist,
                processedOnPath: processed,
                vSet: vSet,
                pAtomicSet: pAtomic,
                nAtomicSet: nAtomic,
                forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve,
                heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )
            return
        }
        processed.insert(currentFormula)

        // Delegate formula expansion based on type
        expandFormulaByType(
            currentFormula: currentFormula,
            currentWorklist: worklist,
            processedOnPath: processed,
            vSet: vSet,
            pAtomicSet: pAtomic,
            nAtomicSet: nAtomic,
            forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve,
            heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Helper method to check if we should debug a formula
    private func shouldDebugFormula(_ formula: LTLFormula<P>) -> Bool {
        let formulaStrForDebug = String(describing: formula)
        // More specific trigger for the NNF of the demo's ¬(p U r) which is (¬r)R(¬p)
        if case .release(let r_lhs, let r_rhs) = formula,
           case .not(let not_lhs) = r_lhs, case .atomic(let atom_lhs) = not_lhs, String(describing: atom_lhs.id).contains("r_kripke"),
           case .not(let not_rhs) = r_rhs, case .atomic(let atom_rhs) = not_rhs, String(describing: atom_rhs.id).contains("p_kripke") {
            if formulaStrForDebug.contains("DemoKripkeModelState") { // Ensure it's the demo's proposition type
                return true
            }
        }
        return false
    }

    // Helper method to print debug information
    private func printDebugInfo(
        heuristicOriginalLTLFormula: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>],
        processedOnPath: Set<LTLFormula<P>>,
        vSet: Set<LTLFormula<P>>,
        pAtomic: Set<P>,
        nAtomic: Set<P>,
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>
    ) {
        let currentWorklistDesc = currentWorklist.map { String(describing: $0).prefix(40) }
        let processedDesc = processedOnPath.map { String(describing: $0).prefix(40) }
        let vSetDesc = vSet.map { String(describing: $0).prefix(40) }
        let pAtomicDesc = pAtomic.map { String(describing: $0.id) }
        let nAtomicDesc = nAtomic.map { String(describing: $0.id) }
        let forSymbolDesc = forSymbol.map { String(describing: $0) }.sorted()
        print("[TGC SOLVE ENTRY for (¬r)R(¬p)] heuristicOriginal: \(String(describing: heuristicOriginalLTLFormula).prefix(80))")
        print("    currentFormula (if any): \(currentWorklist.first != nil ? String(describing: currentWorklist.first!).prefix(80) : "EMPTY")")
        print("    currentWorklist (count \(currentWorklistDesc.count)): \(currentWorklistDesc)")
        print("    processedOnPath (count \(processedDesc.count)): \(processedDesc)")
        print("    V (count \(vSetDesc.count)): \(vSetDesc), P_atomic: \(pAtomicDesc), N_atomic: \(nAtomicDesc), forSymbol: \(forSymbolDesc)")
    }

    // Helper method to handle empty worklist case
    private func handleEmptyWorklist(
        pAtomic: Set<P>,
        nAtomic: Set<P>,
        vSet: Set<LTLFormula<P>>,
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>],
        heuristicOriginalLTLFormula: LTLFormula<P>,
        isTargetFormulaContextForSolve: Bool,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        var currentBasicFormulas = Set<LTLFormula<P>>()
        var consistentPath = true

        let hasInternalContradiction = pAtomic.contains { p_true in nAtomic.contains(p_true) }
        if hasInternalContradiction { consistentPath = false }

        var allowBypassForLivenessSymbolCheck = false
        var isStickyAcceptingStateOfEventuality = false

        if consistentPath {
            if initialWorklistForSolve.count == 1, let singleObligation = initialWorklistForSolve.first {
                (isStickyAcceptingStateOfEventuality, _) = checkForStickyAcceptingState(
                    singleObligation: singleObligation,
                    heuristicOriginalLTLFormula: heuristicOriginalLTLFormula
                )
            }
        }

        if isStickyAcceptingStateOfEventuality {
            allowBypassForLivenessSymbolCheck = true
        }

        if consistentPath && !allowBypassForLivenessSymbolCheck {
            consistentPath = checkConsistencyWithSymbol(
                pAtomic: pAtomic,
                nAtomic: nAtomic,
                forSymbol: forSymbol
            )
        }

        if consistentPath {
            for p_atom in pAtomic { currentBasicFormulas.insert(.atomic(p_atom)) }
            for np_atom in nAtomic { currentBasicFormulas.insert(.not(.atomic(np_atom))) }
        } else {
             currentBasicFormulas = Set()
        }

        let finalV = vSet

        // ---- RE-ENABLING DEBUG FOR solve() base case outcome ----
        if isTargetFormulaContextForSolve { // Use the same flag from solve entry
            print("[TGC SOLVE BASE for (¬r)R(¬p)] forSymbol: \(forSymbol.map { String(describing: $0) }.sorted()), Consistent: \(consistentPath)")
            print("    P_atomic: \(pAtomic.map { String(describing: $0.id) }), N_atomic: \(nAtomic.map { String(describing: $0.id) })")
            print("    Outcome: currentBasic=\(currentBasicFormulas.map { String(describing: $0).prefix(40) }), nextV=\(vSet.map { String(describing: $0).prefix(40) })")
        }
        // ---- END DEBUG ----
        allPossibleOutcomes.append((currentBasicFormulas, finalV, consistentPath))
    }

    // Helper method to check for sticky accepting state
    private func checkForStickyAcceptingState(
        singleObligation: LTLFormula<P>,
        heuristicOriginalLTLFormula: LTLFormula<P>
    ) -> (Bool, LTLFormula<P>?) {
        var isHeuristicAnEventualityEquivalent = false
        var subFormulaOfEventuality: LTLFormula<P>?

        if case .eventually(let sub) = heuristicOriginalLTLFormula {
            isHeuristicAnEventualityEquivalent = true
            subFormulaOfEventuality = sub
        } else if case .not(let innerGlobal) = heuristicOriginalLTLFormula, case .globally(let gSub) = innerGlobal {
            isHeuristicAnEventualityEquivalent = true
            subFormulaOfEventuality = LTLFormula.not(gSub)
        }

        var isStickyAcceptingStateOfEventuality = false
        if isHeuristicAnEventualityEquivalent, let eventualityTarget = subFormulaOfEventuality {
            if LTLFormulaNNFConverter.convert(eventualityTarget) == singleObligation {
                isStickyAcceptingStateOfEventuality = true
            }
        }

        return (isStickyAcceptingStateOfEventuality, subFormulaOfEventuality)
    }

    // Helper method to check consistency with symbol
    private func checkConsistencyWithSymbol(
        pAtomic: Set<P>,
        nAtomic: Set<P>,
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>
    ) -> Bool {
        var consistentPath = true

        for p_true in pAtomic {
            if let p_id = p_true.id as? PropositionIDType, !forSymbol.contains(p_id) {
                consistentPath = false
                break
            }
        }

        if consistentPath {
            for p_false_prop in nAtomic {
                if let p_id = p_false_prop.id as? PropositionIDType, forSymbol.contains(p_id) {
                    consistentPath = false
                    break
                }
            }
        }

        return consistentPath
    }

    // Main formula expansion switch handler
    private func expandFormulaByType(
        currentFormula: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>],
        processedOnPath: Set<LTLFormula<P>>,
        vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>,
        nAtomicSet: Set<P>,
        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>],
        heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        switch currentFormula {
        case .booleanLiteral(let b):
            handleBooleanLiteral(
                value: b, isNegated: false,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .atomic(let p):
            handleAtomicFormula(
                p: p, isNegated: false,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .not(.atomic(let p)):
            handleAtomicFormula(
                p: p, isNegated: true,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .not(.booleanLiteral(let b)):
            handleBooleanLiteral(
                value: b, isNegated: true,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .and(let lhs, let rhs):
            handleAndFormula(
                lhs: lhs, rhs: rhs,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .or(let lhs, let rhs):
            handleOrFormula(
                lhs: lhs, rhs: rhs,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .next(let subFormula):
            handleNextFormula(
                subFormula: subFormula,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .until(let phi, let psi):
            handleUntilFormula(
                phi: phi, psi: psi, currentFormula: currentFormula,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .release(let phi, let psi):
            handleReleaseFormula(
                phi: phi, psi: psi, currentFormula: currentFormula,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .eventually(let subFormula):
            handleEventuallyFormula(
                subFormula: subFormula, currentFormula: currentFormula,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .globally(let subFormula):
            handleGloballyFormula(
                subFormula: subFormula, currentFormula: currentFormula,
                currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )

        case .weakUntil:
            handleErrorCase("WeakUntil (W) should be converted by NNF", currentFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .implies:
            handleErrorCase("Implies (->) should be converted by NNF", currentFormula, allPossibleOutcomes: &allPossibleOutcomes)

        case .not(.until), .not(.release), .not(.weakUntil), .not(.next), .not(.eventually), .not(.globally):
            handleErrorCase("Unexpected negated temporal operator in solve", currentFormula, allPossibleOutcomes: &allPossibleOutcomes)

        default:
            handleErrorCase("Unhandled LTL formula type in solve", currentFormula, allPossibleOutcomes: &allPossibleOutcomes)
        }
    }

    // Helper method for error handling
    private func handleErrorCase(
        _ message: String,
        _ formula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        print("[TGC SOLVE ERROR] \(message). Encountered: \(formula)")
        allPossibleOutcomes.append((Set(), Set(), false))
    }

    // Handler for atomic propositions (.atomic and .not(.atomic))
    private func handleAtomicFormula(
        p: P, isNegated: Bool,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        var currentPAtomic = pAtomicSet
        var currentNAtomic = nAtomicSet

        if isNegated {
            currentNAtomic.insert(p)
        } else {
            currentPAtomic.insert(p)
        }
        solve(
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: currentPAtomic, nAtomicSet: currentNAtomic, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Legacy method for backward compatibility
    private func expandAtomicProposition(p: P,
                                     isNegated: Bool,
                                     currentWorklist: [LTLFormula<P>],
                                     processedOnPath: Set<LTLFormula<P>>,
                                     vSet: Set<LTLFormula<P>>,
                                     pAtomicSet: Set<P>,
                                     nAtomicSet: Set<P>,
                                     forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                                     initialWorklistForSolve: [LTLFormula<P>],
                                     heuristicOriginalLTLFormula: LTLFormula<P>,
                                     allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleAtomicFormula(
            p: p, isNegated: isNegated,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Handler for boolean literals (.booleanLiteral and .not(.booleanLiteral))
    private func handleBooleanLiteral(
        value b: Bool, isNegated: Bool,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        let effectiveValue = isNegated ? !b : b
        if !effectiveValue {
            allPossibleOutcomes.append(([], [], false))
            return
        }
        solve(
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Legacy method for backward compatibility
    private func expandBooleanLiteral(value b: Bool,
                                    isNegated: Bool,
                                    currentWorklist: [LTLFormula<P>],
                                    processedOnPath: Set<LTLFormula<P>>,
                                    vSet: Set<LTLFormula<P>>,
                                    pAtomicSet: Set<P>,
                                    nAtomicSet: Set<P>,
                                    forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                                    initialWorklistForSolve: [LTLFormula<P>],
                                    heuristicOriginalLTLFormula: LTLFormula<P>,
                                    allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleBooleanLiteral(
            value: b, isNegated: isNegated,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Handler for AND formulas (.and)
    private func handleAndFormula(
        lhs: LTLFormula<P>, rhs: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        var newWorklist = currentWorklist
        // Add children to the front of the worklist to process them before other items already in the worklist.
        // This maintains the depth-first nature of the tableau expansion for the conjunction.
        if !processedOnPath.contains(rhs) { newWorklist.insert(rhs, at: 0) }
        if !processedOnPath.contains(lhs) { newWorklist.insert(lhs, at: 0) }
        solve(
            currentWorklist: newWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Legacy method for backward compatibility
    private func expandAnd(_ lhs: LTLFormula<P>, _ rhs: LTLFormula<P>,
                         currentWorklist: [LTLFormula<P>],
                         processedOnPath: Set<LTLFormula<P>>,
                         vSet: Set<LTLFormula<P>>,
                         pAtomicSet: Set<P>,
                         nAtomicSet: Set<P>,
                         forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                         initialWorklistForSolve: [LTLFormula<P>],
                         heuristicOriginalLTLFormula: LTLFormula<P>,
                         allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleAndFormula(
            lhs: lhs, rhs: rhs,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Handler for OR formulas (.or)
    private func handleOrFormula(
        lhs: LTLFormula<P>, rhs: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        // Branch for lhs
        var worklistLhs = currentWorklist
        if !processedOnPath.contains(lhs) { worklistLhs.insert(lhs, at: 0) }
        solve(
            currentWorklist: worklistLhs, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )

        // Branch for rhs
        var worklistRhs = currentWorklist
        if !processedOnPath.contains(rhs) { worklistRhs.insert(rhs, at: 0) }
        solve(
            currentWorklist: worklistRhs, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Legacy method for backward compatibility
    private func expandOr(_ lhs: LTLFormula<P>, _ rhs: LTLFormula<P>,
                        currentWorklist: [LTLFormula<P>],
                        processedOnPath: Set<LTLFormula<P>>,
                        vSet: Set<LTLFormula<P>>,
                        pAtomicSet: Set<P>,
                        nAtomicSet: Set<P>,
                        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                        initialWorklistForSolve: [LTLFormula<P>],
                        heuristicOriginalLTLFormula: LTLFormula<P>,
                        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleOrFormula(
            lhs: lhs, rhs: rhs,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Handler for NEXT formulas (.next)
    private func handleNextFormula(
        subFormula: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        var newV = vSet
        newV.insert(subFormula)
        solve(
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: newV,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Legacy method for backward compatibility
    private func expandNext(_ subFormula: LTLFormula<P>,
                        currentWorklist: [LTLFormula<P>],
                        processedOnPath: Set<LTLFormula<P>>,
                        vSet: Set<LTLFormula<P>>,
                        pAtomicSet: Set<P>,
                        nAtomicSet: Set<P>,
                        forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                        initialWorklistForSolve: [LTLFormula<P>],
                        heuristicOriginalLTLFormula: LTLFormula<P>,
                        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleNextFormula(
            subFormula: subFormula,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Handler for UNTIL formulas (.until)
    private func handleUntilFormula(
        phi: LTLFormula<P>, psi: LTLFormula<P>, currentFormula: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        // Branch 1: psi holds now
        var worklistPsiBranch = currentWorklist
        if !processedOnPath.contains(psi) { worklistPsiBranch.insert(psi, at: 0) }
        solve(
            currentWorklist: worklistPsiBranch, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )

        // Branch 2: phi holds now AND X(phi U psi) holds next
        var worklistPhiBranch = currentWorklist
        if !processedOnPath.contains(phi) { worklistPhiBranch.insert(phi, at: 0) }
        var vForPhiBranch = vSet
        vForPhiBranch.insert(currentFormula) // currentFormula is phi U psi
        solve(
            currentWorklist: worklistPhiBranch, processedOnPath: processedOnPath, vSet: vForPhiBranch,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Legacy method for backward compatibility
    private func expandUntil(_ phi: LTLFormula<P>, _ psi: LTLFormula<P>,
                         currentFormula: LTLFormula<P>, // This is the (phi U psi) formula itself
                         currentWorklist: [LTLFormula<P>],
                         processedOnPath: Set<LTLFormula<P>>,
                         vSet: Set<LTLFormula<P>>,
                         pAtomicSet: Set<P>,
                         nAtomicSet: Set<P>,
                         forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                         initialWorklistForSolve: [LTLFormula<P>],
                         heuristicOriginalLTLFormula: LTLFormula<P>,
                         allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleUntilFormula(
            phi: phi, psi: psi, currentFormula: currentFormula,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Handler for RELEASE formulas (.release)
    private func handleReleaseFormula(
        phi: LTLFormula<P>, psi: LTLFormula<P>, currentFormula: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        // Branch 1: psi holds now
        var worklistBranchPsi = currentWorklist
        if !processedOnPath.contains(psi) { worklistBranchPsi.insert(psi, at: 0) }
        solve(
            currentWorklist: worklistBranchPsi, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )

        // Branch 2: phi holds now AND X(phi R psi) holds next
        var worklistBranchPhi = currentWorklist
        if !processedOnPath.contains(phi) { worklistBranchPhi.insert(phi, at: 0) }
        var vSetBranchPhiAndXR = vSet
        vSetBranchPhiAndXR.insert(currentFormula) // Add X(phi R psi)
        solve(
            currentWorklist: worklistBranchPhi, processedOnPath: processedOnPath, vSet: vSetBranchPhiAndXR,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Legacy method for backward compatibility
    private func expandRelease(_ phi: LTLFormula<P>, _ psi: LTLFormula<P>,
                         currentFormula: LTLFormula<P>, // This is the (phi R psi) formula itself
                         currentWorklist: [LTLFormula<P>],
                         processedOnPath: Set<LTLFormula<P>>,
                         vSet: Set<LTLFormula<P>>,
                         pAtomicSet: Set<P>,
                         nAtomicSet: Set<P>,
                         forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                         initialWorklistForSolve: [LTLFormula<P>],
                         heuristicOriginalLTLFormula: LTLFormula<P>,
                         allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleReleaseFormula(
            phi: phi, psi: psi, currentFormula: currentFormula,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Handler for EVENTUALLY formulas (.eventually)
    private func handleEventuallyFormula(
        subFormula: LTLFormula<P>, currentFormula: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        // F subFormula  ≡  subFormula ∨ X (F subFormula)
        // This is equivalent to: true U subFormula

        // Branch 1: subFormula holds now
        var worklistSubFormulaBranch = currentWorklist
        if !processedOnPath.contains(subFormula) { worklistSubFormulaBranch.insert(subFormula, at: 0) }
        solve(
            currentWorklist: worklistSubFormulaBranch, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )

        // Branch 2: X (F subFormula) holds next
        let worklistNextBranch = currentWorklist
        var vForNextBranch = vSet
        vForNextBranch.insert(currentFormula) // currentFormula is F subFormula
        solve(
            currentWorklist: worklistNextBranch, processedOnPath: processedOnPath, vSet: vForNextBranch,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Legacy method for backward compatibility
    private func expandEventually(_ subFormula: LTLFormula<P>,
                               currentFormula: LTLFormula<P>, // This is F subFormula
                               currentWorklist: [LTLFormula<P>],
                               processedOnPath: Set<LTLFormula<P>>,
                               vSet: Set<LTLFormula<P>>,
                               pAtomicSet: Set<P>,
                               nAtomicSet: Set<P>,
                               forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                               initialWorklistForSolve: [LTLFormula<P>],
                               heuristicOriginalLTLFormula: LTLFormula<P>,
                               allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleEventuallyFormula(
            subFormula: subFormula, currentFormula: currentFormula,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
    }

    // Handler for GLOBALLY formulas (.globally)
    private func handleGloballyFormula(
        subFormula: LTLFormula<P>, currentFormula: LTLFormula<P>,
        currentWorklist: [LTLFormula<P>], processedOnPath: Set<LTLFormula<P>>, vSet: Set<LTLFormula<P>>,
        pAtomicSet: Set<P>, nAtomicSet: Set<P>, forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
        initialWorklistForSolve: [LTLFormula<P>], heuristicOriginalLTLFormula: LTLFormula<P>,
        allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]
    ) {
        // G subFormula  ≡  subFormula ∧ X (G subFormula)

        var worklistSubFormulaBranch = currentWorklist
        if !processedOnPath.contains(subFormula) { worklistSubFormulaBranch.insert(subFormula, at: 0) }

        var subFormulaOutcomes: [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)] = []
        solve(
            currentWorklist: worklistSubFormulaBranch, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &subFormulaOutcomes
        )

        for outcome in subFormulaOutcomes where outcome.isConsistent {
            var vForXGBranch = outcome.nextSetOfNextObligations
            vForXGBranch.insert(currentFormula)

            solve(
                currentWorklist: Array(outcome.nextSetOfCurrentObligations), processedOnPath: processedOnPath, vSet: vForXGBranch,
                pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
                initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
                allPossibleOutcomes: &allPossibleOutcomes
            )
        }
    }

    // Legacy method for backward compatibility
    private func expandGlobally(_ subFormula: LTLFormula<P>,
                              currentFormula: LTLFormula<P>, // This is G subFormula
                              currentWorklist: [LTLFormula<P>],
                              processedOnPath: Set<LTLFormula<P>>,
                              vSet: Set<LTLFormula<P>>,
                              pAtomicSet: Set<P>,
                              nAtomicSet: Set<P>,
                              forSymbol: BuchiAlphabetSymbol<PropositionIDType>,
                              initialWorklistForSolve: [LTLFormula<P>],
                              heuristicOriginalLTLFormula: LTLFormula<P>,
                              allPossibleOutcomes: inout [(nextSetOfCurrentObligations: Set<LTLFormula<P>>, nextSetOfNextObligations: Set<LTLFormula<P>>, isConsistent: Bool)]) {
        handleGloballyFormula(
            subFormula: subFormula, currentFormula: currentFormula,
            currentWorklist: currentWorklist, processedOnPath: processedOnPath, vSet: vSet,
            pAtomicSet: pAtomicSet, nAtomicSet: nAtomicSet, forSymbol: forSymbol,
            initialWorklistForSolve: initialWorklistForSolve, heuristicOriginalLTLFormula: heuristicOriginalLTLFormula,
            allPossibleOutcomes: &allPossibleOutcomes
        )
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
    func idDescription() -> String { self.rawValue }
}
