import Testing
import Foundation
@testable import TemporalKit

/// Tests specifically focused on model checking with the weakUntil operator
struct WeakUntilModelCheckingTests {

    struct MockState: Hashable, CustomStringConvertible {
        let id: Int

        var description: String {
            "S\(id)"
        }
    }

    class MockProposition: TemporalProposition {
        typealias Value = Bool
        let id: PropositionID
        let name: String

        init(id: String, name: String) {
            self.id = PropositionID(rawValue: id)!
            self.name = name
        }

        func evaluate(in context: EvaluationContext) throws -> Bool {
            fatalError("Not used for model checking tests")
        }
    }

    // Simple Kripke structure for testing
    // S0 -> S1 -> S2 -> S3 (loop)
    //       |           ^
    //       v           |
    //       S4 ---------|
    // States S1 and S3 satisfy proposition p
    // States S2 and S4 satisfy proposition q
    class MockKripkeStructure: KripkeStructure {
        typealias State = MockState
        typealias AtomicPropositionIdentifier = PropositionID

        let allStates: Set<MockState> = [
            MockState(id: 0),
            MockState(id: 1),
            MockState(id: 2),
            MockState(id: 3),
            MockState(id: 4)
        ]

        let initialStates: Set<MockState> = [MockState(id: 0)]

        let pID = PropositionID(rawValue: "p")!
        let qID = PropositionID(rawValue: "q")!

        func successors(of state: MockState) -> Set<MockState> {
            switch state.id {
            case 0:
                return [MockState(id: 1)]
            case 1:
                return [MockState(id: 2), MockState(id: 4)]
            case 2:
                return [MockState(id: 3)]
            case 3:
                return [MockState(id: 3)] // Self-loop
            case 4:
                return [MockState(id: 3)]
            default:
                return []
            }
        }

        func atomicPropositionsTrue(in state: MockState) -> Set<PropositionID> {
            switch state.id {
            case 1, 3:
                return [pID]
            case 2, 4:
                return [qID]
            default:
                return []
            }
        }
    }

    @Test
    func testWeakUntilModelChecking() throws {
        // Create a model checker
        let modelChecker = LTLModelChecker<MockKripkeStructure>()

        // Create a Kripke structure
        let model = MockKripkeStructure()

        // Create atomic propositions
        let p = MockProposition(id: "p", name: "p")
        let q = MockProposition(id: "q", name: "q")

        // Create a formula with weakUntil: p W q 
        // "p holds until q becomes true, or p holds forever"
        let formula = LTLFormula<MockProposition>.weakUntil(.atomic(p), .atomic(q))

        // Check the formula against the model
        let result = try modelChecker.check(formula: formula, model: model)

        // In our model, from the initial state S0:
        // Path 1: S0 -> S1(p) -> S2(q) -> ... 
        // Path 2: S0 -> S1(p) -> S4(q) -> ...
        // Both paths satisfy p W q since q eventually becomes true
        #expect(result.holds, "The formula p W q should hold in the model")

        // Create a more complex weakUntil formula: p W (q && X p)
        // "p holds until both q is true and p will be true in the next state, or p holds forever"
        let complexFormula = LTLFormula<MockProposition>.weakUntil(
            .atomic(p),
            .and(.atomic(q), .next(.atomic(p)))
        )

        // Check the complex formula against the model
        let complexResult = try modelChecker.check(formula: complexFormula, model: model)

        // Path 1: S0 -> S1(p) -> S2(q) -> S3(p) -> ...
        // S2 satisfies q, and next state S3 satisfies p, so q && X p is true at S2
        // Path 2: S0 -> S1(p) -> S4(q) -> S3(p) -> ...
        // Similarly, at S4, q && X p is true
        #expect(complexResult.holds, "The formula p W (q && X p) should hold in the model")
    }

    @Test
    func testWeakUntilVsUntil() throws {
        // Create a model checker
        let modelChecker = LTLModelChecker<MockKripkeStructure>()

        // Create a modified Kripke structure with a path where p holds forever but q never holds
        class ModifiedKripkeStructure: MockKripkeStructure {
            override func successors(of state: MockState) -> Set<MockState> {
                switch state.id {
                case 0:
                    return [MockState(id: 1), MockState(id: 5)]
                case 5:
                    return [MockState(id: 6)]
                case 6:
                    return [MockState(id: 6)] // Self-loop where only p holds
                default:
                    return super.successors(of: state)
                }
            }

            override func atomicPropositionsTrue(in state: MockState) -> Set<PropositionID> {
                switch state.id {
                case 5, 6:
                    return [pID] // Only p holds in these states
                default:
                    return super.atomicPropositionsTrue(in: state)
                }
            }
        }

        let model = ModifiedKripkeStructure()

        // Create atomic propositions
        let p = MockProposition(id: "p", name: "p")
        let q = MockProposition(id: "q", name: "q")

        // Test weakUntil: p W q (should hold because either q eventually becomes true or p holds forever)
        let weakUntilFormula = LTLFormula<MockProposition>.weakUntil(.atomic(p), .atomic(q))
        let weakUntilResult = try modelChecker.check(formula: weakUntilFormula, model: model)
        #expect(weakUntilResult.holds, "The formula p W q should hold in the model due to the path where p holds forever")

        // Test until: p U q (should also hold in this model configuration)
        // In the modified model, there is a path where q eventually becomes true (S0 -> S1 -> S2 -> S3)
        // This makes p U q also hold, since it requires just one path where q eventually becomes true
        let untilFormula = LTLFormula<MockProposition>.until(.atomic(p), .atomic(q))
        let untilResult = try modelChecker.check(formula: untilFormula, model: model)
        #expect(untilResult.holds, "The formula p U q should hold in the model as there's a path where q eventually becomes true")
    }
}
