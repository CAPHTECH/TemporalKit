# リアクティブシステムの検証

このチュートリアルでは、TemporalKitを使用してリアクティブシステムの検証を行う方法を学びます。リアクティブシステムとは、外部からの入力やイベントに継続的に応答するシステムであり、UIアプリケーション、サーバー、IoTデバイスなど多岐にわたります。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- リアクティブシステムをKripke構造としてモデル化する
- イベント駆動型の振る舞いを時相論理式で表現する
- 非同期処理や競合状態を検出する
- リアクティブシステムの応答性や安全性を検証する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること
- [高度なLTL式](./AdvancedLTLFormulas.md)のチュートリアルを完了していること

## ステップ1: リアクティブシステムの構造

まず、典型的なリアクティブシステムの構造と特徴について理解しましょう。

```swift
import TemporalKit

// リアクティブシステムの例として、シンプルなUIコントローラーを考える
enum UserAction {
    case tap
    case swipe
    case longPress
    case none
}

enum ViewState {
    case normal
    case highlighted
    case selected
    case disabled
}

enum BackgroundTask {
    case idle
    case loading
    case processing
    case error
}

// リアクティブUIコントローラの状態
struct ReactiveUIState: Hashable, CustomStringConvertible {
    let viewState: ViewState
    let backgroundTask: BackgroundTask
    let lastUserAction: UserAction
    
    var description: String {
        return "UIState(view: \(viewState), background: \(backgroundTask), lastAction: \(lastUserAction))"
    }
}
```

## ステップ2: リアクティブシステムのKripke構造モデル

リアクティブシステムをKripke構造としてモデル化します。

```swift
// リアクティブUIコントローラのKripke構造
struct ReactiveUIModel: KripkeStructure {
    typealias State = ReactiveUIState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init() {
        // 初期状態
        let initialState = ReactiveUIState(
            viewState: .normal,
            backgroundTask: .idle,
            lastUserAction: .none
        )
        
        self.initialStates = [initialState]
        
        // 可能なすべての状態の組み合わせを生成
        var states = Set<State>()
        
        for viewState in [ViewState.normal, .highlighted, .selected, .disabled] {
            for backgroundTask in [BackgroundTask.idle, .loading, .processing, .error] {
                for userAction in [UserAction.none, .tap, .swipe, .longPress] {
                    states.insert(ReactiveUIState(
                        viewState: viewState,
                        backgroundTask: backgroundTask,
                        lastUserAction: userAction
                    ))
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // 現在の状態に基づいて可能な次の状態をモデル化
        
        // 1. ユーザーアクションの遷移
        for newAction in [UserAction.none, .tap, .swipe, .longPress] {
            // タップによる状態変化
            if newAction == .tap {
                // タップの効果はビューの状態に依存
                switch state.viewState {
                case .normal:
                    // 通常状態でタップすると強調表示される
                    nextStates.insert(ReactiveUIState(
                        viewState: .highlighted,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .tap
                    ))
                    
                case .highlighted:
                    // 強調表示状態でタップすると選択される
                    nextStates.insert(ReactiveUIState(
                        viewState: .selected,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .tap
                    ))
                    
                case .selected:
                    // 選択状態でタップすると通常状態に戻る
                    nextStates.insert(ReactiveUIState(
                        viewState: .normal,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .tap
                    ))
                    
                case .disabled:
                    // 無効状態ではタップは効果がない
                    nextStates.insert(ReactiveUIState(
                        viewState: .disabled,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .tap
                    ))
                }
                
                // タップが読み込みを開始する場合
                if state.backgroundTask == .idle {
                    nextStates.insert(ReactiveUIState(
                        viewState: state.viewState,
                        backgroundTask: .loading,
                        lastUserAction: .tap
                    ))
                }
            }
            
            // スワイプによる状態変化
            else if newAction == .swipe {
                // スワイプはビューの状態を通常に戻す
                nextStates.insert(ReactiveUIState(
                    viewState: .normal,
                    backgroundTask: state.backgroundTask,
                    lastUserAction: .swipe
                ))
            }
            
            // 長押しによる状態変化
            else if newAction == .longPress {
                // 長押しは無効状態と通常状態を切り替える
                if state.viewState == .disabled {
                    nextStates.insert(ReactiveUIState(
                        viewState: .normal,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .longPress
                    ))
                } else {
                    nextStates.insert(ReactiveUIState(
                        viewState: .disabled,
                        backgroundTask: state.backgroundTask,
                        lastUserAction: .longPress
                    ))
                }
            }
        }
        
        // 2. バックグラウンドタスクの遷移
        switch state.backgroundTask {
        case .idle:
            // アイドル状態は変化なし
            break
            
        case .loading:
            // 読み込みは処理状態またはエラー状態に進む
            nextStates.insert(ReactiveUIState(
                viewState: state.viewState,
                backgroundTask: .processing,
                lastUserAction: state.lastUserAction
            ))
            
            nextStates.insert(ReactiveUIState(
                viewState: state.viewState,
                backgroundTask: .error,
                lastUserAction: state.lastUserAction
            ))
            
        case .processing:
            // 処理はアイドル状態に戻る
            nextStates.insert(ReactiveUIState(
                viewState: state.viewState,
                backgroundTask: .idle,
                lastUserAction: state.lastUserAction
            ))
            
        case .error:
            // エラーはアイドル状態に戻る
            nextStates.insert(ReactiveUIState(
                viewState: state.viewState,
                backgroundTask: .idle,
                lastUserAction: state.lastUserAction
            ))
        }
        
        // エラー状態ではUIを無効化する可能性
        if state.backgroundTask == .error {
            nextStates.insert(ReactiveUIState(
                viewState: .disabled,
                backgroundTask: state.backgroundTask,
                lastUserAction: state.lastUserAction
            ))
        }
        
        // 現在の状態も後続状態に含める（何も変化しない可能性もある）
        nextStates.insert(state)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // ビュー状態に関する命題
        switch state.viewState {
        case .normal:
            trueProps.insert(isNormal.id)
        case .highlighted:
            trueProps.insert(isHighlighted.id)
        case .selected:
            trueProps.insert(isSelected.id)
        case .disabled:
            trueProps.insert(isDisabled.id)
        }
        
        // バックグラウンドタスクに関する命題
        switch state.backgroundTask {
        case .idle:
            trueProps.insert(isIdle.id)
        case .loading:
            trueProps.insert(isLoading.id)
        case .processing:
            trueProps.insert(isProcessing.id)
        case .error:
            trueProps.insert(isError.id)
        }
        
        // ユーザーアクションに関する命題
        switch state.lastUserAction {
        case .none:
            trueProps.insert(noAction.id)
        case .tap:
            trueProps.insert(wasTapped.id)
        case .swipe:
            trueProps.insert(wasSwiped.id)
        case .longPress:
            trueProps.insert(wasLongPressed.id)
        }
        
        // 複合状態に関する命題
        if state.backgroundTask == .loading || state.backgroundTask == .processing {
            trueProps.insert(isBusy.id)
        }
        
        if state.viewState == .disabled || state.backgroundTask == .error {
            trueProps.insert(hasIssue.id)
        }
        
        return trueProps
    }
}
```

## ステップ3: 命題の定義

リアクティブUIシステムの状態に関する命題を定義します。

```swift
// ビュー状態に関する命題
let isNormal = TemporalKit.makeProposition(
    id: "isNormal",
    name: "ビューが通常状態",
    evaluate: { (state: ReactiveUIState) -> Bool in state.viewState == .normal }
)

let isHighlighted = TemporalKit.makeProposition(
    id: "isHighlighted",
    name: "ビューが強調表示状態",
    evaluate: { (state: ReactiveUIState) -> Bool in state.viewState == .highlighted }
)

let isSelected = TemporalKit.makeProposition(
    id: "isSelected",
    name: "ビューが選択状態",
    evaluate: { (state: ReactiveUIState) -> Bool in state.viewState == .selected }
)

let isDisabled = TemporalKit.makeProposition(
    id: "isDisabled",
    name: "ビューが無効状態",
    evaluate: { (state: ReactiveUIState) -> Bool in state.viewState == .disabled }
)

// バックグラウンドタスクに関する命題
let isIdle = TemporalKit.makeProposition(
    id: "isIdle",
    name: "バックグラウンドがアイドル状態",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask == .idle }
)

let isLoading = TemporalKit.makeProposition(
    id: "isLoading",
    name: "データを読み込み中",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask == .loading }
)

let isProcessing = TemporalKit.makeProposition(
    id: "isProcessing",
    name: "データを処理中",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask == .processing }
)

let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "エラー状態",
    evaluate: { (state: ReactiveUIState) -> Bool in state.backgroundTask == .error }
)

// ユーザーアクションに関する命題
let noAction = TemporalKit.makeProposition(
    id: "noAction",
    name: "アクションなし",
    evaluate: { (state: ReactiveUIState) -> Bool in state.lastUserAction == .none }
)

let wasTapped = TemporalKit.makeProposition(
    id: "wasTapped",
    name: "タップされた",
    evaluate: { (state: ReactiveUIState) -> Bool in state.lastUserAction == .tap }
)

let wasSwiped = TemporalKit.makeProposition(
    id: "wasSwiped",
    name: "スワイプされた",
    evaluate: { (state: ReactiveUIState) -> Bool in state.lastUserAction == .swipe }
)

let wasLongPressed = TemporalKit.makeProposition(
    id: "wasLongPressed",
    name: "長押しされた",
    evaluate: { (state: ReactiveUIState) -> Bool in state.lastUserAction == .longPress }
)

// 複合状態に関する命題
let isBusy = TemporalKit.makeProposition(
    id: "isBusy",
    name: "処理中（読み込みまたは処理）",
    evaluate: { (state: ReactiveUIState) -> Bool in 
        state.backgroundTask == .loading || state.backgroundTask == .processing 
    }
)

let hasIssue = TemporalKit.makeProposition(
    id: "hasIssue",
    name: "問題あり（無効またはエラー）",
    evaluate: { (state: ReactiveUIState) -> Bool in 
        state.viewState == .disabled || state.backgroundTask == .error 
    }
)
```

## ステップ4: リアクティブプロパティの定義

リアクティブシステムに関する重要なプロパティをLTL式として定義します。

```swift
// 型エイリアス（見やすさのため）
typealias UIProp = ClosureTemporalProposition<ReactiveUIState, Bool>
typealias UILTL = LTLFormula<UIProp>

// プロパティ1: 「応答性 - タップされた後、必ずビューの状態が変化する」
let responsiveness = UILTL.globally(
    .implies(
        .atomic(wasTapped),
        .next(
            .or(
                .atomic(isHighlighted),
                .atomic(isSelected),
                .atomic(isNormal)
            )
        )
    )
)

// プロパティ2: 「安全性 - エラーが発生したら、最終的にはアイドル状態に戻る」
let errorRecovery = UILTL.globally(
    .implies(
        .atomic(isError),
        .eventually(.atomic(isIdle))
    )
)

// プロパティ3: 「進行性 - 読み込みを開始したら、最終的には処理が完了する（アイドルに戻る）」
let progressFromLoading = UILTL.globally(
    .implies(
        .atomic(isLoading),
        .eventually(.atomic(isIdle))
    )
)

// プロパティ4: 「選択状態は必ずタップ後にのみ発生する」
let selectionAfterTap = UILTL.globally(
    .implies(
        .atomic(isSelected),
        .previously(.atomic(wasTapped))
    )
)

// プロパティ5: 「無効状態ではタップ操作は状態を変更しない」
let disabledNoChange = UILTL.globally(
    .implies(
        .and(
            .atomic(isDisabled),
            .atomic(wasTapped)
        ),
        .next(.atomic(isDisabled))
    )
)

// プロパティ6: 「エラー状態ではUIを無効化する」
let errorDisablesUI = UILTL.globally(
    .implies(
        .atomic(isError),
        .eventually(.atomic(isDisabled))
    )
)

// DSL記法を使った例
import TemporalKit.DSL

let dslResponsiveness = G(
    .implies(
        .atomic(wasTapped),
        X(
            .or(
                .atomic(isHighlighted),
                .atomic(isSelected),
                .atomic(isNormal)
            )
        )
    )
)
```

## ステップ5: モデル検査の実行

モデル検査を実行して、定義したプロパティをリアクティブシステムが満たすかどうかを検証します。

```swift
let reactiveUIModel = ReactiveUIModel()
let modelChecker = LTLModelChecker<ReactiveUIModel>()

do {
    // プロパティごとに検証を実行
    let result1 = try modelChecker.check(formula: responsiveness, model: reactiveUIModel)
    let result2 = try modelChecker.check(formula: errorRecovery, model: reactiveUIModel)
    let result3 = try modelChecker.check(formula: progressFromLoading, model: reactiveUIModel)
    let result4 = try modelChecker.check(formula: selectionAfterTap, model: reactiveUIModel)
    let result5 = try modelChecker.check(formula: disabledNoChange, model: reactiveUIModel)
    let result6 = try modelChecker.check(formula: errorDisablesUI, model: reactiveUIModel)
    
    // 結果の出力
    print("検証結果:")
    print("1. 応答性: \(result1.holds ? "成立" : "不成立")")
    print("2. エラー回復: \(result2.holds ? "成立" : "不成立")")
    print("3. 読み込みの進行: \(result3.holds ? "成立" : "不成立")")
    print("4. タップ後の選択: \(result4.holds ? "成立" : "不成立")")
    print("5. 無効状態での保護: \(result5.holds ? "成立" : "不成立")")
    print("6. エラー時のUI無効化: \(result6.holds ? "成立" : "不成立")")
    
    // 反例の表示（必要に応じて）
    if case .fails(let counterexample) = result1 {
        print("\nプロパティ1の反例:")
        print("  前置: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("  サイクル: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
    
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ6: イベントストリームのモデル化

リアクティブプログラミングでよく使われるイベントストリームのモデル化方法を見ていきます。

```swift
// イベントの定義
enum Event: Hashable {
    case value(Int)
    case error(String)
    case completed
    case none
}

// イベントストリームの状態
struct EventStreamState: Hashable, CustomStringConvertible {
    let events: [Event]  // これまでに発生したイベント
    let isCompleted: Bool
    let hasError: Bool
    
    var description: String {
        return "Stream(events: \(events.count), completed: \(isCompleted), error: \(hasError))"
    }
    
    // イベントを追加した新しい状態を返す
    func adding(_ event: Event) -> EventStreamState {
        var newEvents = self.events
        newEvents.append(event)
        
        var newIsCompleted = self.isCompleted
        var newHasError = self.hasError
        
        if case .completed = event {
            newIsCompleted = true
        }
        
        if case .error = event {
            newHasError = true
        }
        
        return EventStreamState(
            events: newEvents,
            isCompleted: newIsCompleted,
            hasError: newHasError
        )
    }
}

// イベントストリームのKripke構造
struct EventStreamModel: KripkeStructure {
    typealias State = EventStreamState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State>
    let maxEvents: Int
    
    init(maxEvents: Int = 5) {
        self.maxEvents = maxEvents
        let initialState = EventStreamState(events: [], isCompleted: false, hasError: false)
        self.initialStates = [initialState]
    }
    
    var allStates: Set<State> {
        // 実際のアプリケーションでは、状態空間が大きくなりすぎるため、
        // 明示的に計算せず、必要に応じて生成するアプローチを取るべき
        fatalError("状態空間が大きすぎるため、明示的に計算しません")
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // すでに完了またはエラーの場合、変化なし
        if state.isCompleted || state.hasError {
            nextStates.insert(state)
            return nextStates
        }
        
        // イベント数が上限に達した場合、完了イベントのみ追加可能
        if state.events.count >= maxEvents {
            nextStates.insert(state.adding(.completed))
            nextStates.insert(state.adding(.error("最大イベント数超過")))
            return nextStates
        }
        
        // 値イベントを追加
        for value in 1...3 {  // 値の範囲を制限
            nextStates.insert(state.adding(.value(value)))
        }
        
        // エラーイベントを追加
        nextStates.insert(state.adding(.error("一般エラー")))
        
        // 完了イベントを追加
        nextStates.insert(state.adding(.completed))
        
        // 何も起こらない可能性
        nextStates.insert(state.adding(.none))
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        if state.isCompleted {
            trueProps.insert("isCompleted")
        }
        
        if state.hasError {
            trueProps.insert("hasError")
        }
        
        if !state.events.isEmpty {
            trueProps.insert("hasEvents")
        }
        
        // 値イベントの有無をチェック
        let hasValueEvent = state.events.contains { event in
            if case .value = event { return true }
            return false
        }
        
        if hasValueEvent {
            trueProps.insert("hasValueEvent")
        }
        
        return trueProps
    }
}
```

## ステップ7: イベントストリームのプロパティ検証

イベントストリームに対するプロパティを検証します。

```swift
// イベントストリームプロパティの定義
let streamIsCompleted = TemporalKit.makeProposition(
    id: "isCompleted",
    name: "ストリームが完了している",
    evaluate: { (state: EventStreamState) -> Bool in state.isCompleted }
)

let streamHasError = TemporalKit.makeProposition(
    id: "hasError",
    name: "ストリームがエラーを持つ",
    evaluate: { (state: EventStreamState) -> Bool in state.hasError }
)

let streamHasEvents = TemporalKit.makeProposition(
    id: "hasEvents",
    name: "ストリームがイベントを持つ",
    evaluate: { (state: EventStreamState) -> Bool in !state.events.isEmpty }
)

let streamHasValueEvent = TemporalKit.makeProposition(
    id: "hasValueEvent",
    name: "ストリームが値イベントを持つ",
    evaluate: { (state: EventStreamState) -> Bool in 
        state.events.contains { event in
            if case .value = event { return true }
            return false
        }
    }
)

// プロパティ式の定義
typealias StreamProp = ClosureTemporalProposition<EventStreamState, Bool>
typealias StreamLTL = LTLFormula<StreamProp>

// プロパティ1: 「最終的にストリームは完了するかエラーになる」
let eventuallyCompletedOrError = StreamLTL.eventually(
    .or(
        .atomic(streamIsCompleted),
        .atomic(streamHasError)
    )
)

// プロパティ2: 「エラーまたは完了後は状態が変化しない」
let noChangeAfterTermination = StreamLTL.globally(
    .implies(
        .or(
            .atomic(streamIsCompleted),
            .atomic(streamHasError)
        ),
        .globally(
            .or(
                .atomic(streamIsCompleted),
                .atomic(streamHasError)
            )
        )
    )
)

// プロパティ3: 「値イベント後に完了イベントが続く可能性がある」
let valueLeadsToCompletion = StreamLTL.globally(
    .implies(
        .atomic(streamHasValueEvent),
        .eventually(.atomic(streamIsCompleted))
    )
)

// イベントストリームのモデル検査
let streamModel = EventStreamModel(maxEvents: 3)
let streamModelChecker = LTLModelChecker<EventStreamModel>()

do {
    // プロパティごとに検証を実行
    let streamResult1 = try streamModelChecker.check(formula: eventuallyCompletedOrError, model: streamModel)
    let streamResult2 = try streamModelChecker.check(formula: noChangeAfterTermination, model: streamModel)
    let streamResult3 = try streamModelChecker.check(formula: valueLeadsToCompletion, model: streamModel)
    
    // 結果の出力
    print("\nイベントストリーム検証結果:")
    print("1. 最終的な終了: \(streamResult1.holds ? "成立" : "不成立")")
    print("2. 終了後の状態固定: \(streamResult2.holds ? "成立" : "不成立")")
    print("3. 値から完了への可能性: \(streamResult3.holds ? "成立" : "不成立")")
    
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ8: 非同期処理のモデル化

非同期処理を含むリアクティブシステムのモデル化方法を見ていきます。

```swift
// 非同期タスクの状態
enum AsyncTaskState: Hashable {
    case notStarted
    case pending
    case succeeded
    case failed
}

// 非同期処理を含むシステムの状態
struct AsyncSystemState: Hashable, CustomStringConvertible {
    let mainTask: AsyncTaskState
    let backgroundTasks: [AsyncTaskState]
    let uiState: ViewState
    
    var description: String {
        return "AsyncSystem(main: \(mainTask), background: \(backgroundTasks.count)個, ui: \(uiState))"
    }
}

// 非同期システムのモデル
struct AsyncSystemModel: KripkeStructure {
    typealias State = AsyncSystemState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let initialStates: Set<State>
    
    init() {
        // 初期状態: メインタスクと背景タスクは未開始、UIは通常
        let initialState = AsyncSystemState(
            mainTask: .notStarted,
            backgroundTasks: [.notStarted, .notStarted],
            uiState: .normal
        )
        
        self.initialStates = [initialState]
    }
    
    var allStates: Set<State> {
        // 実装省略（大きな状態空間のため）
        fatalError("状態空間が大きすぎるため、明示的に計算しません")
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // メインタスクの遷移
        let nextMainStates = nextAsyncStates(state.mainTask)
        for nextMain in nextMainStates {
            var newState = state
            newState = AsyncSystemState(
                mainTask: nextMain,
                backgroundTasks: state.backgroundTasks,
                uiState: updateUIForMainTask(state.uiState, nextMain)
            )
            nextStates.insert(newState)
        }
        
        // バックグラウンドタスクの遷移
        for taskIndex in 0..<state.backgroundTasks.count {
            let task = state.backgroundTasks[taskIndex]
            let nextTaskStates = nextAsyncStates(task)
            
            for nextTask in nextTaskStates {
                var newBackgroundTasks = state.backgroundTasks
                newBackgroundTasks[taskIndex] = nextTask
                
                var newUIState = state.uiState
                // バックグラウンドタスクの状態がUIに影響を与える可能性
                if allTasksCompleted(newBackgroundTasks) {
                    if newBackgroundTasks.contains(where: { $0 == .failed }) {
                        newUIState = .disabled
                    } else {
                        newUIState = .normal
                    }
                }
                
                let newState = AsyncSystemState(
                    mainTask: state.mainTask,
                    backgroundTasks: newBackgroundTasks,
                    uiState: newUIState
                )
                nextStates.insert(newState)
            }
        }
        
        // 現在の状態も後続状態に含める
        nextStates.insert(state)
        
        return nextStates
    }
    
    // 非同期タスクの次の状態を決定
    private func nextAsyncStates(_ state: AsyncTaskState) -> [AsyncTaskState] {
        switch state {
        case .notStarted:
            return [.notStarted, .pending]
        case .pending:
            return [.pending, .succeeded, .failed]
        case .succeeded, .failed:
            return [state]  // 終了状態は変化しない
        }
    }
    
    // メインタスクの状態に基づいてUIを更新
    private func updateUIForMainTask(_ uiState: ViewState, _ taskState: AsyncTaskState) -> ViewState {
        switch taskState {
        case .notStarted:
            return uiState
        case .pending:
            return .highlighted  // 処理中は強調表示
        case .succeeded:
            return .selected     // 成功時は選択状態
        case .failed:
            return .disabled     // 失敗時は無効状態
        }
    }
    
    // すべてのバックグラウンドタスクが完了したかチェック
    private func allTasksCompleted(_ tasks: [AsyncTaskState]) -> Bool {
        return tasks.allSatisfy { $0 == .succeeded || $0 == .failed }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // メインタスクの状態に関する命題
        switch state.mainTask {
        case .notStarted:
            trueProps.insert("mainNotStarted")
        case .pending:
            trueProps.insert("mainPending")
        case .succeeded:
            trueProps.insert("mainSucceeded")
        case .failed:
            trueProps.insert("mainFailed")
        }
        
        // バックグラウンドタスクに関する命題
        if state.backgroundTasks.contains(where: { $0 == .pending }) {
            trueProps.insert("hasBackgroundPending")
        }
        
        if state.backgroundTasks.contains(where: { $0 == .failed }) {
            trueProps.insert("hasBackgroundFailed")
        }
        
        if allTasksCompleted(state.backgroundTasks) {
            trueProps.insert("allBackgroundCompleted")
        }
        
        // UIの状態に関する命題
        switch state.uiState {
        case .normal:
            trueProps.insert("uiNormal")
        case .highlighted:
            trueProps.insert("uiHighlighted")
        case .selected:
            trueProps.insert("uiSelected")
        case .disabled:
            trueProps.insert("uiDisabled")
        }
        
        return trueProps
    }
}
```

## まとめ

このチュートリアルでは、TemporalKitを使用してリアクティブシステムの検証を行う方法を学びました。特に以下の点に焦点を当てました：

1. リアクティブUIシステムのKripke構造としてのモデル化方法
2. イベント駆動型の振る舞いを時相論理式で表現する方法
3. イベントストリームと非同期処理のモデル化方法
4. リアクティブシステムの重要なプロパティ（応答性、安全性、進行性など）の検証方法

リアクティブシステムの形式的検証を行うことで、競合状態や応答性の問題などを早期に発見し、より信頼性の高いシステムを構築することができます。

## 次のステップ

- [分散システムのモデル化](./ModelingDistributedSystems.md)で、複数のノードにまたがるシステムの検証方法を学びましょう。
- [UIフローの検証](./VerifyingUIFlows.md)で、ユーザーインターフェースの検証に特化した手法を学びましょう。
- [パフォーマンスの最適化](./OptimizingPerformance.md)で、大規模なリアクティブシステムの検証を効率的に行う方法を学びましょう。 
