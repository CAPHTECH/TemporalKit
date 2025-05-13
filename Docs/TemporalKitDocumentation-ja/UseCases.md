# TemporalKit ユースケース

TemporalKitは様々なiOSアプリケーション開発シナリオで活用できます。このドキュメントでは、一般的なユースケースとその実装例を紹介します。

## 目次

- [アプリケーション状態管理](#アプリケーション状態管理)
- [ユーザーフロー検証](#ユーザーフロー検証)
- [SwiftUI状態マシン検証](#swiftui状態マシン検証)
- [ネットワーク層の信頼性](#ネットワーク層の信頼性)
- [並行処理と非同期操作](#並行処理と非同期操作)
- [アニメーションと遷移シーケンス](#アニメーションと遷移シーケンス)
- [エラー処理パス](#エラー処理パス)
- [セキュリティプロパティ](#セキュリティプロパティ)

## アプリケーション状態管理

iOSアプリは複雑な状態遷移を持つことが多く、すべての状態遷移が有効であること、およびシステムが異常な状態に陥らないことを検証することが重要です。

### 例: 認証状態の検証

```swift
// アプリの認証状態を定義
enum AuthState: Hashable {
    case loggedOut
    case loggingIn
    case loggedIn
    case authError
    case refreshingToken
}

// 認証サブシステムをクリプケ構造としてモデル化
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

// 検証すべきプロパティ:
// 1. 認証エラーは常にログイン画面またはログアウト状態に戻るべき
// 2. 遷移状態は常に最終的に安定状態に至るべき
// 3. ユーザーは認証済み状態から常にログアウトできるべき
```

## ユーザーフロー検証

オンボーディング、登録、チェックアウトなどの複雑なユーザーフローを検証します。

### 例: オンボーディングフローの検証

```swift
// オンボーディングの状態を定義
enum OnboardingState: Hashable {
    case welcome
    case permissions
    case accountCreation
    case profileSetup
    case tutorial
    case complete
    case skipped
}

// オンボーディングモデルを実装
struct OnboardingModel: KripkeStructure {
    typealias State = OnboardingState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.welcome]
    let allStates: Set<State> = [.welcome, .permissions, .accountCreation, 
                                .profileSetup, .tutorial, .complete, .skipped]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .welcome:
            return [.permissions, .skipped]
        case .permissions:
            return [.accountCreation, .skipped]
        case .accountCreation:
            return [.profileSetup, .skipped]
        case .profileSetup:
            return [.tutorial, .complete, .skipped]
        case .tutorial:
            return [.complete]
        case .complete, .skipped:
            return [] // 終了状態
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .welcome:
            return ["isWelcome"]
        case .permissions:
            return ["isPermissions"]
        case .accountCreation:
            return ["isCreatingAccount"]
        case .profileSetup:
            return ["isSettingUpProfile"]
        case .tutorial:
            return ["isTutorial"]
        case .complete:
            return ["isComplete"]
        case .skipped:
            return ["isSkipped"]
        }
    }
}

// 検証すべきプロパティ:
// 1. ユーザーは常にフローをスキップできる
// 2. 完了状態に達するには、権限画面を通過する必要がある
// 3. スキップ状態からは他の状態に遷移できない
```

## SwiftUI状態マシン検証

SwiftUIのViewは、状態に基づいて表示が変わる状態マシンとして考えることができます。これらの状態遷移が正しいことを検証します。

### 例: データロード状態の検証

```swift
// SwiftUIビューの状態を定義
enum ViewState: Hashable {
    case initial
    case loading
    case loaded(Data)
    case empty
    case error(Error)
}

// エラー型をHashableにするためのラッパー
struct ViewError: Hashable, Error {
    let message: String
    
    static func == (lhs: ViewError, rhs: ViewError) -> Bool {
        lhs.message == rhs.message
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(message)
    }
}

// Data型をHashableにするためのラッパー
struct ViewData: Hashable {
    let id: UUID
    let content: String
    
    static func == (lhs: ViewData, rhs: ViewData) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// ビュー状態モデルを実装
struct ViewStateModel: KripkeStructure {
    typealias State = ViewState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.initial]
    let allStates: Set<State>
    
    init() {
        var states: Set<State> = [.initial, .loading, .empty]
        
        // サンプルデータとエラーを追加
        let sampleData = ViewData(id: UUID(), content: "Sample")
        let sampleError = ViewError(message: "Network error")
        
        states.insert(.loaded(sampleData))
        states.insert(.error(sampleError))
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        let sampleData = ViewData(id: UUID(), content: "Sample")
        let sampleError = ViewError(message: "Network error")
        
        switch state {
        case .initial:
            return [.loading]
        case .loading:
            return [.loaded(sampleData), .empty, .error(sampleError)]
        case .loaded:
            return [.loading, .initial]
        case .empty:
            return [.loading, .initial]
        case .error:
            return [.loading, .initial]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .initial:
            return ["isInitial"]
        case .loading:
            return ["isLoading"]
        case .loaded:
            return ["isLoaded", "hasData"]
        case .empty:
            return ["isLoaded", "isEmpty"]
        case .error:
            return ["hasError"]
        }
    }
}

// 検証すべきプロパティ:
// 1. ローディング状態は必ず終了する
// 2. エラー状態からは必ずリトライできる
// 3. 初期状態に戻るパスが常に存在する
```

## ネットワーク層の信頼性

ネットワーク操作、リトライロジック、オフライン動作、キャッシュ戦略を検証します。

### 例: リトライとキャッシュのある要求

```swift
// ネットワークリクエストの状態を定義
enum NetworkRequestState: Hashable {
    case initial
    case checkingCache
    case usingCachedData
    case fetching
    case retrying(attempt: Int)
    case succeeded
    case failed
}

// リクエスト状態モデルを実装
struct NetworkRequestModel: KripkeStructure {
    typealias State = NetworkRequestState
    typealias AtomicPropositionIdentifier = String
    
    let maxRetries = 3
    
    let initialStates: Set<State> = [.initial]
    var allStates: Set<State> {
        var states: Set<State> = [.initial, .checkingCache, .usingCachedData, 
                                 .fetching, .succeeded, .failed]
        
        // リトライ状態を追加
        for attempt in 1...maxRetries {
            states.insert(.retrying(attempt: attempt))
        }
        
        return states
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .initial:
            return [.checkingCache]
        case .checkingCache:
            return [.usingCachedData, .fetching]
        case .usingCachedData:
            return [.initial, .fetching]
        case .fetching:
            return [.succeeded, .retrying(attempt: 1), .failed]
        case .retrying(let attempt):
            if attempt < maxRetries {
                return [.succeeded, .retrying(attempt: attempt + 1), .failed]
            } else {
                return [.succeeded, .failed]
            }
        case .succeeded, .failed:
            return [.initial]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .initial:
            return ["isInitial"]
        case .checkingCache:
            return ["isCheckingCache"]
        case .usingCachedData:
            return ["isUsingCache", "hasData"]
        case .fetching:
            return ["isFetching"]
        case .retrying:
            return ["isRetrying", "isFetching"]
        case .succeeded:
            return ["isSucceeded", "hasData"]
        case .failed:
            return ["isFailed"]
        }
    }
}

// 検証すべきプロパティ:
// 1. 全てのリクエストは最終的に成功または失敗する
// 2. リトライの回数は有限である
// 3. キャッシュデータが利用可能なときは使用される
// 4. 失敗後は常に再試行可能である
```

## 並行処理と非同期操作

非同期操作や並行処理に関連する問題（デッドロック、レースコンディション）を検証します。

### 例: 非同期タスクの検証

```swift
// 非同期操作の状態を定義
enum AsyncOperationState: Hashable {
    case idle
    case pendingPrerequisites
    case inProgress(completion: Double)
    case paused
    case cancelled
    case completed
    case failed(reason: String)
}

// 非同期操作モデルを実装
struct AsyncOperationModel: KripkeStructure {
    typealias State = AsyncOperationState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.idle]
    var allStates: Set<State> {
        var states: Set<State> = [.idle, .pendingPrerequisites, .paused, 
                                 .cancelled, .completed]
        
        // 進行状態を追加
        states.insert(.inProgress(completion: 0.0))
        states.insert(.inProgress(completion: 0.5))
        states.insert(.inProgress(completion: 1.0))
        
        // 失敗状態を追加
        states.insert(.failed(reason: "Network error"))
        states.insert(.failed(reason: "Timeout"))
        
        return states
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .idle:
            return [.pendingPrerequisites, .inProgress(completion: 0.0)]
        case .pendingPrerequisites:
            return [.inProgress(completion: 0.0), .cancelled, .failed(reason: "Prerequisite failed")]
        case .inProgress(let completion):
            var nextStates: Set<State> = [.paused, .cancelled]
            
            if completion < 0.5 {
                nextStates.insert(.inProgress(completion: 0.5))
            } else if completion < 1.0 {
                nextStates.insert(.inProgress(completion: 1.0))
            } else {
                nextStates.insert(.completed)
            }
            
            nextStates.insert(.failed(reason: "Error during execution"))
            
            return nextStates
        case .paused:
            return [.inProgress(completion: 0.5), .cancelled]
        case .cancelled, .completed, .failed:
            return [.idle]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .idle:
            return ["isIdle"]
        case .pendingPrerequisites:
            return ["isPending"]
        case .inProgress(let completion):
            if completion >= 1.0 {
                return ["isInProgress", "isComplete"]
            } else {
                return ["isInProgress"]
            }
        case .paused:
            return ["isPaused"]
        case .cancelled:
            return ["isCancelled"]
        case .completed:
            return ["isCompleted"]
        case .failed:
            return ["isFailed"]
        }
    }
}

// 検証すべきプロパティ:
// 1. キャンセルされた操作は完了状態に到達しない
// 2. 進行中の操作は必ず最終状態に達する
// 3. 一時停止された操作は再開または取り消すことができる
// 4. 失敗した操作は再試行できる
```

## アニメーションと遷移シーケンス

ユーザーインターフェースのアニメーションと遷移が正しい順序で実行されることを検証します。

### 例: 画面遷移アニメーション

```swift
// 画面遷移アニメーションの状態を定義
enum AnimationState: Hashable {
    case idle
    case fadeOutBegin
    case fadeOutComplete
    case transitionBegin
    case transitionComplete
    case fadeInBegin
    case fadeInComplete
}

// アニメーション状態モデルを実装
struct AnimationSequenceModel: KripkeStructure {
    typealias State = AnimationState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.idle]
    let allStates: Set<State> = [.idle, .fadeOutBegin, .fadeOutComplete, 
                                .transitionBegin, .transitionComplete,
                                .fadeInBegin, .fadeInComplete]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .idle:
            return [.fadeOutBegin]
        case .fadeOutBegin:
            return [.fadeOutComplete]
        case .fadeOutComplete:
            return [.transitionBegin]
        case .transitionBegin:
            return [.transitionComplete]
        case .transitionComplete:
            return [.fadeInBegin]
        case .fadeInBegin:
            return [.fadeInComplete]
        case .fadeInComplete:
            return [.idle]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .idle:
            return ["isIdle"]
        case .fadeOutBegin:
            return ["isFadingOut", "isAnimating"]
        case .fadeOutComplete:
            return ["isFadedOut", "isAnimating"]
        case .transitionBegin:
            return ["isTransitioning", "isAnimating"]
        case .transitionComplete:
            return ["isTransitioned", "isAnimating"]
        case .fadeInBegin:
            return ["isFadingIn", "isAnimating"]
        case .fadeInComplete:
            return ["isFadedIn", "isAnimating"]
        }
    }
}

// 検証すべきプロパティ:
// 1. アニメーションシーケンスは常に正しい順序で実行される
// 2. どのアニメーション状態からも最終的にidle状態に戻る
// 3. 遷移はフェードアウトが完了した後にのみ開始される
```

## エラー処理パス

アプリケーション内のすべてのエラー状態が適切に処理され、ユーザーが常に回復できることを検証します。

### 例: フォーム送信とエラー処理

```swift
// フォーム送信の状態を定義
enum FormSubmissionState: Hashable {
    case editing
    case validating
    case submitting
    case success
    case error(FormError)
}

// フォームエラーを定義
enum FormError: Hashable {
    case validation(field: String)
    case network
    case server
    case timeout
}

// フォーム送信モデルを実装
struct FormSubmissionModel: KripkeStructure {
    typealias State = FormSubmissionState
    typealias AtomicPropositionIdentifier = String
    
    let initialStates: Set<State> = [.editing]
    var allStates: Set<State> {
        var states: Set<State> = [.editing, .validating, .submitting, .success]
        
        // エラー状態を追加
        states.insert(.error(.validation(field: "email")))
        states.insert(.error(.validation(field: "password")))
        states.insert(.error(.network))
        states.insert(.error(.server))
        states.insert(.error(.timeout))
        
        return states
    }
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .editing:
            return [.validating]
        case .validating:
            return [.submitting, .error(.validation(field: "email")), 
                   .error(.validation(field: "password"))]
        case .submitting:
            return [.success, .error(.network), .error(.server), .error(.timeout)]
        case .success:
            return [.editing]
        case .error(let errorType):
            switch errorType {
            case .validation:
                return [.editing, .validating]
            case .network, .timeout:
                return [.editing, .submitting]
            case .server:
                return [.editing]
            }
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .editing:
            return ["isEditing"]
        case .validating:
            return ["isValidating"]
        case .submitting:
            return ["isSubmitting"]
        case .success:
            return ["isSuccess"]
        case .error(let errorType):
            switch errorType {
            case .validation(let field):
                return ["hasError", "hasValidationError", "field_\(field)"]
            case .network:
                return ["hasError", "hasNetworkError"]
            case .server:
                return ["hasError", "hasServerError"]
            case .timeout:
                return ["hasError", "hasTimeoutError"]
            }
        }
    }
}

// 検証すべきプロパティ:
// 1. すべてのエラー状態から回復可能である
// 2. バリデーションエラーは編集状態に戻れる
// 3. ネットワークエラーは再送信できる
// 4. 成功後は新しいフォームの編集を開始できる
```

## セキュリティプロパティ

認証、認可、データアクセスなどのセキュリティ関連プロパティを検証します。

### 例: アクセス制御の検証

```swift
// ユーザータイプを定義
enum UserType: Hashable {
    case anonymous
    case regular
    case premium
    case admin
}

// リソースと操作を定義
enum Resource: Hashable {
    case publicContent
    case basicFeature
    case premiumFeature
    case adminPanel
}

enum Operation: Hashable {
    case read
    case create
    case update
    case delete
    case configure
}

// アクセス制御の状態を定義
struct AccessControlState: Hashable {
    let userType: UserType
    let resource: Resource
    let operation: Operation
    let isPermitted: Bool
}

// アクセス制御モデルを実装
struct AccessControlModel: KripkeStructure {
    typealias State = AccessControlState
    typealias AtomicPropositionIdentifier = String
    
    let allUserTypes: [UserType] = [.anonymous, .regular, .premium, .admin]
    let allResources: [Resource] = [.publicContent, .basicFeature, .premiumFeature, .adminPanel]
    let allOperations: [Operation] = [.read, .create, .update, .delete, .configure]
    
    var initialStates: Set<State> {
        // 任意の初期状態を設定
        let sampleState = AccessControlState(
            userType: .anonymous,
            resource: .publicContent,
            operation: .read,
            isPermitted: true
        )
        return [sampleState]
    }
    
    var allStates: Set<State> {
        var states = Set<State>()
        
        for userType in allUserTypes {
            for resource in allResources {
                for operation in allOperations {
                    // 許可ポリシーに基づいて許可状態を設定
                    let isPermitted = isOperationPermitted(
                        userType: userType,
                        resource: resource,
                        operation: operation
                    )
                    
                    let state = AccessControlState(
                        userType: userType,
                        resource: resource,
                        operation: operation,
                        isPermitted: isPermitted
                    )
                    
                    states.insert(state)
                }
            }
        }
        
        return states
    }
    
    func successors(of state: State) -> Set<State> {
        // このモデルでは、すべての状態は独立しており、
        // 一方の状態から別の状態への遷移は許可ポリシーに基づく
        
        var successorStates = Set<State>()
        
        // ユーザータイプの変更（アップグレード、ダウングレード）
        for newUserType in allUserTypes {
            if newUserType != state.userType {
                let isPermitted = isOperationPermitted(
                    userType: newUserType,
                    resource: state.resource,
                    operation: state.operation
                )
                
                let newState = AccessControlState(
                    userType: newUserType,
                    resource: state.resource,
                    operation: state.operation,
                    isPermitted: isPermitted
                )
                
                successorStates.insert(newState)
            }
        }
        
        // リソースの変更
        for newResource in allResources {
            if newResource != state.resource {
                let isPermitted = isOperationPermitted(
                    userType: state.userType,
                    resource: newResource,
                    operation: state.operation
                )
                
                let newState = AccessControlState(
                    userType: state.userType,
                    resource: newResource,
                    operation: state.operation,
                    isPermitted: isPermitted
                )
                
                successorStates.insert(newState)
            }
        }
        
        // 操作の変更
        for newOperation in allOperations {
            if newOperation != state.operation {
                let isPermitted = isOperationPermitted(
                    userType: state.userType,
                    resource: state.resource,
                    operation: newOperation
                )
                
                let newState = AccessControlState(
                    userType: state.userType,
                    resource: state.resource,
                    operation: newOperation,
                    isPermitted: isPermitted
                )
                
                successorStates.insert(newState)
            }
        }
        
        return successorStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        // ユーザータイプに関する命題
        switch state.userType {
        case .anonymous:
            props.insert("isAnonymous")
        case .regular:
            props.insert("isRegularUser")
        case .premium:
            props.insert("isPremiumUser")
        case .admin:
            props.insert("isAdmin")
        }
        
        // リソースに関する命題
        switch state.resource {
        case .publicContent:
            props.insert("isPublicContent")
        case .basicFeature:
            props.insert("isBasicFeature")
        case .premiumFeature:
            props.insert("isPremiumFeature")
        case .adminPanel:
            props.insert("isAdminPanel")
        }
        
        // 操作に関する命題
        switch state.operation {
        case .read:
            props.insert("isReadOperation")
        case .create:
            props.insert("isCreateOperation")
        case .update:
            props.insert("isUpdateOperation")
        case .delete:
            props.insert("isDeleteOperation")
        case .configure:
            props.insert("isConfigureOperation")
        }
        
        // 許可状態に関する命題
        if state.isPermitted {
            props.insert("isPermitted")
        } else {
            props.insert("isDenied")
        }
        
        return props
    }
    
    // アクセス制御ポリシーを実装
    private func isOperationPermitted(userType: UserType, resource: Resource, operation: Operation) -> Bool {
        switch (userType, resource, operation) {
        case (_, .publicContent, .read):
            // 公開コンテンツは誰でも読める
            return true
            
        case (.anonymous, _, _):
            // 匿名ユーザーは公開コンテンツの読み取りのみ
            return false
            
        case (.regular, .basicFeature, _),
             (.regular, .publicContent, _):
            // 一般ユーザーは基本機能と公開コンテンツにアクセス可能
            return operation != .configure
            
        case (.premium, .premiumFeature, _),
             (.premium, .basicFeature, _),
             (.premium, .publicContent, _):
            // プレミアムユーザーはプレミアム機能、基本機能、公開コンテンツにアクセス可能
            return operation != .configure
            
        case (.admin, _, _):
            // 管理者はすべてのリソースにアクセス可能
            return true
            
        default:
            return false
        }
    }
}

// 検証すべきプロパティ:
// 1. 匿名ユーザーは公開コンテンツのみ読み取り可能
// 2. 管理者パネルには管理者のみアクセス可能
// 3. 設定操作は管理者のみ許可される
// 4. ユーザータイプのエスカレーションによる権限昇格はできない
```

これらのユースケースは、TemporalKitを使用してiOSアプリケーションで形式的検証を実装する方法を示しています。アプリケーションの具体的なニーズに合わせて、これらのパターンを適応または拡張することができます。 
