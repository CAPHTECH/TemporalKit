import Foundation
import Testing
@testable import TemporalKit

// MARK: - Error Propagation Tests

@Suite("LTL Formula Trace Evaluation Error Tests")
struct LTLFormulaTraceEvaluationErrorTests {
    
    @Test func testEmptyTraceEvaluationThrowsError() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let emptyTrace: [TestEvaluationContext] = []
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        
        // Atomic proposition
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try evaluator.evaluate(formula: .atomic(TestPropositions.p_true), trace: emptyTrace, contextProvider: contextProvider)
        }
        
        // Boolean literal
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try evaluator.evaluate(formula: .booleanLiteral(true), trace: emptyTrace, contextProvider: contextProvider)
        }
        
        // Not operator
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try evaluator.evaluate(formula: .not(.booleanLiteral(true)), trace: emptyTrace, contextProvider: contextProvider)
        }
        
        // Complex formula
        let complexFormula: LTLFormula<TestProposition> = .until(.atomic(TestPropositions.p_true), .eventually(.atomic(TestPropositions.q_true)))
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try evaluator.evaluate(formula: complexFormula, trace: emptyTrace, contextProvider: contextProvider)
        }
    }
    
    @Test func testTraceIndexOutOfBoundsInNext() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 3)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        
        // Direct evaluation at invalid index should throw
        #expect(throws: LTLTraceEvaluationError.indexOutOfBounds(index: 5, traceLength: 3)) {
            _ = try evaluator.evaluateAt(formula: .next(.booleanLiteral(true)), trace: trace, index: 5, contextProvider: contextProvider)
        }
        
        // Negative index should throw
        #expect(throws: LTLTraceEvaluationError.indexOutOfBounds(index: -1, traceLength: 3)) {
            _ = try evaluator.evaluateAt(formula: .next(.booleanLiteral(true)), trace: trace, index: -1, contextProvider: contextProvider)
        }
        
        // Index equal to trace length should throw
        #expect(throws: LTLTraceEvaluationError.indexOutOfBounds(index: 3, traceLength: 3)) {
            _ = try evaluator.evaluateAt(formula: .next(.booleanLiteral(true)), trace: trace, index: 3, contextProvider: contextProvider)
        }
    }
    
    @Test func testTraceIndexOutOfBoundsInAtomic() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        
        // Evaluation at invalid index
        #expect(throws: LTLTraceEvaluationError.indexOutOfBounds(index: 10, traceLength: 2)) {
            _ = try evaluator.evaluateAt(formula: .atomic(TestPropositions.p_true), trace: trace, index: 10, contextProvider: contextProvider)
        }
    }
    
    @Test func testAndOperatorLeftHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError") }
        let formula: LTLFormula<TestProposition> = .and(.atomic(p_throws), .atomic(TestPropositions.q_true))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError")) {
            _ = try evaluator.evaluateAt(formula: formula, trace: trace, index: 0, contextProvider: contextProvider)
        }
    }
    
    @Test func testOrOperatorLeftHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError") }
        let formula: LTLFormula<TestProposition> = .or(.atomic(p_throws), .atomic(TestPropositions.q_true))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError")) {
            _ = try evaluator.evaluateAt(formula: formula, trace: trace, index: 0, contextProvider: contextProvider)
        }
    }
    
    @Test func testImpliesOperatorLeftHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError") }
        let formula: LTLFormula<TestProposition> = .implies(.atomic(p_throws), .atomic(TestPropositions.q_true))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError")) {
            _ = try evaluator.evaluateAt(formula: formula, trace: trace, index: 0, contextProvider: contextProvider)
        }
    }
    
    @Test func testNextOperatorSubformulaErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: subformulaError") }
        let formula: LTLFormula<TestProposition> = .next(.atomic(p_throws))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: subformulaError")) {
            _ = try evaluator.evaluateAt(formula: formula, trace: trace, index: 0, contextProvider: contextProvider)
        }
    }
    
    @Test func testUntilOperatorRightHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_true = TestPropositions.p_true
        let q_throws = TestProposition(name: "q_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: rightError") }
        // p U q where q throws immediately
        let formula: LTLFormula<TestProposition> = .until(.atomic(p_true), .atomic(q_throws))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: rightError")) {
            _ = try evaluator.evaluateAt(formula: formula, trace: trace, index: 0, contextProvider: contextProvider)
        }
    }
    
    @Test func testUntilOperatorLeftHandErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 3)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError") }
        let q_false = TestPropositions.q_false
        // If q is false at s0, we check p at s0. p throws.
        let formula: LTLFormula<TestProposition> = .until(.atomic(p_throws), .atomic(q_false))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError")) {
            _ = try evaluator.evaluateAt(formula: formula, trace: trace, index: 0, contextProvider: contextProvider)
        }
    }
    
    @Test func testWeakUntilOperatorErrorPropagation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        
        // Test 1: Right-hand side throws immediately
        let q_throws = TestProposition(name: "q_throws") { _ in
            throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: rightError")
        }
        let formula1: LTLFormula<TestProposition> = .weakUntil(.atomic(TestPropositions.p_true), .atomic(q_throws))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: rightError")) {
            _ = try evaluator.evaluateAt(formula: formula1, trace: trace, index: 0, contextProvider: contextProvider)
        }
        
        // Test 2: Left-hand side throws when right is false
        let p_throws = TestProposition(name: "p_throws") { _ in
            throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError")
        }
        let formula2: LTLFormula<TestProposition> = .weakUntil(.atomic(p_throws), .atomic(TestPropositions.q_false))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: leftError")) {
            _ = try evaluator.evaluateAt(formula: formula2, trace: trace, index: 0, contextProvider: contextProvider)
        }
    }
    
    @Test func testNotOperatorWithErroringSubformula() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 1)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: errorInNot") }
        let formula: LTLFormula<TestProposition> = .not(.atomic(p_throws))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: errorInNot")) {
            _ = try evaluator.evaluateAt(formula: formula, trace: trace, index: 0, contextProvider: contextProvider)
        }
    }
    
    @Test func testReleaseOperatorErrorPropagation_Case1_LeftThrows_CorrectedExpectation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: ohNoAnError") }
        // (p_throws R p_false) -> not ( (not p_throws) U (not p_false) ) 
        // -> not ( (not p_throws) U true )
        // Now, evaluating (not p_throws):
        //   not(p_throws) will evaluate p_throws, which throws. So the error propagates immediately.
        let formula_throws_R_false: LTLFormula<TestProposition> = .release(.atomic(p_throws), .atomic(TestPropositions.p_false))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: ohNoAnError")) {
            _ = try evaluator.evaluate(formula: formula_throws_R_false, trace: trace, contextProvider: contextProvider)
        }
    }
    
    @Test func testReleaseOperatorErrorPropagation_Case2_RightThrows() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: ohNoAnError") }
        // (p_true R p_throws) -> not ( (not p_true) U (not p_throws) ) 
        // -> not ( false U (not p_throws) )
        //   false U (not p_throws) at s0:
        //     (not p_throws) at s0 -> should throw.
        let formula_true_R_throws: LTLFormula<TestProposition> = .release(.atomic(TestPropositions.p_true), .atomic(p_throws))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: ohNoAnError")) {
            _ = try evaluator.evaluate(formula: formula_true_R_throws, trace: trace, contextProvider: contextProvider)
        }
    }
    
    @Test func testReleaseOperatorErrorPropagation_Case3_FalseRThrows() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }
        let p_throws = TestProposition(name: "p_throws") { _ in throw LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: ohNoAnError") }
        // (p_false R p_throws) -> not ( (not p_false) U (not p_throws) ) 
        // -> not ( true U (not p_throws) )
        //   true U (not p_throws) at s0:
        //     (not p_throws) at s0 -> should throw.
        let formula_false_R_throws: LTLFormula<TestProposition> = .release(.atomic(TestPropositions.p_false), .atomic(p_throws))
        #expect(throws: LTLTraceEvaluationError.propositionEvaluationFailure("Error evaluating proposition: ohNoAnError")) {
            _ = try evaluator.evaluate(formula: formula_false_R_throws, trace: trace, contextProvider: contextProvider)
        }
    }
}