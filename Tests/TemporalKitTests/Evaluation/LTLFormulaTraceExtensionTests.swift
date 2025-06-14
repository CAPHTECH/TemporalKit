import Testing
@testable import TemporalKit
import Foundation

@Suite("LTLFormula+TraceEvaluation Tests")
struct LTLFormulaTraceExtensionTests {

    // MARK: - Helper Structures from LTLFormulaTraceEvaluationTests
    // (Consider refactoring these into a shared test utility if used in many places)
    struct TestState { let index: Int }
    struct TestEvalContext: EvaluationContext {
        let state: TestState
        let _traceIndex: Int
        init(state: TestState, traceIndex: Int) {
            self.state = state
            self._traceIndex = traceIndex
        }
        func currentStateAs<T>(_ type: T.Type) -> T? { state as? T } // Simplified for this test context
        var traceIndex: Int? { _traceIndex }
    }
    static func createTrace(length: Int) -> [TestEvalContext] {
        (0..<length).map { TestEvalContext(state: TestState(index: $0), traceIndex: $0) }
    }
    static func createTrace(from bools: [Bool]) -> [TestEvalContext] {
        bools.enumerated().map { TestEvalContext(state: TestState(index: $1 ? 1 : 0), traceIndex: $0) }
    }

    static let p_true_prop = ClosureTemporalProposition<TestState, Bool>(id: "p_true", name: "Always True") { _ in true }
    static let p_false_prop = ClosureTemporalProposition<TestState, Bool>(id: "p_false", name: "Always False") { _ in false }
    enum DeliberateError: Error { case testError }
    static let p_throws_prop = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "Always Throws") { _ in throw DeliberateError.testError }

    typealias TestFormula = LTLFormula<ClosureTemporalProposition<TestState, Bool>>

    static let ltl_true: TestFormula = .atomic(p_true_prop)
    static let ltl_false: TestFormula = .atomic(p_false_prop)
    static let ltl_throws: TestFormula = .atomic(p_throws_prop)

    // MARK: - evaluate(over:) Tests

    @Test("evaluate over empty trace throws error")
    func testEvaluateOverEmptyTraceThrows() throws {
        let trace: [TestEvalContext] = []
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try Self.ltl_true.evaluate(over: trace)
        }
    }

    @Test("evaluate over trace - atomic true")
    func testEvaluateOverAtomicTrue() throws {
        let trace = Self.createTrace(length: 3)
        #expect(try Self.ltl_true.evaluate(over: trace) == true)
    }

    @Test("evaluate over trace - atomic false")
    func testEvaluateOverAtomicFalse() throws {
        let trace = Self.createTrace(length: 3)
        #expect(try Self.ltl_false.evaluate(over: trace) == false)
    }

    @Test("evaluate over trace - atomic true with debug handler")
    func testEvaluateOverAtomicTrueWithDebugHandler() throws {
        let trace = Self.createTrace(length: 3)
        var debugMessages: [String] = []
        #expect(try Self.ltl_true.evaluate(over: trace, debugHandler: { debugMessages.append($0) }) == true)
        #expect(!debugMessages.isEmpty)
    }

    @Test("evaluate over trace - atomic throws propagates")
    func testEvaluateOverAtomicThrows() throws {
        let trace = Self.createTrace(length: 3)
        #expect(throws: DeliberateError.testError) { // Expect DeliberateError.testError directly
            _ = try Self.ltl_throws.evaluate(over: trace)
        }
    }

    @Test("evaluate over trace - G p_true")
    func testEvaluateOverGloballyTrue() throws {
        let trace = Self.createTrace(length: 3)
        let formula: TestFormula = .globally(Self.ltl_true)
        #expect(try formula.evaluate(over: trace) == true)
    }

    @Test("evaluate over trace - G p_true with debug handler")
    func testEvaluateOverGloballyTrueWithDebugHandler() throws {
        let trace = Self.createTrace(length: 3)
        let formula: TestFormula = .globally(Self.ltl_true)
        var debugMessages: [String] = []
        #expect(try formula.evaluate(over: trace, debugHandler: { debugMessages.append($0) }) == true)
        #expect(!debugMessages.isEmpty)
    }

    @Test("evaluate over trace - G p_false")
    func testEvaluateOverGloballyFalse() throws {
        let trace = Self.createTrace(length: 3)
        let formula: TestFormula = .globally(Self.ltl_false)
        #expect(try formula.evaluate(over: trace) == false)
    }

    @Test("evaluate over trace - G (p eventually becomes false)")
    func testEvaluateOverGloballyEventuallyFalse() throws {
        let p_idx_eq_0 = ClosureTemporalProposition<TestState, Bool>(id: "p_idx_0", name: "idx==0") { state in
            state.index == 0
        }
        let formula: TestFormula = .globally(.atomic(p_idx_eq_0))
        let trace = Self.createTrace(length: 3) // p_idx_eq_0 is true at s0, false at s1, s2
        #expect(try formula.evaluate(over: trace) == false)
    }

    @Test("evaluate over trace - G (p eventually becomes false) with debug handler")
    func testEvaluateOverGloballyEventuallyFalseWithDebugHandler() throws {
        let p_idx_eq_0 = ClosureTemporalProposition<TestState, Bool>(id: "p_idx_0", name: "idx==0") { state in
            state.index == 0
        }
        let formula: TestFormula = .globally(.atomic(p_idx_eq_0))
        let trace = Self.createTrace(length: 3) // p_idx_eq_0 is true at s0, false at s1, s2
        var debugMessages: [String] = []
        #expect(try formula.evaluate(over: trace, debugHandler: { debugMessages.append($0) }) == false)
        #expect(!debugMessages.isEmpty)
    }

    @Test("evaluate over trace - F p_false")
    func testEvaluateOverEventuallyFalse() throws {
        let trace = Self.createTrace(length: 3)
        let formula: TestFormula = .eventually(Self.ltl_false)
        #expect(try formula.evaluate(over: trace) == false)
    }

    @Test("evaluate over trace - F p_true")
    func testEvaluateOverEventuallyTrue() throws {
        let trace = Self.createTrace(length: 3)
        let formula: TestFormula = .eventually(Self.ltl_true)
        #expect(try formula.evaluate(over: trace) == true)
    }

    @Test("evaluate over trace - F (p eventually becomes true)")
    func testEvaluateOverEventuallyBecomesTrue() throws {
        let p_idx_eq_2 = ClosureTemporalProposition<TestState, Bool>(id: "p_idx_2", name: "idx==2") { state in
            state.index == 2
        }
        let formula: TestFormula = .eventually(.atomic(p_idx_eq_2))
        let trace = Self.createTrace(length: 3) // p_idx_eq_2 is false at s0,s1, true at s2
        #expect(try formula.evaluate(over: trace) == true)
    }

    @Test("evaluate over trace - F (p eventually becomes true) with debug handler")
    func testEvaluateOverEventuallyBecomesTrueWithDebugHandler() throws {
        let p_idx_eq_2 = ClosureTemporalProposition<TestState, Bool>(id: "p_idx_2", name: "idx==2") { state in
            state.index == 2
        }
        let formula: TestFormula = .eventually(.atomic(p_idx_eq_2))
        let trace = Self.createTrace(length: 3) // p_idx_eq_2 is false at s0,s1, true at s2
        var debugMessages: [String] = []
        #expect(try formula.evaluate(over: trace, debugHandler: { debugMessages.append($0) }) == true)
        #expect(!debugMessages.isEmpty)
    }

    @Test("evaluate over trace - X p succeeds")
    func testEvaluateOverNextSucceeds() throws {
        let trace = Self.createTrace(length: 2) // s0, s1
        let p_idx_eq_1 = ClosureTemporalProposition<TestState, Bool>(id: "p_idx_1", name: "idx==1") { state in
            state.index == 1
        }
        let formula: TestFormula = .next(.atomic(p_idx_eq_1))
        #expect(try formula.evaluate(over: trace) == true)
    }

    @Test("evaluate over trace - boolean literal next formula returns early")
    func testEvaluateOverBooleanLiteralNextReturnsEarly() throws {
        let trace = Self.createTrace(length: 5)
        let formula: TestFormula = .not(Self.ltl_true) // This becomes .booleanLiteral(false)
        #expect(try formula.evaluate(over: trace) == false)
    }

    @Test("evaluate over trace - boolean literal next formula returns early with debug handler")
    func testEvaluateOverBooleanLiteralNextReturnsEarlyWithDebugHandler() throws {
        let trace = Self.createTrace(length: 5)
        let formula: TestFormula = .not(Self.ltl_true) // This becomes .booleanLiteral(false) after first step
        var debugMessages: [String] = []
        #expect(try formula.evaluate(over: trace, debugHandler: { debugMessages.append($0) }) == false)
        #expect(!debugMessages.isEmpty)
    }

    @Test("evaluate over trace - X (X p) with too short trace throws inconclusive")
    func testEvaluateOverNextAtEndOfTraceThrowsInconclusive() throws {
        let trace = Self.createTrace(length: 1) // s0. Needs at least 2 states for X(Xp) to resolve beyond a .next
        let formula: TestFormula = .next(.next(.atomic(Self.p_true_prop)))

        var thrownError: Error?
        do {
            _ = try formula.evaluate(over: trace)
        } catch {
            thrownError = error
        }
        #expect(thrownError is LTLTraceEvaluationError)
        if case .inconclusiveEvaluation = (thrownError as? LTLTraceEvaluationError) {
            // Correct error type and case
        } else {
            Issue.record("Expected .inconclusiveEvaluation, got \(String(describing: thrownError))")
        }
    }

    // MARK: - evaluateAt(_:) Tests

    @Test("evaluateAt atomic true")
    func testEvaluateAtAtomicTrue() throws {
        let context = TestEvalContext(state: TestState(index: 0), traceIndex: 0)
        #expect(try Self.ltl_true.evaluateAt(context) == true)
    }

    @Test("evaluateAt atomic false")
    func testEvaluateAtAtomicFalse() throws {
        let context = TestEvalContext(state: TestState(index: 0), traceIndex: 0)
        #expect(try Self.ltl_false.evaluateAt(context) == false)
    }

    @Test("evaluateAt atomic throws")
    func testEvaluateAtAtomicThrows() throws {
        let context = TestEvalContext(state: TestState(index: 0), traceIndex: 0)
        var thrownError: Error?
        do {
            _ = try Self.ltl_throws.evaluateAt(context)
        } catch {
            thrownError = error
        }
        #expect(thrownError is LTLTraceEvaluationError)
        if case .propositionEvaluationFailure = (thrownError as? LTLTraceEvaluationError) {
            // Correct error type and case
        } else {
            Issue.record("Expected .propositionEvaluationFailure, got \(String(describing: thrownError))")
        }
    }

    @Test("evaluate over trace - F p_false with debug handler (never satisfied)")
    func testEvaluateOverEventuallyFalseWithDebugHandler() throws {
        let trace = Self.createTrace(length: 3)
        let formula: TestFormula = .eventually(Self.ltl_false)
        var debugMessages: [String] = []
        #expect(try formula.evaluate(over: trace, debugHandler: { debugMessages.append($0) }) == false)
        #expect(!debugMessages.isEmpty)
    }
}
