# TemporalKit パフォーマンス最適化ガイド

形式的検証は計算コストが高い処理であり、モデルの大きさや複雑さによってはパフォーマンスの問題が発生することがあります。このガイドでは、TemporalKitを使用する際のパフォーマンスを最適化するためのテクニックと推奨事項を説明します。

## 目次

- [モデルサイズの最適化](#モデルサイズの最適化)
- [LTL式の最適化](#ltl式の最適化)
- [命題の最適化](#命題の最適化)
- [アルゴリズムの選択](#アルゴリズムの選択)
- [メモリ使用量の最適化](#メモリ使用量の最適化)
- [増分的検証](#増分的検証)
- [並列処理](#並列処理)
- [キャッシングと再利用](#キャッシングと再利用)
- [プロファイリングと計測](#プロファイリングと計測)

## モデルサイズの最適化

モデル検査の計算複雑性は、状態空間のサイズに大きく依存します。状態空間を小さく保つことで、検証のパフォーマンスを大幅に向上させることができます。

### 状態抽象化

実装の詳細をすべてモデル化するのではなく、検証対象のプロパティに関連する側面のみをモデル化します。

```swift
// 詳細すぎるモデル（非効率的）
struct DetailedUserState: Hashable {
    let userId: UUID
    let username: String
    let email: String
    let profilePicture: URL
    let preferences: [String: Any]
    let lastLoginDate: Date
    let friendList: [UUID]
    let isActive: Bool
    // ...その他多数のフィールド
}

// 抽象化されたモデル（効率的）
struct AbstractUserState: Hashable {
    let authenticationStatus: AuthStatus
    let hasCompletedProfile: Bool
    
    enum AuthStatus: Hashable {
        case unauthenticated
        case authenticating
        case authenticated
        case authenticationFailed
    }
}
```

### 対称性の削減

多くのモデルには対称性があります。例えば、ユーザーIDが異なるだけで機能的に同じ状態があるかもしれません。対称性を認識し利用することで、検証すべき状態の数を減らすことができます。

```swift
// 対称性を持つモデル
struct UserSessionModel: KripkeStructure {
    // ...
    
    // 3つのセッションをモデル化する代わりに、
    // 「アクティブなセッションの数」だけを追跡する
    enum ActiveSessionCount: Hashable {
        case none
        case one
        case twoOrMore
    }
    
    let sessionCount: ActiveSessionCount
    
    // ...
}
```

### 関連のない要素の除外

検証するプロパティに関連のない要素はモデルから除外します。

```swift
// 検証には関連のない詳細を含むモデル
struct PaymentProcessState: Hashable {
    let amount: Decimal
    let currency: String
    let paymentMethod: PaymentMethod
    let timestamp: Date
    let transactionId: String
    // ...
}

// 状態遷移だけに焦点を当てたモデル
enum PaymentProcessPhase: Hashable {
    case initiated
    case processingPayment
    case verifying
    case succeeded
    case failed(reason: FailureReason)
}
```

## LTL式の最適化

LTL式の複雑さもモデル検査のパフォーマンスに影響します。

### 式の単純化

複雑な式を単純な式に分解して個別に検証することで、全体のパフォーマンスを向上させることができます。

```swift
// 複雑な式
let complexFormula = G(.implies(
    .and(.atomic(p1), .atomic(p2)),
    .eventually(.and(.atomic(q1), .or(.atomic(q2), .atomic(q3))))
))

// 単純な式に分解
let simpleFormula1 = G(.implies(.atomic(p1), .eventually(.atomic(q1))))
let simpleFormula2 = G(.implies(.atomic(p2), .eventually(.or(.atomic(q2), .atomic(q3)))))
```

### ネスト深度の削減

深くネストされたLTL式は検証が難しくなることがあります。同じセマンティクスを持つより浅い式を使用すると、パフォーマンスが向上することがあります。

```swift
// 深くネストされた式
let deeplyNested = G(.implies(
    .atomic(p),
    .next(.next(.next(.atomic(q))))
))

// より浅く同等の式
let flattened = G(.implies(
    .atomic(p),
    F(.and(.atomic(q), .not(.or(.atomic(p), .next(.atomic(p))))))
))
```

### 演算子の選択

一部のLTL演算子は他の演算子より計算コストが高いことがあります。可能な場合は、より効率的な演算子を選びましょう。

```swift
// より複雑な演算子を使用
let complexOperator = F(.until(.atomic(p), .atomic(q)))

// より単純な演算子を使用
let simpleOperator = F(.and(.atomic(q), F(.atomic(p))))
```

## 命題の最適化

命題の評価効率も全体のパフォーマンスに影響します。

### 効率的な評価

命題の評価関数は、できるだけ計算効率の良いものにします。

```swift
// 非効率的な評価
let inefficientProp = TemporalKit.makeProposition(
    id: "inefficient",
    name: "非効率的な命題",
    evaluate: { (state: AppState) -> Bool in
        // 重い計算や複雑なフィルタリング
        let result = state.items.filter { item in
            // 複雑な条件
            return complexCalculation(item)
        }.count > 0
        
        return result
    }
)

// 効率的な評価
let efficientProp = TemporalKit.makeProposition(
    id: "efficient",
    name: "効率的な命題",
    evaluate: { (state: AppState) -> Bool in
        // 早期リターンと軽量な計算
        for item in state.items {
            if simpleCheck(item) {
                return true
            }
        }
        return false
    }
)
```

### 命題のキャッシング

同じ状態に対して命題を複数回評価する場合は、結果をキャッシュすることを検討してください。

```swift
class CachingPropositionWrapper<P: TemporalProposition>: TemporalProposition where P.Value == Bool {
    typealias Input = P.Input
    typealias Value = Bool
    typealias ID = P.ID
    
    let wrappedProposition: P
    var cache: [Input: Bool] = [:]
    
    var id: ID { wrappedProposition.id }
    var name: String { wrappedProposition.name }
    
    init(wrappedProposition: P) {
        self.wrappedProposition = wrappedProposition
    }
    
    func evaluate(with context: some EvaluationContext<Input>) throws -> Bool {
        if let cachedResult = cache[context.input] {
            return cachedResult
        }
        
        let result = try wrappedProposition.evaluate(with: context)
        cache[context.input] = result
        return result
    }
}
```

## アルゴリズムの選択

TemporalKitは複数のモデル検査アルゴリズムをサポートしており、検証するプロパティとモデルに応じて適切なアルゴリズムを選択することが重要です。

### 適切なアルゴリズムの選択

```swift
// デフォルトのモデルチェッカー（一般的なLTL式に適している）
let defaultChecker = LTLModelChecker<MyModel>()

// 特定のプロパティタイプに最適化されたチェッカー
let specializedChecker = LTLModelChecker<MyModel>(algorithm: .specialized)

// 大規模モデル用のオンザフライチェッカー
let onTheFlyChecker = LTLModelChecker<MyModel>(algorithm: .onTheFly)
```

## メモリ使用量の最適化

大規模なモデルの検証はメモリを大量に消費する可能性があります。

### 状態表現の最適化

状態表現を最適化してメモリ使用量を削減します。

```swift
// メモリを多く使用する状態表現
struct IneffientState: Hashable {
    let id: UUID
    let name: String
    let longDescription: String
    let history: [StateTransition]
    // ...
}

// メモリ効率の良い状態表現
struct EfficientState: Hashable {
    let id: Int // UUIDの代わりに単純な整数を使用
    let type: StateType // 列挙型を使用
    
    enum StateType: UInt8 { // コンパクトな型を使用
        case initial
        case intermediate
        case final
    }
}
```

### スパース表現

遷移関係が疎である（ほとんどの状態がごく少数の後続状態しか持たない）場合、スパース表現を使用することで多くのメモリを節約できます。

```swift
// 完全な遷移テーブル（メモリ使用量大）
var transitions: [State: Set<State>] = [:]
for state in allStates {
    transitions[state] = computeSuccessors(state)
}

// スパース表現（必要な遷移のみを保存）
func successors(of state: State) -> Set<State> {
    // 状態の特性に基づいて後続状態を計算
    switch state {
    case .initialState:
        return [.processing]
    case .processing:
        return [.success, .error]
    // ...
    }
}
```

## 増分的検証

大規模なシステムでは、一度にすべてを検証するのではなく、増分的に検証することを検討してください。

### コンポーネント分解

システムを小さなコンポーネントに分解し、個別に検証します。

```swift
// 認証サブシステムのモデル
struct AuthenticationModel: KripkeStructure {
    // 認証関連の状態と遷移のみを含む
}

// 支払い処理サブシステムのモデル
struct PaymentProcessingModel: KripkeStructure {
    // 支払い関連の状態と遷移のみを含む
}

// 両方のモデルを個別に検証
let authChecker = LTLModelChecker<AuthenticationModel>()
let paymentChecker = LTLModelChecker<PaymentProcessingModel>()
```

### 段階的検証

最も重要なプロパティから始めて、検証を段階的に拡張していきます。

```swift
// 段階1: 基本的な安全性プロパティ
let safetyProperties = [
    criticalSectionMutex,
    deadlockFreedom,
    invariantMaintenance
]

// 段階2: 活性プロパティ
let livenessProperties = [
    requestsEventuallyResponded,
    progressGuaranteed
]

// 段階3: 公平性プロパティ
let fairnessProperties = [
    noStarvation,
    fairScheduling
]

// 各段階のプロパティを検証
for property in safetyProperties {
    try modelChecker.check(formula: property, model: model)
}
// 安全性が確認できたら次の段階へ
```

## 並列処理

複数のプロパティやモデルの検証を並列化することで、マルチコアシステムのパフォーマンスを向上させることができます。

### 並列プロパティ検証

独立したプロパティを並列に検証します。

```swift
// 並列検証の例
let properties: [LTLFormula<MyProposition>] = [prop1, prop2, prop3, prop4]
let modelChecker = LTLModelChecker<MyModel>()
let model = MyModel()

DispatchQueue.concurrentPerform(iterations: properties.count) { index in
    let property = properties[index]
    do {
        let result = try modelChecker.check(formula: property, model: model)
        print("Property \(index) result: \(result)")
    } catch {
        print("Error checking property \(index): \(error)")
    }
}
```

## キャッシングと再利用

検証結果をキャッシュして再利用することで、反復的な開発プロセスでのパフォーマンスを向上させることができます。

### 部分結果のキャッシング

```swift
class CachingModelChecker<Model: KripkeStructure> {
    private let wrappedChecker: LTLModelChecker<Model>
    private var cache: [String: ModelCheckResult<Model.State>] = [:]
    
    init(wrappedChecker: LTLModelChecker<Model>) {
        self.wrappedChecker = wrappedChecker
    }
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        let cacheKey = "\(formula)"
        
        if let cachedResult = cache[cacheKey] {
            return cachedResult
        }
        
        let result = try wrappedChecker.check(formula: formula, model: model)
        cache[cacheKey] = result
        return result
    }
}
```

## プロファイリングと計測

パフォーマンスの問題を特定して対処するには、プロファイリングと計測が不可欠です。

### 検証時間の計測

```swift
func measureCheckTime<Model: KripkeStructure, P: TemporalProposition>(
    checker: LTLModelChecker<Model>,
    formula: LTLFormula<P>,
    model: Model
) throws -> (result: ModelCheckResult<Model.State>, timeInSeconds: Double) where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
    let startTime = CFAbsoluteTimeGetCurrent()
    let result = try checker.check(formula: formula, model: model)
    let endTime = CFAbsoluteTimeGetCurrent()
    
    let timeInSeconds = endTime - startTime
    return (result, timeInSeconds)
}

// 使用例
do {
    let (result, time) = try measureCheckTime(checker: modelChecker, formula: property, model: myModel)
    print("検証結果: \(result), 実行時間: \(time) 秒")
} catch {
    print("検証エラー: \(error)")
}
```

### メモリ使用量の監視

```swift
func reportMemoryUsage(label: String) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    
    let kerr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        print("\(label) - メモリ使用量: \(usedMB) MB")
    } else {
        print("メモリ使用量の取得に失敗しました")
    }
}

// 使用例
reportMemoryUsage(label: "検証前")
let result = try modelChecker.check(formula: property, model: myModel)
reportMemoryUsage(label: "検証後")
```

## ベストプラクティスのまとめ

1. **モデルを抽象化**: 必要最小限の詳細のみを含めたモデルを作成する
2. **状態空間を小さく保つ**: 対称性を利用し、関連のない要素を除外する
3. **LTL式を単純化**: 複雑な式を単純な式に分解する
4. **効率的な命題評価**: 計算効率の良い評価関数を使用する
5. **増分的検証**: システムを小さなコンポーネントに分解し、段階的に検証する
6. **並列処理の活用**: 独立したプロパティを並列に検証する
7. **結果のキャッシング**: 以前の検証結果を再利用する
8. **メモリ最適化**: メモリ効率の良いデータ構造とアルゴリズムを選択する
9. **プロファイリング**: パフォーマンスのボトルネックを特定して対処する

TemporalKitを使用した形式的検証は、適切な最適化テクニックを適用することで、大規模で複雑なシステムでも実用的なパフォーマンスを達成することができます。 
