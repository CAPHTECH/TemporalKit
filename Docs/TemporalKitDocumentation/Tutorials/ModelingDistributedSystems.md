# Modeling Distributed Systems

This tutorial teaches you how to model and verify distributed systems using TemporalKit. Distributed systems involve multiple nodes cooperating together, and verifying properties like consistency and fault tolerance is crucial.

## Objectives

By the end of this tutorial, you will be able to:

- Model distributed systems as Kripke structures
- Verify distributed system properties such as consistency, fault tolerance, and leader election
- Incorporate realistic behaviors like communication delays and node failures into your models
- Verify the correctness of distributed algorithms

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts
- Completion of the [Concurrent System Verification](./ConcurrentSystemVerification.md) tutorial

## Step 1: Basic Distributed System Model

First, let's create a model for a simple distributed system with multiple nodes sharing values.

```swift
import TemporalKit

// Structure representing a node's state
struct NodeState: Hashable, CustomStringConvertible {
    let id: Int
    let value: Int
    let isActive: Bool
    
    var description: String {
        return "Node(\(id): value=\(value), \(isActive ? "active" : "inactive"))"
    }
}

// State of the entire distributed system
struct DistributedSystemState: Hashable, CustomStringConvertible {
    let nodes: [NodeState]
    
    var description: String {
        return "System(\(nodes.map { $0.description }.joined(separator: ", ")))"
    }
}
```

## Step 2: Creating a Kripke Structure for Distributed Systems

Let's model the distributed system as a Kripke structure.

```swift
// Kripke structure for a simple distributed system
struct SimpleDistributedSystem: KripkeStructure {
    typealias State = DistributedSystemState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let nodeCount: Int
    let initialStates: Set<State>
    
    init(nodeCount: Int = 3) {
        self.nodeCount = nodeCount
        
        // Initial state: all nodes are active with value 0
        let initialNodes = (0..<nodeCount).map { id in
            NodeState(id: id, value: 0, isActive: true)
        }
        
        self.initialStates = [DistributedSystemState(nodes: initialNodes)]
    }
    
    var allStates: Set<State> {
        // In real applications, the state space would be enormous,
        // so we avoid computing it explicitly and generate states on demand
        fatalError("State space is too large to compute explicitly")
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Consider state changes for each node
        for nodeIndex in 0..<state.nodes.count {
            // 1. Possibility of changing the node's value
            if state.nodes[nodeIndex].isActive {
                for newValue in 0...2 {  // Limit the range of values
                    var newNodes = state.nodes
                    newNodes[nodeIndex] = NodeState(
                        id: state.nodes[nodeIndex].id,
                        value: newValue,
                        isActive: true
                    )
                    nextStates.insert(DistributedSystemState(nodes: newNodes))
                }
            }
            
            // 2. Node failure (becoming inactive)
            var newNodes = state.nodes
            newNodes[nodeIndex] = NodeState(
                id: state.nodes[nodeIndex].id,
                value: state.nodes[nodeIndex].value,
                isActive: false
            )
            nextStates.insert(DistributedSystemState(nodes: newNodes))
            
            // 3. Node recovery (becoming active again)
            if !state.nodes[nodeIndex].isActive {
                var newNodes = state.nodes
                newNodes[nodeIndex] = NodeState(
                    id: state.nodes[nodeIndex].id,
                    value: state.nodes[nodeIndex].value,
                    isActive: true
                )
                nextStates.insert(DistributedSystemState(nodes: newNodes))
            }
            
            // 4. Value propagation (copying a value from one node to another)
            for otherNodeIndex in 0..<state.nodes.count where otherNodeIndex != nodeIndex {
                if state.nodes[nodeIndex].isActive && state.nodes[otherNodeIndex].isActive {
                    var newNodes = state.nodes
                    newNodes[otherNodeIndex] = NodeState(
                        id: state.nodes[otherNodeIndex].id,
                        value: state.nodes[nodeIndex].value,
                        isActive: true
                    )
                    nextStates.insert(DistributedSystemState(nodes: newNodes))
                }
            }
        }
        
        // Include the current state in the successor states
        nextStates.insert(state)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // System-wide propositions
        if state.nodes.allSatisfy({ $0.isActive }) {
            trueProps.insert("allNodesActive")
        }
        
        // Consistency-related propositions
        let allSameValue = state.nodes.filter { $0.isActive }.allSatisfy { node in
            node.value == state.nodes.first { $0.isActive }?.value
        }
        
        if allSameValue && state.nodes.contains(where: { $0.isActive }) {
            trueProps.insert("consistentValues")
        }
        
        // Node-specific propositions
        for (index, node) in state.nodes.enumerated() {
            if node.isActive {
                trueProps.insert("node\(index)Active")
            } else {
                trueProps.insert("node\(index)Inactive")
            }
            
            // Value-related propositions
            trueProps.insert("node\(index)Value\(node.value)")
            
            // Relationships between nodes
            for (otherIndex, otherNode) in state.nodes.enumerated() where otherIndex != index {
                if node.isActive && otherNode.isActive && node.value == otherNode.value {
                    trueProps.insert("node\(index)MatchesNode\(otherIndex)")
                }
            }
        }
        
        return trueProps
    }
}
```

## Step 3: Defining Propositions

Let's define propositions related to distributed system states.

```swift
// System-wide propositions
let allNodesActive = TemporalKit.makeProposition(
    id: "allNodesActive",
    name: "All nodes are active",
    evaluate: { (state: DistributedSystemState) -> Bool in
        state.nodes.allSatisfy { $0.isActive }
    }
)

let consistentValues = TemporalKit.makeProposition(
    id: "consistentValues",
    name: "Values are consistent across active nodes",
    evaluate: { (state: DistributedSystemState) -> Bool in
        let activeNodes = state.nodes.filter { $0.isActive }
        guard !activeNodes.isEmpty else { return true }
        let firstValue = activeNodes[0].value
        return activeNodes.allSatisfy { $0.value == firstValue }
    }
)

// Propositions for specific nodes (examples for nodes 0 and 1)
let node0Active = TemporalKit.makeProposition(
    id: "node0Active",
    name: "Node 0 is active",
    evaluate: { (state: DistributedSystemState) -> Bool in
        guard state.nodes.indices.contains(0) else { return false }
        return state.nodes[0].isActive
    }
)

let node1Active = TemporalKit.makeProposition(
    id: "node1Active",
    name: "Node 1 is active",
    evaluate: { (state: DistributedSystemState) -> Bool in
        guard state.nodes.indices.contains(1) else { return false }
        return state.nodes[1].isActive
    }
)

// Value-related propositions
let node0Value1 = TemporalKit.makeProposition(
    id: "node0Value1",
    name: "Node 0 has value 1",
    evaluate: { (state: DistributedSystemState) -> Bool in
        guard state.nodes.indices.contains(0) else { return false }
        return state.nodes[0].value == 1
    }
)

// Relationship propositions
let node0MatchesNode1 = TemporalKit.makeProposition(
    id: "node0MatchesNode1",
    name: "Node 0 and Node 1 have matching values",
    evaluate: { (state: DistributedSystemState) -> Bool in
        guard state.nodes.indices.contains(0), state.nodes.indices.contains(1) else { return false }
        return state.nodes[0].isActive && state.nodes[1].isActive && state.nodes[0].value == state.nodes[1].value
    }
)
```

## Step 4: Defining Distributed System Properties

Let's define important distributed system properties as LTL formulas.

```swift
// Type aliases for readability
typealias DistProp = ClosureTemporalProposition<DistributedSystemState, Bool>
typealias DistLTL = LTLFormula<DistProp>

// Property 1: "Eventual consistency - regardless of state changes, the system eventually reaches a consistent state"
let eventualConsistency = DistLTL.globally(
    .eventually(.atomic(consistentValues))
)

// Property 2: "Fault tolerance - even if some nodes fail, the remaining nodes maintain consistency"
let faultTolerance = DistLTL.globally(
    .implies(
        .not(.atomic(allNodesActive)),
        .eventually(.atomic(consistentValues))
    )
)

// Property 3: "Value propagation - when Node 0's value changes, it eventually propagates to Node 1"
let valuePropagation = DistLTL.globally(
    .implies(
        .and(
            .atomic(node0Value1),
            .atomic(node1Active)
        ),
        .eventually(.atomic(node0MatchesNode1))
    )
)

// Property 4: "Value preservation during failures - an active node's value is preserved during failures"
let valuePreservation = DistLTL.globally(
    .implies(
        .and(
            .atomic(node0Value1),
            .next(.atomic(node0Active))
        ),
        .next(.atomic(node0Value1))
    )
)

// Example using DSL notation
import TemporalKit.DSL

let dslEventualConsistency = G(F(.atomic(consistentValues)))
```

## Step 5: Running Model Checking

Let's verify our distributed system against the defined properties.

```swift
let distributedSystem = SimpleDistributedSystem(nodeCount: 3)
let modelChecker = LTLModelChecker<SimpleDistributedSystem>()

do {
    // Verify each property
    let result1 = try modelChecker.check(formula: eventualConsistency, model: distributedSystem)
    let result2 = try modelChecker.check(formula: faultTolerance, model: distributedSystem)
    let result3 = try modelChecker.check(formula: valuePropagation, model: distributedSystem)
    let result4 = try modelChecker.check(formula: valuePreservation, model: distributedSystem)
    
    // Output results
    print("Verification Results:")
    print("1. Eventual consistency: \(result1.holds ? "holds" : "does not hold")")
    print("2. Fault tolerance: \(result2.holds ? "holds" : "does not hold")")
    print("3. Value propagation: \(result3.holds ? "holds" : "does not hold")")
    print("4. Value preservation: \(result4.holds ? "holds" : "does not hold")")
    
    // Display counterexample if needed
    if case .fails(let counterexample) = result1 {
        print("\nCounterexample for Property 1:")
        print("  Prefix: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("  Cycle: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
    
} catch {
    print("Verification error: \(error)")
}
```

## Step 6: Modeling a Leader Election Protocol

Let's model a leader election protocol, one of the important algorithms in distributed systems.

```swift
// Node roles
enum NodeRole: Hashable, CustomStringConvertible {
    case unknown
    case candidate
    case follower
    case leader
    
    var description: String {
        switch self {
        case .unknown: return "unknown"
        case .candidate: return "candidate"
        case .follower: return "follower"
        case .leader: return "leader"
        }
    }
}

// Node state for leader election protocol
struct ElectionNodeState: Hashable, CustomStringConvertible {
    let id: Int
    let role: NodeRole
    let term: Int  // Election term
    let isActive: Bool
    
    var description: String {
        return "Node(\(id): role=\(role), term=\(term), \(isActive ? "active" : "inactive"))"
    }
}

// State of the entire leader election system
struct LeaderElectionSystemState: Hashable, CustomStringConvertible {
    let nodes: [ElectionNodeState]
    let currentTerm: Int  // Current term for the entire system
    
    var description: String {
        return "Election(term=\(currentTerm), nodes=\(nodes.map { $0.description }.joined(separator: ", ")))"
    }
}

// Kripke structure for leader election protocol
struct LeaderElectionSystem: KripkeStructure {
    typealias State = LeaderElectionSystemState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let nodeCount: Int
    let initialStates: Set<State>
    
    init(nodeCount: Int = 3) {
        self.nodeCount = nodeCount
        
        // Initial state: all nodes are active with unknown role, term is 0
        let initialNodes = (0..<nodeCount).map { id in
            ElectionNodeState(id: id, role: .unknown, term: 0, isActive: true)
        }
        
        self.initialStates = [LeaderElectionSystemState(nodes: initialNodes, currentTerm: 0)]
    }
    
    var allStates: Set<State> {
        // State space is large, so we omit explicit computation
        fatalError("State space is too large to compute explicitly")
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Model state transitions for the leader election protocol
        
        // 1. Possibility of starting a new election term
        let newTerm = state.currentTerm + 1
        for candidateIndex in 0..<state.nodes.count {
            if state.nodes[candidateIndex].isActive {
                var newNodes = state.nodes
                
                // Set the election candidate
                newNodes[candidateIndex] = ElectionNodeState(
                    id: newNodes[candidateIndex].id,
                    role: .candidate,
                    term: newTerm,
                    isActive: true
                )
                
                // Other nodes may become followers
                for i in 0..<newNodes.count where i != candidateIndex {
                    if newNodes[i].isActive {
                        newNodes[i] = ElectionNodeState(
                            id: newNodes[i].id,
                            role: .follower,
                            term: newTerm,
                            isActive: true
                        )
                    }
                }
                
                nextStates.insert(LeaderElectionSystemState(nodes: newNodes, currentTerm: newTerm))
            }
        }
        
        // 2. Possibility of a candidate becoming a leader
        if let candidateIndex = state.nodes.firstIndex(where: { $0.role == .candidate && $0.isActive }) {
            var newNodes = state.nodes
            
            // Set the candidate as leader
            newNodes[candidateIndex] = ElectionNodeState(
                id: newNodes[candidateIndex].id,
                role: .leader,
                term: state.currentTerm,
                isActive: true
            )
            
            nextStates.insert(LeaderElectionSystemState(nodes: newNodes, currentTerm: state.currentTerm))
        }
        
        // 3. Node failures and recoveries
        for nodeIndex in 0..<state.nodes.count {
            // Failure
            if state.nodes[nodeIndex].isActive {
                var newNodes = state.nodes
                newNodes[nodeIndex] = ElectionNodeState(
                    id: newNodes[nodeIndex].id,
                    role: newNodes[nodeIndex].role,
                    term: newNodes[nodeIndex].term,
                    isActive: false
                )
                nextStates.insert(LeaderElectionSystemState(nodes: newNodes, currentTerm: state.currentTerm))
            }
            
            // Recovery
            if !state.nodes[nodeIndex].isActive {
                var newNodes = state.nodes
                newNodes[nodeIndex] = ElectionNodeState(
                    id: newNodes[nodeIndex].id,
                    role: .unknown,  // Role is unknown upon recovery
                    term: state.currentTerm,
                    isActive: true
                )
                nextStates.insert(LeaderElectionSystemState(nodes: newNodes, currentTerm: state.currentTerm))
            }
        }
        
        // Include the current state in the successor states
        nextStates.insert(state)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // Leader election propositions
        let hasLeader = state.nodes.contains { $0.role == .leader && $0.isActive }
        if hasLeader {
            trueProps.insert("hasLeader")
        }
        
        let hasMultipleLeaders = state.nodes.filter { $0.role == .leader && $0.isActive }.count > 1
        if hasMultipleLeaders {
            trueProps.insert("hasMultipleLeaders")
        }
        
        // Node-specific propositions
        for (index, node) in state.nodes.enumerated() {
            if node.isActive {
                trueProps.insert("node\(index)Active")
                
                if node.role == .leader {
                    trueProps.insert("node\(index)IsLeader")
                } else if node.role == .follower {
                    trueProps.insert("node\(index)IsFollower")
                } else if node.role == .candidate {
                    trueProps.insert("node\(index)IsCandidate")
                }
            } else {
                trueProps.insert("node\(index)Inactive")
            }
        }
        
        return trueProps
    }
}
```

## Step 7: Verifying Leader Election Properties

Let's verify the properties of our leader election protocol.

```swift
// Leader election propositions
let hasLeader = TemporalKit.makeProposition(
    id: "hasLeader",
    name: "A leader exists",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in
        state.nodes.contains { $0.role == .leader && $0.isActive }
    }
)

let hasMultipleLeaders = TemporalKit.makeProposition(
    id: "hasMultipleLeaders",
    name: "Multiple leaders exist",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in
        state.nodes.filter { $0.role == .leader && $0.isActive }.count > 1
    }
)

let node0IsLeader = TemporalKit.makeProposition(
    id: "node0IsLeader",
    name: "Node 0 is the leader",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in
        guard state.nodes.indices.contains(0) else { return false }
        return state.nodes[0].role == .leader && state.nodes[0].isActive
    }
)

// Define leader election properties
typealias ElectionProp = ClosureTemporalProposition<LeaderElectionSystemState, Bool>
typealias ElectionLTL = LTLFormula<ElectionProp>

// Property 1: "Eventually a leader is elected"
let eventuallyLeader = ElectionLTL.eventually(.atomic(hasLeader))

// Property 2: "Multiple leaders never exist (safety)"
let singleLeader = ElectionLTL.globally(.not(.atomic(hasMultipleLeaders)))

// Property 3: "Once a leader is elected, it remains the leader (stability)"
let stableLeadership = ElectionLTL.implies(
    .atomic(hasLeader),
    .globally(.atomic(hasLeader))
)

// Property 4: "Any node can become a leader (fairness)"
let fairLeaderElection = ElectionLTL.eventually(.atomic(node0IsLeader))

// Run verification for the leader election protocol
let electionSystem = LeaderElectionSystem(nodeCount: 3)
let electionModelChecker = LTLModelChecker<LeaderElectionSystem>()

do {
    // Verify each property
    let electionResult1 = try electionModelChecker.check(formula: eventuallyLeader, model: electionSystem)
    let electionResult2 = try electionModelChecker.check(formula: singleLeader, model: electionSystem)
    let electionResult3 = try electionModelChecker.check(formula: stableLeadership, model: electionSystem)
    let electionResult4 = try electionModelChecker.check(formula: fairLeaderElection, model: electionSystem)
    
    // Output results
    print("\nLeader Election Verification Results:")
    print("1. Eventually elect leader: \(electionResult1.holds ? "holds" : "does not hold")")
    print("2. Single leader guarantee: \(electionResult2.holds ? "holds" : "does not hold")")
    print("3. Leadership stability: \(electionResult3.holds ? "holds" : "does not hold")")
    print("4. Fair leader election: \(electionResult4.holds ? "holds" : "does not hold")")
    
} catch {
    print("Verification error: \(error)")
}
```

## Summary

In this tutorial, you have learned how to model and verify distributed systems using TemporalKit. We focused on:

1. Modeling simple distributed systems and leader election protocols as Kripke structures
2. Expressing important distributed system properties like consistency, fault tolerance, and leader election as LTL formulas
3. Incorporating realistic behaviors like communication delays and node failures into our models
4. Verifying the safety and liveness properties of distributed algorithms

Formal verification of distributed systems allows you to detect errors in complex distributed algorithms and inconsistencies in shared state early, leading to more robust systems.

## Next Steps

- Explore [Optimizing Performance](./OptimizingPerformance.md) to learn how to efficiently verify larger distributed systems
- Learn about [Verifying Reactive Systems](./VerifyingReactiveSystems.md) to verify event-driven distributed systems 
