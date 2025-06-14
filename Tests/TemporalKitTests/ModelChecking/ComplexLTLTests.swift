import XCTest
@testable import TemporalKit

final class ComplexLTLTests: XCTestCase {

    // MARK: - Test Types and Utilities

    // Define a simple KripkeState type
    struct KripkeState {
        let id: String
        let propositions: [String]
    }

    // Define a simple KripkeTransition type
    struct KripkeTransition {
        let from: String
        let to: String
    }

    // Define a Kripke structure implementation
    struct TestKripkeStructure: KripkeStructure {
        typealias State = String
        typealias AtomicPropositionIdentifier = PropositionID

        let states: [KripkeState]
        let initialState: String
        let transitions: [KripkeTransition]

        var allStates: Set<String> {
            Set(states.map { $0.id })
        }

        var initialStates: Set<String> {
            [initialState]
        }

        func successors(of state: String) -> Set<String> {
            Set(transitions.filter { $0.from == state }.map { $0.to })
        }

        func atomicPropositionsTrue(in state: String) -> Set<PropositionID> {
            guard let kripkeState = states.first(where: { $0.id == state }) else {
                return []
            }
            return Set(kripkeState.propositions.map { PropositionID(rawValue: $0)! })
        }
    }

    // Define proposition type for our tests
    typealias TestProposition = ClosureTemporalProposition<String, Bool>

    // MARK: - Test helper properties
    var modelChecker: LTLModelChecker<TestKripkeStructure>!

    override func setUp() {
        super.setUp()
        modelChecker = LTLModelChecker<TestKripkeStructure>()
    }

    override func tearDown() {
        modelChecker = nil
        super.tearDown()
    }

    // MARK: - Deeply nested formulas tests

    func testDeeplyNestedUntilRelease() {
        // Create a Kripke structure that should satisfy the deeply nested formula
        let kripke = createAcceptingKripke()

        // Create propositions
        let p = makeProposition("p")
        let q = makeProposition("q")
        let r = makeProposition("r")
        let s = makeProposition("s")
        let t = makeProposition("t")

        // Create a deeply nested formula: (p U (q R (r U (s R t))))
        let nestedFormula = LTLFormula<TestProposition>.until(
            .atomic(p),
            .release(
                .atomic(q),
                .until(
                    .atomic(r),
                    .release(
                        .atomic(s),
                        .atomic(t)
                    )
                )
            )
        )

        // Test on a Kripke structure that should satisfy this formula
        do {
            let result = try modelChecker.check(formula: nestedFormula, model: kripke)
            XCTAssertTrue(result.holds, "The deeply nested formula should hold on the accepting Kripke structure")
        } catch {
            XCTFail("Model checking threw an error: \(error)")
        }

        // Test on a Kripke structure that should not satisfy this formula
        let rejectingKripke = createRejectingKripke()
        do {
            let result = try modelChecker.check(formula: nestedFormula, model: rejectingKripke)
            XCTAssertFalse(result.holds, "The deeply nested formula should not hold on the rejecting Kripke structure")
        } catch {
            XCTFail("Model checking threw an error: \(error)")
        }
    }

    func testDeepFormulaCombiningAllOperators() {
        // Create a Kripke structure
        let kripke = createAcceptingKripke()

        // Create propositions
        let p = makeProposition("p")
        let q = makeProposition("q")
        let r = makeProposition("r")

        // Create a formula using all major LTL operators
        // G((p -> X q) & (q -> F r) & (r -> (p U q)))
        let complexFormula = LTLFormula<TestProposition>.globally(
            .and(
                .and(
                    .implies(
                        .atomic(p),
                        .next(.atomic(q))
                    ),
                    .implies(
                        .atomic(q),
                        .eventually(.atomic(r))
                    )
                ),
                .implies(
                    .atomic(r),
                    .until(.atomic(p), .atomic(q))
                )
            )
        )

        // Test on the accepting Kripke structure
        do {
            let result = try modelChecker.check(formula: complexFormula, model: kripke)
            XCTAssertTrue(result.holds, "The complex formula combining all operators should hold on the accepting Kripke structure")
        } catch {
            XCTFail("Model checking threw an error: \(error)")
        }
    }

    // MARK: - Large Kripke structure tests

    func testLargeKripkeStructure() {
        // Create a large Kripke structure (20+ states)
        let largeKripke = createLargeKripke(stateCount: 20)

        // Create propositions
        let p = makeProposition("p")
        let q = makeProposition("q")

        // Test with a moderately complex formula: G(p | F q)
        let formula = LTLFormula<TestProposition>.globally(
            .or(
                .atomic(p),
                .eventually(.atomic(q))
            )
        )

        // Measure performance and verify correctness
        measure {
            do {
                let result = try modelChecker.check(formula: formula, model: largeKripke)
                // Result could be true or false depending on the generated structure
                // We're mainly measuring performance here, not the result
                _ = result.holds
            } catch {
                XCTFail("Model checking threw an error: \(error)")
            }
        }
    }

    func testCyclicKripkeStructureWithNestedFormula() {
        // Create a cyclic Kripke structure
        let cyclicKripke = createCyclicKripke()

        // Create propositions
        let p = makeProposition("p")
        let q = makeProposition("q")
        let r = makeProposition("r")

        // Create a nested formula that should hold on the cyclic structure
        // G F (p & X (q U r))
        let cyclicFormula = LTLFormula<TestProposition>.globally(
            .eventually(
                .and(
                    .atomic(p),
                    .next(
                        .until(.atomic(q), .atomic(r))
                    )
                )
            )
        )

        // Test on the cyclic Kripke structure
        do {
            let result = try modelChecker.check(formula: cyclicFormula, model: cyclicKripke)
            XCTAssertTrue(result.holds, "The nested formula for cyclic behavior should hold on the cyclic structure")
        } catch {
            XCTFail("Model checking threw an error: \(error)")
        }
    }

    // MARK: - Helper methods

    private func makeProposition(_ id: String) -> TestProposition {
        TemporalKit.makeProposition(
            id: id,
            name: id,
            evaluate: { (state: String) -> Bool in
                guard let kripkeState = self.findState(id: state) else { return false }
                return kripkeState.propositions.contains(id)
            }
        )
    }

    private func findState(id: String) -> KripkeState? {
        // Need to search in all our test Kripke structures
        let allStructures = [
            createAcceptingKripke(),
            createRejectingKripke(),
            createCyclicKripke()
        ]

        for structure in allStructures {
            if let state = structure.states.first(where: { $0.id == id }) {
                return state
            }
        }

        // If not found in predefined structures, try to find in a dynamically created large structure
        let largeKripke = createLargeKripke(stateCount: 20)
        return largeKripke.states.first(where: { $0.id == id })
    }

    // MARK: - Kripke structure creation helpers

    private func createAcceptingKripke() -> TestKripkeStructure {
        // Create a structure that should satisfy the deeply nested formula
        // (p U (q R (r U (s R t))))

        let states = [
            KripkeState(id: "s0", propositions: ["p"]),                   // Initial state with p
            KripkeState(id: "s1", propositions: ["p", "q"]),              // Has p and q
            KripkeState(id: "s2", propositions: ["q", "r"]),              // Has q and r
            KripkeState(id: "s3", propositions: ["q", "r", "s"]),         // Has q, r, and s
            KripkeState(id: "s4", propositions: ["q", "s", "t"]),         // Has q, s, and t
            KripkeState(id: "s5", propositions: ["q", "s", "t", "p"])     // Has q, s, t, and p
        ]

        let transitions = [
            KripkeTransition(from: "s0", to: "s1"),
            KripkeTransition(from: "s1", to: "s2"),
            KripkeTransition(from: "s2", to: "s3"),
            KripkeTransition(from: "s3", to: "s4"),
            KripkeTransition(from: "s4", to: "s5"),
            KripkeTransition(from: "s5", to: "s5")  // Loop back
        ]

        return TestKripkeStructure(
            states: states,
            initialState: "s0",
            transitions: transitions
        )
    }

    private func createRejectingKripke() -> TestKripkeStructure {
        // Create a structure that should not satisfy the deeply nested formula

        let states = [
            KripkeState(id: "r0", propositions: ["p"]),                    // Initial state with p
            KripkeState(id: "r1", propositions: ["p"]),                    // Still only p, no q
            KripkeState(id: "r2", propositions: ["r"]),                    // Has r, but q is missing
            KripkeState(id: "r3", propositions: ["r", "s"]),               // Has r and s
            KripkeState(id: "r4", propositions: ["s"])                     // Has s, but t is missing
        ]

        let transitions = [
            KripkeTransition(from: "r0", to: "r1"),
            KripkeTransition(from: "r1", to: "r2"),
            KripkeTransition(from: "r2", to: "r3"),
            KripkeTransition(from: "r3", to: "r4"),
            KripkeTransition(from: "r4", to: "r0")  // Loop back to start
        ]

        return TestKripkeStructure(
            states: states,
            initialState: "r0",
            transitions: transitions
        )
    }

    private func createCyclicKripke() -> TestKripkeStructure {
        // Create a cyclic structure specifically designed for testing
        // G F (p & X (q U r))

        let states = [
            KripkeState(id: "c0", propositions: ["p"]),                     // Initial state with p
            KripkeState(id: "c1", propositions: ["q"]),                     // Has q
            KripkeState(id: "c2", propositions: ["q"]),                     // Still has q
            KripkeState(id: "c3", propositions: ["r"]),                     // Has r
            KripkeState(id: "c4", propositions: ["p"]),                     // Has p again
            KripkeState(id: "c5", propositions: ["q"]),                     // Has q
            KripkeState(id: "c6", propositions: ["r", "p"])                 // Has r and p
        ]

        let transitions = [
            KripkeTransition(from: "c0", to: "c1"),
            KripkeTransition(from: "c1", to: "c2"),
            KripkeTransition(from: "c2", to: "c3"),
            KripkeTransition(from: "c3", to: "c4"),
            KripkeTransition(from: "c4", to: "c5"),
            KripkeTransition(from: "c5", to: "c6"),
            KripkeTransition(from: "c6", to: "c0")  // Complete cycle
        ]

        return TestKripkeStructure(
            states: states,
            initialState: "c0",
            transitions: transitions
        )
    }

    private func createLargeKripke(stateCount: Int) -> TestKripkeStructure {
        var states: [KripkeState] = []
        var transitions: [KripkeTransition] = []

        // Create states with different proposition patterns
        for i in 0..<stateCount {
            var props: [String] = []

            // Assign propositions based on state number patterns
            if i % 2 == 0 { props.append("p") }
            if i % 3 == 0 { props.append("q") }
            if i % 5 == 0 { props.append("r") }
            if i % 7 == 0 { props.append("s") }
            if i % 11 == 0 { props.append("t") }

            states.append(KripkeState(id: "l\(i)", propositions: props))
        }

        // Create transitions - linear path with branches and loops
        for i in 0..<(stateCount - 1) {
            // Linear path: each state transitions to the next state
            transitions.append(KripkeTransition(from: "l\(i)", to: "l\(i + 1)"))

            // Add some loops and branches
            if i % 4 == 0 && i > 0 {
                // Loop back to a previous state
                transitions.append(KripkeTransition(from: "l\(i)", to: "l\(i - 1)"))
            }

            if i % 3 == 0 && i < stateCount - 2 {
                // Skip ahead one state
                transitions.append(KripkeTransition(from: "l\(i)", to: "l\(i + 2)"))
            }

            if i % 5 == 0 && i > 4 {
                // Create longer loops
                transitions.append(KripkeTransition(from: "l\(i)", to: "l\(i - 4)"))
            }
        }

        // Make the last state loop back to prevent terminal states
        transitions.append(KripkeTransition(from: "l\(stateCount - 1)", to: "l\(stateCount / 2)"))

        return TestKripkeStructure(
            states: states,
            initialState: "l0",
            transitions: transitions
        )
    }
}
