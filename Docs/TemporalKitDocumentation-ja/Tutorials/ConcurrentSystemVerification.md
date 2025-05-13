# 並行システムの検証

このチュートリアルでは、TemporalKitを使用して並行システムの検証を行う方法を学びます。複数のプロセスやスレッドが同時に動作するシステムでは、競合状態やデッドロックなどの問題が発生する可能性があり、それらを検出するために形式的な検証が役立ちます。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- 並行システムをKripke構造としてモデル化する
- 並行性に関する重要なプロパティを時相論理式で表現する
- 競合状態やデッドロックなどの並行性の問題を検出する
- 非決定的な振る舞いを持つシステムの検証を行う

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること
- [状態マシンの検証](./StateMachineVerification.md)のチュートリアルを完了していること

## ステップ1: 簡単な並行システムのモデル化

まず、簡単な並行システムの例として、リソースを共有する2つのプロセスをモデル化します。

```swift
import TemporalKit

// プロセスの状態
enum ProcessState: String, Hashable, CustomStringConvertible {
    case idle        // アイドル状態
    case wanting     // リソースを要求中
    case waiting     // リソース待ち
    case critical    // クリティカルセクション内
    case releasing   // リソース解放中
    
    var description: String {
        return rawValue
    }
}

// 共有リソースの状態
enum ResourceState: String, Hashable, CustomStringConvertible {
    case free        // 利用可能
    case taken(by: Int)  // プロセスIDによって使用中
    
    var description: String {
        switch self {
        case .free: return "free"
        case .taken(let id): return "taken(by: \(id))"
        }
    }
    
    // Hashableプロトコルに準拠するため
    func hash(into hasher: inout Hasher) {
        switch self {
        case .free:
            hasher.combine(0)
        case .taken(let id):
            hasher.combine(1)
            hasher.combine(id)
        }
    }
    
    // Equatableプロトコルに準拠するため
    static func == (lhs: ResourceState, rhs: ResourceState) -> Bool {
        switch (lhs, rhs) {
        case (.free, .free): return true
        case let (.taken(id1), .taken(id2)): return id1 == id2
        default: return false
        }
    }
}

// 並行システム全体の状態
struct ConcurrentSystemState: Hashable, CustomStringConvertible {
    let process1: ProcessState
    let process2: ProcessState
    let resource: ResourceState
    
    var description: String {
        return "P1: \(process1), P2: \(process2), Resource: \(resource)"
    }
}
```

## ステップ2: 並行システムのKripke構造の実装

次に、並行システムの状態遷移を表すKripke構造を実装します。

```swift
// 並行システムのKripke構造
struct ConcurrentSystem: KripkeStructure {
    typealias State = ConcurrentSystemState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    init() {
        // 初期状態：両方のプロセスがアイドル状態で、リソースは自由
        let initialState = ConcurrentSystemState(
            process1: .idle,
            process2: .idle,
            resource: .free
        )
        
        self.initialStates = [initialState]
        
        // すべての可能な状態の組み合わせを生成
        // 実際のシステムでは、到達可能な状態のみを考慮することで状態空間を削減できます
        var states = Set<State>()
        
        for p1 in [ProcessState.idle, .wanting, .waiting, .critical, .releasing] {
            for p2 in [ProcessState.idle, .wanting, .waiting, .critical, .releasing] {
                // リソースの状態は制約がある
                if p1 == .critical && p2 == .critical {
                    // 両方が同時にクリティカルセクションにいることはできない（排他制御）
                    continue
                }
                
                // リソースの状態を決定
                if p1 == .critical {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .taken(by: 1)))
                } else if p2 == .critical {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .taken(by: 2)))
                } else {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .free))
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // プロセス1の状態遷移を適用
        for nextP1 in nextProcessStates(for: state.process1, processId: 1, resourceState: state.resource) {
            // プロセス2の状態は変わらず、リソースの状態は更新される可能性がある
            let nextResourceState = updatedResourceState(
                from: state.resource,
                process: state.process1, 
                nextProcess: nextP1, 
                processId: 1
            )
            
            nextStates.insert(ConcurrentSystemState(
                process1: nextP1,
                process2: state.process2,
                resource: nextResourceState
            ))
        }
        
        // プロセス2の状態遷移を適用
        for nextP2 in nextProcessStates(for: state.process2, processId: 2, resourceState: state.resource) {
            // プロセス1の状態は変わらず、リソースの状態は更新される可能性がある
            let nextResourceState = updatedResourceState(
                from: state.resource,
                process: state.process2, 
                nextProcess: nextP2, 
                processId: 2
            )
            
            nextStates.insert(ConcurrentSystemState(
                process1: state.process1,
                process2: nextP2,
                resource: nextResourceState
            ))
        }
        
        // 現在の状態も後続状態に含める（何も変化しない可能性もある）
        nextStates.insert(state)
        
        return nextStates
    }
    
    // プロセスの次の状態を決定するヘルパーメソッド
    private func nextProcessStates(for state: ProcessState, processId: Int, resourceState: ResourceState) -> [ProcessState] {
        switch state {
        case .idle:
            // アイドル状態からリソース要求状態へ
            return [.idle, .wanting]
            
        case .wanting:
            // リソース要求状態からリソース待ち状態へ
            return [.waiting]
            
        case .waiting:
            // リソースが空いていれば、クリティカルセクションに入れる
            if case .free = resourceState {
                return [.waiting, .critical]
            } else {
                // リソースが使用中なら待機を続ける
                return [.waiting]
            }
            
        case .critical:
            // クリティカルセクションから解放状態へ
            return [.releasing]
            
        case .releasing:
            // 解放状態からアイドル状態へ
            return [.idle]
        }
    }
    
    // リソースの状態を更新するヘルパーメソッド
    private func updatedResourceState(from currentState: ResourceState, process: ProcessState, nextProcess: ProcessState, processId: Int) -> ResourceState {
        // プロセスがクリティカルセクションに入る場合
        if process == .waiting && nextProcess == .critical {
            return .taken(by: processId)
        }
        
        // プロセスがリソースを解放する場合
        if process == .critical && nextProcess == .releasing {
            return .free
        }
        
        // それ以外の場合はリソースの状態は変わらない
        return currentState
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // プロセス1の状態に関する命題
        switch state.process1 {
        case .idle:
            trueProps.insert(p1Idle.id)
        case .wanting:
            trueProps.insert(p1Wanting.id)
        case .waiting:
            trueProps.insert(p1Waiting.id)
        case .critical:
            trueProps.insert(p1Critical.id)
        case .releasing:
            trueProps.insert(p1Releasing.id)
        }
        
        // プロセス2の状態に関する命題
        switch state.process2 {
        case .idle:
            trueProps.insert(p2Idle.id)
        case .wanting:
            trueProps.insert(p2Wanting.id)
        case .waiting:
            trueProps.insert(p2Waiting.id)
        case .critical:
            trueProps.insert(p2Critical.id)
        case .releasing:
            trueProps.insert(p2Releasing.id)
        }
        
        // リソースの状態に関する命題
        switch state.resource {
        case .free:
            trueProps.insert(resourceFree.id)
        case .taken(let id):
            trueProps.insert(resourceTaken.id)
            if id == 1 {
                trueProps.insert(resourceTakenByP1.id)
            } else if id == 2 {
                trueProps.insert(resourceTakenByP2.id)
            }
        }
        
        return trueProps
    }
}
```

## ステップ3: 命題の定義

並行システムの状態に関する命題を定義します。

```swift
// プロセス1の状態に関する命題
let p1Idle = TemporalKit.makeProposition(
    id: "p1Idle",
    name: "プロセス1がアイドル状態",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process1 == .idle }
)

let p1Wanting = TemporalKit.makeProposition(
    id: "p1Wanting",
    name: "プロセス1がリソース要求中",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process1 == .wanting }
)

let p1Waiting = TemporalKit.makeProposition(
    id: "p1Waiting",
    name: "プロセス1がリソース待ち",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process1 == .waiting }
)

let p1Critical = TemporalKit.makeProposition(
    id: "p1Critical",
    name: "プロセス1がクリティカルセクション内",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process1 == .critical }
)

let p1Releasing = TemporalKit.makeProposition(
    id: "p1Releasing",
    name: "プロセス1がリソース解放中",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process1 == .releasing }
)

// プロセス2の状態に関する命題
let p2Idle = TemporalKit.makeProposition(
    id: "p2Idle",
    name: "プロセス2がアイドル状態",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process2 == .idle }
)

let p2Wanting = TemporalKit.makeProposition(
    id: "p2Wanting",
    name: "プロセス2がリソース要求中",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process2 == .wanting }
)

let p2Waiting = TemporalKit.makeProposition(
    id: "p2Waiting",
    name: "プロセス2がリソース待ち",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process2 == .waiting }
)

let p2Critical = TemporalKit.makeProposition(
    id: "p2Critical",
    name: "プロセス2がクリティカルセクション内",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process2 == .critical }
)

let p2Releasing = TemporalKit.makeProposition(
    id: "p2Releasing",
    name: "プロセス2がリソース解放中",
    evaluate: { (state: ConcurrentSystemState) -> Bool in state.process2 == .releasing }
)

// リソースの状態に関する命題
let resourceFree = TemporalKit.makeProposition(
    id: "resourceFree",
    name: "リソースが利用可能",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        if case .free = state.resource { return true }
        return false
    }
)

let resourceTaken = TemporalKit.makeProposition(
    id: "resourceTaken",
    name: "リソースが使用中",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        if case .taken = state.resource { return true }
        return false
    }
)

let resourceTakenByP1 = TemporalKit.makeProposition(
    id: "resourceTakenByP1",
    name: "リソースがプロセス1によって使用中",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        if case .taken(let id) = state.resource, id == 1 { return true }
        return false
    }
)

let resourceTakenByP2 = TemporalKit.makeProposition(
    id: "resourceTakenByP2",
    name: "リソースがプロセス2によって使用中",
    evaluate: { (state: ConcurrentSystemState) -> Bool in
        if case .taken(let id) = state.resource, id == 2 { return true }
        return false
    }
)
```

## ステップ4: 検証プロパティの定義

並行システムに対して検証したい重要なプロパティをLTL式として定義します。

```swift
// 型エイリアス（見やすさのため）
typealias ConcurrentProp = ClosureTemporalProposition<ConcurrentSystemState, Bool>
typealias ConcurrentLTL = LTLFormula<ConcurrentProp>

// プロパティ1: 「相互排除（mutual exclusion）- 両方のプロセスが同時にクリティカルセクションに入ることはない」
let mutualExclusion = ConcurrentLTL.globally(
    .not(
        .and(
            .atomic(p1Critical),
            .atomic(p2Critical)
        )
    )
)

// プロパティ2: 「デッドロックがない - 両方のプロセスが同時に永久に待機状態になることはない」
let noDeadlock = ConcurrentLTL.globally(
    .not(
        .and(
            .and(
                .atomic(p1Waiting),
                .atomic(p2Waiting)
            ),
            .globally(
                .and(
                    .atomic(p1Waiting),
                    .atomic(p2Waiting)
                )
            )
        )
    )
)

// プロパティ3: 「飢餓（starvation）がない - リソースを要求するプロセスはいつかはリソースを取得できる」
// プロセス1の場合
let noStarvationP1 = ConcurrentLTL.globally(
    .implies(
        .atomic(p1Waiting),
        .eventually(.atomic(p1Critical))
    )
)

// プロセス2の場合
let noStarvationP2 = ConcurrentLTL.globally(
    .implies(
        .atomic(p2Waiting),
        .eventually(.atomic(p2Critical))
    )
)

// プロパティ4: 「公平性（fairness）- 両方のプロセスが均等にリソースにアクセスできる」
// ここでは単純に「プロセス1がクリティカルセクションに入ったら、
// その後プロセス2もいつかはクリティカルセクションに入れる」という性質で表現
let fairness = ConcurrentLTL.globally(
    .implies(
        .atomic(p1Critical),
        .eventually(.atomic(p2Critical))
    )
)

// プロパティ5: 「進行性（liveness）- システムは常に進行する（クリティカルセクションを通過できる）」
let liveness = ConcurrentLTL.globally(
    .implies(
        .or(
            .atomic(p1Wanting),
            .atomic(p2Wanting)
        ),
        .eventually(
            .or(
                .atomic(p1Critical),
                .atomic(p2Critical)
            )
        )
    )
)

// DSL記法を使った例
import TemporalKit.DSL

let dslMutualExclusion = G(
    .not(
        .and(
            .atomic(p1Critical),
            .atomic(p2Critical)
        )
    )
)
```

## ステップ5: モデル検査の実行

モデル検査を実行して、定義したプロパティを並行システムが満たすかどうかを検証します。

```swift
let concurrentSystem = ConcurrentSystem()
let modelChecker = LTLModelChecker<ConcurrentSystem>()

do {
    // プロパティごとに検証を実行
    let result1 = try modelChecker.check(formula: mutualExclusion, model: concurrentSystem)
    let result2 = try modelChecker.check(formula: noDeadlock, model: concurrentSystem)
    let result3a = try modelChecker.check(formula: noStarvationP1, model: concurrentSystem)
    let result3b = try modelChecker.check(formula: noStarvationP2, model: concurrentSystem)
    let result4 = try modelChecker.check(formula: fairness, model: concurrentSystem)
    let result5 = try modelChecker.check(formula: liveness, model: concurrentSystem)
    
    // 結果の出力
    print("検証結果:")
    print("1. 相互排除: \(result1.holds ? "成立" : "不成立")")
    print("2. デッドロックなし: \(result2.holds ? "成立" : "不成立")")
    print("3a. 飢餓なし（P1）: \(result3a.holds ? "成立" : "不成立")")
    print("3b. 飢餓なし（P2）: \(result3b.holds ? "成立" : "不成立")")
    print("4. 公平性: \(result4.holds ? "成立" : "不成立")")
    print("5. 進行性: \(result5.holds ? "成立" : "不成立")")
    
    // 反例の表示（飢餓の問題があるかもしれない）
    if !result3a.holds, case .fails(let counterexample) = result3a {
        print("\nプロセス1の飢餓の反例:")
        print("  前置: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("  サイクル: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
    
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ6: 問題の特定と修正

モデル検査で発見された問題（例えば飢餓やデッドロック）を修正するために、システムを改良します。

```swift
// 改良版の並行システムのKripke構造
// 優先順位ベースのリソース割り当てを実装
struct ImprovedConcurrentSystem: KripkeStructure {
    typealias State = ConcurrentSystemState
    typealias AtomicPropositionIdentifier = PropositionID
    
    // 各プロセスの優先度を追跡する状態を追加
    struct InternalState {
        var p1WaitTurns: Int = 0
        var p2WaitTurns: Int = 0
    }
    
    let allStates: Set<State>
    let initialStates: Set<State>
    
    // 内部状態（モデル検査の状態には含まれないが、遷移ロジックで使用）
    private var internalState = InternalState()
    
    init() {
        // 元の実装と同じ初期化
        let initialState = ConcurrentSystemState(
            process1: .idle,
            process2: .idle,
            resource: .free
        )
        
        self.initialStates = [initialState]
        
        // 全ての可能な状態（元の実装と同様）
        var states = Set<State>()
        
        for p1 in [ProcessState.idle, .wanting, .waiting, .critical, .releasing] {
            for p2 in [ProcessState.idle, .wanting, .waiting, .critical, .releasing] {
                if p1 == .critical && p2 == .critical {
                    continue
                }
                
                if p1 == .critical {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .taken(by: 1)))
                } else if p2 == .critical {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .taken(by: 2)))
                } else {
                    states.insert(ConcurrentSystemState(process1: p1, process2: p2, resource: .free))
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // リソースの割り当てロジックを修正
        // 両方のプロセスが待機中の場合、より長く待っているプロセスに優先順位を与える
        if state.process1 == .waiting && state.process2 == .waiting && state.resource == .free {
            let priorityToP1 = internalState.p1WaitTurns >= internalState.p2WaitTurns
            
            if priorityToP1 {
                // プロセス1にリソースを割り当て
                nextStates.insert(ConcurrentSystemState(
                    process1: .critical,
                    process2: .waiting,
                    resource: .taken(by: 1)
                ))
                // プロセス2の待機カウントを増やす
                internalState.p2WaitTurns += 1
                internalState.p1WaitTurns = 0
            } else {
                // プロセス2にリソースを割り当て
                nextStates.insert(ConcurrentSystemState(
                    process1: .waiting,
                    process2: .critical,
                    resource: .taken(by: 2)
                ))
                // プロセス1の待機カウントを増やす
                internalState.p1WaitTurns += 1
                internalState.p2WaitTurns = 0
            }
        } else {
            // プロセス1の遷移（元の実装と同様）
            for nextP1 in nextProcessStates(for: state.process1, processId: 1, resourceState: state.resource) {
                let nextResourceState = updatedResourceState(
                    from: state.resource,
                    process: state.process1, 
                    nextProcess: nextP1, 
                    processId: 1
                )
                
                nextStates.insert(ConcurrentSystemState(
                    process1: nextP1,
                    process2: state.process2,
                    resource: nextResourceState
                ))
                
                // 待機カウントの更新
                if state.process1 == .waiting && nextP1 == .waiting {
                    internalState.p1WaitTurns += 1
                }
                if state.process1 == .waiting && nextP1 == .critical {
                    internalState.p1WaitTurns = 0
                }
            }
            
            // プロセス2の遷移（元の実装と同様）
            for nextP2 in nextProcessStates(for: state.process2, processId: 2, resourceState: state.resource) {
                let nextResourceState = updatedResourceState(
                    from: state.resource,
                    process: state.process2, 
                    nextProcess: nextP2, 
                    processId: 2
                )
                
                nextStates.insert(ConcurrentSystemState(
                    process1: state.process1,
                    process2: nextP2,
                    resource: nextResourceState
                ))
                
                // 待機カウントの更新
                if state.process2 == .waiting && nextP2 == .waiting {
                    internalState.p2WaitTurns += 1
                }
                if state.process2 == .waiting && nextP2 == .critical {
                    internalState.p2WaitTurns = 0
                }
            }
        }
        
        // 現在の状態も後続状態に含める
        nextStates.insert(state)
        
        return nextStates
    }
    
    // 元の実装と同じヘルパーメソッド
    private func nextProcessStates(for state: ProcessState, processId: Int, resourceState: ResourceState) -> [ProcessState] {
        // 元の実装と同じ
        switch state {
        case .idle:
            return [.idle, .wanting]
        case .wanting:
            return [.waiting]
        case .waiting:
            if case .free = resourceState {
                return [.waiting, .critical]
            } else {
                return [.waiting]
            }
        case .critical:
            return [.releasing]
        case .releasing:
            return [.idle]
        }
    }
    
    private func updatedResourceState(from currentState: ResourceState, process: ProcessState, nextProcess: ProcessState, processId: Int) -> ResourceState {
        // 元の実装と同じ
        if process == .waiting && nextProcess == .critical {
            return .taken(by: processId)
        }
        
        if process == .critical && nextProcess == .releasing {
            return .free
        }
        
        return currentState
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        // 元の実装と同じ
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        switch state.process1 {
        case .idle:
            trueProps.insert(p1Idle.id)
        case .wanting:
            trueProps.insert(p1Wanting.id)
        case .waiting:
            trueProps.insert(p1Waiting.id)
        case .critical:
            trueProps.insert(p1Critical.id)
        case .releasing:
            trueProps.insert(p1Releasing.id)
        }
        
        switch state.process2 {
        case .idle:
            trueProps.insert(p2Idle.id)
        case .wanting:
            trueProps.insert(p2Wanting.id)
        case .waiting:
            trueProps.insert(p2Waiting.id)
        case .critical:
            trueProps.insert(p2Critical.id)
        case .releasing:
            trueProps.insert(p2Releasing.id)
        }
        
        switch state.resource {
        case .free:
            trueProps.insert(resourceFree.id)
        case .taken(let id):
            trueProps.insert(resourceTaken.id)
            if id == 1 {
                trueProps.insert(resourceTakenByP1.id)
            } else if id == 2 {
                trueProps.insert(resourceTakenByP2.id)
            }
        }
        
        return trueProps
    }
}
```

## ステップ7: 改善されたシステムの検証

改良した並行システムで問題が解決されたかどうかを再検証します。

```swift
let improvedSystem = ImprovedConcurrentSystem()

do {
    // 問題のあったプロパティを再検証
    let improvedResult3a = try modelChecker.check(formula: noStarvationP1, model: improvedSystem)
    let improvedResult3b = try modelChecker.check(formula: noStarvationP2, model: improvedSystem)
    let improvedResult4 = try modelChecker.check(formula: fairness, model: improvedSystem)
    
    print("\n改良版システムの検証結果:")
    print("3a. 飢餓なし（P1）: \(improvedResult3a.holds ? "成立" : "不成立")")
    print("3b. 飢餓なし（P2）: \(improvedResult3b.holds ? "成立" : "不成立")")
    print("4. 公平性: \(improvedResult4.holds ? "成立" : "不成立")")
    
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ8: より複雑な並行性パターンのモデル化

リーダー選出など、より複雑な並行性パターンのモデル化の例を示します。

```swift
// プロセスの状態（リーダー選出プロトコル）
enum LeaderElectionState: String, Hashable, CustomStringConvertible {
    case inactive      // 非アクティブ
    case candidate     // リーダー候補
    case follower      // フォロワー
    case leader        // リーダー
    
    var description: String {
        return rawValue
    }
}

// リーダー選出システム全体の状態
struct LeaderElectionSystemState: Hashable, CustomStringConvertible {
    let process1: LeaderElectionState
    let process2: LeaderElectionState
    let process3: LeaderElectionState
    
    var description: String {
        return "P1: \(process1), P2: \(process2), P3: \(process3)"
    }
}

// リーダー選出システムの命題
let p1IsLeader = TemporalKit.makeProposition(
    id: "p1IsLeader",
    name: "プロセス1がリーダー",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in state.process1 == .leader }
)

let p2IsLeader = TemporalKit.makeProposition(
    id: "p2IsLeader",
    name: "プロセス2がリーダー",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in state.process2 == .leader }
)

let p3IsLeader = TemporalKit.makeProposition(
    id: "p3IsLeader",
    name: "プロセス3がリーダー",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in state.process3 == .leader }
)

let hasLeader = TemporalKit.makeProposition(
    id: "hasLeader",
    name: "リーダーが存在する",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in
        state.process1 == .leader || state.process2 == .leader || state.process3 == .leader
    }
)

let hasMultipleLeaders = TemporalKit.makeProposition(
    id: "hasMultipleLeaders",
    name: "複数のリーダーが存在する",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in
        let leaderCount = [state.process1, state.process2, state.process3]
            .filter { $0 == .leader }
            .count
        return leaderCount > 1
    }
)

// 検証したいプロパティ（リーダー選出）
typealias ElectionProp = ClosureTemporalProposition<LeaderElectionSystemState, Bool>
typealias ElectionLTL = LTLFormula<ElectionProp>

// プロパティ1: 「最終的には必ずリーダーが選出される」
let eventuallyLeader = ElectionLTL.eventually(.atomic(hasLeader))

// プロパティ2: 「一度リーダーが選出されたら、そのリーダーは変わらない」
let leaderStability = ElectionLTL.implies(
    .atomic(hasLeader),
    .globally(.atomic(hasLeader))
)

// プロパティ3: 「複数のリーダーが同時に存在することはない」
let singleLeader = ElectionLTL.globally(.not(.atomic(hasMultipleLeaders)))
```

## まとめ

このチュートリアルでは、TemporalKitを使用して並行システムの検証を行う方法を学びました。特に以下の点に焦点を当てました：

1. 共有リソースを持つ並行システムをKripke構造としてモデル化する方法
2. 相互排除、デッドロック回避、飢餓回避などの重要な並行性プロパティをLTL式で表現する方法
3. モデル検査を実行して並行性の問題を特定する方法
4. 優先順位ベースのリソース割り当てによるシステムの改良方法
5. より複雑な並行性パターン（リーダー選出など）のモデル化方法

並行システムの形式的検証は、競合状態やデッドロックなどの検出が困難な問題を早期に発見するのに役立ちます。TemporalKitを使用することで、これらの検証をSwiftで直接行うことができます。

## 次のステップ

- [パフォーマンスの最適化](./OptimizingPerformance.md)で、状態爆発問題に対処する方法を学びましょう。
- [リアクティブシステムの検証](./VerifyingReactiveSystems.md)で、イベント駆動型の並行システムの検証方法を学びましょう。
- [分散システムのモデル化](./ModelingDistributedSystems.md)で、複数のノードにまたがるシステムの検証方法を学びましょう。 
