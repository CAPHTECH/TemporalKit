# TemporalKit iOS 統合ガイド

このガイドではiOSアプリケーション開発におけるTemporalKitの統合と活用方法について詳細に解説します。TemporalKitは時相論理を通じてアプリケーションの動作を形式的に検証することを可能にし、開発者がより堅牢で予測可能なバグの少ないアプリケーションを構築するのに役立ちます。

## 目次

- [TemporalKit iOS 統合ガイド](#temporalkit-ios-統合ガイド)
  - [目次](#目次)
  - [はじめに](#はじめに)
  - [ユースケース](#ユースケース)
    - [アプリケーション状態管理](#アプリケーション状態管理)
      - [例: 認証状態](#例-認証状態)
    - [ユーザーフロー検証](#ユーザーフロー検証)
      - [検証すべき主要なプロパティ](#検証すべき主要なプロパティ)
    - [SwiftUI 状態マシン検証](#swiftui-状態マシン検証)
    - [ネットワーク層の信頼性](#ネットワーク層の信頼性)
      - [検証すべきプロパティ](#検証すべきプロパティ)
    - [並行処理と非同期操作の検証](#並行処理と非同期操作の検証)
    - [アニメーションと遷移シーケンス](#アニメーションと遷移シーケンス)
  - [実装ガイド](#実装ガイド)
    - [基本セットアップ](#基本セットアップ)
    - [アプリケーション状態の定義](#アプリケーション状態の定義)
    - [クリプキ構造の作成](#クリプキ構造の作成)
    - [時相プロパティの定義](#時相プロパティの定義)
    - [検証の実行](#検証の実行)
  - [実世界の例](#実世界の例)
    - [認証フロー](#認証フロー)
    - [Eコマースのチェックアウトプロセス](#eコマースのチェックアウトプロセス)
    - [コンテンツ読み込みとキャッシュ](#コンテンツ読み込みとキャッシュ)
  - [テストとの統合](#テストとの統合)
    - [ユニットテスト](#ユニットテスト)
    - [UIテスト](#uiテスト)
    - [CI/CD統合](#cicd統合)
  - [ベストプラクティス](#ベストプラクティス)
  - [パフォーマンスの考慮事項](#パフォーマンスの考慮事項)
  - [トラブルシューティング](#トラブルシューティング)
    - [一般的な問題](#一般的な問題)
  - [高度なトピック](#高度なトピック)
    - [パラメータ化モデル](#パラメータ化モデル)
    - [モデル検査と実行時検証の組み合わせ](#モデル検査と実行時検証の組み合わせ)
    - [ドメイン固有のプロパティパターン](#ドメイン固有のプロパティパターン)

## はじめに

TemporalKitは線形時相論理（LTL）を通じてiOS開発に形式的検証技術をもたらします。従来のテスト方法だけに頼るのではなく、TemporalKitを使用することで開発者はアプリケーションの時間的性質（時間の経過に伴うアプリケーションの動作に関する記述）を表現し検証することができます。

iOSアプリケーションにとって、これは次のことを意味します：

- UI状態が正しく遷移することを検証する
- ユーザーフローが期待されたパスをたどることを保証する
- 非同期操作が期待通りに完了することを検証する
- すべてのシナリオでエラー回復が正しく機能することを確認する
- 微妙な状態ベースのバグを事前に防止する

## ユースケース

### アプリケーション状態管理

iOSアプリケーションは通常、複雑な状態管理要件を持っています。TemporalKitを使用して状態遷移を検証し、アプリケーション全体で重要なプロパティが保持されることを確認できます。

#### 例: 認証状態

```swift
// アプリケーションの認証状態を定義
enum AuthState: Hashable {
    case loggedOut     // ログアウト状態
    case loggingIn     // ログイン中
    case loggedIn      // ログイン済み
    case authError     // 認証エラー
    case refreshingToken  // トークン更新中
}

// 認証サブシステムをクリプキ構造としてモデル化
struct AuthStateModel: KripkeStructure {
    typealias State = AuthState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.loggedOut]
    let allStates: Set<State> = [.loggedOut, .loggingIn, .loggedIn, .authError, .refreshingToken]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .loggedOut:
            return [.loggingIn]
        case .loggingIn:
            return [.loggedIn, .authError]
        case .loggedIn:
            return [.loggedIn, .refreshingToken, .loggedOut]
        case .authError:
            return [.loggedOut, .loggingIn]
        case .refreshingToken:
            return [.loggedIn, .loggedOut]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .loggedOut:
            return ["isLoggedOut"]
        case .loggingIn:
            return ["isTransitioning"]
        case .loggedIn:
            return ["isAuthenticated", "canAccessContent"]
        case .authError:
            return ["hasError"]
        case .refreshingToken:
            return ["isAuthenticated", "isTransitioning"]
        }
    }
}

// 時相命題を定義
let isLoggedOut = TemporalKit.makeProposition(
    id: "isLoggedOut",
    name: "ユーザーがログアウト状態",
    evaluate: { (state: AuthState) -> Bool in state == .loggedOut }
)

let isAuthenticated = TemporalKit.makeProposition(
    id: "isAuthenticated",
    name: "ユーザーが認証済み",
    evaluate: { (state: AuthState) -> Bool in state == .loggedIn || state == .refreshingToken }
)

let isTransitioning = TemporalKit.makeProposition(
    id: "isTransitioning",
    name: "システムが遷移状態",
    evaluate: { (state: AuthState) -> Bool in state == .loggingIn || state == .refreshingToken }
)

let hasError = TemporalKit.makeProposition(
    id: "hasError",
    name: "認証エラーが発生",
    evaluate: { (state: AuthState) -> Bool in state == .authError }
)

// 検証する時相プロパティを定義
typealias AuthProp = TemporalKit.ClosureTemporalProposition<AuthState, Bool>

// 1. 認証エラーは常にログイン画面に戻るべき
let errorRecovery: LTLFormula<AuthProp> = .globally(
    .implies(.atomic(hasError), .eventually(.atomic(isLoggedOut)))
)

// 2. 遷移状態は常に最終的に安定状態に至るべき
let transitionCompletion: LTLFormula<AuthProp> = .globally(
    .implies(.atomic(isTransitioning), .eventually(.or(.atomic(isAuthenticated), .atomic(isLoggedOut))))
)

// 3. ユーザーは認証済み状態から常にログアウトできるべき
let logoutAccessibility: LTLFormula<AuthProp> = .globally(
    .implies(.atomic(isAuthenticated), .eventually(.atomic(isLoggedOut)))
)

// 検証を実行
let modelChecker = LTLModelChecker<AuthStateModel>()
let authModel = AuthStateModel()

do {
    let errorRecoveryResult = try modelChecker.check(formula: errorRecovery, model: authModel)
    print("エラー回復プロパティ: \(errorRecoveryResult.holds ? "成立" : "不成立")")
    
    let transitionResult = try modelChecker.check(formula: transitionCompletion, model: authModel)
    print("遷移完了プロパティ: \(transitionResult.holds ? "成立" : "不成立")")
    
    let logoutResult = try modelChecker.check(formula: logoutAccessibility, model: authModel)
    print("ログアウトアクセシビリティプロパティ: \(logoutResult.holds ? "成立" : "不成立")")
} catch {
    print("検証エラー: \(error)")
}
```

### ユーザーフロー検証

オンボーディング、登録、チェックアウトプロセスなどの複雑なユーザーフローをTemporalKitでモデル化および検証できます。

#### 検証すべき主要なプロパティ

- ユーザーは前提条件を完了せずに特定の画面にアクセスできない
- すべてのエラー状態に回復パスがある
- ユーザーは常にフローをキャンセルまたは終了できる
- セッションタイムアウトが正しくフローを中断し回復する
- フロー完了前に必要な情報がすべて収集される

```swift
// 例: オンボーディングフローの検証
enum OnboardingState: Hashable {
    case welcome       // ようこそ画面
    case permissions   // 権限リクエスト
    case accountCreation  // アカウント作成
    case profileSetup  // プロフィール設定
    case tutorial      // チュートリアル
    case complete      // 完了
    case skipped       // スキップ
}

// ユーザーが権限画面を通過せずに「完了」に到達できないことを保証するプロパティを定義
let permissionsRequired: LTLFormula<OnboardingProp> = .globally(
    .implies(
        .atomic(isWelcomeState),
        .not(.until(.not(.atomic(isPermissionsState)), .atomic(isCompleteState)))
    )
)
```

### SwiftUI 状態マシン検証

SwiftUIアプリケーションは基本的に状態マシンです。TemporalKitを使用してビュー状態の遷移が正しいことを検証し、ローディング状態でスタックするなどの問題を防止できます。

```swift
// SwiftUIビュー状態マシンをモデル化
enum ViewState: Hashable {
    case initial    // 初期状態
    case loading    // 読み込み中
    case loaded(Data)  // データ読み込み完了
    case empty      // 空の状態
    case error(Error)  // エラー状態
}

struct ViewStateModel: KripkeStructure {
    // 実装の詳細は簡潔にするため省略
}

// ローディングが常に最終的にロード完了またはエラーにつながることを保証するプロパティ
let loadingCompletes: LTLFormula<ViewProp> = .globally(
    .implies(.atomic(isLoading), .eventually(.or(.atomic(isLoaded), .atomic(isError))))
)
```

### ネットワーク層の信頼性

TemporalKitを使用してネットワーク操作、リトライロジック、キャッシュ動作を検証できます。

#### 検証すべきプロパティ

- ネットワーク障害は常にリトライまたは適切なエラー処理につながる
- キャッシュデータが適切に使用される
- 認証ヘッダーが必要に応じて更新される
- レート制限によるデッドロックが発生しない
- オフライン操作が適切にキューに入れられ、接続が復旧したときに実行される

```swift
// 例: キャッシュとリトライロジックを持つネットワーク層の検証
enum NetworkRequestState: Hashable {
    case initial         // 初期状態
    case checkingCache   // キャッシュ確認中
    case usingCachedData // キャッシュデータ使用中
    case fetching        // データ取得中
    case retrying        // リトライ中
    case succeeded       // 成功
    case failed          // 失敗
}

// すべてのネットワーク操作が最終的に成功または失敗することを保証するプロパティ
let networkOperationsTerminate: LTLFormula<NetworkProp> = .globally(
    .implies(
        .atomic(isFetching),
        .eventually(.or(.atomic(isSucceeded), .atomic(isFailed)))
    )
)

// リトライロジックが有限であることを保証
let boundedRetries: LTLFormula<NetworkProp> = .globally(
    .implies(
        .atomic(isRetrying), 
        .or(.next(.atomic(isSucceeded)), .next(.atomic(isFailed)), .next(.atomic(isRetrying)))
    )
)
```

### 並行処理と非同期操作の検証

TemporalKitを使用して、async/awaitコード、タスク、およびオペレーションの動作を検証し、競合状態やデッドロックを防止します。

```swift
// 非同期操作フローの状態をモデル化
enum AsyncOperationState: Hashable {
    case idle        // アイドル状態
    case inProgress  // 進行中
    case completed   // 完了
    case cancelled   // キャンセル
    case failed      // 失敗
}

// 操作がキャンセル可能であることを保証
let cancellationWorks: LTLFormula<AsyncProp> = .globally(
    .implies(
        .and(.atomic(isInProgress), .next(.atomic(isCancelled))),
        .not(.next(.atomic(isCompleted)))
    )
)

// 操作がスタックしないことを検証
let noDeadlocks: LTLFormula<AsyncProp> = .globally(
    .implies(.atomic(isInProgress), .eventually(.or(.atomic(isCompleted), .atomic(isCancelled), .atomic(isFailed))))
)
```

### アニメーションと遷移シーケンス

複雑なアニメーションシーケンスが期待された順序に従うこと、およびUI状態が正しく遷移することを検証します。

```swift
// アニメーション状態をモデル化
enum AnimationState: Hashable {
    case initial          // 初期状態
    case fadeOutBegin     // フェードアウト開始
    case fadeOutComplete  // フェードアウト完了
    case fadeInBegin      // フェードイン開始
    case fadeInComplete   // フェードイン完了
}

// アニメーションが正しいシーケンスに従うことを保証
let animationSequence: LTLFormula<AnimationProp> = .globally(
    .implies(
        .atomic(isFadeOutBegin),
        .next(.until(.atomic(isFadeOutComplete), .atomic(isFadeInBegin)))
    )
)
```

## 実装ガイド

### 基本セットアップ

1. Swift Package Managerを使用して、プロジェクトにTemporalKitを追加します：

```swift
dependencies: [
    .package(url: "https://github.com/CAPHTECH/TemporalKit.git", from: "0.1.0")
]
```

2. ソースファイルでTemporalKitをインポートします：

```swift
import TemporalKit
```

### アプリケーション状態の定義

まず、アプリケーションまたはコンポーネントが取りうる状態を特定して定義します：

```swift
enum AppState: Hashable {
    case startup      // 起動状態
    case onboarding   // オンボーディング
    case main(MainState)  // メイン画面（サブ状態あり）
    case settings     // 設定画面
    case error(ErrorType)  // エラー状態
}

enum MainState: Hashable {
    case feedLoading  // フィード読み込み中
    case feedLoaded   // フィード読み込み完了
    case feedEmpty    // フィードが空
    case feedError    // フィードエラー
}

enum ErrorType: Hashable {
    case network         // ネットワークエラー
    case authentication  // 認証エラー
    case unknown         // 不明なエラー
}
```

### クリプキ構造の作成

アプリケーションが状態間をどのように遷移するかをモデル化するために、`KripkeStructure`プロトコルを実装します：

```swift
struct AppStateModel: KripkeStructure {
    typealias State = AppState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.startup]
    let allStates: Set<State>
    
    init() {
        // すべての可能な状態を定義
        var states: Set<State> = [.startup, .onboarding, .settings]
        
        // メイン状態を追加
        states.insert(.main(.feedLoading))
        states.insert(.main(.feedLoaded))
        states.insert(.main(.feedEmpty))
        states.insert(.main(.feedError))
        
        // エラー状態を追加
        states.insert(.error(.network))
        states.insert(.error(.authentication))
        states.insert(.error(.unknown))
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .startup:
            return [.onboarding, .main(.feedLoading)]
        case .onboarding:
            return [.main(.feedLoading), .error(.unknown)]
        case .main(let mainState):
            switch mainState {
            case .feedLoading:
                return [.main(.feedLoaded), .main(.feedEmpty), .main(.feedError), .error(.network)]
            case .feedLoaded:
                return [.main(.feedLoading), .settings]
            case .feedEmpty:
                return [.main(.feedLoading)]
            case .feedError:
                return [.main(.feedLoading), .error(.unknown)]
            }
        case .settings:
            return [.main(.feedLoaded), .main(.feedLoading)]
        case .error(let errorType):
            switch errorType {
            case .network:
                return [.main(.feedLoading)]
            case .authentication:
                return [.startup, .onboarding]
            case .unknown:
                return [.startup]
            }
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props: Set<AtomicPropositionIdentifier> = []
        
        switch state {
        case .startup:
            props.insert("isStartup")
        case .onboarding:
            props.insert("isOnboarding")
        case .main(let mainState):
            props.insert("isMain")
            switch mainState {
            case .feedLoading:
                props.insert("isLoading")
            case .feedLoaded:
                props.insert("hasContent")
            case .feedEmpty:
                props.insert("isEmpty")
            case .feedError:
                props.insert("hasError")
            }
        case .settings:
            props.insert("isSettings")
        case .error(let errorType):
            props.insert("isError")
            switch errorType {
            case .network:
                props.insert("isNetworkError")
            case .authentication:
                props.insert("isAuthError")
            case .unknown:
                props.insert("isUnknownError")
            }
        }
        
        return props
    }
}
```

### 時相プロパティの定義

アプリケーション内の条件を記述するための命題を作成し、それらをLTL式に合成します：

```swift
// 命題を定義
let isStartup = TemporalKit.makeProposition(
    id: "isStartup",
    name: "アプリケーションが起動状態",
    evaluate: { (state: AppState) -> Bool in
        if case .startup = state { return true }
        return false
    }
)

let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "アプリケーションがエラー状態",
    evaluate: { (state: AppState) -> Bool in
        if case .error = state { return true }
        return false
    }
)

let isLoading = TemporalKit.makeProposition(
    id: "isLoading",
    name: "アプリケーションがコンテンツを読み込み中",
    evaluate: { (state: AppState) -> Bool in
        if case .main(.feedLoading) = state { return true }
        return false
    }
)

typealias AppProp = TemporalKit.ClosureTemporalProposition<AppState, Bool>

// 時相プロパティをLTL式として定義
let errorRecovery: LTLFormula<AppProp> = .globally(
    .implies(.atomic(isError), .eventually(.not(.atomic(isError))))
)

let loadingCompletes: LTLFormula<AppProp> = .globally(
    .implies(.atomic(isLoading), .eventually(.not(.atomic(isLoading))))
)

let startupEventuallyMain: LTLFormula<AppProp> = .implies(
    .atomic(isStartup),
    .eventually(.or(
        .atomic(TemporalKit.makeProposition(
            id: "isMain",
            name: "メイン画面にいる",
            evaluate: { (state: AppState) -> Bool in
                if case .main = state { return true }
                return false
            }
        )),
        .atomic(isError)
    ))
)
```

### 検証の実行

`LTLModelChecker`を使用して、モデルに対してプロパティを検証します：

```swift
func verifyAppBehavior() {
    let modelChecker = LTLModelChecker<AppStateModel>()
    let appModel = AppStateModel()
    
    do {
        // エラー回復を検証
        let errorRecoveryResult = try modelChecker.check(formula: errorRecovery, model: appModel)
        if errorRecoveryResult.holds {
            print("✅ エラー回復プロパティは成立しています")
        } else {
            print("❌ エラー回復プロパティは不成立です")
            if case .fails(let counterexample) = errorRecoveryResult {
                print("反例: \(counterexample.infinitePathDescription)")
            }
        }
        
        // 読み込み完了を検証
        let loadingResult = try modelChecker.check(formula: loadingCompletes, model: appModel)
        if loadingResult.holds {
            print("✅ 読み込み完了プロパティは成立しています")
        } else {
            print("❌ 読み込み完了プロパティは不成立です")
            if case .fails(let counterexample) = loadingResult {
                print("反例: \(counterexample.infinitePathDescription)")
            }
        }
        
        // 起動フローを検証
        let startupResult = try modelChecker.check(formula: startupEventuallyMain, model: appModel)
        if startupResult.holds {
            print("✅ 起動フロープロパティは成立しています")
        } else {
            print("❌ 起動フロープロパティは不成立です")
            if case .fails(let counterexample) = startupResult {
                print("反例: \(counterexample.infinitePathDescription)")
            }
        }
    } catch {
        print("検証エラー: \(error)")
    }
}
```

## 実世界の例

### 認証フロー

この例では、複数の状態を持つ認証フローをモデル化し、重要なプロパティを検証します：

```swift
enum AuthFlowState: Hashable {
    case initial            // 初期状態
    case enterCredentials   // 認証情報入力
    case authenticating     // 認証中
    case biometricPrompt    // 生体認証プロンプト
    case biometricVerifying // 生体認証検証中
    case mfaRequired        // 多要素認証が必要
    case mfaVerifying       // 多要素認証検証中
    case authenticated      // 認証完了
    case authError(AuthErrorType)  // 認証エラー
    case locked             // ロック状態
}

enum AuthErrorType: Hashable {
    case invalidCredentials // 無効な認証情報
    case networkFailure     // ネットワーク障害
    case biometricFailure   // 生体認証失敗
    case mfaFailure         // 多要素認証失敗
    case accountLocked      // アカウントロック
}

// 以下のようなプロパティをモデル化して検証：
// 1. 認証試行は総当たり攻撃を防ぐために制限されるべき
// 2. ユーザーは常にログイン画面に戻れるべき
// 3. 生体認証は非アクティブの場合タイムアウトするべき
// 4. 複数回の失敗はアカウントロックをトリガーするべき
// 5. ネットワーク障害では認証情報を失わずにリトライできるべき
```

### Eコマースのチェックアウトプロセス

注文完了、在庫確認、支払い処理などのプロパティを検証するチェックアウトフローをモデル化します：

```swift
enum CheckoutState: Hashable {
    case cart               // カート
    case addressEntry       // 住所入力
    case shippingOptions    // 配送オプション
    case paymentEntry       // 支払い情報入力
    case processingPayment  // 支払い処理中
    case orderConfirmation  // 注文確認
    case orderComplete      // 注文完了
    case error(CheckoutError)  // エラー
}

enum CheckoutError: Hashable {
    case paymentFailure         // 支払い失敗
    case inventoryUnavailable   // 在庫なし
    case shippingUnavailable    // 配送不可
    case addressValidationFailed // 住所検証失敗
}

// 以下のようなプロパティをモデル化して検証：
// 1. 支払い処理は住所と配送が確認された後にのみ行われるべき
// 2. 在庫確認は支払い処理の前に行われるべき
// 3. ユーザーは常に前のチェックアウトステップに戻れるべき
// 4. 支払い失敗によって顧客データが失われるべきではない
// 5. 支払いが成功するまで注文は完了とマークされるべきではない
```

### コンテンツ読み込みとキャッシュ

キャッシュとページネーションを伴うコンテンツ読み込みをモデル化し、データの鮮度と読み込み状態に関するプロパティを検証します：

```swift
enum ContentLoadingState: Hashable {
    case idle              // アイドル状態
    case checkingCache     // キャッシュ確認中
    case usingCachedData   // キャッシュデータ使用中
    case fetchingFirstPage // 最初のページ取得中
    case fetchingNextPage  // 次のページ取得中
    case refreshing        // 更新中
    case loaded(hasMore: Bool)  // 読み込み完了（さらにあるか）
    case empty             // 空
    case error(ContentLoadingError)  // エラー
}

enum ContentLoadingError: Hashable {
    case network   // ネットワークエラー
    case parsing   // パースエラー
    case serverError  // サーバーエラー
}

// 以下のようなプロパティをモデル化して検証：
// 1. 初期読み込みはネットワークの前にキャッシュをチェックするべき
// 2. ページネーションは既存のコンテンツを保持するべき
// 3. 更新はキャッシュを無効化するべき
// 4. エラー状態ではリトライが可能であるべき
// 5. 空の状態はエラー状態と区別できるべき
```

## テストとの統合

### ユニットテスト

TemporalKitの検証をユニットテストに統合します：

```swift
func testAuthenticationFlow() {
    let modelChecker = LTLModelChecker<AuthStateModel>()
    let authModel = AuthStateModel()
    
    // 重要なプロパティを定義
    let errorRecovery: LTLFormula<AuthProp> = .globally(
        .implies(.atomic(hasError), .eventually(.atomic(isLoggedOut)))
    )
    
    // 検証してアサート
    do {
        let result = try modelChecker.check(formula: errorRecovery, model: authModel)
        XCTAssertTrue(result.holds, "認証エラー回復プロパティが成立すべきです")
    } catch {
        XCTFail("検証がエラーで失敗しました: \(error)")
    }
}
```

### UIテスト

UIテストの期待される動作を定義するためにTemporalKitを使用します：

```swift
// 期待されるUI状態遷移のモデルを定義
struct LoginScreenModel: KripkeStructure {
    // 実装の詳細は簡潔にするため省略
}

// UIテスト内で：
func testLoginScreenBehavior() {
    // UIテストを実行...
    
    // モデルプロパティを検証
    let modelChecker = LTLModelChecker<LoginScreenModel>()
    let screenModel = LoginScreenModel()
    
    do {
        let result = try modelChecker.check(formula: loginButtonEnablement, model: screenModel)
        XCTAssertTrue(result.holds, "ログインボタンは認証情報が有効な場合にのみ有効化されるべきです")
    } catch {
        XCTFail("検証がエラーで失敗しました: \(error)")
    }
}
```

### CI/CD統合

TemporalKit検証をCI/CDパイプラインに組み込みます：

```swift
// 検証スイートを作成
struct AppVerificationSuite {
    static func verifyAllProperties() throws -> VerificationReport {
        var report = VerificationReport()
        
        // 認証プロパティ
        report.authResults = try verifyAuthFlow()
        
        // ナビゲーションプロパティ
        report.navResults = try verifyNavigation()
        
        // ネットワークプロパティ
        report.networkResults = try verifyNetworkBehavior()
        
        return report
    }
    
    // 実装の詳細は簡潔にするため省略
}

// CIスクリプト内：
do {
    let report = try AppVerificationSuite.verifyAllProperties()
    if !report.allPropertiesHold {
        throw Error("重要な時相プロパティの検証に失敗しました")
    }
} catch {
    print("検証失敗: \(error)")
    exit(1)
}
```

## ベストプラクティス

1. **小さく始める**: 最初は小さな重要なコンポーネントをモデル化して検証し、その後アプリケーション全体に取り組みます。

2. **重要なプロパティに焦点を当てる**: すべてに形式的検証は必要ありません。以下に焦点を当てましょう：
   - エラー回復パス
   - 認証とセキュリティフロー
   - 金融取引
   - データ永続性の保証
   - 重要なユーザージャーニー

3. **段階的な導入**: TemporalKit検証を徐々に追加します：
   - 単一の機能やコンポーネントから始める
   - まずクリティカルパスのテストに追加する
   - 徐々にカバレッジを拡大する

4. **モデルを最新に保つ**: アプリケーションの動作が変更されたら、クリプキ構造と式も更新します。

5. **明確な命名**: 命題や式に明確な名前を付けて、反例を理解しやすくします。

6. **モデルと実装を分離する**: 検証モデルは実装の詳細を複製するのではなく、期待される動作を記述すべきです。

7. **パフォーマンスを考慮する**: 大きな状態空間では、サブコンポーネントを個別に検証します。

## パフォーマンスの考慮事項

1. **状態空間の大きさ**: モデルの状態数は検証パフォーマンスに大きな影響を与えます。必須の状態に焦点を当てた抽象モデルから始めましょう。

2. **式の複雑さ**: 複雑なネストされた式は検証を遅くする可能性があります。複雑なプロパティを小さく構成可能な式に分解しましょう。

3. **段階的検証**: まず単純なプロパティを検証し、その後複雑さを追加します。

4. **開発者ループ**: 検証はプロダクションコードではなく、テストの一部として実行します。

5. **反例分析**: プロパティが失敗した場合、反例を注意深く分析します。微妙なバグや欠落した要件を明らかにすることがよくあります。

## トラブルシューティング

### 一般的な問題

1. **検証に時間がかかりすぎる**:
   - 状態空間が大きすぎる可能性があります
   - モデルを簡素化するか、より小さなコンポーネントに分割してみてください
   - 動作の重要なサブセットに焦点を当ててください

2. **予期しない反例**:
   - モデル遷移を慎重に見直してください
   - プロパティが望ましい動作を正しく表現しているか確認してください
   - 命題が正しく評価されていることを確認してください

3. **式の表現の課題**:
   - 単純なパターン（安全性、活性、公平性）から始めてください
   - より複雑な式を段階的に構築してください
   - 一般的なパターンを構築するためのヘルパー関数を使用してください

## 高度なトピック

### パラメータ化モデル

さまざまなシナリオ用に構成できるモデルを作成します：

```swift
struct ConfigurableAuthFlow: KripkeStructure {
    let maxLoginAttempts: Int       // 最大ログイン試行回数
    let requiresMFA: Bool           // 多要素認証が必要か
    let supportsBiometrics: Bool    // 生体認証をサポートするか
    
    // これらのパラメータを使用した実装
}
```

### モデル検査と実行時検証の組み合わせ

TemporalKitを静的検証と実行時モニタリングの両方に使用します：

```swift
// プロパティを一度定義
let criticalProperty: LTLFormula<AppProp> = // ...

// 静的検証に使用
let modelChecker = LTLModelChecker<AppModel>()
let staticResult = try modelChecker.check(formula: criticalProperty, model: appModel)

// 実行時モニタリングにも使用
let traceEvaluator = LTLFormulaTraceEvaluator<AppProp>()
let runtime = appStateRecorder.captureStates() // 状態キャプチャメカニズム
let runtimeResult = try traceEvaluator.evaluate(formula: criticalProperty, trace: runtime)
```

### ドメイン固有のプロパティパターン

ドメイン内の一般的なパターンのヘルパー関数を作成します：

```swift
// 「この状態は常にあの状態につながる」というヘルパー
func alwaysLeadsTo<P: TemporalProposition>(
    from: P, 
    to: P
) -> LTLFormula<P> {
    return .globally(.implies(.atomic(from), .eventually(.atomic(to))))
}

// 「これらの状態は交互になるべき」というヘルパー
func alternating<P: TemporalProposition>(
    first: P,
    second: P
) -> LTLFormula<P> {
    return .globally(.implies(
        .atomic(first),
        .next(.until(.not(.atomic(first)), .atomic(second)))
    ))
}

// これらのヘルパーを使用
let buttonToConfirmation = alwaysLeadsTo(from: isSubmitButtonPressed, to: isConfirmationShown)
```

このガイドに従うことで、iOSデベロッパーはTemporalKitを活用して、アプリケーション内の重要な動作を形式的に検証し、より堅牢で信頼性の高いソフトウェアを実現できます。
