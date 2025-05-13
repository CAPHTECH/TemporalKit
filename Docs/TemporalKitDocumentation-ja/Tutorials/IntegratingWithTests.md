# テストとの統合

このチュートリアルでは、TemporalKitの時相論理検証をSwiftのテストフレームワークと統合する方法を学びます。単体テストや統合テストにTemporalKitを組み込むことで、より強力で表現力豊かなアサーションを作成できます。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- XCTestとTemporalKitを組み合わせて時相論理テストを作成する
- テストデータ生成に使用するモデル検査のテクニックを適用する
- CI/CDパイプラインにTemporalKitの検証を組み込む
- 時相検証を使用したプロパティベーステストを実装する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること
- XCTestに関する基本的な知識

## ステップ1: テスト環境のセットアップ

まず、TemporalKitを使用するテスト環境をセットアップします。

```swift
import XCTest
import TemporalKit

// テスト対象のシステム
struct CounterSystem {
    var count: Int = 0
    
    mutating func increment() {
        count += 1
    }
    
    mutating func decrement() {
        count -= 1
    }
    
    mutating func reset() {
        count = 0
    }
}

// テストケースクラス
class TemporalLogicTests: XCTestCase {
    // テストメソッドはこれから追加します
}
```

## ステップ2: 基本的な時相アサーションの作成

XCTestに時相論理アサーションを統合する基本的な方法を示します。

```swift
extension TemporalLogicTests {
    
    // シンプルなトレース評価のテスト
    func testSimpleTraceEvaluation() {
        // テスト対象のトレース（状態の配列）
        let trace: [Int] = [0, 1, 2, 3, 2, 1, 0]
        
        // 命題: 「値は0以上」
        let isNonNegative = TemporalKit.makeProposition(
            id: "isNonNegative",
            name: "値は0以上",
            evaluate: { (state: Int) -> Bool in state >= 0 }
        )
        
        // 命題: 「値は偶数」
        let isEven = TemporalKit.makeProposition(
            id: "isEven",
            name: "値は偶数",
            evaluate: { (state: Int) -> Bool in state % 2 == 0 }
        )
        
        // テスト用のLTL式: 「常に0以上の値である」
        let alwaysNonNegative = LTLFormula<ClosureTemporalProposition<Int, Bool>>.globally(
            .atomic(isNonNegative)
        )
        
        // テスト用のLTL式: 「最終的に必ず偶数になる」
        let eventuallyEven = LTLFormula<ClosureTemporalProposition<Int, Bool>>.eventually(
            .atomic(isEven)
        )
        
        // 評価コンテキストプロバイダ
        let contextProvider: (Int, Int) -> EvaluationContext = { (state, index) in
            return SimpleEvaluationContext(state: state, traceIndex: index)
        }
        
        // トレース評価器を作成
        let evaluator = LTLFormulaTraceEvaluator()
        
        do {
            // 式を評価
            let result1 = try evaluator.evaluate(formula: alwaysNonNegative, trace: trace, contextProvider: contextProvider)
            let result2 = try evaluator.evaluate(formula: eventuallyEven, trace: trace, contextProvider: contextProvider)
            
            // 結果をアサート
            XCTAssertTrue(result1, "トレース内の全ての値は0以上であるべき")
            XCTAssertTrue(result2, "トレース内に少なくとも1つの偶数が存在するべき")
            
        } catch {
            XCTFail("評価中にエラーが発生: \(error)")
        }
    }
    
    // 単純な評価コンテキスト
    class SimpleEvaluationContext: EvaluationContext {
        let state: Int
        let traceIndex: Int?
        
        init(state: Int, traceIndex: Int? = nil) {
            self.state = state
            self.traceIndex = traceIndex
        }
        
        func currentStateAs<T>(_ type: T.Type) -> T? {
            return state as? T
        }
    }
}
```

## ステップ3: カスタムTemporalXCTアサーション関数の作成

よく使用される時相論理アサーションのためのヘルパー関数を作成します。

```swift
// 時相論理テスト用のXCTアサーション拡張
extension XCTestCase {
    
    // トレースがLTL式を満たすことをアサートする
    func XCTAssertTemporalFormula<S, P: TemporalProposition>(
        _ formula: LTLFormula<P>,
        satisfiedBy trace: [S],
        contextProvider: @escaping (S, Int) -> EvaluationContext,
        message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) where P.Value == Bool {
        let evaluator = LTLFormulaTraceEvaluator()
        
        do {
            let result = try evaluator.evaluate(formula: formula, trace: trace, contextProvider: contextProvider)
            XCTAssertTrue(result, message, file: file, line: line)
        } catch {
            XCTFail("時相論理式の評価に失敗: \(error)", file: file, line: line)
        }
    }
    
    // モデルがLTL式を満たすことをアサートする
    func XCTAssertModelSatisfies<M: KripkeStructure, P: TemporalProposition>(
        _ formula: LTLFormula<P>,
        model: M,
        message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) where P.Value == Bool {
        let modelChecker = LTLModelChecker<M>()
        
        do {
            let result = try modelChecker.check(formula: formula, model: model)
            
            if !result.holds {
                if case .fails(let counterexample) = result {
                    XCTFail("""
                        モデルはLTL式を満たしていません。
                        \(message)
                        反例:
                          前置: \(counterexample.prefix.map { "\($0)" }.joined(separator: " -> "))
                          サイクル: \(counterexample.cycle.map { "\($0)" }.joined(separator: " -> "))
                        """, file: file, line: line)
                } else {
                    XCTFail("モデルはLTL式を満たしていません。\(message)", file: file, line: line)
                }
            }
        } catch {
            XCTFail("モデル検査中にエラーが発生: \(error)", file: file, line: line)
        }
    }
}
```

## ステップ4: カウンターシステムのテスト

カスタムアサーションを使用して、カウンターシステムをテストします。

```swift
extension TemporalLogicTests {
    
    func testCounterSystem() {
        // カウンターシステムの操作シーケンスとその結果の状態のトレース
        var counter = CounterSystem()
        
        // 操作のシーケンス
        let operations = [
            { counter.reset() },
            { counter.increment() },
            { counter.increment() },
            { counter.decrement() },
            { counter.reset() }
        ]
        
        // 各操作の前後の状態を記録
        var stateTrace: [Int] = [counter.count]
        
        for operation in operations {
            operation()
            stateTrace.append(counter.count)
        }
        
        // 命題の定義
        let isZero = TemporalKit.makeProposition(
            id: "isZero",
            name: "カウンターが0",
            evaluate: { (state: Int) -> Bool in state == 0 }
        )
        
        let isPositive = TemporalKit.makeProposition(
            id: "isPositive",
            name: "カウンターが正の値",
            evaluate: { (state: Int) -> Bool in state > 0 }
        )
        
        // LTL式: 「resetの後は必ずカウンターが0になる」
        // 注：このテストでは操作のトレースではなく状態のトレースを評価しているため、
        // 操作自体に対する論理式ではなく、状態の変化パターンに着目しています
        
        let zeroAfterReset = LTLFormula<ClosureTemporalProposition<Int, Bool>>.globally(
            .implies(
                .atomic(isZero),
                .next(
                    .or(
                        .atomic(isZero),
                        .atomic(isPositive)
                    )
                )
            )
        )
        
        // 評価コンテキストプロバイダ
        let contextProvider: (Int, Int) -> EvaluationContext = { (state, index) in
            return SimpleEvaluationContext(state: state, traceIndex: index)
        }
        
        // カスタムアサーションを使用
        XCTAssertTemporalFormula(
            zeroAfterReset,
            satisfiedBy: stateTrace,
            contextProvider: contextProvider,
            message: "初期状態かリセット後の状態では、次の状態は0か正の値であるべき"
        )
    }
}
```

## ステップ5: Kripke構造を使用したモデルベースのテスト

カウンターシステムをKripke構造としてモデル化し、より包括的なテストを行います。

```swift
// カウンターシステムのKripke構造モデル
struct CounterModel: KripkeStructure {
    typealias State = Int
    typealias AtomicPropositionIdentifier = PropositionID
    
    // モデルの制約を設定（例：カウンターの値を-5から5に制限）
    let minValue: Int
    let maxValue: Int
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init(minValue: Int = -5, maxValue: Int = 5, initialValue: Int = 0) {
        self.minValue = minValue
        self.maxValue = maxValue
        
        // すべての可能な状態を計算
        self.allStates = Set(minValue...maxValue)
        self.initialStates = [initialValue]
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // インクリメント操作
        if state + 1 <= maxValue {
            nextStates.insert(state + 1)
        }
        
        // デクリメント操作
        if state - 1 >= minValue {
            nextStates.insert(state - 1)
        }
        
        // リセット操作
        nextStates.insert(0)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // カウンターの状態に関する命題
        if state == 0 {
            trueProps.insert(isZero.id)
        }
        
        if state > 0 {
            trueProps.insert(isPositive.id)
        }
        
        if state < 0 {
            trueProps.insert(isNegative.id)
        }
        
        if state % 2 == 0 {
            trueProps.insert(isEven.id)
        } else {
            trueProps.insert(isOdd.id)
        }
        
        if state == minValue {
            trueProps.insert(isAtMinValue.id)
        }
        
        if state == maxValue {
            trueProps.insert(isAtMaxValue.id)
        }
        
        return trueProps
    }
}

// カウンターシステムの命題
let isZero = TemporalKit.makeProposition(
    id: "isZero",
    name: "カウンターが0",
    evaluate: { (state: Int) -> Bool in state == 0 }
)

let isPositive = TemporalKit.makeProposition(
    id: "isPositive",
    name: "カウンターが正の値",
    evaluate: { (state: Int) -> Bool in state > 0 }
)

let isNegative = TemporalKit.makeProposition(
    id: "isNegative",
    name: "カウンターが負の値",
    evaluate: { (state: Int) -> Bool in state < 0 }
)

let isEven = TemporalKit.makeProposition(
    id: "isEven",
    name: "カウンターが偶数",
    evaluate: { (state: Int) -> Bool in state % 2 == 0 }
)

let isOdd = TemporalKit.makeProposition(
    id: "isOdd",
    name: "カウンターが奇数",
    evaluate: { (state: Int) -> Bool in state % 2 != 0 }
)

let isAtMinValue = TemporalKit.makeProposition(
    id: "isAtMinValue",
    name: "カウンターが最小値",
    evaluate: { (state: Int) -> Bool in state == -5 } // 簡略化のため直接値を使用
)

let isAtMaxValue = TemporalKit.makeProposition(
    id: "isAtMaxValue",
    name: "カウンターが最大値",
    evaluate: { (state: Int) -> Bool in state == 5 } // 簡略化のため直接値を使用
)
```

## ステップ6: モデルベースのテストケースの実装

カウンターモデルを使用したテストケースを実装します。

```swift
extension TemporalLogicTests {
    
    // カウンターモデルのプロパティテスト
    func testCounterModelProperties() {
        let model = CounterModel()
        
        // 型エイリアス（見やすさのため）
        typealias CounterProp = ClosureTemporalProposition<Int, Bool>
        typealias CounterLTL = LTLFormula<CounterProp>
        
        // プロパティ1: 「最大値に到達した場合、次の状態は0か最大値-1のどちらかである」
        let maxValueTransitions = CounterLTL.globally(
            .implies(
                .atomic(isAtMaxValue),
                .next(
                    .or(
                        .atomic(isZero),
                        .atomic(TemporalKit.makeProposition(
                            id: "isMaxValueMinus1",
                            name: "カウンターが最大値-1",
                            evaluate: { (state: Int) -> Bool in state == 4 }
                        ))
                    )
                )
            )
        )
        
        // プロパティ2: 「0から始めると、常に最終的には0に戻る」
        let alwaysEventuallyZero = CounterLTL.globally(
            .eventually(.atomic(isZero))
        )
        
        // プロパティ3: 「どの状態からも、最終的に偶数の状態に到達できる」
        let eventuallyEven = CounterLTL.globally(
            .eventually(.atomic(isEven))
        )
        
        // プロパティ4: 「どの状態からも、最終的に正の値の状態に到達できる」
        let eventuallyPositive = CounterLTL.globally(
            .eventually(.atomic(isPositive))
        )
        
        // カスタムアサーションを使用してテスト
        XCTAssertModelSatisfies(
            maxValueTransitions,
            model: model,
            message: "最大値からの遷移は0か最大値-1のどちらかであるべき"
        )
        
        XCTAssertModelSatisfies(
            alwaysEventuallyZero,
            model: model,
            message: "どの状態からも最終的には0に戻るべき"
        )
        
        XCTAssertModelSatisfies(
            eventuallyEven,
            model: model,
            message: "どの状態からも偶数の状態に到達できるべき"
        )
        
        XCTAssertModelSatisfies(
            eventuallyPositive,
            model: model,
            message: "どの状態からも正の値の状態に到達できるべき"
        )
    }
}
```

## ステップ7: 複雑なシステムへの統合

より複雑なシステムでの適用例として、簡単なワークフローエンジンのテストを示します。

```swift
// ワークフローの状態
enum WorkflowState: Hashable, CustomStringConvertible {
    case idle
    case started
    case validating
    case processing
    case completed
    case cancelled
    case error(reason: String)
    
    var description: String {
        switch self {
        case .idle: return "待機中"
        case .started: return "開始済み"
        case .validating: return "検証中"
        case .processing: return "処理中"
        case .completed: return "完了"
        case .cancelled: return "キャンセル済み"
        case let .error(reason): return "エラー(\(reason))"
        }
    }
    
    // Hashableプロトコルに準拠するため
    func hash(into hasher: inout Hasher) {
        switch self {
        case .idle: hasher.combine(0)
        case .started: hasher.combine(1)
        case .validating: hasher.combine(2)
        case .processing: hasher.combine(3)
        case .completed: hasher.combine(4)
        case .cancelled: hasher.combine(5)
        case let .error(reason): 
            hasher.combine(6)
            hasher.combine(reason)
        }
    }
    
    // Equatableプロトコルに準拠するため
    static func == (lhs: WorkflowState, rhs: WorkflowState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.started, .started): return true
        case (.validating, .validating): return true
        case (.processing, .processing): return true
        case (.completed, .completed): return true
        case (.cancelled, .cancelled): return true
        case let (.error(reason1), .error(reason2)): return reason1 == reason2
        default: return false
        }
    }
}

// ワークフローエンジンクラス
class WorkflowEngine {
    private(set) var state: WorkflowState = .idle
    private(set) var stateHistory: [WorkflowState] = [.idle]
    
    func start() -> Bool {
        switch state {
        case .idle:
            state = .started
            stateHistory.append(state)
            return true
        default:
            return false
        }
    }
    
    func validate() -> Bool {
        switch state {
        case .started:
            state = .validating
            stateHistory.append(state)
            
            // 検証ロジック（ここでは単純化のためランダムな結果を返す）
            if Bool.random() {
                state = .processing
                stateHistory.append(state)
                return true
            } else {
                state = .error(reason: "検証失敗")
                stateHistory.append(state)
                return false
            }
        default:
            return false
        }
    }
    
    func process() -> Bool {
        switch state {
        case .processing:
            // 処理ロジック（ここでは単純化のためランダムな結果を返す）
            if Bool.random() {
                state = .completed
                stateHistory.append(state)
                return true
            } else {
                state = .error(reason: "処理失敗")
                stateHistory.append(state)
                return false
            }
        default:
            return false
        }
    }
    
    func cancel() -> Bool {
        switch state {
        case .idle, .started, .validating, .processing:
            state = .cancelled
            stateHistory.append(state)
            return true
        default:
            return false
        }
    }
    
    func reset() {
        state = .idle
        stateHistory.append(state)
    }
}

// ワークフローのテスト
extension TemporalLogicTests {
    
    func testWorkflowEngine() {
        // テスト用のワークフローエンジン
        let workflow = WorkflowEngine()
        
        // ワークフローの命題
        let isIdle = TemporalKit.makeProposition(
            id: "isIdle",
            name: "ワークフローが待機中",
            evaluate: { (state: WorkflowState) -> Bool in
                if case .idle = state { return true }
                return false
            }
        )
        
        let isStarted = TemporalKit.makeProposition(
            id: "isStarted",
            name: "ワークフローが開始済み",
            evaluate: { (state: WorkflowState) -> Bool in
                if case .started = state { return true }
                return false
            }
        )
        
        let isCompleted = TemporalKit.makeProposition(
            id: "isCompleted",
            name: "ワークフローが完了",
            evaluate: { (state: WorkflowState) -> Bool in
                if case .completed = state { return true }
                return false
            }
        )
        
        let isError = TemporalKit.makeProposition(
            id: "isError",
            name: "ワークフローがエラー状態",
            evaluate: { (state: WorkflowState) -> Bool in
                if case .error = state { return true }
                return false
            }
        )
        
        let isCancelled = TemporalKit.makeProposition(
            id: "isCancelled",
            name: "ワークフローがキャンセル済み",
            evaluate: { (state: WorkflowState) -> Bool in
                if case .cancelled = state { return true }
                return false
            }
        )
        
        // 操作シーケンスを実行（単純化のためランダム性を無視）
        workflow.start()
        workflow.validate()  // 成功すると仮定
        workflow.process()   // 成功すると仮定
        
        // LTL式: 「開始後は必ずいつか完了するかエラーになるかキャンセルされる」
        let startedLeadsToEnd = LTLFormula<ClosureTemporalProposition<WorkflowState, Bool>>.implies(
            .atomic(isStarted),
            .eventually(
                .or(
                    .atomic(isCompleted),
                    .atomic(isError),
                    .atomic(isCancelled)
                )
            )
        )
        
        // 評価コンテキストプロバイダ
        let contextProvider: (WorkflowState, Int) -> EvaluationContext = { (state, index) in
            return WorkflowEvaluationContext(state: state, traceIndex: index)
        }
        
        // ワークフロー履歴のトレースを評価
        XCTAssertTemporalFormula(
            startedLeadsToEnd,
            satisfiedBy: workflow.stateHistory,
            contextProvider: contextProvider,
            message: "開始されたワークフローは、必ず完了かエラーかキャンセルのいずれかの状態に到達するべき"
        )
    }
    
    // ワークフロー評価コンテキスト
    class WorkflowEvaluationContext: EvaluationContext {
        let state: WorkflowState
        let traceIndex: Int?
        
        init(state: WorkflowState, traceIndex: Int? = nil) {
            self.state = state
            self.traceIndex = traceIndex
        }
        
        func currentStateAs<T>(_ type: T.Type) -> T? {
            return state as? T
        }
    }
}
```

## ステップ8: CI/CDパイプラインとの統合

TemporalKitを使用した時相論理テストをCI/CDパイプラインに統合する方法を示します。以下は、XCTestで時相論理検証を実行するスクリプトの例です。

```swift
// XCTestCaseにテストコレクションを定義するヘルパー拡張
extension TemporalLogicTests {
    
    static var allTests = [
        ("testSimpleTraceEvaluation", testSimpleTraceEvaluation),
        ("testCounterSystem", testCounterSystem),
        ("testCounterModelProperties", testCounterModelProperties),
        ("testWorkflowEngine", testWorkflowEngine)
    ]
    
    // CI環境でテスト結果をJUnitXML形式で出力するヘルパーメソッド
    static func runAllTests() -> Bool {
        let testSuite = XCTestSuite(forTestCaseClass: TemporalLogicTests.self)
        let testObserver = JUnitTestObserver()
        
        testObserver.startMeasuring()
        testSuite.run()
        testObserver.stopMeasuring()
        
        // XML形式でテスト結果を出力
        testObserver.writeReport(to: "temporal_logic_test_results.xml")
        
        return testObserver.hasFailures == false
    }
}

// テスト実行のためのエントリポイント（Linuxなどで使用）
#if os(Linux)
import XCTest

XCTMain([
    testCase(TemporalLogicTests.allTests)
])
#endif
```

## まとめ

このチュートリアルでは、TemporalKitをSwiftのテストフレームワークと統合する方法を学びました。具体的には以下のことを学びました：

1. XCTestと組み合わせた時相論理テストの作成方法
2. カスタムXCTアサーション関数の実装方法
3. トレース評価とモデル検査の両方を使用したテスト方法
4. 実際のアプリケーションコード（カウンターとワークフロー）への適用方法
5. CI/CDパイプラインとの統合方法

時相論理検証を通常のテストに統合することで、単純なアサーションでは表現できない複雑な振る舞いやシーケンスに関するプロパティを検証できるようになります。これにより、システムの堅牢性と信頼性が大幅に向上します。

## 次のステップ

- [実例によるTemporalKit](./TemporalKitByExample.md)で、様々な実践的な適用例を学びましょう。
- [パフォーマンスの最適化](./OptimizingPerformance.md)で、大規模なシステムで時相論理検証を効率的に実行する方法を理解しましょう。
- [リアクティブシステムの検証](./VerifyingReactiveSystems.md)で、非同期システムやイベント駆動システムのテスト方法を学びましょう。 
