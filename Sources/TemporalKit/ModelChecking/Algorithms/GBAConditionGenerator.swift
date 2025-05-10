import Foundation

// Assumes LTLFormula, TemporalProposition, TableauNode, and FormulaAutomatonState are defined and accessible.

internal struct GBAConditionGenerator<P: TemporalProposition> where P.Value == Bool {

    /// Collects all subformulas of the form 'phi U psi' from a given LTL formula.
    /// This is used to identify the obligations that contribute to GBA acceptance conditions.
    private static func collectUntilSubformulas(from formula: LTLFormula<P>) -> Set<LTLFormula<P>> {
        // Removing DEBUG prints from here as the NNF issue seems resolved.
        // print("DEBUG: collectUntilSubformulas received formula: \(String(reflecting: formula))")
        // if case .until(_,_) = formula {
        //     print("DEBUG: Top-level formula IS an .until case.")
        // } else {
        //     print("DEBUG: Top-level formula IS NOT an .until case. Actual case: \(String(describing: formula).split(separator: "(").first ?? "Unknown")")
        // }

        var untils = Set<LTLFormula<P>>()
        var worklist = [LTLFormula<P>]()
        var visited = Set<LTLFormula<P>>()

        // Explicitly check the initial formula before starting the loop
        // to handle cases where the formula itself is the target and might be missed by loop/visited logic.
        if case .until(_, _) = formula {
            untils.insert(formula)
        }
        // Add children of the initial formula to the worklist for further exploration
        // or the formula itself if it wasn't an .until or to explore its children too.
        // To be safe and explore all, always start with the formula in the worklist strategy.
        // The original logic was fine, let's ensure the worklist processing is robust.
        
        worklist.append(formula) // Reset to original strategy, the issue might be elsewhere or subtle.

        while let current = worklist.popLast() {
            if visited.contains(current) { continue }
            visited.insert(current)

            switch current {
            case .booleanLiteral, .atomic:
                break // No subformulas to explore
            case .not(let sub):
                if !visited.contains(sub) { worklist.append(sub) }
            case .and(let l, let r), .or(let l, let r), .implies(let l, let r),
                 .weakUntil(let l, let r), .release(let l, let r):
                if !visited.contains(l) { worklist.append(l) }
                if !visited.contains(r) { worklist.append(r) }
            case .next(let sub), .eventually(let sub), .globally(let sub):
                if !visited.contains(sub) { worklist.append(sub) }
            case .until(let l, let r):
                untils.insert(current) // Add the Until formula itself
                if !visited.contains(l) { worklist.append(l) }     // Also explore subformulas of the Until
                if !visited.contains(r) { worklist.append(r) }
            }
        }
        return untils
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
        let untilSubformulas = collectUntilSubformulas(from: originalNNFFormula)
        var gbaAcceptanceSets: [Set<FormulaAutomatonState>] = []

        // ---- GBAConditionGenerator DEBUG ----
        let pDemoLikeRawValue = "p_demo_like" // For identifying F(!p_demo_like) related U-formula
        // ---- END DEBUG ----

        if !untilSubformulas.isEmpty {
            print("[GBAConditionGenerator DEBUG] Found \(untilSubformulas.count) Until-subformulas. Processing them.")
            for uFormula in untilSubformulas {
                guard case .until(let lhsU, let rhsU) = uFormula else { continue }
                var specificAcceptanceSetForThisU = Set<FormulaAutomatonState>()

                // ---- GBAConditionGenerator DEBUG ----
                var isTargetFNotPFormula = false
                if case .booleanLiteral(true) = lhsU, case .not(let inner) = rhsU, case .atomic(let p) = inner, String(describing: p.id).contains(pDemoLikeRawValue) {
                    isTargetFNotPFormula = true
                    print("[GBAConditionGenerator DEBUG] Processing U-formula relevant to F(!\(pDemoLikeRawValue)): \(String(describing: uFormula))")
                    print("    rhsU (should be !\(pDemoLikeRawValue)): \(String(describing: rhsU))")
                }
                // ---- END DEBUG ----

                for tableauNode in tableauNodes {
                    let satisfiedRhsU = tableauNode.currentFormulas.contains(rhsU)
                    let uFormulaStillActiveCurrent = tableauNode.currentFormulas.contains(uFormula)
                    let uFormulaNotActiveNext = !tableauNode.nextFormulas.contains(uFormula)
                    let uFormulaNotActiveOverall = !uFormulaStillActiveCurrent && uFormulaNotActiveNext
                    
                    if satisfiedRhsU || uFormulaNotActiveOverall {
                        if let stateID = nodeToStateIDMap[tableauNode] {
                            specificAcceptanceSetForThisU.insert(stateID)
                            if isTargetFNotPFormula {
                                print("    [F(!\(pDemoLikeRawValue)) DEBUG] Adding GBA state ID \(stateID) to acceptance set. Node: {current: \(tableauNode.currentFormulas.map{String(describing:$0)}), next: \(tableauNode.nextFormulas.map{String(describing:$0)})}. SatisfiedRhsU: \(satisfiedRhsU), UNotActiveOverall: \(uFormulaNotActiveOverall)")
                            }
                        }
                    }
                }
                if isTargetFNotPFormula {
                    print("[GBAConditionGenerator DEBUG] Acceptance set for F(!\(pDemoLikeRawValue)) (orig U: \(String(describing:uFormula))): \(specificAcceptanceSetForThisU.sorted())")
                }
                gbaAcceptanceSets.append(specificAcceptanceSetForThisU)
            }
        } else {
            // No Until subformulas found.
            // Default acceptance: if the formula is not a Next, all states form a single acceptance set.
            // For Next(sub), only states where 'sub' is current should be accepting.
            if !tableauNodes.isEmpty {
                if case .next(let subFormula) = originalNNFFormula {
                    print("GBAConditionGenerator: Handling Next formula: \(originalNNFFormula)")
                    var nextAcceptanceSet = Set<FormulaAutomatonState>()
                    for tableauNode in tableauNodes {
                        // A state is accepting for X(sub) if sub is now current in that state node.
                        // This means the X has been "consumed".
                        if tableauNode.currentFormulas.contains(subFormula) {
                            if let stateID = nodeToStateIDMap[tableauNode] {
                                nextAcceptanceSet.insert(stateID)
                            }
                        }
                    }
                    // If subFormula itself could be true (always), this might still make many states accepting.
                    // Example: X true. subFormula is true. All nodes where current has true are accepting.
                    // If nextAcceptanceSet is empty, it means 'sub' never became current alone.
                    gbaAcceptanceSets.append(nextAcceptanceSet)
                    print("GBAConditionGenerator: Acceptance for Next: \(nextAcceptanceSet)")
                } else {
                    // Not a Next formula, and no Until. E.g. true, p, p AND q.
                    // print("GBAConditionGenerator: No Until-subformulas and not Next. Defaulting to all GBA states as one acceptance set.") // Removed
                    gbaAcceptanceSets.append(Set(nodeToStateIDMap.values))
                }
            }
        }
        
        if gbaAcceptanceSets.isEmpty && !tableauNodes.isEmpty {
        }
        return gbaAcceptanceSets
    }
} 
