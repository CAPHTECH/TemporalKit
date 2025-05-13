# TemporalKit Advanced Topics

This document covers advanced usage and technical details of TemporalKit. It assumes you already understand the basic usage of the library.

## Table of Contents

- [Implementing Custom Algorithms](#implementing-custom-algorithms)
- [Advanced LTL Formula Patterns](#advanced-ltl-formula-patterns)
- [Extending the Backend Verification Engine](#extending-the-backend-verification-engine)
- [Optimization Techniques for Large Models](#optimization-techniques-for-large-models)
- [Distributed Verification](#distributed-verification)
- [TemporalKit's Internal Architecture](#temporalkits-internal-architecture)
- [Formal Verification Theory](#formal-verification-theory)

## Implementing Custom Algorithms

TemporalKit has an extensible architecture that allows you to implement your own model checking algorithms.

### Creating a Model Checking Algorithm

To implement a custom model checking algorithm, you need to conform to the `LTLModelCheckingAlgorithm` protocol:

```swift
public protocol LTLModelCheckingAlgorithm {
    associatedtype Model: KripkeStructure
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool
}
```

Implementation example:

```swift
struct MyCustomAlgorithm<M: KripkeStructure>: LTLModelCheckingAlgorithm {
    typealias Model = M
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // Implementation of your custom algorithm
        
        // Example: Optimized verification logic for specific types of formulas
        if formula.isSimpleSafetyProperty() {
            return try optimizedSafetyCheck(formula: formula, model: model)
        } else {
            // Use standard algorithm for general cases
            let standardAlgorithm = TableauBasedLTLModelChecking<Model>()
            return try standardAlgorithm.check(formula: formula, model: model)
        }
    }
    
    private func optimizedSafetyCheck<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // Implementation optimized for safety properties
        // ...
    }
}
```

### Using Custom Algorithms

```swift
let customAlgorithm = MyCustomAlgorithm<MyModel>()
let modelChecker = LTLModelChecker<MyModel>(algorithm: customAlgorithm)

// Or use a custom model checker directly
let customModelChecker = CustomModelChecker<MyModel>(algorithm: customAlgorithm)
```

## Advanced LTL Formula Patterns

Here are advanced LTL formula patterns for expressing complex system requirements.

### Response Pattern

The response pattern "whenever event P occurs, eventually event Q occurs" is required in many real-time systems.

```swift
// Response pattern: G(p -> F(q))
func responsePattern<P: TemporalProposition>(
    trigger: P,
    response: P
) -> LTLFormula<P> {
    return .globally(.implies(.atomic(trigger), .eventually(.atomic(response))))
}

// Bounded response: G(p -> F[0,k](q))
// This expresses "When P occurs, Q occurs within k time units"
func boundedResponse<P: TemporalProposition>(
    trigger: P,
    response: P,
    steps: Int
) -> LTLFormula<P> {
    var result: LTLFormula<P> = .atomic(response)
    for _ in 0..<steps {
        result = .or(.atomic(response), .next(result))
    }
    return .globally(.implies(.atomic(trigger), result))
}
```

### Precedence Pattern

The precedence pattern "event P must occur before event Q" can be expressed as:

```swift
// Precedence pattern: !q U (p || G(!q))
func precedencePattern<P: TemporalProposition>(
    precondition: P,
    event: P
) -> LTLFormula<P> {
    return .until(
        .not(.atomic(event)),
        .or(.atomic(precondition), .globally(.not(.atomic(event))))
    )
}
```

### Chain Pattern

Chain patterns express specific sequences of events:

```swift
// Chain pattern: G(p -> X(q -> X(r)))
func chainPattern<P: TemporalProposition>(
    events: [P]
) -> LTLFormula<P> {
    guard !events.isEmpty else {
        return .booleanLiteral(true)
    }
    
    var result: LTLFormula<P> = .atomic(events.last!)
    
    for event in events.dropLast().reversed() {
        result = .implies(.atomic(event), .next(result))
    }
    
    return .globally(result)
}
```

## Extending the Backend Verification Engine

You can extend TemporalKit's verification engine to integrate with external verification tools.

### Integration with External Verification Tools

Example of integration with tools like NuSMV or SPIN:

```swift
class NuSMVIntegration<Model: KripkeStructure>: LTLModelCheckingAlgorithm {
    typealias Model = Model
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // 1. Convert the model to NuSMV format
        let smvModel = convertToSMV(model)
        
        // 2. Convert the LTL formula to NuSMV format
        let smvFormula = convertFormulaToSMV(formula)
        
        // 3. Run NuSMV and parse the results
        let result = runNuSMV(model: smvModel, formula: smvFormula)
        
        // 4. Convert NuSMV results to TemporalKit result format
        return convertNuSMVResult(result, model: model)
    }
    
    // Implementation of NuSMV conversion and execution
    // ...
}
```

### Multi-Engine Strategy

Improve result reliability by using multiple verification engines:

```swift
class MultiEngineVerifier<Model: KripkeStructure> {
    let algorithms: [any LTLModelCheckingAlgorithm<Model>]
    
    init(algorithms: [any LTLModelCheckingAlgorithm<Model>]) {
        self.algorithms = algorithms
    }
    
    func verify<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> VerificationResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        var results: [ModelCheckResult<Model.State>] = []
        var errors: [Error] = []
        
        for algorithm in algorithms {
            do {
                let result = try algorithm.check(formula: formula, model: model)
                results.append(result)
            } catch {
                errors.append(error)
            }
        }
        
        return VerificationResult(results: results, errors: errors)
    }
}

struct VerificationResult<State: Hashable> {
    let results: [ModelCheckResult<State>]
    let errors: [Error]
    
    var isConsistent: Bool {
        // Check if all results agree
        if let first = results.first {
            return results.allSatisfy { $0.holds == first.holds }
        }
        return true
    }
    
    var consensus: ModelCheckResult<State>? {
        // Determine result by majority vote
        // ...
    }
}
```

## Optimization Techniques for Large Models

Advanced optimization techniques for efficiently verifying large models.

### Symbolic Model Checking

Symbolic representation of states instead of explicit enumeration:

```swift
class SymbolicModelChecker<Model: KripkeStructure> {
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // Implementation of symbolic model checking
        // Representing states using data structures like BDDs
        
        // ...
    }
    
    private func encodeStates(_ states: Set<Model.State>) -> SymbolicRepresentation {
        // Encode states into symbolic representation
        // ...
    }
    
    private func fixpointComputation(formula: SymbolicRepresentation, initialStates: SymbolicRepresentation) -> SymbolicRepresentation {
        // Verification using fixpoint computation
        // ...
    }
}
```

### Partial Order Reduction

For concurrent systems, reduce state space by reducing the order of independent actions:

```swift
class PartialOrderReductionOptimizer<Model: KripkeStructure> {
    func optimizeModel(_ model: Model) -> Model {
        // 1. Identify independent actions
        let independentActions = findIndependentActions(model)
        
        // 2. Build a reduced model
        return buildReducedModel(model, independentActions: independentActions)
    }
    
    private func findIndependentActions(_ model: Model) -> Set<Action> {
        // Logic to identify independent actions
        // ...
    }
    
    private func buildReducedModel(_ model: Model, independentActions: Set<Action>) -> Model {
        // Build the reduced model
        // ...
    }
}
```

### Abstraction and Refinement

Iterative approach using abstract models and refining as needed:

```swift
class AbstractionRefinementVerifier<Model: KripkeStructure> {
    func verifyWithRefinement<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // Initial abstraction
        var abstractModel = createInitialAbstraction(model)
        let checker = LTLModelChecker<AbstractModel>()
        
        while true {
            // Verify with the abstract model
            let result = try checker.check(formula: abstractFormula(formula), model: abstractModel)
            
            if case .holds = result {
                // If the abstract model satisfies, so does the original
                return .holds
            } else if case .fails(let counterexample) = result {
                // Check if the counterexample is valid in the original model
                if isCounterexampleValid(counterexample, in: model) {
                    // Return valid counterexample
                    return .fails(counterexample: mapToOriginalStates(counterexample))
                } else {
                    // Refine the model based on the counterexample
                    abstractModel = refineModel(abstractModel, counterexample: counterexample)
                }
            }
        }
    }
    
    // Implementation of abstraction and refinement
    // ...
}
```

## Distributed Verification

Techniques for performing large-scale model checking across multiple machines:

```swift
class DistributedModelChecker<Model: KripkeStructure> {
    let workers: [WorkerNode]
    
    init(workers: [WorkerNode]) {
        self.workers = workers
    }
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // 1. Partition the model
        let partitions = partitionModel(model, workerCount: workers.count)
        
        // 2. Send partitioned model and formula to each worker
        let tasks = zip(workers, partitions).map { worker, partition in
            worker.verify(formula: formula, modelPartition: partition)
        }
        
        // 3. Aggregate results
        let results = try awaitAll(tasks)
        
        // 4. Determine final result
        return combineResults(results)
    }
    
    // Helper methods for distributed verification
    // ...
}
```

## TemporalKit's Internal Architecture

Detailed explanation of TemporalKit's internal architecture and extension points.

### Core Components

```
TemporalKit
├── Core
│   ├── LTLFormula.swift             // LTL formula representation
│   ├── KripkeStructure.swift        // Model state and transition representation
│   ├── TemporalProposition.swift    // Proposition representation
│   └── ModelCheckResult.swift       // Verification result representation
├── Algorithms
│   ├── LTLModelChecker.swift        // Main model checking class
│   ├── TableauGraphConstructor.swift // Tableau-based graph construction
│   ├── LTLFormulaNNFConverter.swift // Conversion to negation normal form
│   └── GBAToBAConverter.swift       // Automaton conversion
├── Evaluation
│   ├── EvaluationContext.swift      // Evaluation context
│   ├── LTLFormulaEvaluator.swift    // Formula evaluation
│   └── LTLFormulaTraceEvaluator.swift // Evaluation over traces
└── DSL
    ├── LTLOperators.swift           // Operator definitions
    └── LTLDSLExtensions.swift       // DSL syntax extensions
```

### Extension Points

Key points for extending TemporalKit:

1. **Custom Proposition Implementation**:

   ```swift
   struct MyCustomProposition: TemporalProposition {
       // Custom implementation
   }
   ```

2. **Custom Model Implementation**:

   ```swift
   struct MyCustomModel: KripkeStructure {
       // Custom implementation
   }
   ```

3. **Custom Verification Algorithm Implementation**:

   ```swift
   struct MyCustomAlgorithm: LTLModelCheckingAlgorithm {
       // Custom implementation
   }
   ```

4. **Custom Evaluation Context Implementation**:

   ```swift
   struct MyCustomContext: EvaluationContext {
       // Custom implementation
   }
   ```

## Formal Verification Theory

Explanation of the theoretical background behind TemporalKit.

### LTL and Automaton Theory

LTL verification is typically implemented based on automaton theory. The main steps are:

1. Take the negation of the LTL formula
2. Convert the formula to a Generalized Büchi Automaton (GBA)
3. Convert the GBA to a Büchi Automaton (BA)
4. Construct the product of the model and the BA
5. Search for accepting cycles

```swift
// Simplified process
func ltlToAutomaton<P: TemporalProposition>(formula: LTLFormula<P>) -> Automaton {
    // 1. Convert to negation normal form
    let nnfFormula = formula.toNNF()
    
    // 2. Create nodes from formula syntax
    let nodes = createTableauNodes(from: nnfFormula)
    
    // 3. Build transition relations between nodes
    let transitions = buildTransitions(between: nodes)
    
    // 4. Build acceptance conditions
    let acceptanceConditions = buildAcceptanceConditions(for: nnfFormula, nodes: nodes)
    
    return Automaton(
        states: nodes,
        initialStates: nodesContainingFormula(nnfFormula),
        transitions: transitions,
        acceptanceConditions: acceptanceConditions
    )
}
```

### Tableau Method

The tableau method is a technique for constructing a nondeterministic Büchi automaton from an LTL formula:

```swift
class TableauGraphConstructor<P: TemporalProposition> {
    func constructTableau(for formula: LTLFormula<P>) -> TableauGraph<P> {
        // 1. Compute the closure of the formula
        let closure = computeClosure(formula)
        
        // 2. Find consistent subsets
        let consistentSubsets = findConsistentSubsets(closure)
        
        // 3. Create graph nodes
        let nodes = consistentSubsets.map { TableauNode(formulas: $0) }
        
        // 4. Build transition relations
        let edges = buildEdges(between: nodes)
        
        // 5. Build acceptance sets
        let acceptanceSets = buildAcceptanceSets(nodes: nodes, originalFormula: formula)
        
        return TableauGraph(
            nodes: nodes,
            initialNodes: findInitialNodes(nodes, formula: formula),
            edges: edges,
            acceptanceSets: acceptanceSets
        )
    }
    
    // Helper methods for tableau method
    // ...
}
```

### On-the-Fly Model Checking

Concept of on-the-fly algorithms to reduce memory usage:

```swift
class OnTheFlyModelChecker<Model: KripkeStructure> {
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // 1. Negate the LTL formula
        let negatedFormula = LTLFormula<P>.not(formula)
        
        // 2. Search the product graph while constructing the tableau on-the-fly
        let result = try searchProductGraph(model: model, formula: negatedFormula)
        
        // 3. Interpret the result
        if result.acceptingCycleFound {
            return .fails(counterexample: result.counterexample)
        } else {
            return .holds
        }
    }
    
    private func searchProductGraph<P: TemporalProposition>(
        model: Model,
        formula: LTLFormula<P>
    ) throws -> SearchResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // Use nested depth-first search to find accepting cycles
        // Expand tableau nodes as needed
        // ...
    }
}
```

## Summary

This document covered advanced usage and technical details of TemporalKit. By understanding and applying these advanced topics, you can verify more complex systems efficiently.

Optimization techniques and distributed verification knowledge are particularly important for verifying large-scale models. Custom algorithm implementations allow for efficient verification tailored to specific domains or problems.

Understanding the theoretical background of formal verification enables more effective use of TemporalKit and provides the knowledge needed to extend it when necessary.
