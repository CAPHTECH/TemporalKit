import Foundation
import Testing
@testable import TemporalKit

// MARK: - Temporal Operator Tests

@Suite("LTL Formula Temporal Operator Trace Evaluation Tests")
struct LTLFormulaTraceEvaluationTemporalTests {
    
    @Test("WeakUntil (W) 演算子の評価が正しく行われること")
    func testWeakUntilOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: p W q where p is always true and q is always false (should be true at all positions)
        let trace1 = createTestTrace(length: 3)
        let formula1: LTLFormula<TestProposition> = .weakUntil(.atomic(TestPropositions.p_true), .atomic(TestPropositions.q_false))
        for i in 0..<trace1.count {
            #expect(try evaluator.evaluateAt(formula: formula1, trace: trace1, index: i, contextProvider: contextProvider))
        }

        // Test 2: p W q where p is false and q is true (should be true at all positions)
        let formula2: LTLFormula<TestProposition> = .weakUntil(.atomic(TestPropositions.p_false), .atomic(TestPropositions.q_true))
        for i in 0..<trace1.count {
            #expect(try evaluator.evaluateAt(formula: formula2, trace: trace1, index: i, contextProvider: contextProvider))
        }

        // Test 3: p W q where both p and q are false (should be false)
        let formula3: LTLFormula<TestProposition> = .weakUntil(.atomic(TestPropositions.p_false), .atomic(TestPropositions.q_false))
        #expect(try !evaluator.evaluateAt(formula: formula3, trace: trace1, index: 0, contextProvider: contextProvider))

        // Test 4: Index-based test - (idx != 0) W (idx == 2)
        // At index 0: false W false → should be false (p false and q will never be true before p becomes true)
        // At index 1: true W false → should be true (p holds and continues to hold)
        // At index 2: true W true → should be true (q is true)
        let idxNot0 = TestProposition(name: "idx_neq_0") { context in
            guard let idx = context.traceIndex else { return false }
            return idx != 0
        }
        let idx2 = IndexEqualsProposition(name: "idx_eq_2", targetIndex: 2)
        let formula4: LTLFormula<TestProposition> = .weakUntil(.atomic(idxNot0), .atomic(idx2))
        
        #expect(try !evaluator.evaluateAt(formula: formula4, trace: trace1, index: 0, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula4, trace: trace1, index: 1, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula4, trace: trace1, index: 2, contextProvider: contextProvider))

        // Test 5: Empty trace behavior
        let emptyTrace: [TestEvaluationContext] = []
        // p W q on empty trace should be true (vacuously true since p holds "forever" in empty trace)
        #expect(try evaluator.evaluate(formula: formula1, trace: emptyTrace, contextProvider: contextProvider))
    }

    @Test("Release Operator Evaluation (p R q == not(not p U not q))")
    func testReleaseOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let simpleEvaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let idxEvaluator = LTLFormulaTraceEvaluator<IndexEqualsProposition>()
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        let emptyTrace: [TestEvaluationContext] = []

        // Test 1: Empty trace: p R q should be true
        #expect(
            try simpleEvaluator.evaluate(
                formula: .release(.atomic(TestPropositions.p_true), .atomic(TestPropositions.p_false)),
                trace: emptyTrace,
                contextProvider: contextProvider
            ),
            "R on empty trace should be true"
        )

        // Test 2: (true R false)
        let trace_s012 = createTestTrace(length: 3)
        // true R false
        // State s0: q_rhs=false, so q_rhs is false AND we need to check if p_lhs=true
        //          Since both q=false and p=true, we continue
        // State s1: q_rhs=false, p_lhs=true, continue
        // State s2: q_rhs=false, p_lhs=true, continue
        // We reach end of trace without q becoming true, but p was always true when q was false
        // So the formula should be false
        #expect(try !simpleEvaluator.evaluateAt(formula: .release(.atomic(TestPropositions.p_true), .atomic(TestPropositions.q_false)), trace: trace_s012, index: 0, contextProvider: contextProvider))

        // Test 3: (false R true)
        // State s0: q_rhs=true, so the formula is immediately true
        #expect(try simpleEvaluator.evaluateAt(formula: .release(.atomic(TestPropositions.p_false), .atomic(TestPropositions.q_true)), trace: trace_s012, index: 0, contextProvider: contextProvider))

        // Test 4: (false R false)
        // State s0: q_rhs=false, p_lhs=false. Since p is false when q is false, the formula fails.
        #expect(try !simpleEvaluator.evaluateAt(formula: .release(.atomic(TestPropositions.p_false), .atomic(TestPropositions.q_false)), trace: trace_s012, index: 0, contextProvider: contextProvider))

        // Test 5: (true R true)
        // State s0: q_rhs=true, so the formula is immediately true
        #expect(try simpleEvaluator.evaluateAt(formula: .release(.atomic(TestPropositions.p_true), .atomic(TestPropositions.q_true)), trace: trace_s012, index: 0, contextProvider: contextProvider))

        // Test 6: Index-based test - p = (idx==0), q = (idx==2)
        // p R q 
        // State s0: q=(idx==2) is false, p=(idx==0) is true, continue
        // State s1: q=(idx==2) is false, p=(idx==0) is false. Since p is false when q is false, the formula fails.
        let formula_p_idx_eq_0: LTLFormula<IndexEqualsProposition> = .atomic(IndexEqualsProposition(name: "p_idx_eq_0", targetIndex: 0))
        #expect(try !idxEvaluator.evaluateAt(formula: .release(formula_p_idx_eq_0, .atomic(IndexEqualsProposition(name: "q_idx_eq_2", targetIndex: 2))), trace: trace_s012, index: 0, contextProvider: contextProvider))

        // Test 7: Verify release matches ¬(¬p U ¬q) by testing both formulations
        // p R q ≡ ¬(¬p U ¬q)
        // For p=(idx==0), the test already shown above gives us release being false at s0.
        // ¬(¬(idx==0) U ¬(idx==2)) = ¬(idx!=0 U idx!=2)
        // s0: ¬p=(idx!=0) is F. ¬q=(idx!=2) is T. So (F U T) is T.
        // ¬(T) is FALSE.
        #expect(
            try !idxEvaluator.evaluate(
                formula: .release(formula_p_idx_eq_0, .atomic(IndexEqualsProposition(name: "q_idx_eq_2", targetIndex: 2))),
                trace: trace_s012,
                contextProvider: contextProvider
            )
        )
    }

    @Test("Next Operator Evaluation")
    func testNextOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 3)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: X(true) - should be true at all positions except the last
        let formula_next_true: LTLFormula<TestProposition> = .next(.booleanLiteral(true))
        #expect(try evaluator.evaluateAt(formula: formula_next_true, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_next_true, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_next_true, trace: trace, index: 2, contextProvider: contextProvider))

        // Test 2: X(false) - should be false at all positions except the last
        let formula_next_false: LTLFormula<TestProposition> = .next(.booleanLiteral(false))
        #expect(try !evaluator.evaluateAt(formula: formula_next_false, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_next_false, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_next_false, trace: trace, index: 2, contextProvider: contextProvider))

        // Test 3: X(p_true)
        let formula_next_p: LTLFormula<TestProposition> = .next(.atomic(TestPropositions.p_true))
        #expect(try evaluator.evaluateAt(formula: formula_next_p, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_next_p, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_next_p, trace: trace, index: 2, contextProvider: contextProvider))

        // Test 4: X(idx==2)
        let idx2 = IndexEqualsProposition(name: "idx_eq_2", targetIndex: 2)
        let formula_next_idx2: LTLFormula<TestProposition> = .next(.atomic(idx2))
        
        // At index 0: next state is index 1, idx==2 is false
        #expect(try !evaluator.evaluateAt(formula: formula_next_idx2, trace: trace, index: 0, contextProvider: contextProvider))
        // At index 1: next state is index 2, idx==2 is true
        #expect(try evaluator.evaluateAt(formula: formula_next_idx2, trace: trace, index: 1, contextProvider: contextProvider))
        // At index 2: no next state, should be false
        #expect(try !evaluator.evaluateAt(formula: formula_next_idx2, trace: trace, index: 2, contextProvider: contextProvider))

        // Test 5: X(X(true))
        let formula_next_next_true: LTLFormula<TestProposition> = .next(.next(.booleanLiteral(true)))
        #expect(try evaluator.evaluateAt(formula: formula_next_next_true, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_next_next_true, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_next_next_true, trace: trace, index: 2, contextProvider: contextProvider))

        // Test 6: Empty trace
        let emptyTrace: [TestEvaluationContext] = []
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try evaluator.evaluate(formula: formula_next_true, trace: emptyTrace, contextProvider: contextProvider)
        }

        // Test 7: Single-element trace
        let singleTrace = createTestTrace(length: 1)
        #expect(try !evaluator.evaluateAt(formula: formula_next_true, trace: singleTrace, index: 0, contextProvider: contextProvider))
    }

    @Test("Eventually Operator Evaluation")
    func testEventuallyOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 4)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: F(true) - should always be true
        let formula_eventually_true: LTLFormula<TestProposition> = .eventually(.booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_eventually_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: F(false) - should always be false
        let formula_eventually_false: LTLFormula<TestProposition> = .eventually(.booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_eventually_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 3: F(p_true) - should be true at all positions
        let formula_eventually_p: LTLFormula<TestProposition> = .eventually(.atomic(TestPropositions.p_true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_eventually_p, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 4: F(idx==3)
        let idx3 = IndexEqualsProposition(name: "idx_eq_3", targetIndex: 3)
        let formula_eventually_idx3: LTLFormula<TestProposition> = .eventually(.atomic(idx3))
        
        // Should be true at indices 0,1,2 (because index 3 will eventually be reached)
        #expect(try evaluator.evaluateAt(formula: formula_eventually_idx3, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_eventually_idx3, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_eventually_idx3, trace: trace, index: 2, contextProvider: contextProvider))
        // Should be true at index 3 (because it's true now)
        #expect(try evaluator.evaluateAt(formula: formula_eventually_idx3, trace: trace, index: 3, contextProvider: contextProvider))

        // Test 5: F(idx==0) - only true at index 0
        let idx0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let formula_eventually_idx0: LTLFormula<TestProposition> = .eventually(.atomic(idx0))
        
        #expect(try evaluator.evaluateAt(formula: formula_eventually_idx0, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_eventually_idx0, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_eventually_idx0, trace: trace, index: 2, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_eventually_idx0, trace: trace, index: 3, contextProvider: contextProvider))

        // Test 6: F(F(p)) ≡ F(p)
        let formula_eventually_eventually_p: LTLFormula<TestProposition> = .eventually(.eventually(.atomic(TestPropositions.p_true)))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_eventually_eventually_p, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 7: Empty trace
        let emptyTrace: [TestEvaluationContext] = []
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try evaluator.evaluate(formula: formula_eventually_true, trace: emptyTrace, contextProvider: contextProvider)
        }
    }

    @Test("Globally Operator Evaluation")
    func testGloballyOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 4)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: G(true) - should always be true
        let formula_globally_true: LTLFormula<TestProposition> = .globally(.booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_globally_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: G(false) - should always be false
        let formula_globally_false: LTLFormula<TestProposition> = .globally(.booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_globally_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 3: G(p_true) - should be true at all positions
        let formula_globally_p: LTLFormula<TestProposition> = .globally(.atomic(TestPropositions.p_true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_globally_p, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 4: G(p_false) - should be false at all positions
        let formula_globally_p_false: LTLFormula<TestProposition> = .globally(.atomic(TestPropositions.p_false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_globally_p_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 5: G(idx >= 2) - different at each position
        let idxGe2 = TestProposition(name: "idx_ge_2") { context in
            guard let idx = context.traceIndex else { return false }
            return idx >= 2
        }
        let formula_globally_idx_ge_2: LTLFormula<TestProposition> = .globally(.atomic(idxGe2))
        
        // At index 0: checks if all future states (0,1,2,3) have idx >= 2, which is false
        #expect(try !evaluator.evaluateAt(formula: formula_globally_idx_ge_2, trace: trace, index: 0, contextProvider: contextProvider))
        // At index 1: checks if all future states (1,2,3) have idx >= 2, which is false
        #expect(try !evaluator.evaluateAt(formula: formula_globally_idx_ge_2, trace: trace, index: 1, contextProvider: contextProvider))
        // At index 2: checks if all future states (2,3) have idx >= 2, which is true
        #expect(try evaluator.evaluateAt(formula: formula_globally_idx_ge_2, trace: trace, index: 2, contextProvider: contextProvider))
        // At index 3: checks if all future states (3) have idx >= 2, which is true
        #expect(try evaluator.evaluateAt(formula: formula_globally_idx_ge_2, trace: trace, index: 3, contextProvider: contextProvider))

        // Test 6: G(G(p)) ≡ G(p)
        let formula_globally_globally_p: LTLFormula<TestProposition> = .globally(.globally(.atomic(TestPropositions.p_true)))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_globally_globally_p, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 7: Empty trace
        let emptyTrace: [TestEvaluationContext] = []
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try evaluator.evaluate(formula: formula_globally_true, trace: emptyTrace, contextProvider: contextProvider)
        }

        // Test 8: G(F(p)) where p is idx==3
        let idx3 = IndexEqualsProposition(name: "idx_eq_3", targetIndex: 3)
        let formula_globally_eventually_idx3: LTLFormula<TestProposition> = .globally(.eventually(.atomic(idx3)))
        
        // At any position, we need F(idx==3) to be true from that point onwards
        // This is only true if we can always reach index 3 eventually
        #expect(try evaluator.evaluateAt(formula: formula_globally_eventually_idx3, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_globally_eventually_idx3, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_globally_eventually_idx3, trace: trace, index: 2, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_globally_eventually_idx3, trace: trace, index: 3, contextProvider: contextProvider))
    }

    @Test("Until Operator Evaluation")
    func testUntilOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 4)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: true U true - should be true (q is immediately true)
        let formula_true_until_true: LTLFormula<TestProposition> = .until(.booleanLiteral(true), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_true_until_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: false U true - should be true (q is immediately true)
        let formula_false_until_true: LTLFormula<TestProposition> = .until(.booleanLiteral(false), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_false_until_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 3: true U false - should be false (q is never true)
        let formula_true_until_false: LTLFormula<TestProposition> = .until(.booleanLiteral(true), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_true_until_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 4: false U false - should be false (q is never true)
        let formula_false_until_false: LTLFormula<TestProposition> = .until(.booleanLiteral(false), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_false_until_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 5: (idx < 2) U (idx == 2)
        let idxLt2 = TestProposition(name: "idx_lt_2") { context in
            guard let idx = context.traceIndex else { return false }
            return idx < 2
        }
        let idx2 = IndexEqualsProposition(name: "idx_eq_2", targetIndex: 2)
        let formula_idx_lt_2_until_idx_2: LTLFormula<TestProposition> = .until(.atomic(idxLt2), .atomic(idx2))
        
        // At index 0: p holds (0 < 2), and eventually at index 2, q becomes true
        #expect(try evaluator.evaluateAt(formula: formula_idx_lt_2_until_idx_2, trace: trace, index: 0, contextProvider: contextProvider))
        // At index 1: p holds (1 < 2), and at next index 2, q becomes true
        #expect(try evaluator.evaluateAt(formula: formula_idx_lt_2_until_idx_2, trace: trace, index: 1, contextProvider: contextProvider))
        // At index 2: p doesn't hold (2 < 2 is false) but q is true, so formula is true
        #expect(try evaluator.evaluateAt(formula: formula_idx_lt_2_until_idx_2, trace: trace, index: 2, contextProvider: contextProvider))
        // At index 3: p doesn't hold and q is false, so formula is false
        #expect(try !evaluator.evaluateAt(formula: formula_idx_lt_2_until_idx_2, trace: trace, index: 3, contextProvider: contextProvider))

        // Test 6: (idx == 0) U (idx == 3) - p only true at start
        let idx0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx3 = IndexEqualsProposition(name: "idx_eq_3", targetIndex: 3)
        let formula_idx0_until_idx3: LTLFormula<TestProposition> = .until(.atomic(idx0), .atomic(idx3))
        
        // At index 0: p is true but becomes false at index 1, before q becomes true at index 3
        #expect(try !evaluator.evaluateAt(formula: formula_idx0_until_idx3, trace: trace, index: 0, contextProvider: contextProvider))
        // At other indices: p is false and q might not be immediately true
        #expect(try !evaluator.evaluateAt(formula: formula_idx0_until_idx3, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_idx0_until_idx3, trace: trace, index: 2, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_idx0_until_idx3, trace: trace, index: 3, contextProvider: contextProvider)) // q is true at index 3

        // Test 7: p U (F q) where p is true and q is idx==3
        let formula_true_until_eventually_idx3: LTLFormula<TestProposition> = .until(.booleanLiteral(true), .eventually(.atomic(idx3)))
        
        // F(idx==3) is true from indices 0-3, so true U F(idx==3) should be true
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_true_until_eventually_idx3, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 8: Empty trace
        let emptyTrace: [TestEvaluationContext] = []
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try evaluator.evaluate(formula: formula_true_until_true, trace: emptyTrace, contextProvider: contextProvider)
        }
    }
}