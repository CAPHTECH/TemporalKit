import Testing
@testable import TemporalKit
import Foundation

@Suite("LTLFormula step() Temporal Basic Tests")
struct LTLFormulaStepTemporalBasicTests {
    
    // MARK: - Helper Structures (similar to LTLFormulaTraceExtensionTests)
    struct TestState { let index: Int; let value: Bool } // value for direct prop eval
    struct TestEvalContext: EvaluationContext {
        let state: TestState
        let _traceIndex: Int
        init(state: TestState, traceIndex: Int) {
            self.state = state
            self._traceIndex = traceIndex
        }
        // Simplified currentStateAs for these tests; propositions will directly use TestState
        func currentStateAs<T>(_ type: T.Type) -> T? {
            if type == TestState.self {
                return state as? T
            }
            return nil
        }
        var traceIndex: Int? { _traceIndex }
    }

    static func makeProp(id: String, evalLogic: @escaping @Sendable (TestState) throws -> Bool) -> ClosureTemporalProposition<TestState, Bool> { // Changed to throws
        ClosureTemporalProposition(id: id, name: id, evaluate: evalLogic) // Changed label to evaluate
    }

    static let p_eval_true = makeProp(id: "p_true") { $0.value == true }
    static let p_eval_false = makeProp(id: "p_false") { state -> Bool in state.value == false } // Example, usually prop name implies truth
    enum DeliberateError: Error { case testError }
    static let p_eval_throws = makeProp(id: "p_throws") { _ in throw DeliberateError.testError }
    static let p_eval_true_next_true = makeProp(id: "p_true_next_true") { $0.value == true } // Added missing prop

    typealias TestFormula = LTLFormula<ClosureTemporalProposition<TestState, Bool>>

    // MARK: - Next operator tests

    @Test("step for .next - X P_true")
    func testStepNext_PropTrue() throws {
        let subFormula: TestFormula = .atomic(Self.p_eval_true)
        let formula: TestFormula = .next(subFormula)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Context irrelevant for .next's own step

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == subFormula)
    }

    @Test("step for .next - X P_false_literal")
    func testStepNext_PropFalseLiteral() throws {
        let subFormula: TestFormula = .booleanLiteral(false)
        let formula: TestFormula = .next(subFormula)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == subFormula)
    }

    @Test("step for .next - X P_nonLiteral_compound")
    func testStepNext_PropNonLiteralCompound() throws {
        let subFormula: TestFormula = .and(.atomic(Self.p_eval_true), .atomic(Self.p_eval_false))
        let formula: TestFormula = .next(subFormula)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == subFormula)
    }

    @Test("step for .next - X P_throws (should not throw in current step)")
    func testStepNext_PropThrows() throws {
        let subFormula: TestFormula = .atomic(Self.p_eval_throws)
        let formula: TestFormula = .next(subFormula)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == subFormula) // The throwing prop is passed as the next obligation
    }

    // MARK: - Eventually (F) operator tests

    @Test("step for .eventually (F P) - P holds now")
    func testStepEventually_PHoldsNow() throws {
        let p: TestFormula = .atomic(Self.p_eval_true)
        let formula: TestFormula = .eventually(p)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Makes p_eval_true evaluate to true

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .eventually (F P) - P does not hold now")
    func testStepEventually_PNotHoldsNow() throws {
        let p: TestFormula = .atomic(Self.p_eval_true) // Using p_eval_true
        let formula: TestFormula = .eventually(p)
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0) // Makes p_eval_true evaluate to false

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        // Since p does not hold now, F p continues as the next obligation
        #expect(nextFormula == formula)
    }

    @Test("step for .eventually (F P) - P throws")
    func testStepEventually_PThrows() throws {
        let p: TestFormula = .atomic(Self.p_eval_throws)
        let formula: TestFormula = .eventually(p)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    // MARK: - Globally (G) operator tests

    @Test("step for .globally (G P) - P holds now")
    func testStepGlobally_PHoldsNow() throws {
        let p: TestFormula = .atomic(Self.p_eval_true)
        let formula: TestFormula = .globally(p)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Makes p_eval_true evaluate to true

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == formula) // Next obligation is G P itself (self)
    }

    @Test("step for .globally (G P) - P does not hold now")
    func testStepGlobally_PNotHoldsNow() throws {
        let p: TestFormula = .atomic(Self.p_eval_true) // Using p_eval_true
        let formula: TestFormula = .globally(p)
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0) // Makes p_eval_true evaluate to false

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        // Since P does not hold now, G P fails immediately
        #expect(nextFormula == .booleanLiteral(false))
    }

    @Test("step for .globally (G P) - P throws")
    func testStepGlobally_PThrows() throws {
        let p: TestFormula = .atomic(Self.p_eval_throws)
        let formula: TestFormula = .globally(p)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }
}