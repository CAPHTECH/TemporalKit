# 実例によるTemporalKit

このチュートリアルでは、実際のユースケースに基づいてTemporalKitを適用する方法を紹介します。具体的なシナリオを通して、形式的検証の実践的な適用方法を学びます。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- 実際のアプリケーションにTemporalKitを適用する方法を理解する
- 様々なドメイン（UI、ネットワーク、状態管理など）での応用例を知る
- 日常的な開発プロセスにTemporalKitを組み込む方法を学ぶ

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること
- [基本的な使い方](./BasicUsage.md)のチュートリアルを完了していること

## 例1：ログイン機能の検証

ユーザー認証フローを例に、TemporalKitでの検証方法を見てみましょう。

```swift
import TemporalKit

// ユーザー認証の状態を表現
enum AuthState: Hashable, CustomStringConvertible {
    case loggedOut
    case loggingIn
    case loginFailed(reason: String)
    case loggedIn(user: String)
    
    var description: String {
        switch self {
        case .loggedOut: return "ログアウト状態"
        case .loggingIn: return "ログイン処理中"
        case .loginFailed(let reason): return "ログイン失敗: \(reason)"
        case .loggedIn(let user): return "ログイン済み: \(user)"
        }
    }
}

// ログインフローのイベント
enum AuthEvent: Hashable {
    case attemptLogin(username: String, password: String)
    case loginSucceeded(user: String)
    case loginFailed(reason: String)
    case logout
}

// 認証システムのKripke構造
struct AuthSystem: KripkeStructure {
    typealias State = AuthState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State> = [.loggedOut]
    
    var allStates: Set<State> {
        // 実際のアプリケーションでは、状態を動的に生成
        [.loggedOut, .loggingIn, .loginFailed(reason: "認証失敗"), .loggedIn(user: "user123")]
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .loggedOut:
            return [.loggedOut, .loggingIn]
            
        case .loggingIn:
            return [.loggingIn, .loggedIn(user: "user123"), .loginFailed(reason: "認証失敗")]
            
        case .loginFailed:
            return [.loginFailed(reason: "認証失敗"), .loggedOut, .loggingIn]
            
        case .loggedIn:
            return [.loggedIn(user: "user123"), .loggedOut]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .loggedOut:
            props.insert("isLoggedOut")
            
        case .loggingIn:
            props.insert("isLoggingIn")
            
        case .loginFailed(let reason):
            props.insert("isLoginFailed")
            props.insert("loginFailedReason_\(reason)")
            
        case .loggedIn(let user):
            props.insert("isLoggedIn")
            props.insert("loggedInUser_\(user)")
        }
        
        return props
    }
}

// 認証に関する命題
let isLoggedOut = TemporalKit.makeProposition(
    id: "isLoggedOut",
    name: "ユーザーがログアウト状態",
    evaluate: { (state: AuthState) -> Bool in
        if case .loggedOut = state { return true }
        return false
    }
)

let isLoggingIn = TemporalKit.makeProposition(
    id: "isLoggingIn",
    name: "ログイン処理中",
    evaluate: { (state: AuthState) -> Bool in
        if case .loggingIn = state { return true }
        return false
    }
)

let isLoginFailed = TemporalKit.makeProposition(
    id: "isLoginFailed",
    name: "ログイン失敗",
    evaluate: { (state: AuthState) -> Bool in
        if case .loginFailed = state { return true }
        return false
    }
)

let isLoggedIn = TemporalKit.makeProposition(
    id: "isLoggedIn",
    name: "ユーザーがログイン済み",
    evaluate: { (state: AuthState) -> Bool in
        if case .loggedIn = state { return true }
        return false
    }
)

// 認証フローに関するLTL式
typealias AuthProp = ClosureTemporalProposition<AuthState, Bool>
typealias AuthLTL = LTLFormula<AuthProp>

// プロパティ1: 「ログイン試行後、最終的にはログイン成功またはログイン失敗状態になる」
let loginEventuallyResolves = AuthLTL.implies(
    .atomic(isLoggingIn),
    .eventually(
        .or(
            .atomic(isLoggedIn),
            .atomic(isLoginFailed)
        )
    )
)

// プロパティ2: 「一度ログインすると、ログアウトするまではログイン状態が維持される」
let loginStateMaintained = AuthLTL.implies(
    .atomic(isLoggedIn),
    .until(
        .atomic(isLoggedIn),
        .atomic(isLoggedOut)
    )
)

// プロパティ3: 「ログイン失敗後は、再度ログインを試みるかログアウト状態に戻れる」
let canRetryAfterFailure = AuthLTL.implies(
    .atomic(isLoginFailed),
    .next(
        .or(
            .atomic(isLoggingIn),
            .atomic(isLoggedOut)
        )
    )
)

// 検証実行
let authSystem = AuthSystem()
let modelChecker = LTLModelChecker<AuthSystem>()

do {
    let result1 = try modelChecker.check(formula: loginEventuallyResolves, model: authSystem)
    let result2 = try modelChecker.check(formula: loginStateMaintained, model: authSystem)
    let result3 = try modelChecker.check(formula: canRetryAfterFailure, model: authSystem)
    
    print("認証フロー検証結果:")
    print("1. ログイン処理の解決: \(result1.holds ? "成立" : "不成立")")
    print("2. ログイン状態の維持: \(result2.holds ? "成立" : "不成立")")
    print("3. 失敗後のリトライ: \(result3.holds ? "成立" : "不成立")")
} catch {
    print("検証エラー: \(error)")
}
```

## 例2：ネットワークリクエストの状態管理

ネットワークリクエストのライフサイクルをTemporalKitで検証する例を見てみましょう。

```swift
import TemporalKit

// ネットワークリクエストの状態
enum NetworkRequestState: Hashable, CustomStringConvertible {
    case idle
    case loading
    case success(data: String)
    case failure(error: String)
    case cancelled
    
    var description: String {
        switch self {
        case .idle: return "アイドル状態"
        case .loading: return "読み込み中"
        case .success(let data): return "成功: \(data)"
        case .failure(let error): return "失敗: \(error)"
        case .cancelled: return "キャンセル済み"
        }
    }
}

// ネットワークリクエストのKripke構造
struct NetworkRequestSystem: KripkeStructure {
    typealias State = NetworkRequestState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State> = [.idle]
    
    var allStates: Set<State> {
        [.idle, .loading, .success(data: "レスポンスデータ"), .failure(error: "ネットワークエラー"), .cancelled]
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .idle:
            return [.idle, .loading]
            
        case .loading:
            return [.loading, .success(data: "レスポンスデータ"), .failure(error: "ネットワークエラー"), .cancelled]
            
        case .success:
            return [.success(data: "レスポンスデータ"), .idle]
            
        case .failure:
            return [.failure(error: "ネットワークエラー"), .idle, .loading]
            
        case .cancelled:
            return [.cancelled, .idle]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .idle:
            props.insert("isIdle")
            
        case .loading:
            props.insert("isLoading")
            
        case .success:
            props.insert("isSuccess")
            
        case .failure:
            props.insert("isFailure")
            
        case .cancelled:
            props.insert("isCancelled")
        }
        
        return props
    }
}

// ネットワークリクエストに関する命題
let isIdle = TemporalKit.makeProposition(
    id: "isIdle",
    name: "アイドル状態",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .idle = state { return true }
        return false
    }
)

let isLoading = TemporalKit.makeProposition(
    id: "isLoading",
    name: "読み込み中",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .loading = state { return true }
        return false
    }
)

let isSuccess = TemporalKit.makeProposition(
    id: "isSuccess",
    name: "成功",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .success = state { return true }
        return false
    }
)

let isFailure = TemporalKit.makeProposition(
    id: "isFailure",
    name: "失敗",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .failure = state { return true }
        return false
    }
)

let isCancelled = TemporalKit.makeProposition(
    id: "isCancelled",
    name: "キャンセル済み",
    evaluate: { (state: NetworkRequestState) -> Bool in
        if case .cancelled = state { return true }
        return false
    }
)

// ネットワークリクエストに関するLTL式
typealias NetworkProp = ClosureTemporalProposition<NetworkRequestState, Bool>
typealias NetworkLTL = LTLFormula<NetworkProp>

// プロパティ1: 「ローディング状態から、必ず成功・失敗・キャンセルのいずれかの状態に遷移する」
let loadingEventuallyCompletes = NetworkLTL.implies(
    .atomic(isLoading),
    .eventually(
        .or(
            .atomic(isSuccess),
            .atomic(isFailure),
            .atomic(isCancelled)
        )
    )
)

// プロパティ2: 「成功または失敗した後は、アイドル状態に戻ることができる」
let canRestartAfterCompletion = NetworkLTL.implies(
    .or(
        .atomic(isSuccess),
        .atomic(isFailure)
    ),
    .eventually(.atomic(isIdle))
)

// プロパティ3: 「リクエストは常にアイドル状態から開始される」
let alwaysStartsFromIdle = NetworkLTL.implies(
    .atomic(isLoading),
    .previously(.atomic(isIdle))
)

// 検証実行
let networkSystem = NetworkRequestSystem()
let networkModelChecker = LTLModelChecker<NetworkRequestSystem>()

do {
    let result1 = try networkModelChecker.check(formula: loadingEventuallyCompletes, model: networkSystem)
    let result2 = try networkModelChecker.check(formula: canRestartAfterCompletion, model: networkSystem)
    
    print("\nネットワークリクエスト検証結果:")
    print("1. ローディング状態の完了: \(result1.holds ? "成立" : "不成立")")
    print("2. 完了後の再開可能性: \(result2.holds ? "成立" : "不成立")")
} catch {
    print("検証エラー: \(error)")
}
```

## 例3：買い物カートのワークフロー

ECサイトの買い物カートの状態遷移を検証する例を見てみましょう。

```swift
import TemporalKit

// カートの状態
struct CartState: Hashable, CustomStringConvertible {
    let items: [String]
    let isCheckingOut: Bool
    let isPaymentProcessing: Bool
    let orderCompleted: Bool
    let hasError: Bool
    
    var description: String {
        let itemsDesc = items.isEmpty ? "空" : items.joined(separator: ", ")
        var stateDesc = "カート[\(itemsDesc)]"
        
        if isCheckingOut { stateDesc += ", チェックアウト中" }
        if isPaymentProcessing { stateDesc += ", 支払い処理中" }
        if orderCompleted { stateDesc += ", 注文完了" }
        if hasError { stateDesc += ", エラー発生" }
        
        return stateDesc
    }
}

// 買い物カートのKripke構造
struct ShoppingCartSystem: KripkeStructure {
    typealias State = CartState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State> = [CartState(
        items: [],
        isCheckingOut: false,
        isPaymentProcessing: false,
        orderCompleted: false,
        hasError: false
    )]
    
    var allStates: Set<State> {
        // 実際のアプリケーションでは、状態を動的に生成
        // ここでは簡略化のため、サンプルの状態を返す
        [
            CartState(items: [], isCheckingOut: false, isPaymentProcessing: false, orderCompleted: false, hasError: false),
            CartState(items: ["商品A"], isCheckingOut: false, isPaymentProcessing: false, orderCompleted: false, hasError: false),
            CartState(items: ["商品A"], isCheckingOut: true, isPaymentProcessing: false, orderCompleted: false, hasError: false),
            CartState(items: ["商品A"], isCheckingOut: true, isPaymentProcessing: true, orderCompleted: false, hasError: false),
            CartState(items: ["商品A"], isCheckingOut: false, isPaymentProcessing: false, orderCompleted: true, hasError: false),
            CartState(items: ["商品A"], isCheckingOut: false, isPaymentProcessing: false, orderCompleted: false, hasError: true)
        ]
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // 商品の追加（最大2つまで）
        if state.items.count < 2 && !state.isCheckingOut && !state.isPaymentProcessing && !state.orderCompleted {
            var newItems = state.items
            newItems.append("新商品")
            nextStates.insert(CartState(
                items: newItems,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // 商品の削除
        if !state.items.isEmpty && !state.isCheckingOut && !state.isPaymentProcessing && !state.orderCompleted {
            var newItems = state.items
            newItems.removeLast()
            nextStates.insert(CartState(
                items: newItems,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // チェックアウト開始
        if !state.items.isEmpty && !state.isCheckingOut && !state.isPaymentProcessing && !state.orderCompleted && !state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: true,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // 支払い処理開始
        if state.isCheckingOut && !state.isPaymentProcessing && !state.orderCompleted && !state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: true,
                isPaymentProcessing: true,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // 注文完了
        if state.isPaymentProcessing && !state.orderCompleted && !state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: true,
                hasError: false
            ))
        }
        
        // エラー発生
        if (state.isCheckingOut || state.isPaymentProcessing) && !state.orderCompleted && !state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: true
            ))
        }
        
        // エラーリセット
        if state.hasError {
            nextStates.insert(CartState(
                items: state.items,
                isCheckingOut: false,
                isPaymentProcessing: false,
                orderCompleted: false,
                hasError: false
            ))
        }
        
        // 現在の状態も遷移先に含める
        nextStates.insert(state)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        if state.items.isEmpty {
            props.insert("cartEmpty")
        } else {
            props.insert("hasItems")
        }
        
        if state.isCheckingOut {
            props.insert("isCheckingOut")
        }
        
        if state.isPaymentProcessing {
            props.insert("isPaymentProcessing")
        }
        
        if state.orderCompleted {
            props.insert("orderCompleted")
        }
        
        if state.hasError {
            props.insert("hasError")
        }
        
        return props
    }
}

// カートに関する命題
let cartEmpty = TemporalKit.makeProposition(
    id: "cartEmpty",
    name: "カートが空",
    evaluate: { (state: CartState) -> Bool in
        state.items.isEmpty
    }
)

let hasItems = TemporalKit.makeProposition(
    id: "hasItems",
    name: "カートに商品あり",
    evaluate: { (state: CartState) -> Bool in
        !state.items.isEmpty
    }
)

let isCheckingOut = TemporalKit.makeProposition(
    id: "isCheckingOut",
    name: "チェックアウト中",
    evaluate: { (state: CartState) -> Bool in
        state.isCheckingOut
    }
)

let isPaymentProcessing = TemporalKit.makeProposition(
    id: "isPaymentProcessing",
    name: "支払い処理中",
    evaluate: { (state: CartState) -> Bool in
        state.isPaymentProcessing
    }
)

let orderCompleted = TemporalKit.makeProposition(
    id: "orderCompleted",
    name: "注文完了",
    evaluate: { (state: CartState) -> Bool in
        state.orderCompleted
    }
)

let hasError = TemporalKit.makeProposition(
    id: "hasError",
    name: "エラー発生",
    evaluate: { (state: CartState) -> Bool in
        state.hasError
    }
)

// カートに関するLTL式
typealias CartProp = ClosureTemporalProposition<CartState, Bool>
typealias CartLTL = LTLFormula<CartProp>

// プロパティ1: 「支払い処理を開始するには、必ずチェックアウト状態を経由する」
let paymentRequiresCheckout = CartLTL.implies(
    .atomic(isPaymentProcessing),
    .previously(.atomic(isCheckingOut))
)

// プロパティ2: 「注文完了するには、必ず支払い処理を経由する」
let orderRequiresPayment = CartLTL.implies(
    .atomic(orderCompleted),
    .previously(.atomic(isPaymentProcessing))
)

// プロパティ3: 「エラーが発生した場合、再度チェックアウトを行える」
let canRecoverFromError = CartLTL.implies(
    .atomic(hasError),
    .eventually(.atomic(isCheckingOut))
)

// プロパティ4: 「空のカートでは、チェックアウトできない」
let emptyCartCannotCheckout = CartLTL.implies(
    .atomic(cartEmpty),
    .globally(.not(.atomic(isCheckingOut)))
)

// 検証実行
let cartSystem = ShoppingCartSystem()
let cartModelChecker = LTLModelChecker<ShoppingCartSystem>()

do {
    let result1 = try cartModelChecker.check(formula: paymentRequiresCheckout, model: cartSystem)
    let result2 = try cartModelChecker.check(formula: orderRequiresPayment, model: cartSystem)
    let result3 = try cartModelChecker.check(formula: canRecoverFromError, model: cartSystem)
    let result4 = try cartModelChecker.check(formula: emptyCartCannotCheckout, model: cartSystem)
    
    print("\n買い物カート検証結果:")
    print("1. 支払いにはチェックアウトが必要: \(result1.holds ? "成立" : "不成立")")
    print("2. 注文完了には支払いが必要: \(result2.holds ? "成立" : "不成立")")
    print("3. エラーからの回復: \(result3.holds ? "成立" : "不成立")")
    print("4. 空カートのチェックアウト禁止: \(result4.holds ? "成立" : "不成立")")
} catch {
    print("検証エラー: \(error)")
}
```

## 例4：プッシュ通知の権限フロー

プッシュ通知の権限リクエストフローを検証する例を見てみましょう。

```swift
import TemporalKit

// 通知権限の状態
enum NotificationPermissionState: Hashable, CustomStringConvertible {
    case notRequested
    case requesting
    case allowed
    case denied
    
    var description: String {
        switch self {
        case .notRequested: return "未リクエスト"
        case .requesting: return "リクエスト中"
        case .allowed: return "許可"
        case .denied: return "拒否"
        }
    }
}

// 通知権限フローのKripke構造
struct NotificationPermissionSystem: KripkeStructure {
    typealias State = NotificationPermissionState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State> = [.notRequested]
    
    var allStates: Set<State> {
        [.notRequested, .requesting, .allowed, .denied]
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .notRequested:
            return [.notRequested, .requesting]
            
        case .requesting:
            return [.requesting, .allowed, .denied]
            
        case .allowed, .denied:
            // 権限が一度決定されたら変更不可（システム設定画面は考慮外）
            return [state]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .notRequested:
            props.insert("notRequested")
            
        case .requesting:
            props.insert("requesting")
            
        case .allowed:
            props.insert("allowed")
            
        case .denied:
            props.insert("denied")
        }
        
        return props
    }
}

// 通知権限に関する命題
let notRequested = TemporalKit.makeProposition(
    id: "notRequested",
    name: "権限未リクエスト",
    evaluate: { (state: NotificationPermissionState) -> Bool in
        state == .notRequested
    }
)

let requesting = TemporalKit.makeProposition(
    id: "requesting",
    name: "権限リクエスト中",
    evaluate: { (state: NotificationPermissionState) -> Bool in
        state == .requesting
    }
)

let allowed = TemporalKit.makeProposition(
    id: "allowed",
    name: "権限許可",
    evaluate: { (state: NotificationPermissionState) -> Bool in
        state == .allowed
    }
)

let denied = TemporalKit.makeProposition(
    id: "denied",
    name: "権限拒否",
    evaluate: { (state: NotificationPermissionState) -> Bool in
        state == .denied
    }
)

// 通知権限に関するLTL式
typealias PermissionProp = ClosureTemporalProposition<NotificationPermissionState, Bool>
typealias PermissionLTL = LTLFormula<PermissionProp>

// プロパティ1: 「権限リクエストは未リクエスト状態からのみ開始できる」
let requestOnlyFromNotRequested = PermissionLTL.implies(
    .atomic(requesting),
    .previously(.atomic(notRequested))
)

// プロパティ2: 「リクエスト中の状態からは、必ず許可または拒否の状態になる」
let requestEventuallyResolves = PermissionLTL.implies(
    .atomic(requesting),
    .eventually(
        .or(
            .atomic(allowed),
            .atomic(denied)
        )
    )
)

// プロパティ3: 「一度許可または拒否の状態になると、その状態は永続する」
let permissionStateIsPersistent = PermissionLTL.implies(
    .or(
        .atomic(allowed),
        .atomic(denied)
    ),
    .globally(
        .or(
            .atomic(allowed),
            .atomic(denied)
        )
    )
)

// 検証実行
let permissionSystem = NotificationPermissionSystem()
let permissionModelChecker = LTLModelChecker<NotificationPermissionSystem>()

do {
    let result1 = try permissionModelChecker.check(formula: requestOnlyFromNotRequested, model: permissionSystem)
    let result2 = try permissionModelChecker.check(formula: requestEventuallyResolves, model: permissionSystem)
    let result3 = try permissionModelChecker.check(formula: permissionStateIsPersistent, model: permissionSystem)
    
    print("\n通知権限フロー検証結果:")
    print("1. リクエスト開始条件: \(result1.holds ? "成立" : "不成立")")
    print("2. リクエスト解決の保証: \(result2.holds ? "成立" : "不成立")")
    print("3. 権限状態の永続性: \(result3.holds ? "成立" : "不成立")")
} catch {
    print("検証エラー: \(error)")
}
```

## まとめ

このチュートリアルでは、TemporalKitを実際のユースケースに適用する方法を見てきました。具体的には以下の例を通じて学びました：

1. ユーザー認証フローの検証 - ログイン状態の遷移と維持の検証
2. ネットワークリクエストの状態管理 - 非同期処理の完了保証
3. 買い物カートのワークフロー - ECサイトの注文プロセスの検証
4. プッシュ通知の権限フロー - 権限リクエストと結果の検証

これらの例から、TemporalKitが様々なアプリケーションドメインで活用できることがわかります。特に以下のような場面で効果的です：

- ユーザーインターフェースの状態遷移
- 非同期処理のライフサイクル管理
- 複雑なビジネスロジックの検証
- 権限や認証などのセキュリティフロー

形式的検証を開発プロセスに組み込むことで、テストだけでは発見しにくいエッジケースやロジックの誤りを早期に発見し、より堅牢なアプリケーションを構築することができます。

## 次のステップ

- [パフォーマンスの最適化](./OptimizingPerformance.md)で、大規模なモデルの検証をより効率的に行う方法を学びましょう。
- [テストとの統合](./IntegratingWithTests.md)で、CIパイプラインにTemporalKitの検証を組み込む方法を学びましょう。 
