# Concurrent System Verification

This tutorial teaches you how to verify concurrent systems using TemporalKit. In systems where multiple processes or threads operate simultaneously, issues like race conditions and deadlocks can occur, and formal verification can help detect them.

## Objectives

By the end of this tutorial, you will be able to:

- Model concurrent systems as Kripke structures
- Express important concurrency properties using temporal logic formulas
- Detect concurrency issues such as race conditions and deadlocks
- Verify systems with non-deterministic behavior

## Prerequisites

- Swift 5.9 or later
- Xcode 15.0 or later
- Understanding of basic TemporalKit concepts
- Completion of the [State Machine Verification](./StateMachineVerification.md) tutorial

## Step 1: Modeling a Simple Concurrent System

First, let's model a simple concurrent system: two processes sharing a resource.

```swift
import TemporalKit

// Process states
enum ProcessState: String, Hashable, CustomStringConvertible {
    case idle        // Idle state
    case wanting     // Requesting resource
    case waiting     // Waiting for resource
    case critical    // In critical section
    case releasing   // Releasing resource
    
    var description: String {
        return rawValue
    }
}

// Shared resource state
enum ResourceState: String, Hashable, CustomStringConvertible {
    case free        // Available
    case taken(by: Int)  // In use by process ID
    
    var description: String {
        switch self {
        case .free: return "free"
        case .taken(let id): return "taken(by: \(id))"
        }
    }
    
    // For Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .free:
            hasher.combine(0)
        case .taken(let id):
            hasher.combine(1)
            hasher.combine(id)
        }
    }
    
    // For Equatable conformance
    static func == (lhs: ResourceState, rhs: ResourceState) -> Bool {
        switch (lhs, rhs) {
        case (.free, .free): return true
        case let (.taken(id1), .taken(id2)): return id1 == id2
        default: return false
        }
    }
}

// Concurrent system state
struct ConcurrentSystemState: Hashable, CustomStringConvertible {
    let process1: ProcessState
    let process2: ProcessState
    let resource: ResourceState
    
    var description: String {
        return "P1: \(process1), P2: \(process2), Resource: \(resource)"
    }
}
```

## Step 2: Implementing a Kripke Structure for the Concurrent System

Next, let's implement a Kripke structure that represents the state transitions of our concurrent system.

```swift
// Concurrent system Kripke structure
struct ConcurrentSystem: KripkeStructure {
    typealias State = ConcurrentSystemState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init() {
        // Initial state: both processes idle, resource free
        let initialState = ConcurrentSystemState(
            process1: .idle,
            process2: .idle,
            resource: .free
        )
        
        self.initialStates = [initialState]
        
        // Generate all possible state combinations
        // In a real system, you would consider only reachable states to reduce state space
        var states = Set<State>()
        
        for p1 in [ProcessState.idle, .wanting, .waiting, .critical, .releasing] {
            for p2 in [ProcessState.idle, .wanting, .waiting, .critical, .releasing] {
                // Resource state has constraints
                if p1 == .critical && p2 == .critical {
                    // Both processes cannot be in critical section simultaneously (mutual exclusion)
                    continue
                }
                
                // Determine resource state
                if p1 == .critical {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .taken(by: 1)))
                } else if p2 == .critical {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .taken(by: 2)))
                } else {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .free))
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Apply process 1 state transitions
        for nextP1 in nextProcessStates(for: state.process1, processId: 1, resourceState: state.resource) {
            // Process 2 state remains unchanged, resource state may be updated
            let nextResourceState = updatedResourceState(
                from: state.resource,
                process: state.process1, 
                nextProcess: nextP1, 
                processId: 1
            )
            
            nextStates.insert(ConcurrentSystemState(
                process1: nextP1,
                process2: state.process2,
                resource: nextResourceState
            ))
        }
        
        // Apply process 2 state transitions
        for nextP2 in nextProcessStates(for: state.process2, processId: 2, resourceState: state.resource) {
            // Process 1 state remains unchanged, resource state may be updated
            let nextResourceState = updatedResourceState(
                from: state.resource,
                process: state.process2, 
                nextProcess: nextP2, 
                processId: 2
            )
            
            nextStates.insert(ConcurrentSystemState(
                process1: state.process1,
                process2: nextP2,
                resource: nextResourceState
            ))
        }
        
        // Also include current state (possibility of no change)
        nextStates.insert(state)
        
        return nextStates
    }
    
    // Helper method to determine the next process states
    private func nextProcessStates(for state: ProcessState, processId: Int, resourceState: ResourceState) -> [ProcessState] {
        switch state {
        case .idle:
            // From idle to requesting resource
            return [.idle, .wanting]
            
        case .wanting:
            // From requesting to waiting for resource
            return [.waiting]
            
        case .waiting:
            // If resource is free, can enter critical section
            if case .free = resourceState {
                return [.waiting, .critical]
            } else {
                // If resource is in use, continue waiting
                return [.waiting]
            }
            
        case .critical:
            // From critical section to releasing
            return [.releasing]
            
        case .releasing:
            // From releasing back to idle
            return [.idle]
        }
    }
    
    // Helper method to update resource state
    private func updatedResourceState(from currentState: ResourceState, process: ProcessState, nextProcess: ProcessState, processId: Int) -> ResourceState {
        // Process entering critical section
        if process == .waiting && nextProcess == .critical {
            return .taken(by: processId)
        }
        
        // Process releasing resource
        if process == .critical && nextProcess == .releasing {
            return .free
        }
        
        // Otherwise resource state remains unchanged
        return currentState
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // Propositions related to process 1 state
        switch state.process1 {
        case .idle:
            trueProps.insert(p1Idle.id)
        case .wanting:
            trueProps.insert(p1Wanting.id)
        case .waiting:
            trueProps.insert(p1Waiting.id)
        case .critical:
            trueProps.insert(p1Critical.id)
        case .releasing:
            trueProps.insert(p1Releasing.id)
        }
        
        // Propositions related to process 2 state
        switch state.process2 {
        case .idle:
            trueProps.insert(p2Idle.id)
        case .wanting:
            trueProps.insert(p2Wanting.id)
        case .waiting:
            trueProps.insert(p2Waiting.id)
        case .critical:
            trueProps.insert(p2Critical.id)
        case .releasing:
            trueProps.insert(p2Releasing.id)
        }
        
        // Propositions related to resource state
        switch state.resource {
        case .free:
            trueProps.insert(resourceFree.id)
        case .taken(let id):
            trueProps.insert(resourceTaken.id)
            if id == 1 {
                trueProps.insert(resourceTakenByP1.id)
            } else if id == 2 {
                trueProps.insert(resourceTakenByP2.id)
            }
        }
        
        return trueProps
    }
}
```

## Step 3: Defining Propositions for the Concurrent System

Let's define the propositions for our concurrent system.

```swift
// Process 1 propositions
let p1Idle = TemporalKit.makeProposition(
    id: "p1Idle",
    name: "Process 1 is idle",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process1 == .idle
    }
)

let p1Wanting = TemporalKit.makeProposition(
    id: "p1Wanting",
    name: "Process 1 is requesting resource",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process1 == .wanting
    }
)

let p1Waiting = TemporalKit.makeProposition(
    id: "p1Waiting",
    name: "Process 1 is waiting for resource",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process1 == .waiting
    }
)

let p1Critical = TemporalKit.makeProposition(
    id: "p1Critical",
    name: "Process 1 is in critical section",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process1 == .critical
    }
)

let p1Releasing = TemporalKit.makeProposition(
    id: "p1Releasing",
    name: "Process 1 is releasing resource",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process1 == .releasing
    }
)

// Process 2 propositions
let p2Idle = TemporalKit.makeProposition(
    id: "p2Idle",
    name: "Process 2 is idle",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process2 == .idle
    }
)

let p2Wanting = TemporalKit.makeProposition(
    id: "p2Wanting",
    name: "Process 2 is requesting resource",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process2 == .wanting
    }
)

let p2Waiting = TemporalKit.makeProposition(
    id: "p2Waiting",
    name: "Process 2 is waiting for resource",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process2 == .waiting
    }
)

let p2Critical = TemporalKit.makeProposition(
    id: "p2Critical",
    name: "Process 2 is in critical section",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process2 == .critical
    }
)

let p2Releasing = TemporalKit.makeProposition(
    id: "p2Releasing",
    name: "Process 2 is releasing resource",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        return state.process2 == .releasing
    }
)

// Resource propositions
let resourceFree = TemporalKit.makeProposition(
    id: "resourceFree",
    name: "Resource is free",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        if case .free = state.resource {
            return true
        }
        return false
    }
)

let resourceTaken = TemporalKit.makeProposition(
    id: "resourceTaken",
    name: "Resource is in use",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        if case .taken = state.resource {
            return true
        }
        return false
    }
)

let resourceTakenByP1 = TemporalKit.makeProposition(
    id: "resourceTakenByP1",
    name: "Resource is in use by Process 1",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        if case .taken(let id) = state.resource, id == 1 {
            return true
        }
        return false
    }
)

let resourceTakenByP2 = TemporalKit.makeProposition(
    id: "resourceTakenByP2",
    name: "Resource is in use by Process 2",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        if case .taken(let id) = state.resource, id == 2 {
            return true
        }
        return false
    }
)
```

## Step 4: Defining Properties to Verify

Now, let's define LTL formulas to verify important concurrency properties.

```swift
// Type aliases to make the code more readable
typealias ConcurrentProp = ClosureTemporalProposition<ConcurrentSystemState, Bool>
typealias ConcurrentLTL = LTLFormula<ConcurrentProp>

// Mutual Exclusion: No two processes are in the critical section simultaneously
let mutualExclusion = ConcurrentLTL.globally(
    .not(
        .and(
            .atomic(p1Critical),
            .atomic(p2Critical)
        )
    )
)

// Deadlock Freedom: It's always possible for a process to get the resource
let deadlockFreedom = ConcurrentLTL.globally(
    .implies(
        .atomic(p1Waiting),
        .eventually(.atomic(p1Critical))
    )
)

// Starvation Freedom: Every waiting process eventually enters the critical section
let starvationFreedom1 = ConcurrentLTL.globally(
    .implies(
        .atomic(p1Waiting),
        .eventually(.atomic(p1Critical))
    )
)

let starvationFreedom2 = ConcurrentLTL.globally(
    .implies(
        .atomic(p2Waiting),
        .eventually(.atomic(p2Critical))
    )
)

// Resource usage: Resource is freed after being used
let resourceFreedAfterUse = ConcurrentLTL.globally(
    .implies(
        .atomic(resourceTaken),
        .eventually(.atomic(resourceFree))
    )
)

// Liveness: Both processes continuously enter and exit the critical section
let liveness1 = ConcurrentLTL.globally(.eventually(.atomic(p1Critical)))
let liveness2 = ConcurrentLTL.globally(.eventually(.atomic(p2Critical)))
```

## Step 5: Running Verification

Now, let's run verification to check if our concurrent system satisfies these properties.

```swift
// Initialize the model and model checker
let concurrentSystem = ConcurrentSystem()
let modelChecker = LTLModelChecker<ConcurrentSystem>()

// Verify properties
do {
    print("Verifying concurrent system properties...")
    
    let mutexResult = try modelChecker.check(formula: mutualExclusion, model: concurrentSystem)
    print("Mutual Exclusion: \(mutexResult.holds ? "holds" : "does not hold")")
    
    let deadlockResult = try modelChecker.check(formula: deadlockFreedom, model: concurrentSystem)
    print("Deadlock Freedom: \(deadlockResult.holds ? "holds" : "does not hold")")
    
    let starvation1Result = try modelChecker.check(formula: starvationFreedom1, model: concurrentSystem)
    print("Starvation Freedom (P1): \(starvation1Result.holds ? "holds" : "does not hold")")
    
    let starvation2Result = try modelChecker.check(formula: starvationFreedom2, model: concurrentSystem)
    print("Starvation Freedom (P2): \(starvation2Result.holds ? "holds" : "does not hold")")
    
    let resourceResult = try modelChecker.check(formula: resourceFreedAfterUse, model: concurrentSystem)
    print("Resource Freed After Use: \(resourceResult.holds ? "holds" : "does not hold")")
    
    let liveness1Result = try modelChecker.check(formula: liveness1, model: concurrentSystem)
    print("Liveness (P1): \(liveness1Result.holds ? "holds" : "does not hold")")
    
    let liveness2Result = try modelChecker.check(formula: liveness2, model: concurrentSystem)
    print("Liveness (P2): \(liveness2Result.holds ? "holds" : "does not hold")")
    
    // If any property doesn't hold, check for counterexamples
    if case .fails(let counterexample) = starvation1Result {
        print("\nCounterexample for Starvation Freedom (P1):")
        print("Prefix: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("Cycle: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
} catch {
    print("Verification error: \(error)")
}
```

## Step 6: Handling Fairness Conditions

In concurrent systems, we often need to add fairness assumptions to ensure that all processes get a chance to execute. Let's modify our model to include fairness considerations.

```swift
// Fairness property: Every process that is continuously trying to enter its
// critical section will eventually be able to do so
let fairnessProperty = ConcurrentLTL.implies(
    .globally(.eventually(.atomic(p1Wanting))),  // Process 1 repeatedly wants the resource
    .globally(.eventually(.atomic(p1Critical)))   // Process 1 repeatedly gets the resource
)

// Weak fairness: If a process continuously requests a resource, it will eventually get it
let weakFairness = ConcurrentLTL.globally(
    .implies(
        .globally(.atomic(p1Waiting)),
        .eventually(.atomic(p1Critical))
    )
)

// Strong fairness: If a process repeatedly requests a resource, it will eventually get it
let strongFairness = ConcurrentLTL.globally(
    .implies(
        .globally(.eventually(.atomic(p1Waiting))),
        .globally(.eventually(.atomic(p1Critical)))
    )
)

// Verify with fairness conditions
do {
    let fairnessResult = try modelChecker.check(formula: fairnessProperty, model: concurrentSystem)
    print("\nFairness Property: \(fairnessResult.holds ? "holds" : "does not hold")")
    
    let weakFairnessResult = try modelChecker.check(formula: weakFairness, model: concurrentSystem)
    print("Weak Fairness: \(weakFairnessResult.holds ? "holds" : "does not hold")")
    
    let strongFairnessResult = try modelChecker.check(formula: strongFairness, model: concurrentSystem)
    print("Strong Fairness: \(strongFairnessResult.holds ? "holds" : "does not hold")")
} catch {
    print("Fairness verification error: \(error)")
}
```

## Step 7: Creating a More Complex Concurrent System

Let's implement a more complex concurrent system with a producer-consumer pattern.

```swift
// Buffer bound
let BUFFER_SIZE = 3

// Producer-Consumer system state
struct ProducerConsumerState: Hashable, CustomStringConvertible {
    enum ProducerState: String {
        case idle, producing, waiting, adding
    }
    
    enum ConsumerState: String {
        case idle, consuming, waiting, removing
    }
    
    let producer: ProducerState
    let consumer: ConsumerState
    let bufferCount: Int  // Number of items in buffer
    
    var description: String {
        return "Producer: \(producer.rawValue), Consumer: \(consumer.rawValue), Buffer: \(bufferCount)/\(BUFFER_SIZE)"
    }
}

// Producer-Consumer system
struct ProducerConsumerSystem: KripkeStructure {
    typealias State = ProducerConsumerState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init() {
        // Initial state: both idle, empty buffer
        let initialState = ProducerConsumerState(
            producer: .idle,
            consumer: .idle,
            bufferCount: 0
        )
        
        self.initialStates = [initialState]
        
        // Generate all possible states
        var states = Set<State>()
        
        for p in [ProducerConsumerState.ProducerState.idle, .producing, .waiting, .adding] {
            for c in [ProducerConsumerState.ConsumerState.idle, .consuming, .waiting, .removing] {
                for b in 0...BUFFER_SIZE {
                    states.insert(ProducerConsumerState(producer: p, consumer: c, bufferCount: b))
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // Producer transitions
        switch state.producer {
        case .idle:
            // Can start producing
            nextStates.insert(ProducerConsumerState(
                producer: .producing,
                consumer: state.consumer,
                bufferCount: state.bufferCount
            ))
            
            // Or stay idle
            nextStates.insert(state)
            
        case .producing:
            // Finished producing, check if can add to buffer
            if state.bufferCount < BUFFER_SIZE {
                // Buffer has space
                nextStates.insert(ProducerConsumerState(
                    producer: .adding,
                    consumer: state.consumer,
                    bufferCount: state.bufferCount
                ))
            } else {
                // Buffer full, must wait
                nextStates.insert(ProducerConsumerState(
                    producer: .waiting,
                    consumer: state.consumer,
                    bufferCount: state.bufferCount
                ))
            }
            
        case .waiting:
            // Check if buffer has space now
            if state.bufferCount < BUFFER_SIZE {
                nextStates.insert(ProducerConsumerState(
                    producer: .adding,
                    consumer: state.consumer,
                    bufferCount: state.bufferCount
                ))
            } else {
                // Still waiting
                nextStates.insert(state)
            }
            
        case .adding:
            // Add to buffer and return to idle
            nextStates.insert(ProducerConsumerState(
                producer: .idle,
                consumer: state.consumer,
                bufferCount: min(state.bufferCount + 1, BUFFER_SIZE)
            ))
        }
        
        // Consumer transitions
        switch state.consumer {
        case .idle:
            // Can start consuming if buffer not empty
            if state.bufferCount > 0 {
                nextStates.insert(ProducerConsumerState(
                    producer: state.producer,
                    consumer: .consuming,
                    bufferCount: state.bufferCount
                ))
            }
            
            // Or stay idle
            nextStates.insert(state)
            
        case .consuming:
            // Finished consuming, check if can remove from buffer
            if state.bufferCount > 0 {
                // Buffer has items
                nextStates.insert(ProducerConsumerState(
                    producer: state.producer,
                    consumer: .removing,
                    bufferCount: state.bufferCount
                ))
            } else {
                // Buffer empty, must wait
                nextStates.insert(ProducerConsumerState(
                    producer: state.producer,
                    consumer: .waiting,
                    bufferCount: state.bufferCount
                ))
            }
            
        case .waiting:
            // Check if buffer has items now
            if state.bufferCount > 0 {
                nextStates.insert(ProducerConsumerState(
                    producer: state.producer,
                    consumer: .removing,
                    bufferCount: state.bufferCount
                ))
            } else {
                // Still waiting
                nextStates.insert(state)
            }
            
        case .removing:
            // Remove from buffer and return to idle
            nextStates.insert(ProducerConsumerState(
                producer: state.producer,
                consumer: .idle,
                bufferCount: max(state.bufferCount - 1, 0)
            ))
        }
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        // Producer state propositions
        switch state.producer {
        case .idle:
            props.insert("producerIdle")
        case .producing:
            props.insert("producerProducing")
        case .waiting:
            props.insert("producerWaiting")
        case .adding:
            props.insert("producerAdding")
        }
        
        // Consumer state propositions
        switch state.consumer {
        case .idle:
            props.insert("consumerIdle")
        case .consuming:
            props.insert("consumerConsuming")
        case .waiting:
            props.insert("consumerWaiting")
        case .removing:
            props.insert("consumerRemoving")
        }
        
        // Buffer state propositions
        if state.bufferCount == 0 {
            props.insert("bufferEmpty")
        }
        
        if state.bufferCount == BUFFER_SIZE {
            props.insert("bufferFull")
        }
        
        if state.bufferCount > 0 && state.bufferCount < BUFFER_SIZE {
            props.insert("bufferPartial")
        }
        
        return props
    }
}
```

## Step 8: Implementing Invariant Properties

Let's verify important properties of our Producer-Consumer system.

```swift
// Define propositions for the Producer-Consumer system
let bufferEmpty = TemporalKit.makeProposition(
    id: "bufferEmpty",
    name: "Buffer is empty",
    evaluate: { (state: ProducerConsumerState) -> Bool in
        return state.bufferCount == 0
    }
)

let bufferFull = TemporalKit.makeProposition(
    id: "bufferFull",
    name: "Buffer is full",
    evaluate: { (state: ProducerConsumerState) -> Bool in
        return state.bufferCount == BUFFER_SIZE
    }
)

let producerWaiting = TemporalKit.makeProposition(
    id: "producerWaiting",
    name: "Producer is waiting",
    evaluate: { (state: ProducerConsumerState) -> Bool in
        return state.producer == .waiting
    }
)

let consumerWaiting = TemporalKit.makeProposition(
    id: "consumerWaiting",
    name: "Consumer is waiting",
    evaluate: { (state: ProducerConsumerState) -> Bool in
        return state.consumer == .waiting
    }
)

// Type aliases
typealias PCProp = ClosureTemporalProposition<ProducerConsumerState, Bool>
typealias PCLTL = LTLFormula<PCProp>

// Properties to verify
// 1. Producer only waits when buffer is full
let producerWaitsWhenFull = PCLTL.globally(
    .implies(
        .atomic(producerWaiting),
        .atomic(bufferFull)
    )
)

// 2. Consumer only waits when buffer is empty
let consumerWaitsWhenEmpty = PCLTL.globally(
    .implies(
        .atomic(consumerWaiting),
        .atomic(bufferEmpty)
    )
)

// 3. The system is deadlock-free
let deadlockFree = PCLTL.globally(
    .not(
        .and(
            .atomic(producerWaiting),
            .atomic(consumerWaiting)
        )
    )
)

// Verify Producer-Consumer system
let producerConsumerSystem = ProducerConsumerSystem()
let pcModelChecker = LTLModelChecker<ProducerConsumerSystem>()

do {
    print("\nVerifying Producer-Consumer system...")
    
    let result1 = try pcModelChecker.check(formula: producerWaitsWhenFull, model: producerConsumerSystem)
    print("Producer only waits when buffer is full: \(result1.holds ? "holds" : "does not hold")")
    
    let result2 = try pcModelChecker.check(formula: consumerWaitsWhenEmpty, model: producerConsumerSystem)
    print("Consumer only waits when buffer is empty: \(result2.holds ? "holds" : "does not hold")")
    
    let result3 = try pcModelChecker.check(formula: deadlockFree, model: producerConsumerSystem)
    print("System is deadlock-free: \(result3.holds ? "holds" : "does not hold")")
    
    // Check for counterexamples
    if case .fails(let counterexample) = result3 {
        print("\nDeadlock counterexample:")
        print("Prefix: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("Cycle: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
} catch {
    print("Producer-Consumer verification error: \(error)")
}
```

## Summary

In this tutorial, you learned how to verify concurrent systems using TemporalKit. Specifically, you learned how to:

1. Model concurrent systems with shared resources as Kripke structures
2. Define LTL formulas to express important concurrency properties like mutual exclusion and deadlock freedom
3. Verify whether your concurrent systems satisfy these properties
4. Handle fairness conditions to ensure all processes get a chance to execute
5. Model and verify more complex concurrent systems like the Producer-Consumer pattern

Formal verification of concurrent systems is particularly valuable because concurrent systems are notoriously difficult to debug due to non-deterministic behaviors, race conditions, and deadlocks.

## Next Steps

- Explore [Optimizing Performance](./OptimizingPerformance.md) for techniques to handle large state spaces in concurrent systems
- Learn about [Integrating with Tests](./IntegratingWithTests.md) to combine formal verification with traditional testing
- Model and verify real-world concurrent algorithms like readers-writers or dining philosophers 
