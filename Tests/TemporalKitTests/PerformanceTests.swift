import XCTest
@testable import TemporalKit

final class PerformanceTests: XCTestCase {

    // MARK: - Test Types and Utilities

    // Use the same test types as in EdgeCaseTests for consistency
    struct KripkeState {
        let id: String
        let propositions: [String]
    }

    struct KripkeTransition {
        let from: String
        let to: String
    }

    // Correctly conform TestKripkeStructure to KripkeStructure
    struct TestKripkeStructure: KripkeStructure {
        typealias State = String
        typealias AtomicPropositionIdentifier = PropositionID // Use PropositionID

        let states: [KripkeState]
        let initialState: String // Store the single initial state
        let transitions: [KripkeTransition]

        var allStates: Set<String> {
            Set(states.map { $0.id })
        }

        // Correct implementation: Computed property conforming to KripkeStructure
        var initialStates: Set<String> {
            [initialState]
        }

        func successors(of state: String) -> Set<String> { // Implement successors
            Set(transitions.filter { $0.from == state }.map { $0.to })
        }

        func atomicPropositionsTrue(in state: String) -> Set<PropositionID> { // Implement atomicPropositionsTrue
            guard let kState = states.first(where: { $0.id == state }) else {
                return []
            }
            return Set(kState.propositions.map { PropositionID(rawValue: $0)! })
        }
    }

    // Use ClosureTemporalProposition like in EdgeCaseTests
    typealias TestProposition = ClosureTemporalProposition<String, Bool>

    // Helper to create ClosureTemporalProposition instances
    func makeProposition(_ name: String) -> TestProposition {
        ClosureTemporalProposition.nonThrowing(
            id: name,
            name: name,
            evaluate: { (_: String) -> Bool in
                true
            }
        )
    }

    // Helper to create a Kripke structure (simplified, ensure reachability)
    func createLargeKripkeStructure(numStates: Int, numTransitionsPerState: Int) -> TestKripkeStructure {
         var states: [KripkeState] = []
        var transitions: [KripkeTransition] = []
        let propositions = ["p", "q", "r", "s"] // Example propositions

        for i in 0..<numStates {
            let stateID = "s\(i)"
            // Assign propositions pseudo-randomly
            let statePropositions = propositions.filter { _ in Bool.random() }
            states.append(KripkeState(id: stateID, propositions: statePropositions))

            var addedTransitions = 0
            for _ in 0..<numTransitionsPerState {
                let targetStateID = "s\(Int.random(in: 0..<numStates))"
                // Allow self-loops in benchmarks
                transitions.append(KripkeTransition(from: stateID, to: targetStateID))
                addedTransitions += 1
            }
             // Ensure at least one transition exists if requested and possible
            if numStates > 0 && numTransitionsPerState > 0 && addedTransitions == 0 {
                let targetStateID = "s\((i + 1) % numStates)" // simple cycle as fallback
                transitions.append(KripkeTransition(from: stateID, to: targetStateID))
            }
        }

        // Basic reachability: Ensure s0 can reach s1, s1 reach s2 etc. if not already possible
        for i in 0..<(numStates - 1) {
            let fromState = "s\(i)"
            let toState = "s\(i + 1)"
            if !transitions.contains(where: { $0.from == fromState }) {
                 // Add transition to next state if source has no outgoing transitions
                 transitions.append(KripkeTransition(from: fromState, to: toState))
            }
        }
         // Ensure the last state has a transition (e.g., loop back or to start) if needed
         if numStates > 0 && numTransitionsPerState > 0 && !transitions.contains(where: { $0.from == "s\(numStates - 1)" }) {
             transitions.append(KripkeTransition(from: "s\(numStates - 1)", to: "s0"))
         }

        // Ensure initialState exists if states is not empty
        let actualInitialState = states.isEmpty ? "" : "s0" // Use s0 or handle empty
        return TestKripkeStructure(states: states, initialState: actualInitialState, transitions: transitions)
    }

    // MARK: - NestedDFS Benchmarks

    func testNestedDFS_Performance_SmallStructure() {
        let kripke = createLargeKripkeStructure(numStates: 10, numTransitionsPerState: 2)
        let p = makeProposition("p")
        let formula: LTLFormula<TestProposition> = .globally(.atomic(p)) // Use .atomic

        // LTLModelChecker is not generic on Proposition anymore
        let modelChecker = LTLModelChecker<TestKripkeStructure>()

        self.measure {
            // Call verify with the correct signature
            _ = try? modelChecker.check( // Use check method
                formula: formula,
                model: kripke
            )
        }
    }

    func testNestedDFS_Performance_MediumStructure() {
        let kripke = createLargeKripkeStructure(numStates: 50, numTransitionsPerState: 3)
        let p = makeProposition("p")
        let q = makeProposition("q")
        // G(p -> F q)
        let formula: LTLFormula<TestProposition> = .globally(
            .implies(
                .atomic(p), // Use .atomic
                .eventually(.atomic(q)) // Use .atomic
            )
        )
        let modelChecker = LTLModelChecker<TestKripkeStructure>()

        self.measure {
             _ = try? modelChecker.check( // Use check method
                formula: formula,
                model: kripke
            )
        }
    }

    func testNestedDFS_Performance_LargeStructure() {
        // Note: 100 states can be quite demanding for complex formulas
        let kripke = createLargeKripkeStructure(numStates: 100, numTransitionsPerState: 2)
        let p = makeProposition("p")
        let q = makeProposition("q")
        let r = makeProposition("s")
        // G(p -> (X(q U r)))
        let formula: LTLFormula<TestProposition> = .globally(
            .implies(
                .atomic(p), // Use .atomic
                .next(
                    .until(.atomic(q), .atomic(r)) // Use .atomic
                )
            )
        )
        let modelChecker = LTLModelChecker<TestKripkeStructure>()

        self.measure {
             _ = try? modelChecker.check( // Use check method
                formula: formula,
                model: kripke
            )
        }
    }

    // MARK: - GBAConditionGenerator Benchmarks

    private func createGBAConditionGenerator() -> GBAConditionGenerator<TestProposition> {
        GBAConditionGenerator<TestProposition>()
    }

    func testGBAGeneration_Performance_SimpleFormula() {
        let p = makeProposition("p")
        let formula: LTLFormula<TestProposition> = .globally(.atomic(p))
        let nnfFormula = LTLFormulaNNFConverter.convert(formula) // Convert to NNF

        let constructor = TableauGraphConstructor<TestProposition, PropositionID>(
            nnfFormula: nnfFormula, // Use NNF formula
            originalPreNNFFormula: formula,
            relevantPropositions: Set([p.id])
        )
        constructor.buildGraph()
        let tableauNodes = constructor.constructedTableauNodes
        let nodeMap = constructor.gbaStateIDMap

        let generator = createGBAConditionGenerator()

        self.measure {
            _ = GBAConditionGenerator<TestProposition>.determineConditions(
                tableauNodes: tableauNodes,
                nodeToStateIDMap: nodeMap,
                originalNNFFormula: nnfFormula // Use NNF formula
            )
        }
    }

    func testGBAGeneration_Performance_MediumFormula() {
        let p = makeProposition("p")
        let q = makeProposition("q")
        let formula: LTLFormula<TestProposition> = .globally(
            .implies(
                .atomic(p),
                .eventually(.atomic(q))
            )
        )
        let nnfFormula = LTLFormulaNNFConverter.convert(formula) // Convert to NNF

        let constructor = TableauGraphConstructor<TestProposition, PropositionID>(
            nnfFormula: nnfFormula, // Use NNF formula
            originalPreNNFFormula: formula,
            relevantPropositions: Set([p.id, q.id])
        )
        constructor.buildGraph()
        let tableauNodes = constructor.constructedTableauNodes
        let nodeMap = constructor.gbaStateIDMap

        let generator = createGBAConditionGenerator()

        self.measure {
            _ = GBAConditionGenerator<TestProposition>.determineConditions(
                tableauNodes: tableauNodes,
                nodeToStateIDMap: nodeMap,
                originalNNFFormula: nnfFormula // Use NNF formula
            )
        }
    }

    func testGBAGeneration_Performance_ComplexFormula() {
        let p = makeProposition("p")
        let q = makeProposition("q")
        let r = makeProposition("r")
        let s = makeProposition("s")
        let formula: LTLFormula<TestProposition> = .globally(
            .implies(
                .atomic(p),
                .next(
                    .release(
                        .atomic(q),
                        .until(.atomic(r), .atomic(s))
                    )
                )
            )
        )
        let nnfFormula = LTLFormulaNNFConverter.convert(formula) // Convert to NNF

        let constructor = TableauGraphConstructor<TestProposition, PropositionID>(
            nnfFormula: nnfFormula, // Use NNF formula
            originalPreNNFFormula: formula,
            relevantPropositions: Set([p.id, q.id, r.id, s.id])
        )
        constructor.buildGraph()
        let tableauNodes = constructor.constructedTableauNodes
        let nodeMap = constructor.gbaStateIDMap

        let generator = createGBAConditionGenerator()

        self.measure {
            _ = GBAConditionGenerator<TestProposition>.determineConditions(
                tableauNodes: tableauNodes,
                nodeToStateIDMap: nodeMap,
                originalNNFFormula: nnfFormula // Use NNF formula
            )
        }
    }
}
