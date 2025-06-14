import Foundation

// MARK: - NestedDFS Algorithm for Büchi Automaton Emptiness Checking

internal enum NestedDFSAlgorithm {

    // Helper to get successors for a state in a Büchi automaton.
    private static func getSuccessors<StateType: Hashable, AlphabetSymbolType: Hashable>(
        of state: StateType,
        in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) -> [StateType] {
        automaton.transitions.filter { $0.sourceState == state }.map { $0.destinationState }
    }

    /// Finds an accepting run in a Büchi automaton using an improved Nested DFS algorithm.
    /// An accepting run consists of a path from an initial state to an accepting state,
    /// followed by a cycle containing at least one accepting state.
    ///
    /// - Parameters:
    ///   - automaton: The Büchi automaton to check for emptiness.
    /// - Returns: A tuple `(prefix: [StateType], cycle: [StateType])` if an accepting run is found,
    ///            otherwise `nil`.
    /// - Throws: `LTLModelCheckerError` if an error occurs during processing.
    internal static func findAcceptingRun<StateType: Hashable, AlphabetSymbolType: Hashable>(
        in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) throws -> (prefix: [StateType], cycle: [StateType])? {
        // Algorithm state
        var visited = Set<StateType>() // States visited in outer DFS
        var stack = [StateType]() // Current outer DFS stack
        var inStack = Set<StateType>() // Set of states in the current DFS stack
        var onPath = [StateType: StateType]() // Path reconstruction: key -> parent state

        // Outer DFS function - searches for accepting states
        func dfs1(_ state: StateType) throws -> (prefix: [StateType], cycle: [StateType])? {
            visited.insert(state)
            stack.append(state)
            inStack.insert(state)

            // If we found an accepting state, start inner DFS to search for a cycle
            if automaton.acceptingStates.contains(state) {
                var cycleVisited = Set<StateType>() // States visited during inner DFS
                var cyclePath = [StateType]() // Path that forms the cycle

                if try dfs2(state, state, &cycleVisited, &cyclePath) {
                    // Reconstruct prefix path from initial state to accepting state
                    var prefix = [state]
                    var current = state
                    while let prev = onPath[current], prev != current {
                        prefix.insert(prev, at: 0)
                        current = prev
                    }

                    return (prefix: prefix, cycle: cyclePath)
                }
            }

            // Continue outer DFS with successors
            let successors = getSuccessors(of: state, in: automaton)
            for nextState in successors {
                if !visited.contains(nextState) {
                    onPath[nextState] = state // Mark this path for reconstruction later
                    if let result = try dfs1(nextState) {
                        return result
                    }
                }
                // Direct cycle detection optimization: Check for cycles to accepting states in stack
                else if inStack.contains(nextState) && automaton.acceptingStates.contains(nextState) {
                    // Found a path back to an accepting state in our stack - reconstruct cycle
                    var cycle = [nextState]
                    var current = state

                    // Reconstruct cycle path
                    while current != nextState {
                        cycle.insert(current, at: 0)
                        if let prev = onPath[current] {
                            current = prev
                        } else {
                            break // Safety check
                        }
                    }

                    // Ensure this cycle contains at least one accepting state
                    if !automaton.acceptingStates.isDisjoint(with: Set(cycle)) {
                        // Build the prefix to the accepting state
                        var prefix = [nextState]
                        current = nextState
                        while let prev = onPath[current], prev != current && !cycle.contains(prev) {
                            prefix.insert(prev, at: 0)
                            current = prev
                        }

                        return (prefix: prefix, cycle: cycle)
                    }
                }
            }

            stack.removeLast()
            inStack.remove(state)
            return nil
        }

        // Inner DFS function - searches for a cycle containing accepting states
        func dfs2(_ start: StateType, _ current: StateType, _ visited: inout Set<StateType>, _ cyclePath: inout [StateType]) throws -> Bool {
            visited.insert(current)
            cyclePath.append(current)

            let successors = getSuccessors(of: current, in: automaton)
            for nextState in successors {
                // Found a direct cycle back to the accepting state - successfully found an accepting cycle
                if nextState == start {
                    cyclePath.append(nextState) // Close the cycle
                    return true
                }

                // Continue inner DFS if we haven't visited this state yet
                if !visited.contains(nextState) {
                    if try dfs2(start, nextState, &visited, &cyclePath) {
                        return true
                    }
                }
                // Check for an alternative cycle through states we've already seen
                else if cyclePath.contains(nextState) {
                    // Found a state already in the cycle path - extract the cycle
                    if let index = cyclePath.firstIndex(of: nextState) {
                        // Extract the cycle part from the current path 
                        let potentialCycle = Array(cyclePath[index...])

                        // Verify this cycle contains at least one accepting state
                        if automaton.acceptingStates.contains(where: { potentialCycle.contains($0) }) {
                            cyclePath = potentialCycle
                            return true
                        }
                    }
                }
            }

            cyclePath.removeLast() // Backtrack
            return false
        }

        // Try main algorithm from each initial state
        for initialState in automaton.initialStates {
            if !visited.contains(initialState) {
                onPath[initialState] = initialState // Mark initial state as its own parent
                if let result = try dfs1(initialState) {
                    return result
                }
            }
        }

        // Special case checks for edge cases

        // Case 1: Initial state is accepting and has only self-loops or no outgoing transitions
        for initState in automaton.initialStates {
            if automaton.acceptingStates.contains(initState) {
                let successors = getSuccessors(of: initState, in: automaton)
                if successors.isEmpty || successors.allSatisfy({ $0 == initState }) {
                    return (prefix: [], cycle: [initState])
                }
            }
        }

        // Case 2: More thorough search using strongly connected components
        if let result = try thoroughAcceptingCycleSearch(in: automaton) {
            return result
        }

        // No accepting run found
        return nil
    }

    // Thorough search for accepting cycles using SCC identification and analysis
    private static func thoroughAcceptingCycleSearch<StateType: Hashable, AlphabetSymbolType: Hashable>(
        in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) throws -> (prefix: [StateType], cycle: [StateType])? {
        // Compute all strongly connected components in the automaton
        let sccs = computeSCCs(automaton: automaton)

        // Filter SCCs that contain at least one accepting state
        let acceptingSccs = sccs.filter { scc in
            scc.contains { automaton.acceptingStates.contains($0) }
        }

        for scc in acceptingSccs {
            // Find an accepting state in this SCC
            guard let acceptingState = scc.first(where: { automaton.acceptingStates.contains($0) }) else {
                continue
            }

            // Find a path from an initial state to this accepting SCC
            guard let initialState = automaton.initialStates.first else { continue }

            if let prefix = try? findPath(from: initialState, to: acceptingState, in: automaton) {
                // Find a cycle within this SCC that includes the accepting state
                if let cycle = try findCycleInSCC(from: acceptingState, scc: scc, automaton: automaton) {
                    return (prefix: prefix, cycle: cycle)
                }
            }
        }

        return nil
    }

    // Helper to find a cycle within a strongly connected component (SCC)
    private static func findCycleInSCC<StateType: Hashable, AlphabetSymbolType: Hashable>(
        from start: StateType,
        scc: Set<StateType>,
        automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) throws -> [StateType]? {
        var visited = Set<StateType>()
        var stack = [(state: start, path: [start])]

        while !stack.isEmpty {
            let (current, path) = stack.removeLast()

            let successors = getSuccessors(of: current, in: automaton).filter { scc.contains($0) }
            for successor in successors {
                // Found a cycle back to the starting state
                if successor == start {
                    return path + [start]
                }

                // Continue searching if we haven't visited this state yet
                if !visited.contains(successor) {
                    visited.insert(successor)
                    stack.append((successor, path + [successor]))
                }
            }
        }

        return nil
    }

    // Compute strongly connected components using Tarjan's algorithm
    private static func computeSCCs<StateType: Hashable, AlphabetSymbolType: Hashable>(
        automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) -> [Set<StateType>] {
        var sccs = [Set<StateType>]()
        var index = 0
        var indices = [StateType: Int]()
        var lowlinks = [StateType: Int]()
        var onStack = Set<StateType>()
        var stack = [StateType]()

        func strongconnect(_ v: StateType) {
            indices[v] = index
            lowlinks[v] = index
            index += 1
            stack.append(v)
            onStack.insert(v)

            for w in getSuccessors(of: v, in: automaton) {
                if indices[w] == nil {
                    strongconnect(w)
                    lowlinks[v] = min(lowlinks[v]!, lowlinks[w]!)
                } else if onStack.contains(w) {
                    lowlinks[v] = min(lowlinks[v]!, indices[w]!)
                }
            }

            if lowlinks[v] == indices[v] {
                var scc = Set<StateType>()
                var w: StateType

                repeat {
                    w = stack.removeLast()
                    onStack.remove(w)
                    scc.insert(w)
                } while w != v

                if !scc.isEmpty {
                    sccs.append(scc)
                }
            }
        }

        for v in automaton.states {
            if indices[v] == nil {
                strongconnect(v)
            }
        }

        return sccs
    }

    // Helper function to find a path between two states using BFS
    private static func findPath<StateType: Hashable, AlphabetSymbolType: Hashable>(
        from start: StateType,
        to end: StateType,
        in automaton: BuchiAutomaton<StateType, AlphabetSymbolType>
    ) throws -> [StateType] {
        if start == end { return [start] }

        var visited = Set<StateType>()
        var queue = [(state: start, path: [start])]

        while !queue.isEmpty {
            let (current, path) = queue.removeFirst()
            if visited.contains(current) { continue }
            visited.insert(current)

            let successors = getSuccessors(of: current, in: automaton)
            for successor in successors {
                if successor == end {
                    return path + [successor]
                }
                if !visited.contains(successor) {
                    queue.append((successor, path + [successor]))
                }
            }
        }

        throw LTLModelCheckerError.internalProcessingError("No path found between states in automaton")
    }
}
