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
        
        // print("[NestedDFS] Starting findAcceptingRun. Automaton: States=\(automaton.states.count), Initial=\(automaton.initialStates.count), Accepting=\(automaton.acceptingStates.count), Transitions=\(automaton.transitions.count)")
        // if automaton.states.count < 20 { // Log details only for smaller automata
        //     print("[NestedDFS]   Initial States: \(automaton.initialStates)")
        //     print("[NestedDFS]   Accepting States: \(automaton.acceptingStates)")
        //     if automaton.transitions.count < 30 {
        //          print("[NestedDFS]   Transitions (first \(automaton.transitions.prefix(5).count)): \(automaton.transitions.prefix(5).map { "(\($0.sourceState), \($0.symbol), \($0.destinationState))" }) ")
        //     }
        // }

        var blueVisited = Set<StateType>() 
        var path: [StateType: StateType] = [:] 

        for initialState in automaton.initialStates {
            if !blueVisited.contains(initialState) {
                var dfs1Stack: [(state: StateType, successorIndex: Int, successors: [StateType])] = []
                
                blueVisited.insert(initialState)
                path[initialState] = initialState 
                dfs1Stack.append((initialState, 0, getSuccessors(of: initialState, in: automaton)))
                // print("[NestedDFS] DFS1: Initial push for \(initialState). Stack size: \(dfs1Stack.count)")

                while !dfs1Stack.isEmpty {
                    let stackTopIndex = dfs1Stack.count - 1
                    let (currentState, successorIdx, successors) = dfs1Stack[stackTopIndex]
                    // print("[NestedDFS] DFS1: Popped \(currentState) (idx \(successorIdx)/\(successors.count)) from stack. Stack size: \(dfs1Stack.count - 1)")

                    if successorIdx < successors.count {
                        let nextState = successors[successorIdx]
                        dfs1Stack[stackTopIndex].successorIndex += 1 
                        // print("[NestedDFS] DFS1:   Exploring successor \(nextState) of \(currentState). Updated successorIdx for \(currentState) to \(dfs1Stack[stackTopIndex].successorIndex).")

                        if !blueVisited.contains(nextState) {
                            blueVisited.insert(nextState)
                            path[nextState] = currentState
                            let nextSuccessors = getSuccessors(of: nextState, in: automaton)
                            dfs1Stack.append((nextState, 0, nextSuccessors))
                            // print("[NestedDFS] DFS1:   Push \(nextState). Successors: \(nextSuccessors.count). Stack: \(dfs1Stack.map { $0.state })")
                        } else {
                            // print("[NestedDFS] DFS1:   Successor \(nextState) already blueVisited.")
                        }
                    } else {
                        let s = dfs1Stack.removeLast().state
                        // print("[NestedDFS] DFS1: Finished exploring successors of \(s). Popping from stack. Stack size: \(dfs1Stack.count)")

                        if automaton.acceptingStates.contains(s) {
                            // print("[NestedDFS] DFS1: <<< Accepting state \(s) found! Starting DFS2. >>>")
                            var redVisited = Set<StateType>()
                            var dfs2Stack: [(state: StateType, si: Int, ss: [StateType])] = [] 
                            
                            redVisited.insert(s)
                            let s_successors_for_dfs2 = getSuccessors(of: s, in: automaton)
                            dfs2Stack.append((s, 0, s_successors_for_dfs2))
                            var cyclePath: [StateType: StateType] = [:]; cyclePath[s] = s
                            // print("[NestedDFS] DFS2: Push \(s) for accept_state \(s). Successors: \(s_successors_for_dfs2.count). Stack: \(dfs2Stack.map { $0.state })")

                            while !dfs2Stack.isEmpty {
                                let dfs2StackTopIndex = dfs2Stack.count - 1
                                let (currentRedState, redSuccessorIdx, redSuccessors) = dfs2Stack[dfs2StackTopIndex]
                                // print("[NestedDFS] DFS2: Popped \(currentRedState) (idx \(redSuccessorIdx)/\(redSuccessors.count)) from stack. DFS2 Stack: \(dfs2Stack.map { $0.state })")

                                if redSuccessorIdx < redSuccessors.count {
                                    let nextRedState = redSuccessors[redSuccessorIdx]
                                    dfs2Stack[dfs2StackTopIndex].si += 1
                                    // print("[NestedDFS] DFS2:   Exploring successor \(nextRedState) of \(currentRedState). Updated idx for \(currentRedState) to \(dfs2Stack[dfs2StackTopIndex].si).")

                                    if nextRedState == s { 
                                        // print("[NestedDFS] DFS2: <<< Cycle back to \(s) found from \(currentRedState)! >>>")
                                        var cycle: [StateType] = [s]
                                        var curr = currentRedState
                                        while curr != s {
                                            cycle.insert(curr, at: 0)
                                            guard let parentInCycle = cyclePath[curr] else {
                                                throw LTLModelCheckerError.internalProcessingError("Error reconstructing cycle path: parent not found.")
                                            }
                                            curr = parentInCycle
                                        }
                                        
                                        var prefix: [StateType] = [] 
                                        var currNode = s
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
                                        prefix.append(s) 
                                        // print("[NestedDFS] DFS2: Reconstructed prefix: \(prefix). Returning run (Prefix: \(prefix.count) states, Cycle: \(cycle.count) states).")
                                        return (prefix: prefix, cycle: cycle)
                                    }

                                    if !redVisited.contains(nextRedState) {
                                        redVisited.insert(nextRedState)
                                        cyclePath[nextRedState] = currentRedState
                                        let nextRedSuccessors = getSuccessors(of: nextRedState, in: automaton)
                                        dfs2Stack.append((nextRedState, 0, nextRedSuccessors))
                                        // print("[NestedDFS] DFS2:   Push \(nextRedState). Successors: \(nextRedSuccessors.count). Stack: \(dfs2Stack.map { $0.state })")
                                    } else {
                                        // print("[NestedDFS] DFS2:   Successor \(nextRedState) already redVisited or part of current DFS2 path for this accept state.")
                                    }
                                } else {
                                    // print("[NestedDFS] DFS2: Finished exploring successors of \(currentRedState). Popping.")
                                    let poppedRed = dfs2Stack.removeLast().state
                                    redVisited.remove(poppedRed) // Key correction: allow revisiting via other paths in DFS2
                                }
                            }
                            // print("[NestedDFS] DFS2: Finished for \(s), no cycle to \(s) found via this DFS2.")
                        }
                    }
                }
            }
        }
        // print("[NestedDFS] findAcceptingRun: No accepting run found. Automaton potentially empty or no cycle through accepting state.")
        return nil 
    }
} 
