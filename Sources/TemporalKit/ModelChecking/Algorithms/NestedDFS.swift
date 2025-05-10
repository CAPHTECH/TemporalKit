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
    
    // This helper function is no longer used after generalizing the inner DFS.
    // private static func getSuccessorsForInnerDfs<StateType: Hashable, AlphabetSymbolType: Hashable>(
    //     of state: StateType, 
    //     in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>, 
    //     onOuterPath: Set<StateType>
    // ) -> [StateType] {
    //     return automaton.transitions
    //         .filter { $0.sourceState == state && onOuterPath.contains($0.destinationState) }
    //         .map { $0.destinationState }
    // }

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
        
        print("[NestedDFS] Starting findAcceptingRun. Automaton: States=\(automaton.states.count), Initial=\(automaton.initialStates.count), Accepting=\(automaton.acceptingStates.count), Transitions=\(automaton.transitions.count)")
        if automaton.states.count < 20 { // Log details only for smaller automata
            print("[NestedDFS]   Initial States: \(automaton.initialStates)")
            print("[NestedDFS]   Accepting States: \(automaton.acceptingStates)")
            // Showing all transitions can be too verbose, first few if needed
            if automaton.transitions.count < 30 {
                 print("[NestedDFS]   Transitions (first \(automaton.transitions.prefix(5).count)): \(automaton.transitions.prefix(5).map { "(\($0.sourceState), \($0.symbol), \($0.destinationState))" }) ")
            }
        }

        var blueVisited = Set<StateType>() 
        var path: [StateType: StateType] = [:] 

        for initialState in automaton.initialStates {
            print("[NestedDFS] DFS1: Trying initial state: \(initialState)")
            if !blueVisited.contains(initialState) {
                var dfs1Stack: [(state: StateType, successorIndex: Int, successors: [StateType])] = []
                var currentDfs1PathForLogging: [StateType] = [] 
                
                blueVisited.insert(initialState)
                // print("[NestedDFS] DFS1: Add \(initialState) to blueVisited. Path: \(currentDfs1PathForLogging)")
                path[initialState] = initialState 
                let initialSuccessors = getSuccessors(of: initialState, in: automaton)
                dfs1Stack.append((initialState, 0, initialSuccessors))
                currentDfs1PathForLogging.append(initialState)
                print("[NestedDFS] DFS1: Push \(initialState). Successors: \(initialSuccessors.count). Stack: \(dfs1Stack.map { $0.state })")

                while !dfs1Stack.isEmpty {
                    let stackTopIndex = dfs1Stack.count - 1
                    let (currentState, successorIdx, successors) = dfs1Stack[stackTopIndex]
                    // print("[NestedDFS] DFS1: Top: \(currentState) (Path: \(currentDfs1PathForLogging)), SuccIdx: \(successorIdx)/\(successors.count)")

                    if successorIdx < successors.count {
                        let nextState = successors[successorIdx]
                        dfs1Stack[stackTopIndex].successorIndex += 1
                        // print("[NestedDFS] DFS1:   Try \(currentState) -> \(nextState)")

                        if !blueVisited.contains(nextState) {
                            blueVisited.insert(nextState)
                            // print("[NestedDFS] DFS1:   Add \(nextState) to blueVisited. Path: \(currentDfs1PathForLogging)")
                            path[nextState] = currentState
                            let nextSuccessors = getSuccessors(of: nextState, in: automaton)
                            dfs1Stack.append((nextState, 0, nextSuccessors))
                            currentDfs1PathForLogging.append(nextState)
                            print("[NestedDFS] DFS1:   Push \(nextState). Successors: \(nextSuccessors.count). Stack: \(dfs1Stack.map { $0.state })")
                        } else {
                            // print("[NestedDFS] DFS1:   \(nextState) already in blueVisited.")
                        }
                    } else {
                        let (s, _, _) = dfs1Stack.removeLast()
                        if !currentDfs1PathForLogging.isEmpty { currentDfs1PathForLogging.removeLast() }
                        // print("[NestedDFS] DFS1: Pop \(s). Stack: \(dfs1Stack.map { $0.state })")

                        if automaton.acceptingStates.contains(s) {
                            print("[NestedDFS] DFS1: <<< Accepting state \(s) found! Starting DFS2. >>>")
                            var redVisited = Set<StateType>()
                            var dfs2Stack: [(state: StateType, si: Int, ss: [StateType])] = [] 
                            var currentDfs2PathForLogging: [StateType] = [] 
                            
                            redVisited.insert(s)
                            let s_successors_for_dfs2 = getSuccessors(of: s, in: automaton)
                            dfs2Stack.append((s, 0, s_successors_for_dfs2))
                            currentDfs2PathForLogging.append(s)
                            print("[NestedDFS] DFS2: Push \(s) for accept_state \(s). Successors: \(s_successors_for_dfs2.count). Stack: \(dfs2Stack.map { $0.state })")
                            var cyclePath: [StateType: StateType] = [:]; cyclePath[s] = s

                            while !dfs2Stack.isEmpty {
                                let dfs2StackTopIndex = dfs2Stack.count - 1
                                let (currentRedState, redSuccessorIdx, redSuccessors) = dfs2Stack[dfs2StackTopIndex]
                                // print("[NestedDFS] DFS2: Top: \(currentRedState) (RedPath: \(currentDfs2PathForLogging)), SuccIdx: \(redSuccessorIdx)/\(redSuccessors.count) for accept_state \(s)")

                                if redSuccessorIdx < redSuccessors.count {
                                    let nextRedState = redSuccessors[redSuccessorIdx]
                                    dfs2Stack[dfs2StackTopIndex].si += 1
                                    // print("[NestedDFS] DFS2:   Try \(currentRedState) -> \(nextRedState) for accept_state \(s).")

                                    if nextRedState == s { 
                                        print("[NestedDFS] DFS2: <<< Cycle back to \(s) found from \(currentRedState)! >>>")
                                        var cycle: [StateType] = [s]
                                        var curr = currentRedState
                                        while curr != s {
                                            cycle.insert(curr, at: 0)
                                            guard let parentInCycle = cyclePath[curr] else {
                                                throw LTLModelCheckerError.internalProcessingError("Error reconstructing cycle path: parent not found for \(curr).")
                                            }
                                            curr = parentInCycle
                                        }
                                        // print("[NestedDFS] DFS2: Reconstructed cycle: \(cycle)")
                                        
                                        var prefix: [StateType] = [] 
                                        var currNode = s
                                        if path[currNode] != currNode { 
                                            var tempPrefix: [StateType] = []
                                            while path[currNode] != currNode { 
                                                guard let parentInPath = path[currNode] else {
                                                    throw LTLModelCheckerError.internalProcessingError("Error reconstructing prefix path: parent not found for \(currNode).")
                                                }
                                                tempPrefix.insert(parentInPath, at: 0)
                                                currNode = parentInPath
                                            }
                                            prefix = tempPrefix
                                        }
                                        prefix.append(s) 
                                        print("[NestedDFS] DFS2: Reconstructed prefix: \(prefix). Returning run (Prefix: \(prefix.count) states, Cycle: \(cycle.count) states).")
                                        return (prefix: prefix, cycle: cycle)
                                    }

                                    if !redVisited.contains(nextRedState) {
                                        redVisited.insert(nextRedState)
                                        cyclePath[nextRedState] = currentRedState
                                        let nextRedSuccessors = getSuccessors(of: nextRedState, in: automaton)
                                        dfs2Stack.append((nextRedState, 0, nextRedSuccessors))
                                        currentDfs2PathForLogging.append(nextRedState)
                                        print("[NestedDFS] DFS2:   Push \(nextRedState). Successors: \(nextRedSuccessors.count). Stack: \(dfs2Stack.map { $0.state })")
                                    } else {
                                        // print("[NestedDFS] DFS2:   \(nextRedState) already in redVisited for accept_state \(s).")
                                    }
                                } else {
                                    let (poppedRed, _, _) = dfs2Stack.removeLast()
                                    if !currentDfs2PathForLogging.isEmpty { currentDfs2PathForLogging.removeLast() }
                                    redVisited.remove(poppedRed) 
                                    // print("[NestedDFS] DFS2: Pop \(poppedRed). redVisited removed \(poppedRed). Stack: \(dfs2Stack.map { $0.state }) for accept_state \(s).")
                                }
                            }
                            print("[NestedDFS] DFS2: Finished for \(s), no cycle to \(s) found via this DFS2.")
                        }
                    }
                }
            }
        }
        print("[NestedDFS] findAcceptingRun: No accepting run found. Automaton potentially empty or no cycle through accepting state.")
        return nil 
    }
} 
