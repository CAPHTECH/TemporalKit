import Testing
@testable import TemporalKit
import Foundation

@Suite("LTLFormula step() Temporal Advanced Tests")
struct LTLFormulaStepTemporalAdvancedTests {
    
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

    // MARK: - Until (U) operator tests

    @Test("step for .until (P U Q) - Q holds now")
    func testStepUntil_QHoldsNow() throws {
        let p: TestFormula = .atomic(Self.p_eval_false) // P can be anything if Q holds
        let q: TestFormula = .atomic(Self.p_eval_true)
        let formula: TestFormula = .until(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Makes q_eval_true true

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .until (P U Q) - Q not holds, P holds now")
    func testStepUntil_QNotHolds_PHoldsNow() throws {
        let p: TestFormula = .atomic(Self.p_eval_true)
        let q: TestFormula = .atomic(Self.p_eval_false)
        let formula: TestFormula = .until(p, q)
        // Context: p_eval_true is true, p_eval_false is false (so q is false)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        // Since q.next is false, the until obligation can never be satisfied
        #expect(nextFormula == .booleanLiteral(false))
    }

    @Test("step for .until (P U Q) - Q not holds, P not holds now")
    func testStepUntil_QNotHolds_PNotHoldsNow() throws {
        // We need P to be false and Q to be false with the same context.
        // Context: TestState(index: 0, value: false)
        // p_eval_true logic: { $0.value == true }. With value:false, this is false.
        let p_is_false: TestFormula = .atomic(Self.p_eval_true)
        let q_is_false: TestFormula = .atomic(Self.p_eval_true) // Corrected: q should also be false in this context.
        let formula: TestFormula = .until(p_is_false, q_is_false)
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false))
    }

    @Test("step for .until (P U Q) - Q throws")
    func testStepUntil_QThrows() throws {
        let p: TestFormula = .atomic(Self.p_eval_true)
        let q: TestFormula = .atomic(Self.p_eval_throws)
        let formula: TestFormula = .until(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    @Test("step for .until (P U Q) - Q false, P throws")
    func testStepUntil_QFalse_PThrows() throws {
        let p: TestFormula = .atomic(Self.p_eval_throws)
        let q: TestFormula = .booleanLiteral(false) // Q is definitively false
        let formula: TestFormula = .until(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    // MARK: - Weak Until (W) operator tests

    @Test("step for .weakUntil (P W Q) - Q holds now")
    func testStepWeakUntil_QHoldsNow() throws {
        let p: TestFormula = .atomic(Self.p_eval_false) // P can be anything if Q holds
        let q: TestFormula = .atomic(Self.p_eval_true)
        let formula: TestFormula = .weakUntil(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Makes q_eval_true true

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .weakUntil (P W Q) - Q not holds, P holds now")
    func testStepWeakUntil_QNotHolds_PHoldsNow() throws {
        let p: TestFormula = .atomic(Self.p_eval_true)
        let q: TestFormula = .atomic(Self.p_eval_false)
        let formula: TestFormula = .weakUntil(p, q)
        // Context: p_eval_true is true, p_eval_false is false (so q is false)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == formula) // Next obligation is P W Q itself
    }

    @Test("step for .weakUntil (P W Q) - Q not holds, P not holds now")
    func testStepWeakUntil_QNotHolds_PNotHoldsNow() throws {
        // We need P to be false and Q to be false with the same context.
        // Context: TestState(index: 0, value: false)
        // p_eval_true logic: { $0.value == true }. With value:false, this is false.
        let p_is_false: TestFormula = .atomic(Self.p_eval_true)
        let q_is_false: TestFormula = .atomic(Self.p_eval_true)
        let formula: TestFormula = .weakUntil(p_is_false, q_is_false)
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false))
    }

    @Test("step for .weakUntil (P W Q) - Q throws")
    func testStepWeakUntil_QThrows() throws {
        let p: TestFormula = .atomic(Self.p_eval_true)
        let q: TestFormula = .atomic(Self.p_eval_throws)
        let formula: TestFormula = .weakUntil(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    @Test("step for .weakUntil (P W Q) - Q false, P throws")
    func testStepWeakUntil_QFalse_PThrows() throws {
        let p: TestFormula = .atomic(Self.p_eval_throws)
        let q: TestFormula = .booleanLiteral(false) // Q is definitively false
        let formula: TestFormula = .weakUntil(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    // MARK: - Release (R) operator tests

    @Test("step for .release (P R Q) - Q is false now")
    func testStepRelease_QFalse() throws {
        let p: TestFormula = .atomic(Self.p_eval_true) // P can be anything
        let q: TestFormula = .atomic(Self.p_eval_false) // Q is intended to be false
        let formula: TestFormula = .release(p, q)
        // Context: To make q (.atomic(p_eval_false)) evaluate to false, state.value must be true.
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Corrected context

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false))
    }

    @Test("step for .release (P R Q) - Q true, P true")
    func testStepRelease_QTrue_PTrue() throws {
        let p: TestFormula = .atomic(Self.p_eval_true)
        let q: TestFormula = .atomic(Self.p_eval_true)
        let formula: TestFormula = .release(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Makes both P and Q true

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .release (P R Q) - Q true, P false")
    func testStepRelease_QTrue_PFalse() throws {
        let p: TestFormula = .atomic(Self.p_eval_false) // P is false
        let q: TestFormula = .atomic(Self.p_eval_true)  // Q is true
        let formula: TestFormula = .release(p, q)
        // Context: value=true makes p_eval_false false, and p_eval_true true.
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == formula) // Next obligation is P R Q itself (self)
    }

    @Test("step for .release (P R Q) - Q throws")
    func testStepRelease_QThrows() throws {
        let p: TestFormula = .atomic(Self.p_eval_true)
        let q: TestFormula = .atomic(Self.p_eval_throws)
        let formula: TestFormula = .release(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    @Test("step for .release (P R Q) - Q true, P throws")
    func testStepRelease_QTrue_PThrows() throws {
        let p: TestFormula = .atomic(Self.p_eval_throws)
        let q: TestFormula = .booleanLiteral(true) // Q is definitively true
        let formula: TestFormula = .release(p, q)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }
}