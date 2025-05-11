import Foundation

// Assumes LTLFormula, TemporalProposition, TableauNode, and FormulaAutomatonState are defined and accessible.

internal struct GBAConditionGenerator<P: TemporalProposition> where P.Value == Bool {

    /// Collects all subformulas of the form 'U', 'F', 'R', or 'G'.
    private static func collectLivenessSubformulas(from formula: LTLFormula<P>) -> Set<LTLFormula<P>> {
        var livenessFormulas = Set<LTLFormula<P>>()
        var worklist = [formula]
        var visited = Set<LTLFormula<P>>()

        while let current = worklist.popLast() {
            if visited.contains(current) { continue }
            visited.insert(current)

            // 1. Add to livenessFormulas ONLY if current itself is U, F, R, or G
            switch current {
            case .until(_, _), .eventually(_), .release(_, _), .globally(_):
                livenessFormulas.insert(current)
            default:
                break // Not a top-level liveness formula itself
            }

            // 2. ALWAYS recurse on children to find NESTED liveness formulas
            switch current {
                case .not(let sub), .next(let sub), .eventually(let sub), .globally(let sub):
                    if !visited.contains(sub) { worklist.append(sub) }
                case .until(let l, let r), .release(let l, let r), .weakUntil(let l, let r), 
                     .and(let l, let r), .or(let l, let r), .implies(let l, let r):
                    if !visited.contains(l) { worklist.append(l) }
                    if !visited.contains(r) { worklist.append(r) }
                case .booleanLiteral(_), .atomic(_):
                    break // No children to recurse on
            }
        }
        return livenessFormulas
    }

    /// Determines the Generalized Büchi Automaton (GBA) acceptance conditions.
    /// - Parameters:
    ///   - tableauNodes: All unique `TableauNode`s created during tableau construction.
    ///   - nodeToStateIDMap: A map from each `TableauNode` to its integer state ID in the GBA.
    ///   - originalNNFFormula: The Negation Normal Form of the input LTL formula.
    /// - Returns: An array of sets of state IDs. Each set `F_i` represents an acceptance condition.
    ///            A run is accepting if it visits states from each `F_i` infinitely often.
    internal static func determineConditions(
        tableauNodes: Set<TableauNode<P>>,
        nodeToStateIDMap: [TableauNode<P>: FormulaAutomatonState],
        originalNNFFormula: LTLFormula<P>
    ) -> [Set<FormulaAutomatonState>] {
        // Special case for a constant false formula -> no accepting states in its BA
        if case .booleanLiteral(let bVal) = originalNNFFormula, !bVal {
            // print("[GBACond DEBUG] NNF is 'false'. Returning GBA sets [[]] for no BA accepting states.")
            return [Set<FormulaAutomatonState>()] // One empty set signals BA should have no accepting states
        }

        let livenessSubformulas = collectLivenessSubformulas(from: originalNNFFormula)
        var gbaAcceptanceSets: [Set<FormulaAutomatonState>] = []
        let nnfDesc = String(describing: originalNNFFormula)

        if livenessSubformulas.isEmpty {
            // For non-liveness formulas (like Xp, p, true), GBA sets are empty, BA becomes all-accepting.
            // 'false' is handled above.
            // print("[GBACond DEBUG] NNF \(nnfDesc) has NO U/F/R/G liveness. GBA sets empty (BA all accepting).")
        } else {
            for livenessFormula in livenessSubformulas {
                var specificAcceptanceSet = Set<FormulaAutomatonState>()
                var isTargetReleaseFormulaForLog_OuterLoop = false // For the final set log
                if case .release(let l_log_outer, let r_log_outer) = livenessFormula {
                    let lDesc_outer = String(describing: l_log_outer)
                    let rDesc_outer = String(describing: r_log_outer)
                    if lDesc_outer.contains("r_kripke") && lDesc_outer.contains("not(atomic") &&
                       rDesc_outer.contains("p_kripke") && rDesc_outer.contains("not(atomic") &&
                       (lDesc_outer.contains("DemoKripkeModelState") || rDesc_outer.contains("DemoKripkeModelState")) {
                        isTargetReleaseFormulaForLog_OuterLoop = true
                    }
                }

                for tableauNode in tableauNodes {
                    guard let nodeID = nodeToStateIDMap[tableauNode] else { continue }
                    var conditionMet = false

                    switch livenessFormula {
                    case .until(let lhsU, let rhsU):
                        if lhsU.isBooleanLiteralTrue() { 
                            conditionMet = tableauNode.currentFormulas.contains(rhsU) 
                        } else { 
                            conditionMet = tableauNode.currentFormulas.contains(rhsU) || 
                                         !tableauNode.nextFormulas.contains(livenessFormula) 
                        }
                    case .eventually(let subE): 
                        conditionMet = tableauNode.currentFormulas.contains(subE) || 
                                     !tableauNode.currentFormulas.contains(livenessFormula)
                    
                    case .release(let lhsR, let rhsR):
                        if lhsR.isBooleanLiteralFalse() { // G rhsR (NNF: false R rhsR)
                            conditionMet = tableauNode.currentFormulas.contains(LTLFormula.not(rhsR))
                        } else { // Standard A R B
                            conditionMet = tableauNode.currentFormulas.contains(rhsR) || 
                                         !tableauNode.currentFormulas.contains(livenessFormula)
                        }
                    case .globally(let subG): // G subG (where subG is A)
                        conditionMet = tableauNode.currentFormulas.contains(LTLFormula.not(subG))

                    default:
                         print("[GBACond WARN] Unexpected liveness formula type in loop: \(livenessFormula) for NNF \(nnfDesc). Skipping.")
                         continue 
                    }
                    
                    if conditionMet {
                        specificAcceptanceSet.insert(nodeID)
                    }
                }

                if isTargetReleaseFormulaForLog_OuterLoop { // Use the outer flag for the summary log
                    print("[GBACond DEBUG REL_SET_FINAL for (¬r)R(¬p)] Liveness: \(String(describing:livenessFormula).prefix(100)), SpecificAcceptanceSet: \(specificAcceptanceSet.sorted().map {String(describing:$0)}) (Size: \(specificAcceptanceSet.count))")
                }

                if !specificAcceptanceSet.isEmpty {
                    gbaAcceptanceSets.append(specificAcceptanceSet)
                } else {
                    print("[GBACond WARN] Liveness formula \(livenessFormula) in \(nnfDesc) yielded empty specific acceptance set. Appending empty set.")
                    gbaAcceptanceSets.append(Set<FormulaAutomatonState>())
                }
            }
        }
        
        // Final debug print (expanded trigger)
        let descForFinalLog = String(describing: originalNNFFormula) // Use original NNF for trigger condition
        if descForFinalLog.contains("until(booleanLiteral(true), atomic") || 
           (descForFinalLog.contains("release(not(atomic") && descForFinalLog.contains("r_kripke") && descForFinalLog.contains("p_kripke")) || 
           descForFinalLog.contains("release(booleanLiteral(false), atomic") {
             print("[GBACond DEBUG FINAL] Final gbaAcceptanceSets for NNF \(nnfDesc): count = \(gbaAcceptanceSets.count), content = \(gbaAcceptanceSets.map { $0.sorted().map { String(describing: $0) } })")
        }
        return gbaAcceptanceSets
    }
}

fileprivate extension LTLFormula {
    func isBooleanLiteralTrue() -> Bool {
        if case .booleanLiteral(let bVal) = self, bVal == true { return true }
        return false
    }
    func isBooleanLiteralFalse() -> Bool {
        if case .booleanLiteral(let bVal) = self, !bVal { return true }
        return false
    }
    var isRelease: Bool {
        if case .release = self { return true } else { return false }
    }
}
