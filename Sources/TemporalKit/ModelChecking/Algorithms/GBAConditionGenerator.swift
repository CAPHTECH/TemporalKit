import Foundation

// MARK: - GBAConditionGenerator - Creates Generalized Büchi Automaton Acceptance Conditions

/// Generates acceptance conditions for a Generalized Büchi Automaton (GBA) based on LTL formulas.
/// This is a critical component for LTL-to-BA conversion using the tableau method.
internal struct GBAConditionGenerator<P: TemporalProposition> where P.Value == Bool {

    /// Collects all temporal subformulas that require liveness acceptance conditions.
    /// These are: Until (U), Eventually (F), Release (R), and Globally (G) operators.
    ///
    /// - Parameter formula: The formula to analyze for liveness subformulas.
    /// - Returns: A set of liveness subformulas extracted from the input formula.
    private static func collectLivenessSubformulas(from formula: LTLFormula<P>) -> Set<LTLFormula<P>> {
        var livenessFormulas = Set<LTLFormula<P>>()
        var worklist = [formula]
        var visited = Set<LTLFormula<P>>()

        while let current = worklist.popLast() {
            if visited.contains(current) { continue }
            visited.insert(current)

            // 1. Add to livenessFormulas ONLY if current itself is U, F, R, or G
            switch current {
            case .until, .eventually, .release, .globally:
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
                case .booleanLiteral, .atomic:
                    break // No children to recurse on
            }
        }
        return livenessFormulas
    }

    /// Determines the Generalized Büchi Automaton (GBA) acceptance conditions.
    /// 
    /// For each liveness formula in the LTL specification, this method constructs an acceptance set.
    /// A run in the resulting GBA is accepting if it visits at least one state from each acceptance set
    /// infinitely often.
    ///
    /// - Parameters:
    ///   - tableauNodes: All unique `TableauNode`s created during tableau construction.
    ///   - nodeToStateIDMap: A map from each `TableauNode` to its integer state ID in the GBA.
    ///   - originalNNFFormula: The Negation Normal Form of the input LTL formula.
    /// - Returns: An array of sets of state IDs. Each set `F_i` represents an acceptance condition.
    internal static func determineConditions(
        tableauNodes: Set<TableauNode<P>>,
        nodeToStateIDMap: [TableauNode<P>: FormulaAutomatonState],
        originalNNFFormula: LTLFormula<P>
    ) -> [Set<FormulaAutomatonState>] {
        // Special case: Formula is "false" - return empty acceptance set
        if case .booleanLiteral(let bVal) = originalNNFFormula, !bVal {
            return [Set<FormulaAutomatonState>()]
        }

        let livenessSubformulas = collectLivenessSubformulas(from: originalNNFFormula)
        var gbaAcceptanceSets: [Set<FormulaAutomatonState>] = []

        // If no liveness subformulas, all states are implicitly accepting
        if livenessSubformulas.isEmpty {
            // Create a single acceptance set containing all states
            var allStatesSet = Set<FormulaAutomatonState>()
            for tableauNode in tableauNodes {
                if let nodeID = nodeToStateIDMap[tableauNode] {
                    allStatesSet.insert(nodeID)
                }
            }
            if !allStatesSet.isEmpty {
                gbaAcceptanceSets.append(allStatesSet)
            }
        } else {
            // Process each liveness formula to create its acceptance set
            for livenessFormula in livenessSubformulas {
                var specificAcceptanceSet = Set<FormulaAutomatonState>()

                for tableauNode in tableauNodes {
                    guard let nodeID = nodeToStateIDMap[tableauNode] else { continue }
                    var conditionMet = false

                    switch livenessFormula {
                    case .until(let lhsU, let rhsU):
                        // For Until (A U B), a node contributes to acceptance set if:
                        // 1. It contains B (right side of Until is satisfied), OR
                        // 2. It does not contain A U B (formula doesn't need to be satisfied)
                        if lhsU.isBooleanLiteralTrue() {
                            conditionMet = tableauNode.currentFormulas.contains(rhsU)
                        } else {
                            conditionMet = tableauNode.currentFormulas.contains(rhsU) ||
                                         !tableauNode.currentFormulas.contains(livenessFormula)
                        }

                    case .eventually(let subE):
                        // For Eventually (F A), a node contributes to acceptance set if:
                        // 1. It contains A (the Eventually is satisfied), OR
                        // 2. It does not contain F A (formula doesn't need to be satisfied)
                        conditionMet = tableauNode.currentFormulas.contains(subE) ||
                                     !tableauNode.currentFormulas.contains(livenessFormula)

                    case .release(let lhsR, let rhsR):
                        // For Release (A R B), acceptance requires satisfying B until A & B holds
                        // A node contributes to acceptance set if:
                        // 1. It does not contain A R B (formula doesn't need to be satisfied), OR
                        // 2. It contains A (left operand satisfied - releases B from obligation), OR
                        // 3. It does not contain B (Release is false, so acceptance set not relevant)
                        conditionMet = !tableauNode.currentFormulas.contains(livenessFormula) ||
                                       tableauNode.currentFormulas.contains(lhsR) ||
                                       !tableauNode.currentFormulas.contains(rhsR)

                        // Special case: if A is false, R becomes G(B), which has a different acceptance condition
                        if lhsR.isBooleanLiteralFalse() {
                            // For false R B (equivalent to G B), a node contributes if it contains B
                            conditionMet = tableauNode.currentFormulas.contains(rhsR) ||
                                         !tableauNode.currentFormulas.contains(livenessFormula)
                        }

                        // Special case: if A is true, R becomes just B, no liveness constraint needed
                        if lhsR.isBooleanLiteralTrue() {
                            conditionMet = true // All states can be in acceptance set
                        }

                    case .globally(let subG):
                        // For Globally (G A), a node contributes to acceptance set if:
                        // 1. It contains A (the Globally condition is maintained), OR
                        // 2. It does not contain G A (formula doesn't need to be satisfied)
                        conditionMet = tableauNode.currentFormulas.contains(subG) ||
                                      !tableauNode.currentFormulas.contains(livenessFormula)

                    default:
                        continue // Skip non-liveness formulas
                    }

                    if conditionMet {
                        specificAcceptanceSet.insert(nodeID)
                    }
                }

                // Add the acceptance set if it's not empty, or this is the only liveness formula
                if !specificAcceptanceSet.isEmpty || livenessSubformulas.count == 1 {
                     gbaAcceptanceSets.append(specificAcceptanceSet)
                } else {
                    // This is a fallback to ensure we have an acceptance set even if empty
                    // (GBAToBAConverter handles this case)
                    gbaAcceptanceSets.append(Set<FormulaAutomatonState>())
                }
            }
        }

        // Validate acceptance sets
        if livenessSubformulas.isEmpty && gbaAcceptanceSets.isEmpty && !tableauNodes.isEmpty {
            // For formulas without liveness but with tableau nodes, create an all-accepting set
            var allStatesSet = Set<FormulaAutomatonState>()
            for tableauNode in tableauNodes {
                if let nodeID = nodeToStateIDMap[tableauNode] {
                    allStatesSet.insert(nodeID)
                }
            }
            if !allStatesSet.isEmpty {
                gbaAcceptanceSets.append(allStatesSet)
            }
        }

        return gbaAcceptanceSets
    }
}

fileprivate extension LTLFormula {
    /// Returns true if this formula is the boolean literal `true`.
    func isBooleanLiteralTrue() -> Bool {
        if case .booleanLiteral(let bVal) = self, bVal == true { return true }
        return false
    }

    /// Returns true if this formula is the boolean literal `false`.
    func isBooleanLiteralFalse() -> Bool {
        if case .booleanLiteral(let bVal) = self, !bVal { return true }
        return false
    }
}
