import Testing
import XCTest
@testable import TemporalKit

/// テストで使用するシンプルな命題の実装
private class TestProposition: TemporalProposition {
    typealias Value = Bool
    let id: PropositionID
    let name: String
    let evaluationResult: Bool
    
    init(id: String, name: String, evaluationResult: Bool = true) {
        self.id = PropositionID(rawValue: id)
        self.name = name
        self.evaluationResult = evaluationResult
    }
    
    func evaluate(in context: EvaluationContext) throws -> Bool {
        return evaluationResult
    }
}

/// 特定のインデックスでのみtrueを返す命題
private class IndexEqualsProposition: TemporalProposition {
    typealias Value = Bool
    let id: PropositionID
    let name: String
    let targetIndex: Int

    init(id: String = UUID().uuidString, name: String = "IndexEquals", targetIndex: Int) {
        self.id = PropositionID(rawValue: id)
        self.name = name
        self.targetIndex = targetIndex
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        guard let currentIndex = context.traceIndex else { return false }
        return currentIndex == targetIndex
    }
}

/// 特定のインデックスより小さい場合にtrueを返す命題
private class IndexLessThanProposition: TemporalProposition {
    typealias Value = Bool
    let id: PropositionID
    let name: String
    let threshold: Int

    init(id: String = UUID().uuidString, name: String = "IndexLessThan", threshold: Int) {
        self.id = PropositionID(rawValue: id)
        self.name = name
        self.threshold = threshold
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        guard let currentIndex = context.traceIndex else { return false }
        return currentIndex < threshold
    }
}

/// 特定のトレースインデックスでfalseを返す命題 (テスト用)
private class SometimesFalseProposition: TemporalProposition {
    typealias Value = Bool
    let id: PropositionID
    let name: String
    let falseAtIndex: Int

    init(id: String = UUID().uuidString, name: String = "SometimesFalse", falseAtIndex: Int = 1) {
        self.id = PropositionID(rawValue: id)
        self.name = name
        self.falseAtIndex = falseAtIndex
    }

    func evaluate(in context: EvaluationContext) throws -> Bool {
        guard let currentIndex = context.traceIndex else { return true } // traceIndexがない場合はデフォルトでtrue
        return currentIndex != falseAtIndex
    }
}

/// 常にtrueを返す命題
private class AlwaysTrueProposition: TemporalProposition {
    typealias Value = Bool
    let id = PropositionID(rawValue: "AlwaysTrue")
    let name = "AlwaysTrue"
    func evaluate(in context: EvaluationContext) throws -> Bool { true }
}

/// 常にfalseを返す命題
private class AlwaysFalseProposition: TemporalProposition {
    typealias Value = Bool
    let id = PropositionID(rawValue: "AlwaysFalse")
    let name = "AlwaysFalse"
    func evaluate(in context: EvaluationContext) throws -> Bool { false }
}

/// テストで使用するシンプルなコンテキストの実装
private struct TestEvaluationContext: EvaluationContext {
    let index: Int
    
    init(index: Int) {
        self.index = index
    }
    
    func currentStateAs<T>(_ type: T.Type) -> T? {
        return nil
    }
    
    var traceIndex: Int? {
        return index
    }
}

@Suite("LTLFormulaTraceEvaluation")
struct LTLFormulaTraceEvaluationTests {
    // テスト用のトレース作成ヘルパーメソッド
    private func createTestTrace(length: Int) -> [TestEvaluationContext] {
        return (0..<length).map { TestEvaluationContext(index: $0) }
    }
    
    // MARK: - 基本的なトレース評価テスト
    
    @Test("空のトレースに対して例外がスローされること")
    func testEmptyTraceThrowsException() throws {
        // 設定
        let proposition = TestProposition(id: "test", name: "Test Proposition")
        let formula: LTLFormula<TestProposition> = .atomic(proposition)
        let emptyTrace: [TestEvaluationContext] = []
        
        // 実行と検証
        do {
            _ = try formula.evaluate(over: emptyTrace)
            XCTFail("空トレースに対する評価は例外をスローするべきですが、例外が発生しませんでした")
        } catch LTLTraceEvaluationError.emptyTrace {
            // 期待通りの例外
            XCTAssertTrue(true, "空トレースに対して期待通りの例外がスローされました")
        } catch {
            XCTFail("期待される例外タイプではありません: \(error)")
        }
    }
    
    @Test("原子命題の評価が正しく行われること")
    func testAtomicPropositionEvaluation() throws {
        // トレースの設定
        let trace = createTestTrace(length: 3)
        
        // trueの命題
        let trueProposition = TestProposition(id: "true", name: "Always True", evaluationResult: true)
        let trueFormula: LTLFormula<TestProposition> = .atomic(trueProposition)
        
        // falseの命題
        let falseProposition = TestProposition(id: "false", name: "Always False", evaluationResult: false)
        let falseFormula: LTLFormula<TestProposition> = .atomic(falseProposition)
        
        // 実行と検証
        do {
            let trueResult = try trueFormula.evaluate(over: trace)
            XCTAssertEqual(trueResult, true, "trueの命題は常にtrueと評価されるべきです")
            
            let falseResult = try falseFormula.evaluate(over: trace)
            XCTAssertEqual(falseResult, false, "falseの命題は常にfalseと評価されるべきです")
        } catch {
            XCTFail("原子命題の評価中に予期しない例外が発生しました: \(error)")
        }
    }
    
    @Test("論理結合子（AND、OR、NOT）の評価が正しく行われること")
    func testLogicalConnectivesEvaluation() throws {
        // トレースの設定
        let trace = createTestTrace(length: 3)
        
        // 命題の設定
        let trueProposition = TestProposition(id: "true", name: "Always True", evaluationResult: true)
        let falseProposition = TestProposition(id: "false", name: "Always False", evaluationResult: false)
        
        let trueFormula: LTLFormula<TestProposition> = .atomic(trueProposition)
        let falseFormula: LTLFormula<TestProposition> = .atomic(falseProposition)
        
        // 論理結合子を使用した式
        let andFormula = trueFormula && falseFormula  // true AND false = false
        let orFormula = trueFormula || falseFormula   // true OR false = true
        let notFormula = !trueFormula                 // NOT true = false
        
        // 実行と検証
        do {
            let andResult = try andFormula.evaluate(over: trace)
            XCTAssertEqual(andResult, false, "true AND false はfalseと評価されるべきです")
            
            let orResult = try orFormula.evaluate(over: trace)
            XCTAssertEqual(orResult, true, "true OR false はtrueと評価されるべきです")
            
            let notResult = try notFormula.evaluate(over: trace)
            XCTAssertEqual(notResult, false, "NOT true はfalseと評価されるべきです")
        } catch {
            XCTFail("論理結合子の評価中に予期しない例外が発生しました: \(error)")
        }
    }
    
    // MARK: - 時相演算子のテスト
    
    @Test("Next (X) 演算子の評価が正しく行われること")
    func testNextOperatorEvaluation() throws {
        // トレースの設定
        let trace = createTestTrace(length: 3) // s0, s1, s2
        
        // X(index == 1) : 次の状態でインデックスが1である (つまり現在のインデックスが0)
        let proposition = IndexEqualsProposition(name: "indexEquals1", targetIndex: 1)
        let nextFormula: LTLFormula<IndexEqualsProposition> = .X(.atomic(proposition))
        
        do {
            let result = try nextFormula.evaluate(over: trace)
            XCTAssertEqual(result, true, "X(index==1)は、インデックス0の状態で評価すると、次の状態(s1)でindex==1がtrueなのでtrueとなるべきです")
        } catch {
            XCTFail("Next演算子の評価中に予期しない例外が発生しました: \(error)")
        }

        // X(index == 0) : 次の状態でインデックスが0である (これは通常偽)
        let propIndex0 = IndexEqualsProposition(name: "indexEquals0", targetIndex: 0)
        let nextFormulaFalse: LTLFormula<IndexEqualsProposition> = .X(.atomic(propIndex0))
        do {
            let resultFalse = try nextFormulaFalse.evaluate(over: trace)
            XCTAssertFalse(resultFalse, "X(index==0)は、インデックス0の状態で評価すると、次の状態(s1)でindex==0がfalseなのでfalseとなるべきです")
        } catch {
            XCTFail("Next演算子(偽ケース)の評価中に予期しない例外が発生しました: \(error)")
        }
    }
    
    @Test("Eventually (F) 演算子の評価が正しく行われること")
    func testEventuallyOperatorEvaluation() throws {
        let trace = createTestTrace(length: 5) // s0, s1, s2, s3, s4

        // F(index == 2)
        let proposition = IndexEqualsProposition(name: "indexEquals2", targetIndex: 2)
        let eventuallyFormula: LTLFormula<IndexEqualsProposition> = .F(.atomic(proposition))
        
        do {
            let result = try eventuallyFormula.evaluate(over: trace)
            XCTAssertEqual(result, true, "F(index==2)は、トレース内にインデックス2の状態があるのでtrueと評価されるべきです")
            
            // 短いトレースの場合（インデックス2に達する前に終わる）
            let shortTrace = createTestTrace(length: 2) // s0, s1
            let shortTraceResult = try eventuallyFormula.evaluate(over: shortTrace)
            XCTAssertEqual(shortTraceResult, false, "F(index==2)は、短いトレース(s0,s1)ではfalseと評価されるべきです")

            // F(index == 10) (トレース外)
            let propIndex10 = IndexEqualsProposition(name: "indexEquals10", targetIndex: 10)
            let eventuallyFormulaFalse: LTLFormula<IndexEqualsProposition> = .F(.atomic(propIndex10))
            let resultFalse = try eventuallyFormulaFalse.evaluate(over: trace)
            XCTAssertFalse(resultFalse, "F(index==10)は、トレース内にindex==10の状態がないのでfalseと評価されるべきです")
        } catch {
            XCTFail("Eventually演算子の評価中に予期しない例外が発生しました: \(error)")
        }
    }
    
    @Test("Always (G) 演算子の評価が正しく行われること")
    func testAlwaysOperatorEvaluation() throws {
        // トレースの設定
        let trace = createTestTrace(length: 3)
        
        // 常にtrueを返す命題
        let alwaysTrueProposition = AlwaysTrueProposition()
        let alwaysTrueFormula = LTLFormula.G(.atomic(alwaysTrueProposition))
        
        // インデックス1の時だけfalseを返す命題
        let sometimesFalseProposition = SometimesFalseProposition(falseAtIndex: 1)
        let sometimesFalseFormula = LTLFormula.G(.atomic(sometimesFalseProposition))
        
        do {
            // 常にtrueの命題に対するAlways演算子はtrueになるべき
            let alwaysTrueResult = try alwaysTrueFormula.evaluate(over: trace)
            XCTAssertEqual(alwaysTrueResult, true, "G(alwaysTrue)は、すべての状態でtrueなのでtrueと評価されるべきです")
            
            // 時々falseの命題に対するAlways演算子はfalseになるべき
            let sometimesFalseResult = try sometimesFalseFormula.evaluate(over: trace)
            XCTAssertEqual(sometimesFalseResult, false, "G(sometimesFalse)は、インデックス1でfalseになるためfalseと評価されるべきです")
        } catch {
            XCTFail("Always演算子の評価中に予期しない例外が発生しました: \(error)")
        }
    }
    
    @Test("Until (U) 演算子の評価が正しく行われること")
    func testUntilOperatorEvaluation() throws {
        let trace = createTestTrace(length: 5) // s0, s1, s2, s3, s4
        let shortTrace = createTestTrace(length: 3) // s0, s1, s2

        // Proposition instances (all IndexEqualsProposition for consistency in formulas)
        let p_idx_eq_0 = IndexEqualsProposition(name: "idx_eq_0", targetIndex: 0)
        let p_idx_eq_1 = IndexEqualsProposition(name: "idx_eq_1", targetIndex: 1)
        let p_idx_eq_2 = IndexEqualsProposition(name: "idx_eq_2", targetIndex: 2)
        let p_idx_eq_3 = IndexEqualsProposition(name: "idx_eq_3", targetIndex: 3)
        let p_idx_eq_10 = IndexEqualsProposition(name: "idx_eq_10", targetIndex: 10)

        do {
            // Test Case 1: (index < 3) U (index == 3)
            // (index < 3) is represented as (index == 0 || index == 1 || index == 2)
            let p_less_than_3_formula: LTLFormula<IndexEqualsProposition> = 
                .or(.atomic(p_idx_eq_0), .or(.atomic(p_idx_eq_1), .atomic(p_idx_eq_2)))
            let q_equals_3_formula: LTLFormula<IndexEqualsProposition> = .atomic(p_idx_eq_3)
            
            let untilFormula_case1 = p_less_than_3_formula ~>> q_equals_3_formula
            let result_case1 = try untilFormula_case1.evaluate(over: trace)
            // s0: p(T), q(F). s1: p(T), q(F). s2: p(T), q(F). s3: p(F), q(T). -> True
            XCTAssertTrue(result_case1, "((idx==0||1||2) U (idx==3)) on trace [s0-s4] should be true")

            let short_result_case1 = try untilFormula_case1.evaluate(over: shortTrace)
            // s0: p(T), q(F). s1: p(T), q(F). s2: p(T), q(F). Trace ends, q never true. -> False
            XCTAssertFalse(short_result_case1, "((idx==0||1||2) U (idx==3)) on trace [s0-s2] should be false")

            // Test Case 2: q が最後まで現れないケース (pは特定の状態でのみtrue)
            // (index == 0) U (index == 10)
            let untilFormulaNonSatisfiedQ: LTLFormula<IndexEqualsProposition> = .atomic(p_idx_eq_0) ~>> .atomic(p_idx_eq_10)
            let resultNonSatisfiedQ = try untilFormulaNonSatisfiedQ.evaluate(over: trace)
            // s0: p(T), q(F). s1: p(F), q(F). q never true. -> False
            XCTAssertFalse(resultNonSatisfiedQ, "(idx==0 U idx==10) on trace [s0-s4] should be false as q never holds")

            // Test Case 3: pが途中でfalseになるケース (qが現れる前に)
            // (index == 0) U (index == 3)
            let untilFormulaPEventuallyFalse: LTLFormula<IndexEqualsProposition> = .atomic(p_idx_eq_0) ~>> .atomic(p_idx_eq_3)
            let resultPEventuallyFalse = try untilFormulaPEventuallyFalse.evaluate(over: trace)
            // s0: p(T), q(F). 
            // s1: p(F). q not yet true. p failed. -> False
            XCTAssertFalse(resultPEventuallyFalse, "(idx==0 U idx==3) on trace [s0-s4] should be false as p becomes false before q")

            // Test Case 4: qが即座にtrueのケース
            // (index == 1) U (index == 0)
            let untilFormulaQImmediatelyTrue: LTLFormula<IndexEqualsProposition> = .atomic(p_idx_eq_1) ~>> .atomic(p_idx_eq_0)
            let resultQImmediatelyTrue = try untilFormulaQImmediatelyTrue.evaluate(over: trace)
            // s0: q(T). -> True
            XCTAssertTrue(resultQImmediatelyTrue, "(idx==1 U idx==0) on trace [s0-s4] should be true as q holds at s0")

        } catch {
            XCTFail("Until演算子の評価中に予期しない例外が発生しました: \(error)")
        }
    }
}
