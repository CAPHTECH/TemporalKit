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
        if case .booleanLiteral(let bVal) = originalNNFFormula, !bVal {
            return [Set<FormulaAutomatonState>()]
        }

        let livenessSubformulas = collectLivenessSubformulas(from: originalNNFFormula)
        var gbaAcceptanceSets: [Set<FormulaAutomatonState>] = []

        if livenessSubformulas.isEmpty {
            // No explicit liveness, GBA implicitly all-accepting (converted to BA all-accepting)
        } else {
            for livenessFormula in livenessSubformulas {
                var specificAcceptanceSet = Set<FormulaAutomatonState>()
                for tableauNode in tableauNodes {
                    guard let nodeID = nodeToStateIDMap[tableauNode] else { continue }
                    var conditionMet = false

                    switch livenessFormula {
                    case .until(let lhsU, let rhsU):
                        if lhsU.isBooleanLiteralTrue() { 
                            conditionMet = tableauNode.currentFormulas.contains(rhsU) 
                        } else { 
                            conditionMet = tableauNode.currentFormulas.contains(rhsU) || 
                                         !tableauNode.currentFormulas.contains(livenessFormula)
                        }

                    case .eventually(let subE):
                        conditionMet = tableauNode.currentFormulas.contains(subE) || 
                                     !tableauNode.currentFormulas.contains(livenessFormula) 
                    
                    case .release(let lhsR, let rhsR):
                        let currentContainsRhsR = tableauNode.currentFormulas.contains(rhsR)
                        if lhsR.isBooleanLiteralFalse() { // G form
                            conditionMet = !tableauNode.currentFormulas.contains(LTLFormula.not(rhsR))
                        } else { // Standard A R B
                            conditionMet = currentContainsRhsR || !tableauNode.currentFormulas.contains(livenessFormula)
                        }

                    case .globally(let subG):
                        conditionMet = !tableauNode.currentFormulas.contains(LTLFormula.not(subG))
                    
                    default:
                        continue 
                    }

                    if conditionMet {
                        specificAcceptanceSet.insert(nodeID)
                    }
                }
                
                if !specificAcceptanceSet.isEmpty || livenessSubformulas.count == 1 { 
                     gbaAcceptanceSets.append(specificAcceptanceSet)
                } else {
                    gbaAcceptanceSets.append(Set<FormulaAutomatonState>())
                }
            }
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
}
