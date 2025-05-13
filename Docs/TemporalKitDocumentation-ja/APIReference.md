# TemporalKit API リファレンス

このドキュメントはTemporalKitの主要なAPIについて解説します。TemporalKitは形式的検証、特に線形時相論理（LTL）を使用してシステムの動作を検証するためのSwiftライブラリです。

## コアコンポーネント

### LTLFormula

LTL（線形時相論理）式を表現するための型です。

```swift
public indirect enum LTLFormula<P: TemporalProposition>: Hashable where P.Value == Bool {
    case booleanLiteral(Bool)
    case atomic(P)
    case not(LTLFormula<P>)
    case and(LTLFormula<P>, LTLFormula<P>)
    case or(LTLFormula<P>, LTLFormula<P>)
    case implies(LTLFormula<P>, LTLFormula<P>)
    
    case next(LTLFormula<P>)
    case eventually(LTLFormula<P>)
    case globally(LTLFormula<P>)
    
    case until(LTLFormula<P>, LTLFormula<P>)
    case weakUntil(LTLFormula<P>, LTLFormula<P>)
    case release(LTLFormula<P>, LTLFormula<P>)
}
```

#### 主なメソッド

- `normalized()` - 式を正規化する
- `toNNF()` - 否定標準形（NNF）に変換する
- `containsEventually()` - 式が「いつか」演算子を含むかどうかを返す
- `containsGlobally()` - 式が「常に」演算子を含むかどうかを返す
- `containsNext()` - 式が「次に」演算子を含むかどうかを返す
- `containsUntil()` - 式が「まで」演算子を含むかどうかを返す

#### DSL演算子

- `X(φ)` - 「次に」演算子
- `F(φ)` - 「いつか」演算子
- `G(φ)` - 「常に」演算子
- `φ ~>> ψ` - 「まで」演算子
- `φ ~~> ψ` - 「弱まで」演算子
- `φ ~< ψ` - 「リリース」演算子
- `φ ==> ψ` - 含意演算子
- `φ && ψ` - 論理積演算子
- `φ || ψ` - 論理和演算子

### KripkeStructure

システムの状態遷移モデルを表現するためのプロトコルです。

```swift
public protocol KripkeStructure {
    associatedtype State: Hashable
    associatedtype AtomicPropositionIdentifier: Hashable

    var allStates: Set<State> { get }
    var initialStates: Set<State> { get }

    func successors(of state: State) -> Set<State>
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier>
}
```

#### 実装必須のメンバー

- `allStates` - モデルのすべての状態のセット
- `initialStates` - モデルの初期状態のセット
- `successors(of:)` - 指定された状態から遷移可能な状態のセットを返す
- `atomicPropositionsTrue(in:)` - 指定された状態で真となる原子命題のIDのセットを返す

### TemporalProposition

状態に対して評価できる命題を表現するためのプロトコルです。

```swift
public protocol TemporalProposition: Hashable {
    associatedtype Input
    associatedtype Value
    associatedtype ID: Hashable
    
    var id: ID { get }
    var name: String { get }
    
    func evaluate(with context: some EvaluationContext<Input>) throws -> Value
}
```

#### 実装必須のメンバー

- `id` - 命題の一意の識別子
- `name` - 命題の説明的な名前
- `evaluate(with:)` - 評価コンテキストに対して命題を評価する

### LTLModelChecker

LTL式をクリプケ構造（Kripke structure）に対して検査するためのクラスです。

```swift
public class LTLModelChecker<Model: KripkeStructure> {
    public init()
    
    public func check<P: TemporalProposition>(
        formula: LTLFormula<P>, 
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool
}
```

#### 主なメソッド

- `check(formula:model:)` - 指定されたモデルに対してLTL式が成り立つかどうかを検証する

### ModelCheckResult

モデル検査の結果を表現する列挙型です。

```swift
public enum ModelCheckResult<State: Hashable> {
    case holds
    case fails(counterexample: Counterexample<State>)
}
```

- `holds` - フォーミュラがモデルに対して成立する
- `fails(counterexample:)` - フォーミュラがモデルに対して成立せず、反例が提供される

### Counterexample

モデル検査時にフォーミュラが成立しない場合の反例を表現する構造体です。

```swift
public struct Counterexample<State: Hashable> {
    public let prefix: [State]
    public let cycle: [State]
    
    public init(prefix: [State], cycle: [State])
}
```

- `prefix` - 反例の接頭辞部分（初期状態から循環部分への有限パス）
- `cycle` - 反例の循環部分（無限に繰り返される部分）

## ヘルパークラスと関数

### ClosureTemporalProposition

クロージャーを使用して命題を簡単に作成するためのヘルパー型です。

```swift
public struct ClosureTemporalProposition<Input, Output>: TemporalProposition where Output == Bool {
    public typealias ID = PropositionID
    public typealias EvaluationClosure = (Input) throws -> Output
    
    public let id: ID
    public let name: String
    private let evaluationClosure: EvaluationClosure
    
    public init(id: ID, name: String, evaluationClosure: @escaping EvaluationClosure)
}
```

### makeProposition

命題を簡単に作成するためのヘルパー関数です。

```swift
public func makeProposition<Input>(
    id: String,
    name: String,
    evaluate: @escaping (Input) -> Bool
) -> ClosureTemporalProposition<Input, Bool>
```

### EvaluationContext

命題の評価に必要なコンテキストを提供するためのプロトコルです。

```swift
public protocol EvaluationContext<Input> {
    associatedtype Input
    
    var input: Input { get }
    var traceIndex: Int? { get }
}
```

## トレース評価

### LTLFormulaTraceEvaluator

LTL式を有限トレースに対して評価するためのクラスです。

```swift
public class LTLFormulaTraceEvaluator<P: TemporalProposition> where P.Value == Bool {
    public init()
    
    public func evaluate<S, C: EvaluationContext>(
        formula: LTLFormula<P>,
        trace: [S],
        contextProvider: (S, Int) -> C
    ) throws -> Bool
}
```

#### 主なメソッド

- `evaluate(formula:trace:contextProvider:)` - 指定されたトレースに対してLTL式が成立するかどうかを評価する

## エラー型

### TemporalKitError

TemporalKitライブラリで発生する可能性のあるエラーを表現する列挙型です。

```swift
public enum TemporalKitError: Error, LocalizedError {
    case invalidFormula(String)
    case evaluationFailed(String)
    case invalidTraceEvaluation(String)
    case incompatibleTypes(String)
    case unsupportedOperation(String)
}
```

### LTLModelCheckerError

モデル検査中に発生する可能性のあるエラーを表現する列挙型です。

```swift
public enum LTLModelCheckerError: Error, LocalizedError {
    case algorithmsNotImplemented(String)
    case internalProcessingError(String)
}
```

## 使用例

```swift
// 状態の定義
enum SystemState: Hashable {
    case s0, s1, s2
}

// システムモデルの定義
struct MySystemModel: KripkeStructure {
    typealias State = SystemState
    typealias AtomicPropositionIdentifier = String
    
    let allStates: Set<State> = [.s0, .s1, .s2]
    let initialStates: Set<State> = [.s0]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .s0: return [.s1]
        case .s1: return [.s2]
        case .s2: return [.s0]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .s0: return ["p"]
        case .s1: return ["q"]
        case .s2: return ["p", "r"]
        }
    }
}

// 命題の定義
let p = TemporalKit.makeProposition(
    id: "p",
    name: "命題 p",
    evaluate: { (state: SystemState) -> Bool in
        switch state {
        case .s0, .s2: return true
        default: return false
        }
    }
)

let q = TemporalKit.makeProposition(
    id: "q",
    name: "命題 q",
    evaluate: { (state: SystemState) -> Bool in
        switch state {
        case .s1: return true
        default: return false
        }
    }
)

// LTL式の定義
let formula = G(p ==> X(q))

// モデル検査の実行
let modelChecker = LTLModelChecker<MySystemModel>()
let myModel = MySystemModel()

do {
    let result = try modelChecker.check(formula: formula, model: myModel)
    if result.holds {
        print("フォーミュラが成立しています")
    } else {
        print("フォーミュラが成立しません")
        if case .fails(let counterexample) = result {
            print("反例: \(counterexample)")
        }
    }
} catch {
    print("検証エラー: \(error)")
}
```
