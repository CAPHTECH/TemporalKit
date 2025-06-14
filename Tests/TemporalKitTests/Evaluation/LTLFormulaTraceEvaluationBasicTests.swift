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
        _traceIndex
    }
}

/// テストで使用するシンプルな命題の実装
class TestProposition: TemporalProposition, @unchecked Sendable {
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
        try evaluationResult(context)
    }
}

// MARK: - Common Test Propositions

enum TestPropositions {
    static let p_true = TestProposition(id: "p_true", name: "p") { _ in true }
    static let p_false = TestProposition(id: "p_false", name: "p") { _ in false }
    static let q_true = TestProposition(id: "q_true", name: "q") { _ in true }
    static let q_false = TestProposition(id: "q_false", name: "q") { _ in false }
}

// MARK: - Helper Functions

/// テスト用のトレースを作成
func createTestTrace(length: Int) -> [TestEvaluationContext] {
    return (0..<length).map { index in
        TestEvaluationContext(state: TestState(index: index), traceIndex: index)
    }
}

// MARK: - Index Based Propositions

class IndexEqualsProposition: TemporalProposition, @unchecked Sendable {
    typealias Value = Bool
    let id: PropositionID
    let name: String
    let targetIndex: Int

    init(name: String, targetIndex: Int) {
        self.id = PropositionID(rawValue: "idx_eq_\(targetIndex)")!
        self.name = name
        self.targetIndex = targetIndex
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        guard let traceIndex = context.traceIndex else {
            throw LTLTraceEvaluationError.missingTraceIndex(formula: "IndexEqualsProposition")
        }
        return traceIndex == targetIndex
    }
}

// MARK: - Basic Operator Tests

@Suite("LTL Formula Basic Operator Trace Evaluation Tests")
struct LTLFormulaTraceEvaluationBasicTests {
    
    @Test("Atomic Proposition Evaluation")
    func testAtomicPropositionEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 3)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: Atomic proposition that always returns true
        let formula_p_true: LTLFormula<TestProposition> = .atomic(TestPropositions.p_true)
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_p_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: Atomic proposition that always returns false
        let formula_p_false: LTLFormula<TestProposition> = .atomic(TestPropositions.p_false)
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_p_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 3: Index-based proposition
        let idxProp = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let formula_idx_eq_1: LTLFormula<TestProposition> = .atomic(idxProp)
        
        #expect(try !evaluator.evaluateAt(formula: formula_idx_eq_1, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_idx_eq_1, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_idx_eq_1, trace: trace, index: 2, contextProvider: contextProvider))
    }

    @Test("Boolean Literal Evaluation")
    func testBooleanLiteralEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 2)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: true literal
        let formula_true: LTLFormula<TestProposition> = .booleanLiteral(true)
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: false literal
        let formula_false: LTLFormula<TestProposition> = .booleanLiteral(false)
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_false, trace: trace, index: i, contextProvider: contextProvider))
        }
    }

    @Test("Not Operator Evaluation")
    func testNotOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 3)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: ¬true = false
        let formula_not_true: LTLFormula<TestProposition> = .not(.booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_not_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: ¬false = true
        let formula_not_false: LTLFormula<TestProposition> = .not(.booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_not_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 3: ¬¬true = true
        let formula_not_not_true: LTLFormula<TestProposition> = .not(.not(.booleanLiteral(true)))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_not_not_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 4: ¬(idx==1)
        let idxProp = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let formula_not_idx_eq_1: LTLFormula<TestProposition> = .not(.atomic(idxProp))
        
        #expect(try evaluator.evaluateAt(formula: formula_not_idx_eq_1, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_not_idx_eq_1, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_not_idx_eq_1, trace: trace, index: 2, contextProvider: contextProvider))
    }

    @Test("And Operator Evaluation")
    func testAndOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 3)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: true ∧ true = true
        let formula_true_and_true: LTLFormula<TestProposition> = .and(.booleanLiteral(true), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_true_and_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: true ∧ false = false
        let formula_true_and_false: LTLFormula<TestProposition> = .and(.booleanLiteral(true), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_true_and_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 3: false ∧ true = false
        let formula_false_and_true: LTLFormula<TestProposition> = .and(.booleanLiteral(false), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_false_and_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 4: false ∧ false = false
        let formula_false_and_false: LTLFormula<TestProposition> = .and(.booleanLiteral(false), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_false_and_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 5: p_true ∧ q_true = true
        let formula_p_and_q: LTLFormula<TestProposition> = .and(.atomic(TestPropositions.p_true), .atomic(TestPropositions.q_true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_p_and_q, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 6: (idx==0) ∧ (idx==1) = false at all positions
        let idx0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let formula_idx0_and_idx1: LTLFormula<TestProposition> = .and(.atomic(idx0), .atomic(idx1))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_idx0_and_idx1, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 7: (idx==1) ∧ true = (idx==1)
        let formula_idx1_and_true: LTLFormula<TestProposition> = .and(.atomic(idx1), .booleanLiteral(true))
        #expect(try !evaluator.evaluateAt(formula: formula_idx1_and_true, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_idx1_and_true, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_idx1_and_true, trace: trace, index: 2, contextProvider: contextProvider))
    }

    @Test("Or Operator Evaluation")
    func testOrOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 3)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: true ∨ true = true
        let formula_true_or_true: LTLFormula<TestProposition> = .or(.booleanLiteral(true), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_true_or_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: true ∨ false = true
        let formula_true_or_false: LTLFormula<TestProposition> = .or(.booleanLiteral(true), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_true_or_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 3: false ∨ true = true
        let formula_false_or_true: LTLFormula<TestProposition> = .or(.booleanLiteral(false), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_false_or_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 4: false ∨ false = false
        let formula_false_or_false: LTLFormula<TestProposition> = .or(.booleanLiteral(false), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_false_or_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 5: p_false ∨ q_false = false
        let formula_p_or_q: LTLFormula<TestProposition> = .or(.atomic(TestPropositions.p_false), .atomic(TestPropositions.q_false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_p_or_q, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 6: (idx==0) ∨ (idx==1) at each position
        let idx0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let formula_idx0_or_idx1: LTLFormula<TestProposition> = .or(.atomic(idx0), .atomic(idx1))
        
        #expect(try evaluator.evaluateAt(formula: formula_idx0_or_idx1, trace: trace, index: 0, contextProvider: contextProvider))
        #expect(try evaluator.evaluateAt(formula: formula_idx0_or_idx1, trace: trace, index: 1, contextProvider: contextProvider))
        #expect(try !evaluator.evaluateAt(formula: formula_idx0_or_idx1, trace: trace, index: 2, contextProvider: contextProvider))
    }

    @Test("Implies Operator Evaluation")
    func testImpliesOperatorEvaluation() throws {
        let evaluator = LTLFormulaTraceEvaluator<TestProposition>()
        let trace = createTestTrace(length: 3)
        let contextProvider = { (context: TestEvaluationContext, _: Int) -> TestEvaluationContext in context }

        // Test 1: true → true = true
        let formula_true_implies_true: LTLFormula<TestProposition> = .implies(.booleanLiteral(true), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_true_implies_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 2: true → false = false
        let formula_true_implies_false: LTLFormula<TestProposition> = .implies(.booleanLiteral(true), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_true_implies_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 3: false → true = true
        let formula_false_implies_true: LTLFormula<TestProposition> = .implies(.booleanLiteral(false), .booleanLiteral(true))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_false_implies_true, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 4: false → false = true
        let formula_false_implies_false: LTLFormula<TestProposition> = .implies(.booleanLiteral(false), .booleanLiteral(false))
        for i in 0..<trace.count {
            #expect(try evaluator.evaluateAt(formula: formula_false_implies_false, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 5: p_true → q_false = false
        let formula_p_implies_q: LTLFormula<TestProposition> = .implies(.atomic(TestPropositions.p_true), .atomic(TestPropositions.q_false))
        for i in 0..<trace.count {
            #expect(try !evaluator.evaluateAt(formula: formula_p_implies_q, trace: trace, index: i, contextProvider: contextProvider))
        }

        // Test 6: (idx==0) → (idx==1)
        let idx0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let idx1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let formula_idx0_implies_idx1: LTLFormula<TestProposition> = .implies(.atomic(idx0), .atomic(idx1))
        
        // At index 0: true → false = false
        #expect(try !evaluator.evaluateAt(formula: formula_idx0_implies_idx1, trace: trace, index: 0, contextProvider: contextProvider))
        // At index 1: false → true = true
        #expect(try evaluator.evaluateAt(formula: formula_idx0_implies_idx1, trace: trace, index: 1, contextProvider: contextProvider))
        // At index 2: false → false = true
        #expect(try evaluator.evaluateAt(formula: formula_idx0_implies_idx1, trace: trace, index: 2, contextProvider: contextProvider))
    }
}