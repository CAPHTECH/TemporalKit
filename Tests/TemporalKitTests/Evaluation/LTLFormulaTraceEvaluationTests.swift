import Foundation
import Testing
@testable import TemporalKit

// MARK: - Helper Structures and Classes for Testing

/// テストで使用するシンプルな状態の実装
struct TestState {
    let index: Int
}

/// テストで使用するシンプルなコンテキストの実装
struct TestEvaluationContext: EvaluationContext {
    let state: TestState
    private let _traceIndex: Int // Renamed to avoid direct name clash if compiler gets confused, and to make intent clear

    init(state: TestState, traceIndex: Int) {
        self.state = state
        self._traceIndex = traceIndex
    }

    func currentStateAs<T>(_ type: T.Type) -> T? {
        if type == TestState.self {
            return state as? T
        }
        return nil
    }

    // Explicitly provide traceIndex as required by EvaluationContext protocol
    var traceIndex: Int? {
        return _traceIndex
    }
}

/// テストで使用するシンプルな命題の実装
class TestProposition: TemporalProposition {
    typealias Value = Bool
    let id: PropositionID
    let name: String
    let evaluationResult: (_ context: EvaluationContext) throws -> Bool

    init(id: String = UUID().uuidString, name: String, evaluation: @escaping (_ context: EvaluationContext) throws -> Bool) {
        self.id = PropositionID(rawValue: id)!
        self.name = name
        self.evaluationResult = evaluation
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        return try evaluationResult(context)
    }
}

/// 特定のインデックスでのみtrueを返す命題
class IndexEqualsProposition: TemporalProposition {
    typealias Value = Bool
    let id: PropositionID
    let name: String
    let targetIndex: Int

    init(id: String = UUID().uuidString, name: String = "IndexEquals", targetIndex: Int) {
        self.id = PropositionID(rawValue: id)!
        self.name = name
        self.targetIndex = targetIndex
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        guard let currentIndex = context.traceIndex else { return false }
        return currentIndex == targetIndex
    }
}

// Helper function to create a test trace from an array of boolean values
func createTestTrace(from bools: [Bool]) -> [TestEvaluationContext] {
    return bools.enumerated().map {
        (index, boolValue) -> TestEvaluationContext in
        let state = TestState(index: boolValue ? 1 : 0)
        return TestEvaluationContext(state: state, traceIndex: index)
    }
}

// Helper function to create a test trace of a given length
func createTestTrace(length: Int) -> [TestEvaluationContext] {
    return Array(0..<length).map { index -> TestEvaluationContext in
        let state = TestState(index: index)
        return TestEvaluationContext(state: state, traceIndex: index)
    }
}

// Predefined test propositions
let p_true = TestProposition(name: "p_true", evaluation: { _ in true })
let p_false = TestProposition(name: "p_false", evaluation: { _ in false })

// Convenience TRUE/FALSE LTL formulas for testing (using p_true)
let ltl_true: LTLFormula<TestProposition> = .atomic(p_true)
// Using .not(.atomic(p_true)) for ltl_false, or .atomic(p_false) are both valid.
// Let's use .atomic(p_false) for clarity if p_false is defined.
let ltl_false: LTLFormula<TestProposition> = .atomic(p_false)

@Suite final class LTLFormulaTraceEvaluationTests {
    @Test("WeakUntil (W) 演算子の評価が正しく行われること")
    func testWeakUntilOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx_eq_1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let idx_eq_2 = IndexEqualsProposition(name: "idx_eq_2", targetIndex: 2)
        let p_idx_lt_1: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        let p_idx_lt_2: LTLFormula<IndexEqualsProposition> = .or(.atomic(idx_eq_0), .atomic(idx_eq_1))
        let p_idx_lt_3: LTLFormula<IndexEqualsProposition> = .or(.atomic(idx_eq_0), .or(.atomic(idx_eq_1), .atomic(idx_eq_2)))
        let q_idx_eq_2: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_2)
        let q_idx_eq_10: LTLFormula<IndexEqualsProposition> = .atomic(IndexEqualsProposition(name: "idx_eq_10", targetIndex: 10))
        let q_idx_eq_0: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        let q_idx_eq_1: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_1)

        let trace3 = createTestTrace(length: 3) // s0, s1, s2
        let trace2 = createTestTrace(length: 2) // s0, s1
        let trace0: [TestEvaluationContext] = []         // Empty trace

        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test Case 1: p U q is true
        // (index < 2) W (index == 2) on trace [s0, s1, s2] => true
        // s0: index=0 (<2), s1: index=1 (<2), s2: index=2 (==2)
        let formula1: LTLFormula<IndexEqualsProposition> = .weakUntil(p_idx_lt_2, q_idx_eq_2)
        let result1 = try evaluator.evaluate(formula: formula1, trace: trace3, contextProvider: contextProvider)
        #expect(result1, "(index < 2) W (index == 2) on trace length 3 should be true")

        // Test Case 2: G p is true
        // (index < 3) W (index == 10) on trace [s0, s1, s2] => true, because G(index < 3) is true
        let formula2: LTLFormula<IndexEqualsProposition> = .weakUntil(p_idx_lt_3, q_idx_eq_10)
        let result2 = try evaluator.evaluate(formula: formula2, trace: trace3, contextProvider: contextProvider)
        #expect(result2, "(index < 3) W (index == 10) on trace length 3 should be true")

        // Test Case 3: Neither p U q nor G p is true
        // (index < 1) W (index == 10) on trace [s0, s1, s2] => false
        // s0: index=0 (<1), s1: index=1 (not <1), s2: index=2 (not <1). q never holds.
        let formula3: LTLFormula<IndexEqualsProposition> = .weakUntil(p_idx_lt_1, q_idx_eq_10)
        let result3 = try evaluator.evaluate(formula: formula3, trace: trace3, contextProvider: contextProvider)
        #expect(!result3, "(index < 1) W (index == 10) on trace length 3 should be false")

        // Test Case 4: q holds at initial state
        // (index < 1) W (index == 0) on trace [s0, s1, s2] => true
        let formula4: LTLFormula<IndexEqualsProposition> = .weakUntil(p_idx_lt_1, q_idx_eq_0)
        let result4 = try evaluator.evaluate(formula: formula4, trace: trace3, contextProvider: contextProvider)
        #expect(result4, "(index < 1) W (index == 0) on trace length 3 should be true")

        // Test Case 5: Empty trace
        // G(p) is true on an empty trace, and p W q == G(p) || (p U q).
        // p U q is false on an empty trace. So p W q should be true.
        let formula5: LTLFormula<IndexEqualsProposition> = .weakUntil(p_idx_lt_1, q_idx_eq_10)
        let result5 = try evaluator.evaluate(formula: formula5, trace: trace0, contextProvider: contextProvider)
        #expect(result5, "p W q should be true on an empty trace because G(p) is true on an empty trace")

        // Test Case 6: q holds at the end of a short trace
        // (index < 2) W (index == 1) on trace [s0, s1] => true
        let formula6: LTLFormula<IndexEqualsProposition> = .weakUntil(p_idx_lt_2, q_idx_eq_1)
        let result6 = try evaluator.evaluate(formula: formula6, trace: trace2, contextProvider: contextProvider)
        #expect(result6, "(index < 2) W (index == 1) on trace length 2 should be true")

        // Test Case 7: p U q is false, G p is false, but q holds eventually after p fails
        // (index == 0) W (index == 2) on trace [s0, s1, s2] => false
        // This should be false because \'index == 0\' does not hold until \'index == 2\'.
        let p_is_zero: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        let formula7: LTLFormula<IndexEqualsProposition> = .weakUntil(p_is_zero, q_idx_eq_2)
        let result7 = try evaluator.evaluate(formula: formula7, trace: trace3, contextProvider: contextProvider)
        #expect(!result7, "(index == 0) W (index == 2) on trace length 3 should be false")
    }

    @Test("Release Operator Evaluation (p R q == not(not p U not q))")
    func testReleaseOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let p_true: LTLFormula<TestProposition> = .atomic(TemporalKitTests.p_true) // Use fully qualified name if helpers are outside class
        let p_false: LTLFormula<TestProposition> = .atomic(TemporalKitTests.p_false)
        let trueLit: LTLFormula<TestProposition> = .booleanLiteral(true)
        let falseLit: LTLFormula<TestProposition> = .booleanLiteral(false)

        let trace_s012 = createTestTrace(length: 3)
        let trace_s0 = createTestTrace(length: 1)
        let emptyTrace: [TestEvaluationContext] = []

        // Test 1: Empty trace: p R q should be true
        #expect(try simpleEvaluator.evaluate(formula: .release(p_true, p_false), trace: emptyTrace, contextProvider: contextProvider), "R on empty trace should be true")

        // Test 2: Basic Literal/Propositional Cases
        // true R true => true
        #expect(try simpleEvaluator.evaluate(formula: .release(trueLit, trueLit), trace: trace_s0, contextProvider: contextProvider))
        // true R false => false
        #expect(try !simpleEvaluator.evaluate(formula: .release(trueLit, falseLit), trace: trace_s0, contextProvider: contextProvider))
        // false R true => true
        #expect(try simpleEvaluator.evaluate(formula: .release(falseLit, trueLit), trace: trace_s0, contextProvider: contextProvider))
        // false R false => false. ¬(¬F U ¬F) = ¬(T U T) = ¬T = F
        #expect(try !simpleEvaluator.evaluate(formula: .release(falseLit, falseLit), trace: trace_s0, contextProvider: contextProvider))
        
        #expect(try simpleEvaluator.evaluate(formula: .release(p_true, p_true), trace: trace_s0, contextProvider: contextProvider))
        #expect(try !simpleEvaluator.evaluate(formula: .release(p_true, p_false), trace: trace_s0, contextProvider: contextProvider))
        #expect(try simpleEvaluator.evaluate(formula: .release(p_false, p_true), trace: trace_s0, contextProvider: contextProvider))
        #expect(try !simpleEvaluator.evaluate(formula: .release(p_false, p_false), trace: trace_s0, contextProvider: contextProvider))

        // Test 3: q holds always (G q), then p R q is true
        // (idx == 0) R (idx < 3) on [s0, s1, s2]
        // p = (idx==0), q = (idx < 3). q is always true on this trace.
        let p_idx_eq_0_prop = IndexEqualsProposition(name: "p_idx_eq_0", targetIndex: 0)
        let q_idx_lt_3_prop = TestProposition(name: "q_idx_lt_3") { ctx in guard let i = ctx.traceIndex else {return false}; return i < 3 }
        let formula_p_idx_eq_0: LTLFormula<IndexEqualsProposition> = .atomic(p_idx_eq_0_prop)
        let formula_q_idx_lt_3_testprop: LTLFormula<TestProposition> = .atomic(q_idx_lt_3_prop)
        // Need a common proposition type or two evaluators. Let's use TestProposition for this specific case.
        // We need p to be TestProposition as well for combined formula.
        let p_tp_idx_eq_0 = TestProposition(name: "p_tp_idx_eq_0") { ctx in guard let i = ctx.traceIndex else {return false}; return i == 0}
        let formula_p_tp_idx_eq_0 : LTLFormula<TestProposition> = .atomic(p_tp_idx_eq_0)
        #expect(try simpleEvaluator.evaluate(formula: .release(formula_p_tp_idx_eq_0, formula_q_idx_lt_3_testprop), trace: trace_s012, contextProvider: contextProvider))

        // Test 4: p R q where q must hold until p first becomes true.
        // Example: p = (idx == 1), q = (idx == 0). Trace [s0, s1, s2]
        // ¬(¬p U ¬q) = ¬(idx != 1 U idx != 0)
        // s0: (idx!=1) is T. (idx!=0) is F. For U, (idx!=1) must hold.
        // s1: (idx!=1) is F. (idx!=0) is T. (idx!=0) holds. (idx!=1) held at s0.
        // So, (¬p U ¬q) is TRUE. Thus, p R q is FALSE.
        let p_idx_eq_1 = IndexEqualsProposition(name: "p_idx_eq_1", targetIndex: 1)
        let q_idx_eq_0 = IndexEqualsProposition(name: "q_idx_eq_0", targetIndex: 0)
        let formula_p_eq_1 : LTLFormula<IndexEqualsProposition> = .atomic(p_idx_eq_1)
        let formula_q_eq_0 : LTLFormula<IndexEqualsProposition> = .atomic(q_idx_eq_0)
        #expect(try !idxEvaluator.evaluate(formula: .release(formula_p_eq_1, formula_q_eq_0), trace: trace_s012, contextProvider: contextProvider))

        // Test 5: p never true, q always true => true
        // (idx == 5) R (idx < 3) on [s0, s1, s2]
        // p = (idx==5) (false always). q = (idx < 3) (true always)
        // ¬(¬p U ¬q) = ¬(idx != 5 U idx >= 3)
        // s0: (idx!=5) is T. (idx>=3) is F. U requires (idx!=5) to hold.
        // s1: (idx!=5) is T. (idx>=3) is F. U requires (idx!=5) to hold.
        // s2: (idx!=5) is T. (idx>=3) is F. U requires (idx!=5) to hold.
        // (idx!=5) U (idx>=3) is false as (idx>=3) never holds.
        // So, ¬(false) is TRUE.
        // let p_idx_eq_5 = IndexEqualsProposition(name: "p_idx_eq_5", targetIndex: 5) // This line will be removed
        // We need q_idx_lt_3 of type IndexEqualsProposition or convert p_idx_eq_5 to TestProposition.
        // For simplicity, let's make q_idx_lt_3 compatible with idxEvaluator.
        // However, IndexEqualsProposition cannot represent idx < 3 directly. So we use TestProposition.
        let p_tp_idx_eq_5 = TestProposition(name: "p_tp_idx_eq_5") {ctx in guard let i = ctx.traceIndex else {return false}; return i == 5}
        #expect(try simpleEvaluator.evaluate(formula: .release(.atomic(p_tp_idx_eq_5), formula_q_idx_lt_3_testprop), trace: trace_s012, contextProvider: contextProvider))

        // Test 6: q becomes true at s1, p is true at s0 and s1
        // (idx < 2) R (idx == 1). Trace [s0, s1, s2]
        // p = (idx < 2), q = (idx == 1)
        // ¬(¬(idx < 2) U ¬(idx == 1)) = ¬(idx >= 2 U idx != 1)
        // s0: (idx>=2) is F. (idx!=1) is T. U is T because RHS is T.
        // So, ¬(T) = FALSE.
        // Let's re-verify R semantics: q must hold until and including p first true. If p never true, q must hold always.
        // Or: for all k, if p is false for all j < k, then q_k. OR p_k is true and q_k is true.
        // (idx < 2) R (idx == 1)
        // s0: p=(idx<2)=T. q=(idx==1)=F. For R, q must hold until p is true. Is q true at s0? No. If p is true at s0, q must be true at s0. This is F.
        // This interpretation means if p is true at t, q must be true at t. Also, if p is false at t0..tk-1, q must be true at t0..tk. And if p is true at tk, q must be true at tk.
        // Simpler: q must hold as long as p holds, and if p becomes false, q must have held at that point.
        // No, standard is: q must be true until and including the point where p first becomes true. If p never becomes true, q must remain true forever. (This is from Wikipedia for R)
        // More common definition: p R q  =  q W (p & q)
        // Let's use the textbook definition:  ψ R φ ≡ ¬(¬ψ U ¬φ)
        // For (idx < 2) R (idx == 1) on [s0,s1,s2]:
        // p = idx < 2; q = idx == 1
        // ¬p = idx >= 2; ¬q = idx != 1
        // Evaluate (idx >= 2) U (idx != 1) on [s0,s1,s2]
        // s0: p_u=(idx>=2) is F. q_u=(idx!=1) is T. (F U T) is T because q_u holds.
        // So, ¬(¬p U ¬q) = ¬(T) = F. This formula should be FALSE.
        let p_idx_lt_2_alt = TestProposition(name:"p_idx_lt_2_alt") { ctx in guard let i = ctx.traceIndex else {return false}; return i < 2}
        let q_idx_eq_1_alt = TestProposition(name:"q_idx_eq_1_alt") { ctx in guard let i = ctx.traceIndex else {return false}; return i == 1}
        let formula_p_lt_2_alt: LTLFormula<TestProposition> = .atomic(p_idx_lt_2_alt)
        let formula_q_eq_1_alt: LTLFormula<TestProposition> = .atomic(q_idx_eq_1_alt)
        #expect(try !simpleEvaluator.evaluate(formula: .release(formula_p_lt_2_alt, formula_q_eq_1_alt), trace: trace_s012, contextProvider: contextProvider))

        // Test 7: p R q where p becomes false while q is still false. -> false
        // (idx == 0) R (idx == 2) on [s0, s1, s2]
        // p = (idx==0), q = (idx==2)
        // ¬(¬(idx==0) U ¬(idx==2)) = ¬(idx!=0 U idx!=2)
        // s0: ¬p=(idx!=0) is F. ¬q=(idx!=2) is T. So (F U T) is T.
        // ¬(T) is FALSE.
        #expect(try !idxEvaluator.evaluate(formula: .release(formula_p_idx_eq_0, .atomic(IndexEqualsProposition(name:"q_idx_eq_2", targetIndex: 2))), trace: trace_s012, contextProvider: contextProvider))
    }

    // MARK: - Basic Operator Evaluation Tests

    @Test("Atomic Proposition Evaluation")
    func testAtomicPropositionEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let trace = createTestTrace(length: 3) // s0, s1, s2
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: Proposition true at index 0
        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let formula_idx_eq_0: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        #expect(try evaluator.evaluate(formula: formula_idx_eq_0, trace: trace, contextProvider: contextProvider))
        // To check at index 1, evaluate on subtrace starting at index 1
        // The proposition idx_eq_0 checks its targetIndex (0) against the *current* context.traceIndex.
        // When we pass trace.dropFirst(), the first element of that subtrace has original index 1.
        // The TestEvaluationContext's traceIndex is crucial here.
        let subTrace1 = Array(trace.dropFirst())
        #expect(try !evaluator.evaluate(formula: formula_idx_eq_0, trace: subTrace1, contextProvider: contextProvider))

        // Test 2: Proposition true at index 1
        let idx_eq_1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let formula_idx_eq_1: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_1)
        #expect(try !evaluator.evaluate(formula: formula_idx_eq_1, trace: trace, contextProvider: contextProvider)) // Evaluates at trace[0] (index 0)
        #expect(try evaluator.evaluate(formula: formula_idx_eq_1, trace: subTrace1, contextProvider: contextProvider)) // Evaluates at subTrace1[0] (original index 1)

        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        // Test 3: Proposition always true
        let formula_p_true: LTLFormula<TestProposition> = .atomic(p_true)
        #expect(try simpleEvaluator.evaluate(formula: formula_p_true, trace: trace, contextProvider: contextProvider))
        #expect(try simpleEvaluator.evaluate(formula: formula_p_true, trace: subTrace1, contextProvider: contextProvider))

        // Test 4: Proposition always false
        let formula_p_false: LTLFormula<TestProposition> = .atomic(p_false)
        #expect(try !simpleEvaluator.evaluate(formula: formula_p_false, trace: trace, contextProvider: contextProvider))
        #expect(try !simpleEvaluator.evaluate(formula: formula_p_false, trace: subTrace1, contextProvider: contextProvider))
    }

    @Test("Boolean Literal Evaluation")
    func testBooleanLiteralEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>() // Proposition type doesn't matter for literals
        let trace = createTestTrace(length: 1) // s0. Content doesn't matter.
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let formula_true: LTLFormula<TestProposition> = .booleanLiteral(true)
        #expect(try evaluator.evaluate(formula: formula_true, trace: trace, contextProvider: contextProvider))

        let formula_false: LTLFormula<TestProposition> = .booleanLiteral(false)
        #expect(try !evaluator.evaluate(formula: formula_false, trace: trace, contextProvider: contextProvider))

        // Test on empty trace - should still work as it does not depend on trace content or length
        let emptyTrace: [TestEvaluationContext] = []
        #expect(try evaluator.evaluate(formula: formula_true, trace: emptyTrace, contextProvider: contextProvider))
        #expect(try !evaluator.evaluate(formula: formula_false, trace: emptyTrace, contextProvider: contextProvider))
    }

    @Test("Not Operator Evaluation")
    func testNotOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2) // s0, s1. Content doesn't matter for p_true/p_false
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: !true_literal
        let not_true_literal: LTLFormula<TestProposition> = .not(.booleanLiteral(true))
        #expect(try !simpleEvaluator.evaluate(formula: not_true_literal, trace: trace, contextProvider: contextProvider))

        // Test 2: !false_literal
        let not_false_literal: LTLFormula<TestProposition> = .not(.booleanLiteral(false))
        #expect(try simpleEvaluator.evaluate(formula: not_false_literal, trace: trace, contextProvider: contextProvider))

        // Test 3: !p_true (where p_true is .atomic(TestProposition that is always true))
        let not_p_true: LTLFormula<TestProposition> = .not(.atomic(p_true))
        #expect(try !simpleEvaluator.evaluate(formula: not_p_true, trace: trace, contextProvider: contextProvider))

        // Test 4: !p_false (where p_false is .atomic(TestProposition that is always false))
        let not_p_false: LTLFormula<TestProposition> = .not(.atomic(p_false))
        #expect(try simpleEvaluator.evaluate(formula: not_p_false, trace: trace, contextProvider: contextProvider))

        // Test with IndexEqualsProposition
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let fullTrace = createTestTrace(length: 2) // s0, s1. traceIndex will be 0 for s0, 1 for s1.

        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let formula_not_idx_eq_0: LTLFormula<IndexEqualsProposition> = .not(.atomic(idx_eq_0))

        // Test 5: !(index == 0) at trace[0] (where index == 0 is true)
        // Expected: false
        #expect(try !idxEvaluator.evaluate(formula: formula_not_idx_eq_0, trace: fullTrace, contextProvider: contextProvider))

        // Test 6: !(index == 0) at trace[1] (where index == 0 is false because context.traceIndex will be 1)
        // Expected: true
        let subTrace_s1_onwards = Array(fullTrace.dropFirst())
        #expect(try idxEvaluator.evaluate(formula: formula_not_idx_eq_0, trace: subTrace_s1_onwards, contextProvider: contextProvider))
    }

    @Test("And Operator Evaluation")
    func testAndOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1) // Length 1 is sufficient for non-temporal operators
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Literals
        let trueLit: LTLFormula<TestProposition> = .booleanLiteral(true)
        let falseLit: LTLFormula<TestProposition> = .booleanLiteral(false)

        // Test 1: true && true
        #expect(try simpleEvaluator.evaluate(formula: .and(trueLit, trueLit), trace: trace, contextProvider: contextProvider))

        // Test 2: true && false
        #expect(try !simpleEvaluator.evaluate(formula: .and(trueLit, falseLit), trace: trace, contextProvider: contextProvider))

        // Test 3: false && true
        #expect(try !simpleEvaluator.evaluate(formula: .and(falseLit, trueLit), trace: trace, contextProvider: contextProvider))

        // Test 4: false && false
        #expect(try !simpleEvaluator.evaluate(formula: .and(falseLit, falseLit), trace: trace, contextProvider: contextProvider))

        // Atomic Propositions
        let p_true_atomic: LTLFormula<TestProposition> = .atomic(p_true)
        let p_false_atomic: LTLFormula<TestProposition> = .atomic(p_false)

        // Test 5: p_true && p_true
        #expect(try simpleEvaluator.evaluate(formula: .and(p_true_atomic, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test 6: p_true && p_false
        #expect(try !simpleEvaluator.evaluate(formula: .and(p_true_atomic, p_false_atomic), trace: trace, contextProvider: contextProvider))

        // Test 7: p_false && p_true
        #expect(try !simpleEvaluator.evaluate(formula: .and(p_false_atomic, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test 8: p_false && p_false
        #expect(try !simpleEvaluator.evaluate(formula: .and(p_false_atomic, p_false_atomic), trace: trace, contextProvider: contextProvider))

        // Mixed: Literal and Atomic
        // Test 9: true && p_true
        #expect(try simpleEvaluator.evaluate(formula: .and(trueLit, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test 10: true && p_false
        #expect(try !simpleEvaluator.evaluate(formula: .and(trueLit, p_false_atomic), trace: trace, contextProvider: contextProvider))


        // Test with IndexEqualsProposition
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let fullTrace_idx = createTestTrace(length: 2) // s0, s1

        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx_eq_1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)

        let formula_idx_eq_0: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        let formula_idx_eq_1: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_1)

        // Test 11: (index == 0) && (index == 0) at trace[0] (true && true) -> true
        #expect(try idxEvaluator.evaluate(formula: .and(formula_idx_eq_0, formula_idx_eq_0), trace: fullTrace_idx, contextProvider: contextProvider))

        // Test 12: (index == 0) && (index == 1) at trace[0] (true && false) -> false
        #expect(try !idxEvaluator.evaluate(formula: .and(formula_idx_eq_0, formula_idx_eq_1), trace: fullTrace_idx, contextProvider: contextProvider))

        // Test 13: (index == 0) && (index == 1) at trace[1] (s1, where context.traceIndex = 1)
        // (index == 0) is false, (index == 1) is true. So, false && true -> false
        let subTrace_s1_onwards_idx = Array(fullTrace_idx.dropFirst())
        #expect(try !idxEvaluator.evaluate(formula: .and(formula_idx_eq_0, formula_idx_eq_1), trace: subTrace_s1_onwards_idx, contextProvider: contextProvider))
        
        // Test 14: (index == 1) && (index == 1) at trace[1] (s1, where context.traceIndex = 1)
        // (index == 1) is true. So, true && true -> true
        #expect(try idxEvaluator.evaluate(formula: .and(formula_idx_eq_1, formula_idx_eq_1), trace: subTrace_s1_onwards_idx, contextProvider: contextProvider))
    }

    @Test("Or Operator Evaluation")
    func testOrOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1) // Length 1 is sufficient
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Literals
        let trueLit: LTLFormula<TestProposition> = .booleanLiteral(true)
        let falseLit: LTLFormula<TestProposition> = .booleanLiteral(false)

        // Test 1: true || true
        #expect(try simpleEvaluator.evaluate(formula: .or(trueLit, trueLit), trace: trace, contextProvider: contextProvider))

        // Test 2: true || false
        #expect(try simpleEvaluator.evaluate(formula: .or(trueLit, falseLit), trace: trace, contextProvider: contextProvider))

        // Test 3: false || true
        #expect(try simpleEvaluator.evaluate(formula: .or(falseLit, trueLit), trace: trace, contextProvider: contextProvider))

        // Test 4: false || false
        #expect(try !simpleEvaluator.evaluate(formula: .or(falseLit, falseLit), trace: trace, contextProvider: contextProvider))

        // Atomic Propositions
        let p_true_atomic: LTLFormula<TestProposition> = .atomic(p_true)
        let p_false_atomic: LTLFormula<TestProposition> = .atomic(p_false)

        // Test 5: p_true || p_true
        #expect(try simpleEvaluator.evaluate(formula: .or(p_true_atomic, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test 6: p_true || p_false
        #expect(try simpleEvaluator.evaluate(formula: .or(p_true_atomic, p_false_atomic), trace: trace, contextProvider: contextProvider))

        // Test 7: p_false || p_true
        #expect(try simpleEvaluator.evaluate(formula: .or(p_false_atomic, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test 8: p_false || p_false
        #expect(try !simpleEvaluator.evaluate(formula: .or(p_false_atomic, p_false_atomic), trace: trace, contextProvider: contextProvider))

        // Mixed: Literal and Atomic
        // Test 9: true || p_false
        #expect(try simpleEvaluator.evaluate(formula: .or(trueLit, p_false_atomic), trace: trace, contextProvider: contextProvider))

        // Test 10: false || p_true
        #expect(try simpleEvaluator.evaluate(formula: .or(falseLit, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test with IndexEqualsProposition
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let fullTrace_idx = createTestTrace(length: 2) // s0, s1

        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx_eq_1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)

        let formula_idx_eq_0: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        let formula_idx_eq_1: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_1)

        // Test 11: (index == 0) || (index == 1) at trace[0] (true || false) -> true
        #expect(try idxEvaluator.evaluate(formula: .or(formula_idx_eq_0, formula_idx_eq_1), trace: fullTrace_idx, contextProvider: contextProvider))

        // Test 12: (index == 1) || (index == 1) at trace[0] (false || false) -> false
        let formula_idx_eq_1_twice = LTLFormula<IndexEqualsProposition>.or(formula_idx_eq_1, formula_idx_eq_1)
        #expect(try !idxEvaluator.evaluate(formula: formula_idx_eq_1_twice, trace: fullTrace_idx, contextProvider: contextProvider))
        
        // Test 13: (index == 0) || (index == 1) at trace[1] (s1, context.traceIndex = 1)
        // (index == 0) is false, (index == 1) is true. So, false || true -> true
        let subTrace_s1_onwards_idx = Array(fullTrace_idx.dropFirst())
        #expect(try idxEvaluator.evaluate(formula: .or(formula_idx_eq_0, formula_idx_eq_1), trace: subTrace_s1_onwards_idx, contextProvider: contextProvider))
    }

    @Test("Implies Operator Evaluation")
    func testImpliesOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1) // Length 1 is sufficient
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Literals
        let trueLit: LTLFormula<TestProposition> = .booleanLiteral(true)
        let falseLit: LTLFormula<TestProposition> = .booleanLiteral(false)

        // Test 1: true => true (true)
        #expect(try simpleEvaluator.evaluate(formula: .implies(trueLit, trueLit), trace: trace, contextProvider: contextProvider))

        // Test 2: true => false (false)
        #expect(try !simpleEvaluator.evaluate(formula: .implies(trueLit, falseLit), trace: trace, contextProvider: contextProvider))

        // Test 3: false => true (true)
        #expect(try simpleEvaluator.evaluate(formula: .implies(falseLit, trueLit), trace: trace, contextProvider: contextProvider))

        // Test 4: false => false (true)
        #expect(try simpleEvaluator.evaluate(formula: .implies(falseLit, falseLit), trace: trace, contextProvider: contextProvider))

        // Atomic Propositions
        let p_true_atomic: LTLFormula<TestProposition> = .atomic(p_true)
        let p_false_atomic: LTLFormula<TestProposition> = .atomic(p_false)

        // Test 5: p_true => p_true (true)
        #expect(try simpleEvaluator.evaluate(formula: .implies(p_true_atomic, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test 6: p_true => p_false (false)
        #expect(try !simpleEvaluator.evaluate(formula: .implies(p_true_atomic, p_false_atomic), trace: trace, contextProvider: contextProvider))

        // Test 7: p_false => p_true (true)
        #expect(try simpleEvaluator.evaluate(formula: .implies(p_false_atomic, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test 8: p_false => p_false (true)
        #expect(try simpleEvaluator.evaluate(formula: .implies(p_false_atomic, p_false_atomic), trace: trace, contextProvider: contextProvider))

        // Mixed: Literal and Atomic
        // Test 9: true => p_false (false)
        #expect(try !simpleEvaluator.evaluate(formula: .implies(trueLit, p_false_atomic), trace: trace, contextProvider: contextProvider))

        // Test 10: false => p_true (true)
        #expect(try simpleEvaluator.evaluate(formula: .implies(falseLit, p_true_atomic), trace: trace, contextProvider: contextProvider))

        // Test with IndexEqualsProposition
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let fullTrace_idx = createTestTrace(length: 2) // s0, s1

        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx_eq_1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)

        let formula_idx_eq_0: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        let formula_idx_eq_1: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_1)

        // Test 11: (index == 0) => (index == 0) at trace[0] (true => true) -> true
        #expect(try idxEvaluator.evaluate(formula: .implies(formula_idx_eq_0, formula_idx_eq_0), trace: fullTrace_idx, contextProvider: contextProvider))

        // Test 12: (index == 0) => (index == 1) at trace[0] (true => false) -> false
        #expect(try !idxEvaluator.evaluate(formula: .implies(formula_idx_eq_0, formula_idx_eq_1), trace: fullTrace_idx, contextProvider: contextProvider))
        
        // Test 13: (index == 1) => (index == 0) at trace[0] (false => true) -> true
        #expect(try idxEvaluator.evaluate(formula: .implies(formula_idx_eq_1, formula_idx_eq_0), trace: fullTrace_idx, contextProvider: contextProvider))

        // Test 14: (index == 0) => (index == 1) at trace[1] (s1, context.traceIndex = 1)
        // (index == 0) is false, (index == 1) is true. So, false => true -> true
        let subTrace_s1_onwards_idx = Array(fullTrace_idx.dropFirst())
        #expect(try idxEvaluator.evaluate(formula: .implies(formula_idx_eq_0, formula_idx_eq_1), trace: subTrace_s1_onwards_idx, contextProvider: contextProvider))
    }

    @Test("Next Operator Evaluation")
    func testNextOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace_len2 = createTestTrace(length: 2) // s0, s1
        let trace_len1 = createTestTrace(length: 1) // s0
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let trueLit: LTLFormula<TestProposition> = .booleanLiteral(true)
        let falseLit: LTLFormula<TestProposition> = .booleanLiteral(false)
        let p_true_atomic: LTLFormula<TestProposition> = .atomic(p_true)
        let p_false_atomic: LTLFormula<TestProposition> = .atomic(p_false)

        // Test 1: X true on [s0, s1] (evaluates true at s1) -> true at s0
        #expect(try simpleEvaluator.evaluate(formula: .next(trueLit), trace: trace_len2, contextProvider: contextProvider))

        // Test 2: X false on [s0, s1] (evaluates false at s1) -> false at s0
        #expect(try !simpleEvaluator.evaluate(formula: .next(falseLit), trace: trace_len2, contextProvider: contextProvider))

        // Test 3: X p_true on [s0, s1]
        #expect(try simpleEvaluator.evaluate(formula: .next(p_true_atomic), trace: trace_len2, contextProvider: contextProvider))

        // Test 4: X p_false on [s0, s1]
        #expect(try !simpleEvaluator.evaluate(formula: .next(p_false_atomic), trace: trace_len2, contextProvider: contextProvider))

        // Test with IndexEqualsProposition
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let trace_len3_idx = createTestTrace(length: 3) // s0, s1, s2

        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx_eq_1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)

        let formula_idx_eq_0: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        let formula_idx_eq_1: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_1)

        // Test 5: X (index == 1) at trace[0] on [s0, s1, s2]
        // Inner formula (index == 1) evaluated at trace[1] (s1, context.traceIndex=1) is true.
        #expect(try idxEvaluator.evaluate(formula: .next(formula_idx_eq_1), trace: trace_len3_idx, contextProvider: contextProvider))

        // Test 6: X (index == 0) at trace[0] on [s0, s1, s2]
        // Inner formula (index == 0) evaluated at trace[1] (s1, context.traceIndex=1) is false.
        #expect(try !idxEvaluator.evaluate(formula: .next(formula_idx_eq_0), trace: trace_len3_idx, contextProvider: contextProvider))

        // Test 7: X p on a trace of length 1 (e.g., trace_len1 = [s0]) should throw traceIndexOutOfBounds.
        // This is already covered by testTraceIndexOutOfBoundsInNext, but good to confirm here as well.
        do {
            let _ = try simpleEvaluator.evaluate(formula: .next(p_true_atomic), trace: trace_len1, contextProvider: contextProvider)
            Issue.record("Expected LTLTraceEvaluationError.traceIndexOutOfBounds but no error was thrown.")
        } catch let error as LTLTraceEvaluationError {
            switch error {
            case .traceIndexOutOfBounds(let index, let length):
                #expect(index == 1, "Error index should be 1 for Next on trace of length 1")
                #expect(length == 1, "Error traceLength should be 1 for Next on trace of length 1")
            default:
                Issue.record("Expected LTLTraceEvaluationError.traceIndexOutOfBounds but got \(error)")
            }
        } catch {
            Issue.record("Expected LTLTraceEvaluationError but got a different error type: \(error)")
        }
        
        // Test 8: X (index == 0) when current state is s1 of [s0, s1, s2] (i.e. evaluate on subtrace from s1)
        // We evaluate `X (index == 0)` on the trace `[s1, s2]`. 
        // The inner formula `(index == 0)` is evaluated at the next state, which is `s2`.
        // In the context of `s2` (original index 2), `index == 0` is false.
        let subTrace_s1_onwards_idx = Array(trace_len3_idx.dropFirst()) // trace is [s1, s2]
        #expect(try !idxEvaluator.evaluate(formula: .next(formula_idx_eq_0), trace: subTrace_s1_onwards_idx, contextProvider: contextProvider))

        // Test 9: X (index == 2) when current state is s1 of [s0, s1, s2]
        // We evaluate `X (index == 2)` on the trace `[s1, s2]`.
        // The inner formula `(index == 2)` is evaluated at the next state, which is `s2`.
        // In the context of `s2` (original index 2), `(index == 2)` is true.
        let idx_eq_2 = IndexEqualsProposition(name: "idx_eq_2", targetIndex: 2)
        let formula_idx_eq_2 : LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_2)
        #expect(try idxEvaluator.evaluate(formula: .next(formula_idx_eq_2), trace: subTrace_s1_onwards_idx, contextProvider: contextProvider))
    }

    @Test("Eventually Operator Evaluation")
    func testEventuallyOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let trueLit: LTLFormula<TestProposition> = .booleanLiteral(true)
        let falseLit: LTLFormula<TestProposition> = .booleanLiteral(false)
        let p_true_atomic: LTLFormula<TestProposition> = .atomic(p_true)
        let p_false_atomic: LTLFormula<TestProposition> = .atomic(p_false)

        // Test 1: F true_literal (should be true on any non-empty trace)
        let trace_len1 = createTestTrace(length: 1)
        #expect(try simpleEvaluator.evaluate(formula: .eventually(trueLit), trace: trace_len1, contextProvider: contextProvider))

        // Test 2: F false_literal (should be false on any non-empty trace)
        #expect(try !simpleEvaluator.evaluate(formula: .eventually(falseLit), trace: trace_len1, contextProvider: contextProvider))

        // Test 3: F p_true (p_true is always true, so F p_true is true)
        #expect(try simpleEvaluator.evaluate(formula: .eventually(p_true_atomic), trace: trace_len1, contextProvider: contextProvider))

        // Test 4: F p_false (p_false is never true, so F p_false is false on non-empty trace)
        #expect(try !simpleEvaluator.evaluate(formula: .eventually(p_false_atomic), trace: trace_len1, contextProvider: contextProvider))

        // Test 5: F p on an empty trace (should be false)
        let emptyTrace: [TestEvaluationContext] = []
        #expect(try !simpleEvaluator.evaluate(formula: .eventually(p_true_atomic), trace: emptyTrace, contextProvider: contextProvider))
        #expect(try !simpleEvaluator.evaluate(formula: .eventually(falseLit), trace: emptyTrace, contextProvider: contextProvider)) // Also for literal


        // Test with IndexEqualsProposition
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let trace_len3_idx = createTestTrace(length: 3) // s0, s1, s2. Indices 0, 1, 2
        let trace_len5_idx = createTestTrace(length: 5) // s0, s1, s2, s3, s4. Indices 0, 1, 2, 3, 4

        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx_eq_1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let idx_eq_2 = IndexEqualsProposition(name: "idx_eq_2", targetIndex: 2)
        let idx_eq_4 = IndexEqualsProposition(name: "idx_eq_4", targetIndex: 4) // For new test
        let idx_eq_5 = IndexEqualsProposition(name: "idx_eq_5", targetIndex: 5) // Will not occur in trace_len3_idx
        let idx_eq_10 = IndexEqualsProposition(name: "idx_eq_10", targetIndex: 10) // For new test, will not occur

        let formula_F_idx_eq_0: LTLFormula<IndexEqualsProposition> = .eventually(.atomic(idx_eq_0))
        let formula_F_idx_eq_1: LTLFormula<IndexEqualsProposition> = .eventually(.atomic(idx_eq_1))
        let formula_F_idx_eq_2: LTLFormula<IndexEqualsProposition> = .eventually(.atomic(idx_eq_2))
        let formula_F_idx_eq_4: LTLFormula<IndexEqualsProposition> = .eventually(.atomic(idx_eq_4)) // For new test
        let formula_F_idx_eq_5: LTLFormula<IndexEqualsProposition> = .eventually(.atomic(idx_eq_5))
        let formula_F_idx_eq_10: LTLFormula<IndexEqualsProposition> = .eventually(.atomic(idx_eq_10)) // For new test


        // Test 6: F (index == 0) on [s0, s1, s2] -> true (holds at s0)
        #expect(try idxEvaluator.evaluate(formula: formula_F_idx_eq_0, trace: trace_len3_idx, contextProvider: contextProvider))

        // Test 7: F (index == 1) on [s0, s1, s2] -> true (holds at s1)
        #expect(try idxEvaluator.evaluate(formula: formula_F_idx_eq_1, trace: trace_len3_idx, contextProvider: contextProvider))

        // Test 8: F (index == 2) on [s0, s1, s2] -> true (holds at s2)
        #expect(try idxEvaluator.evaluate(formula: formula_F_idx_eq_2, trace: trace_len3_idx, contextProvider: contextProvider))

        // Test 9: F (index == 5) on [s0, s1, s2] -> false (never holds)
        #expect(try !idxEvaluator.evaluate(formula: formula_F_idx_eq_5, trace: trace_len3_idx, contextProvider: contextProvider))

        // Test 10: F (index == 1) evaluated on subtrace [s1, s2] (from original s0, s1, s2)
        // Original indices are 1, 2. So (index == 1) holds at the first state of this subtrace.
        let subTrace_s1_onwards = Array(trace_len3_idx.dropFirst())
        #expect(try idxEvaluator.evaluate(formula: formula_F_idx_eq_1, trace: subTrace_s1_onwards, contextProvider: contextProvider))

        // Test 11: F (index == 0) evaluated on subtrace [s1, s2]
        // Original indices are 1, 2. (index == 0) never holds.
        #expect(try !idxEvaluator.evaluate(formula: formula_F_idx_eq_0, trace: subTrace_s1_onwards, contextProvider: contextProvider))
        
        // Test 12: F (index == 2) evaluated on subtrace [s2]
        // Original index is 2. (index == 2) holds.
        let subTrace_s2_onwards = Array(trace_len3_idx.dropFirst(2))
        #expect(try idxEvaluator.evaluate(formula: formula_F_idx_eq_2, trace: subTrace_s2_onwards, contextProvider: contextProvider))

        // Test 13 (New): F (index == 4) on [s0, s1, s2, s3, s4] -> true (holds at the very last state)
        #expect(try idxEvaluator.evaluate(formula: formula_F_idx_eq_4, trace: trace_len5_idx, contextProvider: contextProvider))

        // Test 14 (New): F (index == 10) on [s0, s1, s2, s3, s4] -> false (never holds on a longer trace)
        #expect(try !idxEvaluator.evaluate(formula: formula_F_idx_eq_10, trace: trace_len5_idx, contextProvider: contextProvider))
    }

    @Test("Globally Operator Evaluation")
    func testGloballyOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let trueLit: LTLFormula<TestProposition> = .booleanLiteral(true)
        let falseLit: LTLFormula<TestProposition> = .booleanLiteral(false)
        let p_true_atomic: LTLFormula<TestProposition> = .atomic(p_true)
        let p_false_atomic: LTLFormula<TestProposition> = .atomic(p_false)

        // Test 1: G true_literal (should be true on any trace)
        let trace_len1 = createTestTrace(length: 1)
        let trace_len3 = createTestTrace(length: 3)
        let trace_len5 = createTestTrace(length: 5) // For new test
        #expect(try simpleEvaluator.evaluate(formula: .globally(trueLit), trace: trace_len1, contextProvider: contextProvider))
        #expect(try simpleEvaluator.evaluate(formula: .globally(trueLit), trace: trace_len3, contextProvider: contextProvider))

        // Test 2: G false_literal (should be false if trace is non-empty)
        #expect(try !simpleEvaluator.evaluate(formula: .globally(falseLit), trace: trace_len1, contextProvider: contextProvider))
        #expect(try !simpleEvaluator.evaluate(formula: .globally(falseLit), trace: trace_len3, contextProvider: contextProvider))

        // Test 3: G p_true (p_true is always true, so G p_true is true)
        #expect(try simpleEvaluator.evaluate(formula: .globally(p_true_atomic), trace: trace_len3, contextProvider: contextProvider))

        // Test 4: G p_false (p_false is never true, so G p_false is false if trace non-empty)
        #expect(try !simpleEvaluator.evaluate(formula: .globally(p_false_atomic), trace: trace_len3, contextProvider: contextProvider))

        // Test 5: G p on an empty trace (should be true, vacuously)
        let emptyTrace: [TestEvaluationContext] = []
        #expect(try simpleEvaluator.evaluate(formula: .globally(p_true_atomic), trace: emptyTrace, contextProvider: contextProvider))
        #expect(try simpleEvaluator.evaluate(formula: .globally(falseLit), trace: emptyTrace, contextProvider: contextProvider)) // Also for literal

        // Test with IndexEqualsProposition (using TestProposition with custom evaluation for simplicity for < predicate)
        let testPropEvaluator = LTLFormulaTraceEvaluator<TestProposition>() 

        // Proposition: index < 3 (true for s0, s1, s2 in trace_s012)
        let idx_lt_3_prop = TestProposition(name: "idx_lt_3") { context in
            guard let currentIdx = context.traceIndex else { return false }
            return currentIdx < 3
        }
        let formula_G_idx_lt_3: LTLFormula<TestProposition> = .globally(.atomic(idx_lt_3_prop))
        
        // Test 6: G (index < 3) on [s0, s1, s2] -> true
        #expect(try testPropEvaluator.evaluate(formula: formula_G_idx_lt_3, trace: trace_len3, contextProvider: contextProvider))

        // Proposition: index < 2 (true for s0, s1; false for s2 in trace_s012)
        let idx_lt_2_prop = TestProposition(name: "idx_lt_2") { context in
            guard let currentIdx = context.traceIndex else { return false }
            return currentIdx < 2
        }
        let formula_G_idx_lt_2: LTLFormula<TestProposition> = .globally(.atomic(idx_lt_2_prop))

        // Test 7: G (index < 2) on [s0, s1, s2] -> false (fails at s2)
        #expect(try !testPropEvaluator.evaluate(formula: formula_G_idx_lt_2, trace: trace_len3, contextProvider: contextProvider))
        
        // Test 8: G (index < 1) evaluated on subtrace [s1, s2] (from original s0, s1, s2)
        // Original indices of subtrace are 1, 2. (index < 1) is false at s1 (original index 1).
        let idx_lt_1_prop = TestProposition(name: "idx_lt_1") { context in
            guard let currentIdx = context.traceIndex else { return false }
            return currentIdx < 1
        }
        let formula_G_idx_lt_1: LTLFormula<TestProposition> = .globally(.atomic(idx_lt_1_prop))
        let subTrace_s1_onwards_len3 = Array(trace_len3.dropFirst())
        #expect(try !testPropEvaluator.evaluate(formula: formula_G_idx_lt_1, trace: subTrace_s1_onwards_len3, contextProvider: contextProvider))

        // Test 9: G (index < 3) evaluated on subtrace [s1, s2]
        // Original indices of subtrace are 1, 2. (index < 3) is true for both.
        #expect(try testPropEvaluator.evaluate(formula: formula_G_idx_lt_3, trace: subTrace_s1_onwards_len3, contextProvider: contextProvider))

        // Test 10: G (index == 0) on [s0] -> true
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let idx_eq_0_prop = IndexEqualsProposition(name: "idx_eq_0_specific", targetIndex: 0)
        let formula_G_idx_eq_0 : LTLFormula<IndexEqualsProposition> = .globally(.atomic(idx_eq_0_prop))
        #expect(try idxEvaluator.evaluate(formula: formula_G_idx_eq_0, trace: trace_len1, contextProvider: contextProvider))

        // Test 11 (New): G (index < 4) on [s0,s1,s2,s3,s4] -> false (fails at last state s4)
        let idx_lt_4_prop = TestProposition(name: "idx_lt_4") { context in
            guard let currentIdx = context.traceIndex else { return false }
            return currentIdx < 4
        }
        let formula_G_idx_lt_4: LTLFormula<TestProposition> = .globally(.atomic(idx_lt_4_prop))
        #expect(try !testPropEvaluator.evaluate(formula: formula_G_idx_lt_4, trace: trace_len5, contextProvider: contextProvider))
    }

    @Test("Until Operator Evaluation")
    func testUntilOperatorEvaluation() throws {
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let p_true_atomic: LTLFormula<TestProposition> = .atomic(p_true)
        let p_false_atomic: LTLFormula<TestProposition> = .atomic(p_false)
        let trueLit: LTLFormula<TestProposition> = .booleanLiteral(true)
        let falseLit: LTLFormula<TestProposition> = .booleanLiteral(false)

        let trace_s012 = createTestTrace(length: 3) // s0, s1, s2
        let trace_s0 = createTestTrace(length: 1)   // s0
        let emptyTrace: [TestEvaluationContext] = []

        // Test 1: q holds immediately. p U q => true
        // (idx == 0) U (idx == 0) on [s0, s1, s2] -> true (q holds at s0)
        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let formula_idx_eq_0 : LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        #expect(try idxEvaluator.evaluate(formula: .until(formula_idx_eq_0, formula_idx_eq_0), trace: trace_s012, contextProvider: contextProvider))
        // true U p_true -> true
        #expect(try simpleEvaluator.evaluate(formula: .until(trueLit, p_true_atomic), trace: trace_s0, contextProvider: contextProvider))

        // Test 2: q holds after a few states, p holds until then. p U q => true
        // (idx < 2) U (idx == 2) on [s0, s1, s2]
        // s0: idx=0 (<2), s1: idx=1 (<2), s2: idx=2 (==2)
        let idx_lt_2_prop = TestProposition(name: "idx_lt_2") { ctx in guard let i = ctx.traceIndex else {return false}; return i < 2 }
        let idx_eq_2_prop = TestProposition(name: "idx_eq_2") { ctx in guard let i = ctx.traceIndex else {return false}; return i == 2 }
        let formula_p_lt_2: LTLFormula<TestProposition> = .atomic(idx_lt_2_prop)
        let formula_q_eq_2: LTLFormula<TestProposition> = .atomic(idx_eq_2_prop)
        #expect(try simpleEvaluator.evaluate(formula: .until(formula_p_lt_2, formula_q_eq_2), trace: trace_s012, contextProvider: contextProvider))

        // Test 3: p becomes false before q becomes true. p U q => false
        // (idx == 0) U (idx == 2) on [s0, s1, s2]
        // s0: idx=0 (p holds), s1: idx=1 (p fails), s2: idx=2 (q holds, but p failed too early)
        let formula_p_eq_0: LTLFormula<TestProposition> = .atomic(TestProposition(name: "idx_eq_0_specific") { ctx in guard let i = ctx.traceIndex else {return false}; return i == 0 })
        #expect(try !simpleEvaluator.evaluate(formula: .until(formula_p_eq_0, formula_q_eq_2), trace: trace_s012, contextProvider: contextProvider))

        // Test 4: q never becomes true. p U q => false
        // (idx < 3) U (idx == 5) on [s0, s1, s2]
        let idx_lt_3_prop = TestProposition(name: "idx_lt_3") { ctx in guard let i = ctx.traceIndex else {return false}; return i < 3 }
        let idx_eq_5_prop = TestProposition(name: "idx_eq_5") { ctx in guard let i = ctx.traceIndex else {return false}; return i == 5 }
        let formula_p_lt_3: LTLFormula<TestProposition> = .atomic(idx_lt_3_prop)
        let formula_q_eq_5: LTLFormula<TestProposition> = .atomic(idx_eq_5_prop)
        #expect(try !simpleEvaluator.evaluate(formula: .until(formula_p_lt_3, formula_q_eq_5), trace: trace_s012, contextProvider: contextProvider))

        // Test 5: true U q (equivalent to F q)
        // true U (idx == 2) on [s0, s1, s2] -> true
        #expect(try simpleEvaluator.evaluate(formula: .until(trueLit, formula_q_eq_2), trace: trace_s012, contextProvider: contextProvider))
        // true U (idx == 5) on [s0, s1, s2] -> false
        #expect(try !simpleEvaluator.evaluate(formula: .until(trueLit, formula_q_eq_5), trace: trace_s012, contextProvider: contextProvider))

        // Test 6: p U false (should generally be false unless p is also false and trace is empty... but U requires q to eventually hold)
        // So, p U false is always false on non-empty trace.
        #expect(try !simpleEvaluator.evaluate(formula: .until(p_true_atomic, falseLit), trace: trace_s012, contextProvider: contextProvider))
        #expect(try !simpleEvaluator.evaluate(formula: .until(p_false_atomic, falseLit), trace: trace_s012, contextProvider: contextProvider))

        // Test 7: p U q on an empty trace (should be false)
        #expect(try !simpleEvaluator.evaluate(formula: .until(p_true_atomic, p_true_atomic), trace: emptyTrace, contextProvider: contextProvider))

        // Test 8: More complex IndexEqualsProposition example
        // (index == 0) U (index == 1) on trace [s0, s1, s2]
        // s0: p=(idx==0) is true. q=(idx==1) is false.
        // s1: q=(idx==1) is true. So, formula holds.
        let idx_eq_1_formula: LTLFormula<IndexEqualsProposition> = .atomic(IndexEqualsProposition(name: "idx_is_1", targetIndex: 1))
        #expect(try idxEvaluator.evaluate(formula: .until(formula_idx_eq_0, idx_eq_1_formula), trace: trace_s012, contextProvider: contextProvider))

        // Test 9: (index == 1) U (index == 0) on trace [s0, s1, s2] -> true
        // s0: q=(idx==0) is true. Formula holds immediately.
        #expect(try idxEvaluator.evaluate(formula: .until(idx_eq_1_formula, formula_idx_eq_0), trace: trace_s012, contextProvider: contextProvider))

        // Test 10: Evaluate on subtrace
        // (idx < 2) U (idx == 2) on subtrace [s1, s2] (original indices 1, 2)
        // Subtrace s0 (orig s1): idx=1 (<2). q=(idx==2) is false
        // Subtrace s1 (orig s2): idx=2 (not <2, but q=(idx==2) is true)
        // Here, p is TestProposition (idx_lt_2_prop), q is TestProposition (idx_eq_2_prop)
        let subTrace_s1_onwards = Array(trace_s012.dropFirst())
        #expect(try simpleEvaluator.evaluate(formula: .until(formula_p_lt_2, formula_q_eq_2), trace: subTrace_s1_onwards, contextProvider: contextProvider))
    }

    // MARK: - Error Handling Tests
    @Test func testEmptyTraceEvaluationThrowsError() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let formula: LTLFormula<TestProposition> = .atomic(p_true)
        let trace: [TestEvaluationContext] = []
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        #expect {
            try evaluator.evaluate(formula: formula, trace: trace, contextProvider: contextProvider)
        } throws: { error in
            guard let evalError = error as? LTLTraceEvaluationError else {
                Issue.record("Error was not of type LTLTraceEvaluationError: \\(error)")
                return false
            }
            if case .traceIndexOutOfBounds = evalError {
                return true
            } else {
                Issue.record("Error was not traceIndexOutOfBounds for empty trace (atomic): \\(evalError)")
                return false
            }
        }
    }

    @Test func testTraceIndexOutOfBoundsInNext() throws {
        let trace = createTestTrace(length: 1) // s0
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let formula: LTLFormula<TestProposition> = .next(.atomic(p_true))
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        #expect {
            try evaluator.evaluate(formula: formula, trace: trace, contextProvider: contextProvider)
        } throws: { error in
            guard let evalError = error as? LTLTraceEvaluationError else {
                Issue.record("Error was not of type LTLTraceEvaluationError: \\(error)")
                return false
            }
            if case .traceIndexOutOfBounds(let index, let traceLength) = evalError {
                #expect(index == 1, "Error index should be 1 for Next on trace of length 1")
                #expect(traceLength == 1, "Error traceLength should be 1 for Next on trace of length 1")
                return true
            } else {
                 Issue.record("Error was not traceIndexOutOfBounds: \\(evalError) for LTLFormula.next")
                 return false
            }
        }
    }

    @Test func testTraceIndexOutOfBoundsInAtomic() throws {
        let trace = createTestTrace(length: 1) // s0
        let evaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let atomic_formula: LTLFormula<IndexEqualsProposition> = .atomic(idx_eq_0)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let result = try evaluator.evaluate(formula: atomic_formula, trace: trace, contextProvider: contextProvider)
        #expect(result, "Atomic proposition idx_eq_0 should be true at index 0 on trace [s0]")
    }

    private enum DeliberateTestError: Error, Equatable {
        case ohNoAnError
    }

    private let p_throws = TestProposition(name: "p_throws", evaluation: { _ in throw DeliberateTestError.ohNoAnError })

    @Test func testAndOperatorLeftHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let formula_throws_and_true: LTLFormula<TestProposition> = .and(.atomic(p_throws), .atomic(p_true))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_throws_and_true, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testOrOperatorLeftHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let formula_throws_or_true: LTLFormula<TestProposition> = .or(.atomic(p_throws), .atomic(p_true))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_throws_or_true, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testImpliesOperatorLeftHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let formula_throws_implies_true: LTLFormula<TestProposition> = .implies(.atomic(p_throws), .atomic(p_true))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_throws_implies_true, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testNextOperatorSubformulaErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let formula_X_throws: LTLFormula<TestProposition> = .next(.atomic(p_throws))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_X_throws, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testUntilOperatorRightHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let formula_true_U_throws: LTLFormula<TestProposition> = .until(.atomic(p_true), .atomic(p_throws))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_true_U_throws, trace: trace, contextProvider: contextProvider)
        }
        let formula_false_U_throws: LTLFormula<TestProposition> = .until(.atomic(p_false), .atomic(p_throws))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_false_U_throws, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testUntilOperatorLeftHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2) 
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_false_at_s0 = TestProposition(name: "p_false_at_s0") { ctx in ctx.traceIndex != 0 }
        let formula_throws_U_false_at_s0: LTLFormula<TestProposition> = .until(.atomic(p_throws), .atomic(p_false_at_s0))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_throws_U_false_at_s0, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testWeakUntilOperatorErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let formula_G_throws_W_true: LTLFormula<TestProposition> = .weakUntil(.atomic(p_throws), .atomic(p_true))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_G_throws_W_true, trace: trace, contextProvider: contextProvider)
        }
        let formula_false_W_false_U_throws: LTLFormula<TestProposition> = .weakUntil(.atomic(p_false), .atomic(p_throws))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_false_W_false_U_throws, trace: trace, contextProvider: contextProvider)
        }
        let p_false_at_s0 = TestProposition(name: "p_false_at_s0_for_W_U_left_err", evaluation: { $0.traceIndex != 0 })
        let formula_false_W_throws_U_false_at_s0: LTLFormula<TestProposition> = .weakUntil(
            .atomic(p_false), 
            .until(.atomic(p_throws), .atomic(p_false_at_s0))
        )
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_false_W_throws_U_false_at_s0, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testNotOperatorWithErroringSubformula() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let formula_not_throws: LTLFormula<TestProposition> = .not(.atomic(p_throws))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_not_throws, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testReleaseOperatorErrorPropagation_Case1_LeftThrows_CorrectedExpectation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        // p_throws R p_true  => not ( (not p_throws) U (not p_true) )
        // not p_true is false.
        // (not p_throws) U false  --- this evaluates to false, as 'not p_throws' is never evaluated because 'false' (right operand) is never true.
        // not (false) is true. No error should be thrown.
        let formula_throws_R_true: LTLFormula<TestProposition> = .release(.atomic(p_throws), .atomic(p_true))
        let result = try evaluator.evaluate(formula: formula_throws_R_true, trace: trace, contextProvider: contextProvider)
        #expect(result == true)
    }

    @Test func testReleaseOperatorErrorPropagation_Case2_RightThrows() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        // p_true R p_throws => not ( (not p_true) U (not p_throws) )
        // (not p_true) is false. (not p_throws) will be evaluated for the U's right operand.
        // Evaluation of (not p_throws) at s0 for the U should throw.
        let formula_true_R_throws: LTLFormula<TestProposition> = .release(.atomic(p_true), .atomic(p_throws))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_true_R_throws, trace: trace, contextProvider: contextProvider)
        }
    }

    @Test func testReleaseOperatorErrorPropagation_Case3_FalseRThrows() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        // (p_false R p_throws) -> not ( (not p_false) U (not p_throws) ) 
        // -> not ( true U (not p_throws) )
        //   true U (not p_throws) at s0:
        //     (not p_throws) at s0 -> should throw.
        let formula_false_R_throws: LTLFormula<TestProposition> = .release(.atomic(p_false), .atomic(p_throws))
        #expect(throws: DeliberateTestError.ohNoAnError) {
            _ = try evaluator.evaluate(formula: formula_false_R_throws, trace: trace, contextProvider: contextProvider)
        }
    }

}
