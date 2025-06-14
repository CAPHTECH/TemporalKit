import Foundation
import Testing
@testable import TemporalKit

// MARK: - Basic Operator Tests

@Suite("LTL Formula Basic Operator Trace Evaluation Tests")
struct LTLFormulaTraceEvaluationBasicTests {
    
    @Test("Atomic Proposition Evaluation")
    func testAtomicPropositionEvaluation() throws {
        let trace = createTrace(length: 3)

        // Test 1: Atomic proposition that always returns true
        for i in 0..<trace.count {
            #expect(try ltl_true.evaluateAt(trace[i]))
        }

        // Test 2: Atomic proposition that always returns false
        for i in 0..<trace.count {
            #expect(try !ltl_false.evaluateAt(trace[i]))
        }

        // Test 3: Index-based proposition
        let idxProp = ClosureTemporalProposition<TestState, Bool>(id: "idx_eq_1", name: "idx_eq_1") { state in
            state.index == 1
        }
        let formula_idx_eq_1: TestFormula = .atomic(idxProp)
        
        #expect(try !formula_idx_eq_1.evaluateAt(trace[0]))
        #expect(try formula_idx_eq_1.evaluateAt(trace[1]))
        #expect(try !formula_idx_eq_1.evaluateAt(trace[2]))
    }

    @Test("Boolean Literal Evaluation")
    func testBooleanLiteralEvaluation() throws {
        let trace = createTrace(length: 2)

        // Test 1: true literal
        let formula_true: TestFormula = .booleanLiteral(true)
        for i in 0..<trace.count {
            #expect(try formula_true.evaluateAt(trace[i]))
        }

        // Test 2: false literal
        let formula_false: TestFormula = .booleanLiteral(false)
        for i in 0..<trace.count {
            #expect(try !formula_false.evaluateAt(trace[i]))
        }
    }

    @Test("Not Operator Evaluation")
    func testNotOperatorEvaluation() throws {
        let trace = createTrace(length: 3)

        // Test 1: ¬true = false
        let formula_not_true: TestFormula = .not(.booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try !formula_not_true.evaluateAt(trace[i]))
        }

        // Test 2: ¬false = true
        let formula_not_false: TestFormula = .not(.booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try formula_not_false.evaluateAt(trace[i]))
        }

        // Test 3: ¬¬true = true
        let formula_not_not_true: TestFormula = .not(.not(.booleanLiteral(true)))
        for i in 0..<trace.count {
            #expect(try formula_not_not_true.evaluateAt(trace[i]))
        }

        // Test 4: ¬(idx==1)
        let idxProp = ClosureTemporalProposition<TestState, Bool>(id: "idx_eq_1", name: "idx_eq_1") { state in
            state.index == 1
        }
        let formula_not_idx_eq_1: TestFormula = .not(.atomic(idxProp))
        
        #expect(try formula_not_idx_eq_1.evaluateAt(trace[0]))
        #expect(try !formula_not_idx_eq_1.evaluateAt(trace[1]))
        #expect(try formula_not_idx_eq_1.evaluateAt(trace[2]))
    }

    @Test("And Operator Evaluation")
    func testAndOperatorEvaluation() throws {
        let trace = createTrace(length: 3)

        // Test 1: true ∧ true = true
        let formula_true_and_true: TestFormula = .and(.booleanLiteral(true), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try formula_true_and_true.evaluateAt(trace[i]))
        }

        // Test 2: true ∧ false = false
        let formula_true_and_false: TestFormula = .and(.booleanLiteral(true), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !formula_true_and_false.evaluateAt(trace[i]))
        }

        // Test 3: false ∧ true = false
        let formula_false_and_true: TestFormula = .and(.booleanLiteral(false), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try !formula_false_and_true.evaluateAt(trace[i]))
        }

        // Test 4: false ∧ false = false
        let formula_false_and_false: TestFormula = .and(.booleanLiteral(false), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !formula_false_and_false.evaluateAt(trace[i]))
        }

        // Test 5: p_true ∧ q_true = true
        let formula_p_and_q: TestFormula = .and(.atomic(p_true_prop), .atomic(p_true_prop))
        for i in 0..<trace.count {
            #expect(try formula_p_and_q.evaluateAt(trace[i]))
        }

        // Test 6: (idx==0) ∧ (idx==1) = false at all positions
        let idx0 = ClosureTemporalProposition<TestState, Bool>(id: "idx_eq_0", name: "idx_eq_0") { state in
            state.index == 0
        }
        let idx1 = ClosureTemporalProposition<TestState, Bool>(id: "idx_eq_1", name: "idx_eq_1") { state in
            state.index == 1
        }
        let formula_idx0_and_idx1: TestFormula = .and(.atomic(idx0), .atomic(idx1))
        for i in 0..<trace.count {
            #expect(try !formula_idx0_and_idx1.evaluateAt(trace[i]))
        }

        // Test 7: (idx==1) ∧ true = (idx==1)
        let formula_idx1_and_true: TestFormula = .and(.atomic(idx1), .booleanLiteral(true))
        #expect(try !formula_idx1_and_true.evaluateAt(trace[0]))
        #expect(try formula_idx1_and_true.evaluateAt(trace[1]))
        #expect(try !formula_idx1_and_true.evaluateAt(trace[2]))
    }

    @Test("Or Operator Evaluation")
    func testOrOperatorEvaluation() throws {
        let trace = createTrace(length: 3)

        // Test 1: true ∨ true = true
        let formula_true_or_true: TestFormula = .or(.booleanLiteral(true), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try formula_true_or_true.evaluateAt(trace[i]))
        }

        // Test 2: true ∨ false = true
        let formula_true_or_false: TestFormula = .or(.booleanLiteral(true), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try formula_true_or_false.evaluateAt(trace[i]))
        }

        // Test 3: false ∨ true = true
        let formula_false_or_true: TestFormula = .or(.booleanLiteral(false), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try formula_false_or_true.evaluateAt(trace[i]))
        }

        // Test 4: false ∨ false = false
        let formula_false_or_false: TestFormula = .or(.booleanLiteral(false), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !formula_false_or_false.evaluateAt(trace[i]))
        }

        // Test 5: p_false ∨ q_false = false
        let formula_p_or_q: TestFormula = .or(.atomic(p_false_prop), .atomic(p_false_prop))
        for i in 0..<trace.count {
            #expect(try !formula_p_or_q.evaluateAt(trace[i]))
        }

        // Test 6: (idx==0) ∨ (idx==1) at each position
        let idx0 = ClosureTemporalProposition<TestState, Bool>(id: "idx_eq_0", name: "idx_eq_0") { state in
            state.index == 0
        }
        let idx1 = ClosureTemporalProposition<TestState, Bool>(id: "idx_eq_1", name: "idx_eq_1") { state in
            state.index == 1
        }
        let formula_idx0_or_idx1: TestFormula = .or(.atomic(idx0), .atomic(idx1))
        
        #expect(try formula_idx0_or_idx1.evaluateAt(trace[0]))
        #expect(try formula_idx0_or_idx1.evaluateAt(trace[1]))
        #expect(try !formula_idx0_or_idx1.evaluateAt(trace[2]))
    }

    @Test("Implies Operator Evaluation")
    func testImpliesOperatorEvaluation() throws {
        let trace = createTrace(length: 3)

        // Test 1: true → true = true
        let formula_true_implies_true: TestFormula = .implies(.booleanLiteral(true), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try formula_true_implies_true.evaluateAt(trace[i]))
        }

        // Test 2: true → false = false
        let formula_true_implies_false: TestFormula = .implies(.booleanLiteral(true), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !formula_true_implies_false.evaluateAt(trace[i]))
        }

        // Test 3: false → true = true
        let formula_false_implies_true: TestFormula = .implies(.booleanLiteral(false), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try formula_false_implies_true.evaluateAt(trace[i]))
        }

        // Test 4: false → false = true
        let formula_false_implies_false: TestFormula = .implies(.booleanLiteral(false), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try formula_false_implies_false.evaluateAt(trace[i]))
        }

        // Test 5: p_true → q_false = false
        let formula_p_implies_q: TestFormula = .implies(.atomic(p_true_prop), .atomic(p_false_prop))
        for i in 0..<trace.count {
            #expect(try !formula_p_implies_q.evaluateAt(trace[i]))
        }

        // Test 6: (idx==0) → (idx==1)
        let idx0 = ClosureTemporalProposition<TestState, Bool>(id: "idx_eq_0", name: "idx_eq_0") { state in
            state.index == 0
        }
        let idx1 = ClosureTemporalProposition<TestState, Bool>(id: "idx_eq_1", name: "idx_eq_1") { state in
            state.index == 1
        }
        let formula_idx0_implies_idx1: TestFormula = .implies(.atomic(idx0), .atomic(idx1))
        
        // At index 0: true → false = false
        #expect(try !formula_idx0_implies_idx1.evaluateAt(trace[0]))
        // At index 1: false → true = true
        #expect(try formula_idx0_implies_idx1.evaluateAt(trace[1]))
        // At index 2: false → false = true
        #expect(try formula_idx0_implies_idx1.evaluateAt(trace[2]))
    }
}