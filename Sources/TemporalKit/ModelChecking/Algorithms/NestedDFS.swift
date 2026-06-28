import Foundation

// MARK: - NestedDFS Algorithm for Büchi Automaton Emptiness Checking

internal enum NestedDFSAlgorithm {

    /// Finds an accepting run in a Büchi automaton using the standard 2-color Nested DFS
    /// (Holzmann-Peled-Yannakakis / CVWY algorithm).
    ///
    /// Blue phase (outer DFS) explores states in post-order. Red phase (inner DFS)
    /// is launched at each accepting state only after all its descendants have been
    /// fully explored — the post-order invariant that guarantees correctness. The red
    /// set is shared globally across all seeds.
    ///
    /// - Parameter automaton: The Büchi automaton to check for emptiness.
    /// - Returns: `(prefix, cycle)` where prefix is the path from an initial state to the
    ///   seed (accepting state) and cycle is the loop from seed back to seed; `nil` if no
    ///   accepting run exists.
    /// - Throws: `LTLModelCheckerError` if an error occurs during processing.
    internal static func findAcceptingRun<StateType: Hashable, AlphabetSymbolType: Hashable>(
        in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) throws -> (prefix: [StateType], cycle: [StateType])? {
        // Build adjacency dict once: O(|transitions|) prep → O(1) lookup per call.
        var succ = [StateType: [StateType]]()
        for t in automaton.transitions {
            succ[t.sourceState, default: []].append(t.destinationState)
        }

        var blue = Set<StateType>()    // outer DFS visited
        var red = Set<StateType>()     // inner DFS visited, shared across all seeds
        var blueStack = [StateType]()  // current outer DFS path for prefix reconstruction

        // Red phase: seek a path from `current` back to `seed`.
        func dfsRed(
            seed: StateType,
            current: StateType,
            redPath: [StateType]
        ) -> (prefix: [StateType], cycle: [StateType])? {
            red.insert(current)
            for t in succ[current, default: []] {
                if t == seed {
                    // Drop the seed from prefix so that prefix.last → cycle.first is a real
                    // transition (contract: Counterexample.cycle doc, ModelCheckResult.swift L31-33).
                    return (prefix: Array(blueStack.dropLast()), cycle: redPath)
                }
                if !red.contains(t) {
                    if let result = dfsRed(seed: seed, current: t, redPath: redPath + [t]) {
                        return result
                    }
                }
            }
            return nil
        }

        // Blue phase: post-order traversal, launches red phase at accepting states.
        func dfsBlue(_ s: StateType) -> (prefix: [StateType], cycle: [StateType])? {
            blue.insert(s)
            blueStack.append(s)
            for t in succ[s, default: []] where !blue.contains(t) {
                if let result = dfsBlue(t) { return result }
            }
            // Post-order invariant: inner DFS only after all of s's descendants are explored.
            if automaton.acceptingStates.contains(s) {
                if let result = dfsRed(seed: s, current: s, redPath: [s]) {
                    return result
                }
            }
            blueStack.removeLast()
            return nil
        }

        for s0 in automaton.initialStates where !blue.contains(s0) {
            if let result = dfsBlue(s0) { return result }
        }
        return nil
    }
}
