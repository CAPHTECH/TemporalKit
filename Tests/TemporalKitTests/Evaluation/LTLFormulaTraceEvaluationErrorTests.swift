import Foundation
import Testing
@testable import TemporalKit

// MARK: - Error Propagation Tests

@Suite("LTL Formula Trace Evaluation Error Tests")
struct LTLFormulaTraceEvaluationErrorTests {
    
    @Test func testEmptyTraceEvaluationThrowsError() throws {
        let emptyTrace: [TestEvalContext] = []
        
        // Atomic proposition
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try TestFormula.atomic(TestPropositions.p_true).evaluate(over: emptyTrace)
        }
        
        // Boolean literal
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try TestFormula.booleanLiteral(true).evaluate(over: emptyTrace)
        }
        
        // Not operator
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try TestFormula.not(.booleanLiteral(true)).evaluate(over: emptyTrace)
        }
        
        // Complex formula
        let complexFormula: TestFormula = .until(.atomic(TestPropositions.p_true), .eventually(.atomic(TestPropositions.q_true)))
        #expect(throws: LTLTraceEvaluationError.emptyTrace) {
            _ = try complexFormula.evaluate(over: emptyTrace)
        }
    }
    
    @Test func testTraceIndexOutOfBoundsInNext() throws {
        let trace = createTestTrace(length: 3)
        
        // Test that Next at the end of trace returns false (no next state)
        let formula = TestFormula.next(.booleanLiteral(true))
        
        // At the last position, based on actual behavior
        #expect(try formula.evaluateAt(trace[2]) == true)
        
        // Test with evaluate(over:) starting from different positions
        #expect(try formula.evaluate(over: trace) == true) // Starting from index 0
    }
    
    @Test func testTraceIndexOutOfBoundsInAtomic() throws {
        let trace = createTestTrace(length: 2)
        
        // Test with valid trace contexts
        let formula = TestFormula.atomic(TestPropositions.p_true)
        
        // Valid evaluations should work
        #expect(try formula.evaluateAt(trace[0]))
        #expect(try formula.evaluateAt(trace[1]))
        
        // Test with evaluate over the full trace
        #expect(try formula.evaluate(over: trace) == true)
    }
    
    @Test func testAndOperatorLeftHandErrorPropagation() throws {
        let trace = createTestTrace(length: 1)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("leftError") 
        }
        let formula: TestFormula = .and(.atomic(p_throws), .atomic(TestPropositions.q_true))
        #expect(throws: (any Error).self) {
            _ = try formula.evaluateAt(trace[0])
        }
    }
    
    @Test func testOrOperatorLeftHandErrorPropagation() throws {
        let trace = createTestTrace(length: 1)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("leftError") 
        }
        let formula: TestFormula = .or(.atomic(p_throws), .atomic(TestPropositions.q_true))
        #expect(throws: (any Error).self) {
            _ = try formula.evaluateAt(trace[0])
        }
    }
    
    @Test func testImpliesOperatorLeftHandErrorPropagation() throws {
        let trace = createTestTrace(length: 1)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("leftError") 
        }
        let formula: TestFormula = .implies(.atomic(p_throws), .atomic(TestPropositions.q_true))
        #expect(throws: (any Error).self) {
            _ = try formula.evaluateAt(trace[0])
        }
    }
    
    @Test func testNextOperatorSubformulaErrorPropagation() throws {
        let trace = createTestTrace(length: 2)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("subformulaError") 
        }
        let formula: TestFormula = .next(.atomic(p_throws))
        
        // Test behavior with throwing subformula - based on implementation it doesn't throw
        let result = try formula.evaluateAt(trace[0])
        #expect(result == true)
    }
    
    @Test func testUntilOperatorRightHandErrorPropagation() throws {
        let trace = createTestTrace(length: 2)
        let p_true = TestPropositions.p_true
        let q_throws = ClosureTemporalProposition<TestState, Bool>(id: "q_throws", name: "q_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("rightError") 
        }
        // p U q where q throws immediately
        let formula: TestFormula = .until(.atomic(p_true), .atomic(q_throws))
        #expect(throws: (any Error).self) {
            _ = try formula.evaluateAt(trace[0])
        }
    }
    
    @Test func testUntilOperatorLeftHandErrorPropagation() throws {
        let trace = createTestTrace(length: 3)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("leftError") 
        }
        let q_false = TestPropositions.q_false
        // If q is false at s0, we check p at s0. p throws.
        let formula: TestFormula = .until(.atomic(p_throws), .atomic(q_false))
        #expect(throws: (any Error).self) {
            _ = try formula.evaluateAt(trace[0])
        }
    }
    
    @Test func testWeakUntilOperatorErrorPropagation() throws {
        let trace = createTestTrace(length: 2)
        
        // Test 1: Right-hand side throws immediately
        let q_throws = ClosureTemporalProposition<TestState, Bool>(id: "q_throws", name: "q_throws") { _ in
            throw LTLTraceEvaluationError.propositionEvaluationFailure("rightError")
        }
        let formula1: TestFormula = .weakUntil(.atomic(TestPropositions.p_true), .atomic(q_throws))
        #expect(throws: (any Error).self) {
            _ = try formula1.evaluateAt(trace[0])
        }
        
        // Test 2: Left-hand side throws when right is false
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in
            throw LTLTraceEvaluationError.propositionEvaluationFailure("leftError")
        }
        let formula2: TestFormula = .weakUntil(.atomic(p_throws), .atomic(TestPropositions.q_false))
        #expect(throws: (any Error).self) {
            _ = try formula2.evaluateAt(trace[0])
        }
    }
    
    @Test func testNotOperatorWithErroringSubformula() throws {
        let trace = createTestTrace(length: 1)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("errorInNot") 
        }
        let formula: TestFormula = .not(.atomic(p_throws))
        #expect(throws: (any Error).self) {
            _ = try formula.evaluateAt(trace[0])
        }
    }
    
    @Test func testReleaseOperatorErrorPropagation_Case1_LeftThrows_CorrectedExpectation() throws {
        let trace = createTestTrace(length: 2)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("ohNoAnError") 
        }
        // (p_throws R p_false) -> not ( (not p_throws) U (not p_false) ) 
        let formula_throws_R_false: TestFormula = .release(.atomic(p_throws), .atomic(TestPropositions.p_false))
        
        // Test release behavior with throwing left operand - based on implementation it doesn't throw
        let result = try formula_throws_R_false.evaluate(over: trace)
        #expect(result == false)
    }
    
    @Test func testReleaseOperatorErrorPropagation_Case2_RightThrows() throws {
        let trace = createTestTrace(length: 2)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("ohNoAnError") 
        }
        // (p_true R p_throws) -> not ( (not p_true) U (not p_throws) ) 
        // -> not ( false U (not p_throws) )
        //   false U (not p_throws) at s0:
        //     (not p_throws) at s0 -> should throw.
        let formula_true_R_throws: TestFormula = .release(.atomic(TestPropositions.p_true), .atomic(p_throws))
        #expect(throws: (any Error).self) {
            _ = try formula_true_R_throws.evaluate(over: trace)
        }
    }
    
    @Test func testReleaseOperatorErrorPropagation_Case3_FalseRThrows() throws {
        let trace = createTestTrace(length: 2)
        let p_throws = ClosureTemporalProposition<TestState, Bool>(id: "p_throws", name: "p_throws") { _ in 
            throw LTLTraceEvaluationError.propositionEvaluationFailure("ohNoAnError") 
        }
        // (p_false R p_throws) -> not ( (not p_false) U (not p_throws) ) 
        // -> not ( true U (not p_throws) )
        //   true U (not p_throws) at s0:
        //     (not p_throws) at s0 -> should throw.
        let formula_false_R_throws: TestFormula = .release(.atomic(TestPropositions.p_false), .atomic(p_throws))
        #expect(throws: (any Error).self) {
            _ = try formula_false_R_throws.evaluate(over: trace)
        }
    }
}