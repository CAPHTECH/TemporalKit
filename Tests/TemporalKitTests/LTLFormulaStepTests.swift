import Testing
@testable import TemporalKit
import Foundation

@Suite("LTLFormula step() Tests")
struct LTLFormulaStepTests {

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

    // MARK: - Atomic Proposition Tests
    @Test("step for .atomic when proposition evaluates to true")
    func testStepAtomic_PropTrue() throws {
        let formula: TestFormula = .atomic(Self.p_eval_true)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)

        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .atomic when proposition evaluates to false")
    func testStepAtomic_PropFalse() throws {
        // Using p_eval_true but context makes it false
        let formula: TestFormula = .atomic(Self.p_eval_true)
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)

        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false))
    }

    @Test("step for .atomic when proposition throws")
    func testStepAtomic_PropThrows() throws {
        let formula: TestFormula = .atomic(Self.p_eval_throws)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    // MARK: - Boolean Literal Tests
    @Test("step for .booleanLiteral(true)")
    func testStepBooleanLiteral_True() throws {
        let formula: TestFormula = .booleanLiteral(true)
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0) // Context content doesn't matter
        let (holdsNow, nextFormula) = try formula.step(with: context)

        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .booleanLiteral(false)")
    func testStepBooleanLiteral_False() throws {
        let formula: TestFormula = .booleanLiteral(false)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Context content doesn't matter
        let (holdsNow, nextFormula) = try formula.step(with: context)

        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false))
    }

    // MARK: - And operator tests

    @Test("step for .and - true && true")
    func testStepAnd_TrueTrue() throws {
        let formula: TestFormula = .and(.booleanLiteral(true), .booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true)) // true && true -> next is true
    }

    @Test("step for .and - true && false")
    func testStepAnd_TrueFalse() throws {
        let formula: TestFormula = .and(.booleanLiteral(true), .booleanLiteral(false))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false)) // true && false -> next is false
    }

    @Test("step for .and - false && true")
    func testStepAnd_FalseTrue() throws {
        let formula: TestFormula = .and(.booleanLiteral(false), .booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false)) // false && true -> next is false
    }

    @Test("step for .and - false && false")
    func testStepAnd_FalseFalse() throws {
        let formula: TestFormula = .and(.booleanLiteral(false), .booleanLiteral(false))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false)) // false && false -> next is false
    }

    @Test("step for .and - P1_true (next non-literal) && P2_true (next non-literal)")
    func testStepAnd_NonLiteralNext() throws {
        let p1: TestFormula = .next(.atomic(Self.p_eval_true)) // p1.step -> (true, .atomic(p_true))
        let p2: TestFormula = .next(.atomic(Self.p_eval_false)) // p2.step -> (true, .atomic(p_false))
        let formula: TestFormula = .and(p1, p2)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // true (p1 holdsNow) && true (p2 holdsNow)
        // next: .atomic(p_true) && .atomic(p_false)
        #expect(nextFormula == .and(.atomic(Self.p_eval_true), .atomic(Self.p_eval_false)))
    }

    @Test("step for .and - P1_true.next=true && P2_nonLit (simplification)")
    func testStepAnd_LhsNextTrueSimplification() throws {
        let p1: TestFormula = .atomic(Self.p_eval_true_next_true) // p1.step -> (true, .booleanLiteral(true))
        let p2: TestFormula = .next(.atomic(Self.p_eval_false)) // p2.step -> (true, .atomic(p_false))
        let formula: TestFormula = .and(p1, p2)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        // next: true && .atomic(p_false) -> .atomic(p_false)
        #expect(nextFormula == .atomic(Self.p_eval_false))
    }

    @Test("step for .and - P1_nonLit && P2_true.next=true (simplification)")
    func testStepAnd_RhsNextTrueSimplification() throws {
        let p1: TestFormula = .next(.atomic(Self.p_eval_false)) // p1.step -> (true, .atomic(p_false))
        let p2: TestFormula = .atomic(Self.p_eval_true_next_true) // p2.step -> (true, .booleanLiteral(true))
        let formula: TestFormula = .and(p1, p2)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        // next: .atomic(p_false) && true -> .atomic(p_false)
        #expect(nextFormula == .atomic(Self.p_eval_false))
    }

    @Test("step for .and - Error in LHS propagates")
    func testStepAnd_LhsThrows() throws {
        let formula: TestFormula = .and(.atomic(Self.p_eval_throws), .booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    @Test("step for .and - Error in RHS propagates (after LHS eval)")
    func testStepAnd_RhsThrows() throws {
        let formula: TestFormula = .and(.booleanLiteral(true), .atomic(Self.p_eval_throws))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    // MARK: - Not operator tests

    @Test("step for .not - not(true)")
    func testStepNot_True() throws {
        let formula: TestFormula = .not(.booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0) // Context irrelevant
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false))
    }

    @Test("step for .not - not(false)")
    func testStepNot_False() throws {
        let formula: TestFormula = .not(.booleanLiteral(false))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0) // Context irrelevant
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .not - not(X P_true) where next is non-literal")
    func testStepNot_NextNonLiteral() throws {
        let subFormula: TestFormula = .next(.atomic(Self.p_eval_true))
        // subFormula.step will yield (true, .atomic(Self.p_eval_true))
        let formula: TestFormula = .not(subFormula)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // value: true for p_eval_true

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false) // not(true) is false
        #expect(nextFormula == .not(.atomic(Self.p_eval_true))) // not(atomic(p_true))
    }

    @Test("step for .not - Error in subformula propagates")
    func testStepNot_SubFormulaThrows() throws {
        let formula: TestFormula = .not(.atomic(Self.p_eval_throws))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    // MARK: - Or operator tests

    @Test("step for .or - true || true")
    func testStepOr_TrueTrue() throws {
        let formula: TestFormula = .or(.booleanLiteral(true), .booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .or - true || false")
    func testStepOr_TrueFalse() throws {
        let formula: TestFormula = .or(.booleanLiteral(true), .booleanLiteral(false))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true)) // true || X -> true
    }

    @Test("step for .or - false || true")
    func testStepOr_FalseTrue() throws {
        let formula: TestFormula = .or(.booleanLiteral(false), .booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true)
        #expect(nextFormula == .booleanLiteral(true)) // X || true -> true. Oh, wait. OR simplification. false || Y -> Y. So next should be true.
    }

    @Test("step for .or - false || false")
    func testStepOr_FalseFalse() throws {
        let formula: TestFormula = .or(.booleanLiteral(false), .booleanLiteral(false))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false)
        #expect(nextFormula == .booleanLiteral(false))
    }

    @Test("step for .or - P1_true (non-lit next) || P2_true (non-lit next)")
    func testStepOr_NonLiteralNextBothTrue() throws {
        let p1: TestFormula = .next(.atomic(Self.p_eval_true))  // steps to (true, .atomic(p_eval_true))
        let p2: TestFormula = .next(.atomic(Self.p_eval_false)) // steps to (true, .atomic(p_eval_false))
        let formula: TestFormula = .or(p1, p2)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // true || true
        // next: .atomic(p_eval_true) || .atomic(p_eval_false)
        #expect(nextFormula == .or(.atomic(Self.p_eval_true), .atomic(Self.p_eval_false)))
    }

    @Test("step for .or - false || P_nonLit (simplification: false || Y -> Y)")
    func testStepOr_LhsFalseSimplification() throws {
        let p1: TestFormula = .booleanLiteral(false) // steps to (false, .booleanLiteral(false))
        let p2: TestFormula = .next(.atomic(Self.p_eval_true)) // steps to (true, .atomic(p_eval_true))
        let formula: TestFormula = .or(p1, p2)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // false || true
        #expect(nextFormula == .atomic(Self.p_eval_true)) // false || .atomic(p_eval_true) -> .atomic(p_eval_true)
    }

    @Test("step for .or - P_nonLit || false (simplification: Y || false -> Y)")
    func testStepOr_RhsFalseSimplification() throws {
        let p1: TestFormula = .next(.atomic(Self.p_eval_true)) // steps to (true, .atomic(p_eval_true))
        let p2: TestFormula = .booleanLiteral(false) // steps to (false, .booleanLiteral(false))
        let formula: TestFormula = .or(p1, p2)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // true || false
        #expect(nextFormula == .atomic(Self.p_eval_true)) // .atomic(p_eval_true) || false -> .atomic(p_eval_true)
    }

    @Test("step for .or - Error in LHS propagates (LHS false)")
    func testStepOr_LhsThrows_LhsFalse() throws {
        let formula: TestFormula = .or(.atomic(Self.p_eval_throws), .booleanLiteral(true)) // If LHS non-throwing would be false || true
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
            // Error should propagate because evaluation of LHS happens before short-circuit check for OR.
            // Let's confirm the logic: OR short-circuits if LHS is true. If LHS is false or throws, RHS is evaluated.
            // If p_eval_throws -> (throws), then error propagates.
        }
    }

    @Test("step for .or - Error in RHS propagates (LHS false)")
    func testStepOr_RhsThrows_LhsFalse() throws {
        let formula: TestFormula = .or(.booleanLiteral(false), .atomic(Self.p_eval_throws))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    @Test("step for .or - LHS true, RHS throws (short-circuit evaluation)")
    func testStepOr_LhsTrue_RhsThrows_ShortCircuit() throws {
        let formula: TestFormula = .or(.booleanLiteral(true), .atomic(Self.p_eval_throws))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        // The OR implementation uses short-circuit evaluation, so when LHS.next is true,
        // RHS is not evaluated and no error should be thrown.
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true, "OR with LHS true should hold now")
        #expect(nextFormula == .booleanLiteral(true), "OR with LHS true next should be true")
    }

    // MARK: - Implies operator tests

    @Test("step for .implies - true -> true")
    func testStepImplies_TrueTrue() throws {
        let formula: TestFormula = .implies(.booleanLiteral(true), .booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // !true || true == true
        #expect(nextFormula == .booleanLiteral(true)) // next(!T || T) -> next(F || T) -> T
    }

    @Test("step for .implies - true -> false")
    func testStepImplies_TrueFalse() throws {
        let formula: TestFormula = .implies(.booleanLiteral(true), .booleanLiteral(false))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == false) // !true || false == false
        #expect(nextFormula == .booleanLiteral(false)) // next(!T || F) -> next(F || F) -> F
    }

    @Test("step for .implies - false -> true")
    func testStepImplies_FalseTrue() throws {
        let formula: TestFormula = .implies(.booleanLiteral(false), .booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // !false || true == true
        #expect(nextFormula == .booleanLiteral(true)) // next(!F || T) -> next(T || T) -> T
    }

    @Test("step for .implies - false -> false")
    func testStepImplies_FalseFalse() throws {
        let formula: TestFormula = .implies(.booleanLiteral(false), .booleanLiteral(false))
        let context = TestEvalContext(state: TestState(index: 0, value: false), traceIndex: 0)
        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // !false || false == true
        #expect(nextFormula == .booleanLiteral(true)) // next(!F || F) -> next(T || F) -> T
    }

    @Test("step for .implies - P_true_nextT -> Q_true_nextNonLit")
    func testStepImplies_LhsNextTrue_RhsNextNonLit() throws {
        let p1: TestFormula = .atomic(Self.p_eval_true_next_true)  // steps to (true, .booleanLiteral(true))
        let p2: TestFormula = .next(.atomic(Self.p_eval_false))     // steps to (true, .atomic(p_eval_false))
        let formula: TestFormula = .implies(p1, p2)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // !true || true == true
        // lhsNext = true. !lhsNext = false.
        // rhsNext = .atomic(p_eval_false)
        // nextFormula = .or(.booleanLiteral(false), .atomic(p_eval_false)) -> .atomic(p_eval_false)
        #expect(nextFormula == .atomic(Self.p_eval_false))
    }

    @Test("step for .implies - P_true_nextNonLit -> Q_true_nextT")
    func testStepImplies_LhsNextNonLit_RhsNextTrue() throws {
        let p1: TestFormula = .next(.atomic(Self.p_eval_true))     // steps to (true, .atomic(p_eval_true))
        let p2: TestFormula = .atomic(Self.p_eval_true_next_true)  // steps to (true, .booleanLiteral(true))
        let formula: TestFormula = .implies(p1, p2)
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: context)
        #expect(holdsNow == true) // !true || true == true
        // lhsNext = .atomic(p_eval_true). !lhsNext = .not(.atomic(p_eval_true)).
        // rhsNext = .booleanLiteral(true)
        // nextFormula = .or(.not(.atomic(p_eval_true)), .booleanLiteral(true)) -> .booleanLiteral(true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .implies - P_false_nextF -> Q_true_nextNonLit (LHS false implies current true)")
    func testStepImplies_LhsFalse_RhsNextNonLit() throws {
        let p1: TestFormula = .atomic(Self.p_eval_false) // steps to (false, .booleanLiteral(false))
        let p2: TestFormula = .next(.atomic(Self.p_eval_true))    // steps to (true, .atomic(p_eval_true))
        let formula: TestFormula = .implies(p1, p2)
        // Context: p_eval_false will make it evaluate to false for holdsNow in p1.step()
        let evalContext = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0) // Changed value to true for p1 to be false

        let (holdsNow, nextFormula) = try formula.step(with: evalContext)
        #expect(holdsNow == true) // !false || true == true
        // lhsNext = .booleanLiteral(false). !lhsNext = .booleanLiteral(true).
        // rhsNext = .atomic(p_eval_true).
        // nextFormula = .or(.booleanLiteral(true), .atomic(p_eval_true)) -> .booleanLiteral(true)
        #expect(nextFormula == .booleanLiteral(true))
    }

    @Test("step for .implies - P_true_nextNonLit -> Q_false_nextF (can result in false)")
    func testStepImplies_LhsTrue_RhsFalse() throws {
        let p1: TestFormula = .next(.atomic(Self.p_eval_true))    // steps to (true, .atomic(p_eval_true))
        let p2: TestFormula = .atomic(Self.p_eval_false) // steps to (false, .booleanLiteral(false))
        let formula: TestFormula = .implies(p1, p2)
        // Context: p_eval_true makes p1 holdsNow true, p_eval_false makes p2 holdsNow false.
        let evalContext = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)

        let (holdsNow, nextFormula) = try formula.step(with: evalContext)
        #expect(holdsNow == false) // !true || false == false
        // lhsNext = .atomic(p_eval_true). !lhsNext = .not(.atomic(p_eval_true)).
        // rhsNext = .booleanLiteral(false).
        // nextFormula = .or(.not(.atomic(p_eval_true)), .booleanLiteral(false)) -> .not(.atomic(p_eval_true))
        #expect(nextFormula == .not(.atomic(Self.p_eval_true)))
    }

    @Test("step for .implies - Error in LHS propagates")
    func testStepImplies_LhsThrows() throws {
        let formula: TestFormula = .implies(.atomic(Self.p_eval_throws), .booleanLiteral(true))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

    @Test("step for .implies - Error in RHS propagates")
    func testStepImplies_RhsThrows() throws {
        let formula: TestFormula = .implies(.booleanLiteral(false), .atomic(Self.p_eval_throws))
        let context = TestEvalContext(state: TestState(index: 0, value: true), traceIndex: 0)
        // !false || (throws) -> true || (throws). 
        // For holdsNow, it's true. But evaluating rhs.step() for nextFormula will throw.
        #expect(throws: DeliberateError.testError) {
            _ = try formula.step(with: context)
        }
    }

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
        // Context: To make q (.atomic(Self.p_eval_false)) evaluate to false, state.value must be true.
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
