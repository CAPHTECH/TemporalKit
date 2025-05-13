# 命題の定義と使用

このチュートリアルでは、TemporalKitで時相命題（Temporal Proposition）を定義し使用する方法を詳しく学びます。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- さまざまな種類の時相命題を定義する
- カスタム命題クラスを作成する
- 複合命題を組み合わせる
- トレース評価とモデル検査で命題を使用する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本的な使い方を理解していること（[はじめてのTemporalKit](./BasicUsage.md)をご覧ください）

## ステップ1: 時相命題の基本

TemporalKitでは、命題は`TemporalProposition`プロトコルに準拠するオブジェクトとして表現されます。これらの命題は、システムの状態を評価して真または偽の値を返します。

```swift
import TemporalKit

// 簡単な状態定義
struct AppState {
    let isUserLoggedIn: Bool
    let hasNewNotifications: Bool
    let isNetworkAvailable: Bool
    let currentScreen: Screen
    
    enum Screen {
        case login
        case home
        case settings
        case profile
    }
}
```

## ステップ2: クロージャを使用した命題の定義

最も簡単な命題の定義方法は、`makeProposition`ファクトリ関数を使用することです。

```swift
// ユーザーがログインしているかを確認する命題
let isLoggedIn = TemporalKit.makeProposition(
    id: "isLoggedIn",
    name: "ユーザーがログインしている",
    evaluate: { (state: AppState) -> Bool in
        return state.isUserLoggedIn
    }
)

// 新しい通知があるかを確認する命題
let hasNotifications = TemporalKit.makeProposition(
    id: "hasNotifications",
    name: "新しい通知がある",
    evaluate: { (state: AppState) -> Bool in
        return state.hasNewNotifications
    }
)

// ホーム画面を表示しているかを確認する命題
let isOnHomeScreen = TemporalKit.makeProposition(
    id: "isOnHomeScreen",
    name: "ホーム画面を表示している",
    evaluate: { (state: AppState) -> Bool in
        return state.currentScreen == .home
    }
)
```

## ステップ3: `ClosureTemporalProposition`を直接使用する

より詳細な制御が必要な場合は、`ClosureTemporalProposition`クラスを直接使用できます。

```swift
// ネットワークが利用可能かつユーザーがログインしているかを確認する命題
let isConnectedAndLoggedIn = ClosureTemporalProposition<AppState, Bool>(
    id: "isConnectedAndLoggedIn",
    name: "ネットワーク接続かつログイン済み",
    evaluate: { state in
        // 評価中に何らかの処理が必要な場合はここに記述できます
        let isConnected = state.isNetworkAvailable
        let isLoggedIn = state.isUserLoggedIn
        
        // デバッグ情報を記録するなど
        print("接続状態: \(isConnected), ログイン状態: \(isLoggedIn)")
        
        return isConnected && isLoggedIn
    }
)
```

## ステップ4: カスタム命題クラスの作成

より複雑なケースでは、`TemporalProposition`プロトコルに準拠した独自のクラスを作成できます。

```swift
// アプリ固有の命題のベースクラス
class AppProposition: TemporalProposition {
    public typealias Value = Bool
    
    public let id: PropositionID
    public let name: String
    
    init(id: String, name: String) {
        self.id = PropositionID(rawValue: id)
        self.name = name
    }
    
    public func evaluate(in context: EvaluationContext) throws -> Bool {
        guard let appContext = context as? AppEvaluationContext else {
            throw TemporalKitError.stateTypeMismatch(
                expected: "AppEvaluationContext",
                actual: String(describing: type(of: context)),
                propositionID: id,
                propositionName: name
            )
        }
        return evaluateWithAppState(appContext.state)
    }
    
    // サブクラスでオーバーライドする
    func evaluateWithAppState(_ state: AppState) -> Bool {
        fatalError("サブクラスで実装する必要があります")
    }
}

// ログイン状態を確認するカスタム命題
class IsLoggedInProposition: AppProposition {
    init() {
        super.init(id: "customIsLoggedIn", name: "ユーザーがログイン状態（カスタム）")
    }
    
    override func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.isUserLoggedIn
    }
}

// 特定の画面を表示しているかを確認するカスタム命題
class IsOnScreenProposition: AppProposition {
    private let targetScreen: AppState.Screen
    
    init(screen: AppState.Screen) {
        self.targetScreen = screen
        super.init(
            id: "isOnScreen_\(screen)",
            name: "現在の画面が \(screen) である"
        )
    }
    
    override func evaluateWithAppState(_ state: AppState) -> Bool {
        return state.currentScreen == targetScreen
    }
}

// カスタム命題のインスタンス化
let customIsLoggedIn = IsLoggedInProposition()
let isOnSettingsScreen = IsOnScreenProposition(screen: .settings)
let isOnProfileScreen = IsOnScreenProposition(screen: .profile)
```

## ステップ5: 評価コンテキストの作成

命題を評価するには、`EvaluationContext`プロトコルに準拠したコンテキストが必要です。

```swift
// アプリケーション状態のための評価コンテキスト
class AppEvaluationContext: EvaluationContext {
    let state: AppState
    let traceIndex: Int?
    
    init(state: AppState, traceIndex: Int? = nil) {
        self.state = state
        self.traceIndex = traceIndex
    }
    
    func currentStateAs<T>(_ type: T.Type) -> T? {
        return state as? T
    }
}
```

## ステップ6: トレース評価での命題の使用

一連の状態（トレース）に対して時相論理式を評価してみましょう。

```swift
// アプリケーション状態のトレースを作成
let trace: [AppState] = [
    AppState(isUserLoggedIn: false, hasNewNotifications: false, isNetworkAvailable: true, currentScreen: .login),
    AppState(isUserLoggedIn: true, hasNewNotifications: false, isNetworkAvailable: true, currentScreen: .home),
    AppState(isUserLoggedIn: true, hasNewNotifications: true, isNetworkAvailable: true, currentScreen: .home),
    AppState(isUserLoggedIn: true, hasNewNotifications: false, isNetworkAvailable: true, currentScreen: .profile)
]

// 命題からLTL式を作成
let formula1 = LTLFormula<AppProposition>.eventually(.atomic(customIsLoggedIn))
let formula2 = LTLFormula<AppProposition>.globally(.implies(
    .atomic(isOnHomeScreen as! AppProposition),
    .eventually(.atomic(isOnProfileScreen))
))

// 評価コンテキストプロバイダ（状態とインデックスを関連付ける関数）
let contextProvider: (AppState, Int) -> EvaluationContext = { state, index in
    return AppEvaluationContext(state: state, traceIndex: index)
}

// トレース評価器を作成
let evaluator = LTLFormulaTraceEvaluator()

// 式を評価
do {
    let result1 = try evaluator.evaluate(formula: formula1, trace: trace, contextProvider: contextProvider)
    let result2 = try evaluator.evaluate(formula: formula2, trace: trace, contextProvider: contextProvider)
    
    print("最終的にログインする: \(result1)")
    print("ホーム画面からは必ず最終的にプロフィール画面に遷移する: \(result2)")
} catch {
    print("評価エラー: \(error)")
}
```

## ステップ7: モデル検査での命題の使用

命題を使用してモデル検査を行う例を示します。

```swift
// アプリケーションの状態遷移モデル
struct AppStateModel: KripkeStructure {
    typealias State = AppState.Screen
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State> = [.login, .home, .settings, .profile]
    let initialStates: Set<State> = [.login]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .login:
            return [.home]
        case .home:
            return [.settings, .profile]
        case .settings:
            return [.home]
        case .profile:
            return [.home]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        // 画面に対応する命題を追加
        switch state {
        case .login:
            props.insert(PropositionID(rawValue: "isOnScreen_login"))
        case .home:
            props.insert(PropositionID(rawValue: "isOnScreen_home"))
        case .settings:
            props.insert(PropositionID(rawValue: "isOnScreen_settings"))
        case .profile:
            props.insert(PropositionID(rawValue: "isOnScreen_profile"))
        }
        
        return props
    }
}

// 画面に関する命題
let isOnLoginScreen = TemporalKit.makeProposition(
    id: "isOnScreen_login",
    name: "ログイン画面を表示している",
    evaluate: { (state: AppState.Screen) -> Bool in state == .login }
)

let isOnHomeScreenForModel = TemporalKit.makeProposition(
    id: "isOnScreen_home",
    name: "ホーム画面を表示している",
    evaluate: { (state: AppState.Screen) -> Bool in state == .home }
)

// モデル検査用のLTL式
let formula_home_to_settings = LTLFormula<ClosureTemporalProposition<AppState.Screen, Bool>>.globally(
    .implies(
        .atomic(isOnHomeScreenForModel),
        .eventually(.atomic(TemporalKit.makeProposition(
            id: "isOnScreen_settings",
            name: "設定画面を表示している",
            evaluate: { (state: AppState.Screen) -> Bool in state == .settings }
        )))
    )
)

// モデル検査の実行
let modelChecker = LTLModelChecker<AppStateModel>()
let appModel = AppStateModel()

do {
    let result = try modelChecker.check(formula: formula_home_to_settings, model: appModel)
    print("ホーム画面からは常に最終的に設定画面に到達可能: \(result.holds ? "成立" : "不成立")")
    
    if case .fails(let counterexample) = result {
        print("反例:")
        print("  前置: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("  サイクル: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
} catch {
    print("モデル検査エラー: \(error)")
}
```

## ステップ8: 命題の組み合わせと再利用

命題を組み合わせて、より複雑な条件を表現する方法を示します。

```swift
// 命題を組み合わせるユーティリティ関数
func and<StateType>(_ p1: ClosureTemporalProposition<StateType, Bool>, _ p2: ClosureTemporalProposition<StateType, Bool>) -> ClosureTemporalProposition<StateType, Bool> {
    return TemporalKit.makeProposition(
        id: "and_\(p1.id.rawValue)_\(p2.id.rawValue)",
        name: "(\(p1.name) AND \(p2.name))",
        evaluate: { state in
            let context = AppEvaluationContext(state: state as! AppState)
            return try p1.evaluate(in: context) && p2.evaluate(in: context)
        }
    )
}

func or<StateType>(_ p1: ClosureTemporalProposition<StateType, Bool>, _ p2: ClosureTemporalProposition<StateType, Bool>) -> ClosureTemporalProposition<StateType, Bool> {
    return TemporalKit.makeProposition(
        id: "or_\(p1.id.rawValue)_\(p2.id.rawValue)",
        name: "(\(p1.name) OR \(p2.name))",
        evaluate: { state in
            let context = AppEvaluationContext(state: state as! AppState)
            return try p1.evaluate(in: context) || p2.evaluate(in: context)
        }
    )
}

func not<StateType>(_ p: ClosureTemporalProposition<StateType, Bool>) -> ClosureTemporalProposition<StateType, Bool> {
    return TemporalKit.makeProposition(
        id: "not_\(p.id.rawValue)",
        name: "NOT (\(p.name))",
        evaluate: { state in
            let context = AppEvaluationContext(state: state as! AppState)
            return try !p.evaluate(in: context)
        }
    )
}

// 例：ログインしているが通知がない状態
let loggedInWithoutNotifications = and(isLoggedIn, not(hasNotifications))

// 例：ホーム画面または設定画面を表示している
let isOnHomeOrSettings = or(isOnHomeScreen, isOnSettingsScreen as! ClosureTemporalProposition<AppState, Bool>)
```

## まとめ

このチュートリアルでは、TemporalKitで時相命題を定義し使用する様々な方法を学びました：

1. クロージャを使用した簡単な命題の定義
2. `ClosureTemporalProposition`を直接使用するケース
3. カスタム命題クラスの作成と継承
4. 評価コンテキストの作成と使用
5. トレース評価とモデル検査での命題の使用
6. 命題の組み合わせと再利用の方法

命題は時相論理式の基本的な構成要素であり、システム状態の特定の側面を捉えるために使用されます。適切な命題を設計することで、複雑なシステムの振る舞いを正確にモデル化し検証することができます。

## 次のステップ

- [UIフローの検証](./VerifyingUIFlows.md)を学んで、実際のアプリケーションシナリオに命題を適用する方法を理解しましょう。
- [高度なLTL式](./AdvancedLTLFormulas.md)を学んで、より複雑なプロパティを表現する方法を理解しましょう。
- [テストとの統合](./IntegratingWithTests.md)を読んで、命題を使用したテストの書き方を学びましょう。 
