import Foundation

// NestedDFSAlgorithm needs to know about ProductState and BuchiAutomaton
// Assuming these are accessible (e.g., internal to the TemporalKit module)

internal enum NestedDFSAlgorithm {

    // Helper to get successors for a state in a Büchi automaton.
    // Kept generic for potential reuse, though currently specific to ProductState via LTLModelChecker's use.
    private static func getSuccessors<StateType: Hashable, AlphabetSymbolType: Hashable>(
        of state: StateType, 
        in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) -> [StateType] {
        return automaton.transitions.filter { $0.sourceState == state }.map { $0.destinationState }
    }
    
    // Helper to get successors for the inner DFS, constrained to states on the outer DFS path.
    private static func getSuccessorsForInnerDfs<StateType: Hashable, AlphabetSymbolType: Hashable>(
        of state: StateType, 
        in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>, 
        onOuterPath: Set<StateType>
    ) -> [StateType] {
        return automaton.transitions
            .filter { $0.sourceState == state && onOuterPath.contains($0.destinationState) }
            .map { $0.destinationState }
    }

    /// Finds an accepting run in a Büchi automaton using Nested DFS.
    /// An accepting run is a path from an initial state to an accepting state `u`,
    /// followed by a cycle from `u` back to `u` that also visits `u`.
    ///
    /// - Parameters:
    ///   - automaton: The Büchi automaton to check for emptiness.
    /// - Returns: A tuple `(prefix: [StateType], cycle: [StateType])` if an accepting run is found,
    ///            otherwise `nil`.
    /// - Throws: Potentially errors if issues arise (though this basic version does not define specific errors).
    internal static func findAcceptingRun<StateType: Hashable, AlphabetSymbolType: Hashable>(
        in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) throws -> (prefix: [StateType], cycle: [StateType])? {
        
        var blueVisited = Set<StateType>() // States visited by outer DFS (dfs1)
        var path: [StateType: StateType] = [:] // For reconstructing path: child -> parent

        for initialState in automaton.initialStates {
            if !blueVisited.contains(initialState) {
                var dfs1Stack: [(state: StateType, successorIndex: Int, successors: [StateType])] = []
                
                blueVisited.insert(initialState)
                path[initialState] = initialState 
                dfs1Stack.append((initialState, 0, getSuccessors(of: initialState, in: automaton)))

                while !dfs1Stack.isEmpty {
                    let stackTopIndex = dfs1Stack.count - 1
                    let (currentState, successorIdx, successors) = dfs1Stack[stackTopIndex]

                    if successorIdx < successors.count {
                        let nextState = successors[successorIdx]
                        dfs1Stack[stackTopIndex].successorIndex += 1

                        if !blueVisited.contains(nextState) {
                            blueVisited.insert(nextState)
                            path[nextState] = currentState
                            dfs1Stack.append((nextState, 0, getSuccessors(of: nextState, in: automaton)))
                        }
                    } else {
                        let s = dfs1Stack.removeLast().state

                        if automaton.acceptingStates.contains(s) {
                            var redVisited = Set<StateType>()
                            var dfs2Stack: [(state: StateType, si: Int, ss: [StateType])] = [] // (state, successorIndex, successors)
                            let onOuterPathStates = Set(dfs1Stack.map { $0.state }).union([s])
                            
                            redVisited.insert(s)
                            dfs2Stack.append((s, 0, getSuccessorsForInnerDfs(of: s, in: automaton, onOuterPath: onOuterPathStates)))
                            var cyclePath: [StateType: StateType] = [:]; cyclePath[s] = s

                            while !dfs2Stack.isEmpty {
                                let dfs2StackTopIndex = dfs2Stack.count - 1
                                let (currentRedState, redSuccessorIdx, redSuccessors) = dfs2Stack[dfs2StackTopIndex]

                                if redSuccessorIdx < redSuccessors.count {
                                    let nextRedState = redSuccessors[redSuccessorIdx]
                                    dfs2Stack[dfs2StackTopIndex].si += 1

                                    if nextRedState == s { // Cycle back to s found!
                                        var cycle: [StateType] = [s]
                                        var curr = currentRedState
                                        while curr != s {
                                            cycle.insert(curr, at: 0)
                                            guard let parentInCycle = cyclePath[curr] else {
                                                // Should not happen if logic is correct
                                                throw LTLModelCheckerError.internalProcessingError("Error reconstructing cycle path: parent not found.")
                                            }
                                            curr = parentInCycle
                                        }
                                        
                                        var prefix: [StateType] = [] // Path to s (exclusive of s, then add s)
                                        var currNode = s
                                        // Reconstruct path to s, but don't include s itself in this loop if path[s] == s means s is initial
                                        // If s is initial and also the cycle point, prefix is empty.
                                        if path[currNode] != currNode {
                                            var tempPrefix: [StateType] = []
                                            while path[currNode] != currNode { 
                                                guard let parentInPath = path[currNode] else {
                                                    throw LTLModelCheckerError.internalProcessingError("Error reconstructing prefix path: parent not found.")
                                                }
                                                tempPrefix.insert(parentInPath, at: 0)
                                                currNode = parentInPath
                                            }
                                            prefix = tempPrefix
                                        }
                                        prefix.append(s) // Add s to the end of the prefix
                                        
                                        return (prefix: prefix, cycle: cycle)
                                    }

                                    if !redVisited.contains(nextRedState) {
                                        redVisited.insert(nextRedState)
                                        cyclePath[nextRedState] = currentRedState
                                        dfs2Stack.append((nextRedState, 0, getSuccessorsForInnerDfs(of: nextRedState, in: automaton, onOuterPath: onOuterPathStates)))
                                    }
                                } else {
                                    dfs2Stack.removeLast()
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil // No accepting run found
    }
} 
