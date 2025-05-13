# TemporalKit コア概念

TemporalKitは線形時相論理（LTL）と形式検証の原則に基づいています。このドキュメントでは、ライブラリの基礎となる主要な概念を解説します。

## 線形時相論理（LTL）

線形時相論理は、時間の経過に伴うシステムの動作を記述するための形式言語です。LTLは「常に」、「いつか」、「次に」などの時間的演算子を使用して、状態の無限シーケンスである実行パス上でプロパティが成り立つかどうかを指定します。

### 基本演算子

TemporalKitは以下のLTL演算子をサポートしています：

#### 論理演算子

- **論理定数**: `true`, `false`
- **否定**: `not φ` (φではない)
- **結合**: `φ and ψ` (φかつψ)
- **選言**: `φ or ψ` (φまたはψ)
- **含意**: `φ implies ψ` (φならばψ)

#### 時相演算子

- **Next (X)**: `X φ` または `.next(φ)` - 次の状態でφが成立する
- **Eventually (F)**: `F φ` または `.eventually(φ)` - いつかφが成立する
- **Globally (G)**: `G φ` または `.globally(φ)` - 常にφが成立する
- **Until (U)**: `φ U ψ` または `.until(φ, ψ)` - ψが成立するまでφが成立し続ける
- **Weak Until (W)**: `φ W ψ` または `.weakUntil(φ, ψ)` - ψが成立するまでφが成立し続けるか、常にφが成立する
- **Release (R)**: `φ R ψ` または `.release(φ, ψ)` - φが成立するまでψが成立し続け、φが成立する時点でもψが成立しなければならない

### Swift実装

TemporalKitでは、LTL式は`LTLFormula<P>`型で表現されます。ここで`P`は命題の型です。

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

### DSL構文

TemporalKitは、より読みやすいLTL式を記述するためのDSLも提供しています：

```swift
// 標準記法
let formula1 = LTLFormula.globally(.implies(.atomic(isLoading), .eventually(.atomic(isLoaded))))

// DSL記法
let formula2 = G(isLoading ==> F(isLoaded))

// 中置演算子の場合
let formula3 = isLoading ==> F(isLoaded) // p implies F q
let formula4 = p ~>> q                   // p until q
```

## クリプケ構造

クリプケ構造（Kripke Structure）は、状態遷移システムの形式的なモデルです。これは有限状態マシンに似ていますが、各状態に真となる原子命題のセットがラベル付けされています。

### 公式定義

クリプケ構造`M`は以下の要素からなるタプル`M = (S, S₀, R, L)`です：

- `S`: システムの可能な状態の有限集合
- `S₀ ⊆ S`: 初期状態の集合
- `R ⊆ S × S`: 遷移関係（どの状態からどの状態へ遷移できるか）
- `L: S → 2^AP`: ラベリング関数（各状態で真となる原子命題の集合を与える）

ここで`AP`は原子命題の集合です。

### Swift実装

TemporalKitでは、クリプケ構造は`KripkeStructure`プロトコルで表現されます：

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

## 時相命題

時相命題（Temporal Proposition）は、システムの状態に対して評価できる論理的記述です。TemporalKitでは、`TemporalProposition`プロトコルを使用して命題を定義します：

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

### 命題の作成

命題は以下のように作成できます：

```swift
// クロージャーを使用して命題を作成
let isAuthenticated = TemporalKit.makeProposition(
    id: "isAuthenticated",
    name: "ユーザーが認証済み",
    evaluate: { (state: AuthState) -> Bool in 
        return state == .loggedIn || state == .refreshingToken 
    }
)
```

## モデル検査

モデル検査は、指定されたモデルに対してLTL式が成立するかどうかを検証するプロセスです。TemporalKitでは、`LTLModelChecker`クラスを使用してこれを行います：

```swift
let modelChecker = LTLModelChecker<MySystemModel>()
let myModel = MySystemModel()
let safetyProperty: LTLFormula<MyProp> = .globally(.implies(.atomic(isCritical), .atomic(isMutexLocked)))

do {
    let result = try modelChecker.check(formula: safetyProperty, model: myModel)
    if result.holds {
        print("安全性プロパティが成立しています")
    } else {
        print("安全性プロパティが不成立です")
        if case .fails(let counterexample) = result {
            print("反例: \(counterexample)")
        }
    }
} catch {
    print("検証エラー: \(error)")
}
```

### 検証結果

モデル検査の結果は`ModelCheckResult`型で表現されます：

```swift
public enum ModelCheckResult<State: Hashable> {
    case holds
    case fails(counterexample: Counterexample<State>)
}
```

式が成立しない場合、反例が提供されます。反例は有限の接頭辞とループを含む状態のシーケンスで、式を満たさない無限の実行パスを表します。

## LTLとシステム検証

LTLとモデル検査の組み合わせにより、以下のようなプロパティを検証できます：

### 安全性プロパティ

「悪いことは決して起こらない」という形式のプロパティです。例えば：

```swift
// クリティカルセクションに同時に2つのプロセスがないことを保証
let safety = .globally(.not(.and(.atomic(process1InCritical), .atomic(process2InCritical))))
```

### 活性プロパティ

「良いことはいつか必ず起こる」という形式のプロパティです。例えば：

```swift
// リクエストは最終的に必ず応答される
let liveness = .globally(.implies(.atomic(requestSent), .eventually(.atomic(responseReceived))))
```

### 公平性プロパティ

「特定の条件が無限回成立するなら、別の条件も無限回成立する」という形式のプロパティです。例えば：

```swift
// プロセスが無限回スケジュールされるなら、無限回実行される
let fairness = .implies(
    .globally(.eventually(.atomic(processScheduled))),
    .globally(.eventually(.atomic(processExecuted)))
)
```

## 実世界への応用

これらの理論的概念は実世界の問題に応用できます：

- **アプリ状態管理**: アプリの状態遷移が正しいことを検証
- **ユーザーフロー**: 認証、チェックアウトなどの重要なフローの正確性を検証
- **エラー処理**: すべてのエラー状態に回復パスがあることを保証
- **並行処理**: レースコンディションやデッドロックを検出
- **セキュリティプロパティ**: アクセス制御ルールが常に適用されることを検証

TemporalKitはこれらの概念を実用的なSwiftコードに落とし込み、形式検証の強力なツールをiOSアプリケーション開発に提供します。
