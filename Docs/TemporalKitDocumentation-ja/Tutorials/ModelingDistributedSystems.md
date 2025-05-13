# 分散システムのモデル化

このチュートリアルでは、TemporalKitを使用して分散システムのモデル化と検証を行う方法を学びます。分散システムは複数のノードが協調して動作するシステムであり、一貫性や耐障害性などの検証が重要です。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- 分散システムをKripke構造としてモデル化する
- 一貫性、耐障害性、リーダー選出などの分散システムプロパティを検証する
- 通信遅延やノード障害などの現実的な挙動をモデルに取り込む
- 分散アルゴリズムの正確性を検証する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること
- [並行システムの検証](./ConcurrentSystemVerification.md)のチュートリアルを完了していること

## ステップ1: 基本的な分散システムモデル

まず、シンプルな分散システムのモデルを作成します。ここでは、複数のノードが値を共有するシステムを考えます。

```swift
import TemporalKit

// ノードの状態を表現する構造体
struct NodeState: Hashable, CustomStringConvertible {
    let id: Int
    let value: Int
    let isActive: Bool
    
    var description: String {
        return "Node(\(id): value=\(value), \(isActive ? "active" : "inactive"))"
    }
}

// 分散システム全体の状態
struct DistributedSystemState: Hashable, CustomStringConvertible {
    let nodes: [NodeState]
    
    var description: String {
        return "System(\(nodes.map { $0.description }.joined(separator: ", ")))"
    }
}
```

## ステップ2: 分散システムのKripke構造モデル

分散システムをKripke構造としてモデル化します。

```swift
// シンプルな分散システムのKripke構造
struct SimpleDistributedSystem: KripkeStructure {
    typealias State = DistributedSystemState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let nodeCount: Int
    let initialStates: Set<State>
    
    init(nodeCount: Int = 3) {
        self.nodeCount = nodeCount
        
        // 初期状態: すべてのノードはアクティブで、値は0
        let initialNodes = (0..<nodeCount).map { id in
            NodeState(id: id, value: 0, isActive: true)
        }
        
        self.initialStates = [DistributedSystemState(nodes: initialNodes)]
    }
    
    var allStates: Set<State> {
        // 実際のアプリケーションでは、状態空間が膨大になるため
        // 明示的に計算せず、必要に応じて生成するべき
        fatalError("状態空間が大きすぎるため、明示的に計算しません")
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // 各ノードの状態変化を考慮
        for nodeIndex in 0..<state.nodes.count {
            // 1. ノードの値を変更する可能性
            if state.nodes[nodeIndex].isActive {
                for newValue in 0...2 {  // 値の範囲を制限
                    var newNodes = state.nodes
                    newNodes[nodeIndex] = NodeState(
                        id: state.nodes[nodeIndex].id,
                        value: newValue,
                        isActive: true
                    )
                    nextStates.insert(DistributedSystemState(nodes: newNodes))
                }
            }
            
            // 2. ノードの障害（非アクティブ化）
            var newNodes = state.nodes
            newNodes[nodeIndex] = NodeState(
                id: state.nodes[nodeIndex].id,
                value: state.nodes[nodeIndex].value,
                isActive: false
            )
            nextStates.insert(DistributedSystemState(nodes: newNodes))
            
            // 3. ノードの回復（再アクティブ化）
            if !state.nodes[nodeIndex].isActive {
                var newNodes = state.nodes
                newNodes[nodeIndex] = NodeState(
                    id: state.nodes[nodeIndex].id,
                    value: state.nodes[nodeIndex].value,
                    isActive: true
                )
                nextStates.insert(DistributedSystemState(nodes: newNodes))
            }
            
            // 4. 値の伝播（あるノードから別のノードへの値のコピー）
            for otherNodeIndex in 0..<state.nodes.count where otherNodeIndex != nodeIndex {
                if state.nodes[nodeIndex].isActive && state.nodes[otherNodeIndex].isActive {
                    var newNodes = state.nodes
                    newNodes[otherNodeIndex] = NodeState(
                        id: state.nodes[otherNodeIndex].id,
                        value: state.nodes[nodeIndex].value,
                        isActive: true
                    )
                    nextStates.insert(DistributedSystemState(nodes: newNodes))
                }
            }
        }
        
        // 現在の状態も後続状態に含める
        nextStates.insert(state)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // システム全体の命題
        if state.nodes.allSatisfy({ $0.isActive }) {
            trueProps.insert("allNodesActive")
        }
        
        // 一貫性に関する命題
        let allSameValue = state.nodes.filter { $0.isActive }.allSatisfy { node in
            node.value == state.nodes.first { $0.isActive }?.value
        }
        
        if allSameValue && state.nodes.contains(where: { $0.isActive }) {
            trueProps.insert("consistentValues")
        }
        
        // ノードごとの命題
        for (index, node) in state.nodes.enumerated() {
            if node.isActive {
                trueProps.insert("node\(index)Active")
            } else {
                trueProps.insert("node\(index)Inactive")
            }
            
            // 値に関する命題
            trueProps.insert("node\(index)Value\(node.value)")
            
            // 他のノードとの関係に関する命題
            for (otherIndex, otherNode) in state.nodes.enumerated() where otherIndex != index {
                if node.isActive && otherNode.isActive && node.value == otherNode.value {
                    trueProps.insert("node\(index)MatchesNode\(otherIndex)")
                }
            }
        }
        
        return trueProps
    }
}
```

## ステップ3: 命題の定義

分散システムの状態に関する命題を定義します。

```swift
// システム全体に関する命題
let allNodesActive = TemporalKit.makeProposition(
    id: "allNodesActive",
    name: "すべてのノードがアクティブ",
    evaluate: { (state: DistributedSystemState) -> Bool in
        state.nodes.allSatisfy { $0.isActive }
    }
)

let consistentValues = TemporalKit.makeProposition(
    id: "consistentValues",
    name: "アクティブなノード間で値が一貫している",
    evaluate: { (state: DistributedSystemState) -> Bool in
        let activeNodes = state.nodes.filter { $0.isActive }
        guard !activeNodes.isEmpty else { return true }
        let firstValue = activeNodes[0].value
        return activeNodes.allSatisfy { $0.value == firstValue }
    }
)

// 特定のノードに関する命題（例としてノード0と1）
let node0Active = TemporalKit.makeProposition(
    id: "node0Active",
    name: "ノード0がアクティブ",
    evaluate: { (state: DistributedSystemState) -> Bool in
        guard state.nodes.indices.contains(0) else { return false }
        return state.nodes[0].isActive
    }
)

let node1Active = TemporalKit.makeProposition(
    id: "node1Active",
    name: "ノード1がアクティブ",
    evaluate: { (state: DistributedSystemState) -> Bool in
        guard state.nodes.indices.contains(1) else { return false }
        return state.nodes[1].isActive
    }
)

// 値に関する命題
let node0Value1 = TemporalKit.makeProposition(
    id: "node0Value1",
    name: "ノード0の値が1",
    evaluate: { (state: DistributedSystemState) -> Bool in
        guard state.nodes.indices.contains(0) else { return false }
        return state.nodes[0].value == 1
    }
)

// ノード間の関係に関する命題
let node0MatchesNode1 = TemporalKit.makeProposition(
    id: "node0MatchesNode1",
    name: "ノード0とノード1の値が一致",
    evaluate: { (state: DistributedSystemState) -> Bool in
        guard state.nodes.indices.contains(0), state.nodes.indices.contains(1) else { return false }
        return state.nodes[0].isActive && state.nodes[1].isActive && state.nodes[0].value == state.nodes[1].value
    }
)
```

## ステップ4: 分散システムプロパティの定義

分散システムに関する重要なプロパティをLTL式として定義します。

```swift
// 型エイリアス（見やすさのため）
typealias DistProp = ClosureTemporalProposition<DistributedSystemState, Bool>
typealias DistLTL = LTLFormula<DistProp>

// プロパティ1: 「最終的な一貫性 - どんな状態変化があっても、最終的には一貫した状態に到達する」
let eventualConsistency = DistLTL.globally(
    .eventually(.atomic(consistentValues))
)

// プロパティ2: 「耐障害性 - 一部のノードが故障しても、残りのノードは一貫性を維持できる」
let faultTolerance = DistLTL.globally(
    .implies(
        .not(.atomic(allNodesActive)),
        .eventually(.atomic(consistentValues))
    )
)

// プロパティ3: 「値の伝播 - ノード0の値が変更されると、最終的にはノード1にも伝播する」
let valuePropagation = DistLTL.globally(
    .implies(
        .and(
            .atomic(node0Value1),
            .atomic(node1Active)
        ),
        .eventually(.atomic(node0MatchesNode1))
    )
)

// プロパティ4: 「障害時の不変条件 - アクティブなノードの値は、障害発生中も保持される」
let valuePreservation = DistLTL.globally(
    .implies(
        .and(
            .atomic(node0Value1),
            .next(.atomic(node0Active))
        ),
        .next(.atomic(node0Value1))
    )
)

// DSL記法を使った例
import TemporalKit.DSL

let dslEventualConsistency = G(F(.atomic(consistentValues)))
```

## ステップ5: モデル検査の実行

モデル検査を実行して、定義したプロパティを分散システムが満たすかどうかを検証します。

```swift
let distributedSystem = SimpleDistributedSystem(nodeCount: 3)
let modelChecker = LTLModelChecker<SimpleDistributedSystem>()

do {
    // プロパティごとに検証を実行
    let result1 = try modelChecker.check(formula: eventualConsistency, model: distributedSystem)
    let result2 = try modelChecker.check(formula: faultTolerance, model: distributedSystem)
    let result3 = try modelChecker.check(formula: valuePropagation, model: distributedSystem)
    let result4 = try modelChecker.check(formula: valuePreservation, model: distributedSystem)
    
    // 結果の出力
    print("検証結果:")
    print("1. 最終的な一貫性: \(result1.holds ? "成立" : "不成立")")
    print("2. 耐障害性: \(result2.holds ? "成立" : "不成立")")
    print("3. 値の伝播: \(result3.holds ? "成立" : "不成立")")
    print("4. 障害時の不変条件: \(result4.holds ? "成立" : "不成立")")
    
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

## ステップ6: リーダー選出プロトコルのモデル化

分散システムの重要なアルゴリズムの一つであるリーダー選出プロトコルをモデル化します。

```swift
// ノードの役割
enum NodeRole: Hashable, CustomStringConvertible {
    case unknown
    case candidate
    case follower
    case leader
    
    var description: String {
        switch self {
        case .unknown: return "不明"
        case .candidate: return "候補"
        case .follower: return "フォロワー"
        case .leader: return "リーダー"
        }
    }
}

// リーダー選出プロトコルのノード状態
struct ElectionNodeState: Hashable, CustomStringConvertible {
    let id: Int
    let role: NodeRole
    let term: Int  // 選挙期間
    let isActive: Bool
    
    var description: String {
        return "Node(\(id): role=\(role), term=\(term), \(isActive ? "active" : "inactive"))"
    }
}

// リーダー選出システム全体の状態
struct LeaderElectionSystemState: Hashable, CustomStringConvertible {
    let nodes: [ElectionNodeState]
    let currentTerm: Int  // システム全体の現在の期間
    
    var description: String {
        return "Election(term=\(currentTerm), nodes=\(nodes.map { $0.description }.joined(separator: ", ")))"
    }
}

// リーダー選出プロトコルのKripke構造
struct LeaderElectionSystem: KripkeStructure {
    typealias State = LeaderElectionSystemState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let nodeCount: Int
    let initialStates: Set<State>
    
    init(nodeCount: Int = 3) {
        self.nodeCount = nodeCount
        
        // 初期状態: すべてのノードはアクティブで、役割は不明、期間は0
        let initialNodes = (0..<nodeCount).map { id in
            ElectionNodeState(id: id, role: .unknown, term: 0, isActive: true)
        }
        
        self.initialStates = [LeaderElectionSystemState(nodes: initialNodes, currentTerm: 0)]
    }
    
    var allStates: Set<State> {
        // 状態空間が大きいため、実装を省略
        fatalError("状態空間が大きすぎるため、明示的に計算しません")
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // リーダー選出プロトコルの状態遷移をモデル化
        
        // 1. 新しい選挙期間を開始する可能性
        let newTerm = state.currentTerm + 1
        for candidateIndex in 0..<state.nodes.count {
            if state.nodes[candidateIndex].isActive {
                var newNodes = state.nodes
                
                // 選挙の候補者を設定
                newNodes[candidateIndex] = ElectionNodeState(
                    id: newNodes[candidateIndex].id,
                    role: .candidate,
                    term: newTerm,
                    isActive: true
                )
                
                // 他のノードはフォロワーになる可能性
                for i in 0..<newNodes.count where i != candidateIndex {
                    if newNodes[i].isActive {
                        newNodes[i] = ElectionNodeState(
                            id: newNodes[i].id,
                            role: .follower,
                            term: newTerm,
                            isActive: true
                        )
                    }
                }
                
                nextStates.insert(LeaderElectionSystemState(nodes: newNodes, currentTerm: newTerm))
            }
        }
        
        // 2. 候補者がリーダーになる可能性
        if let candidateIndex = state.nodes.firstIndex(where: { $0.role == .candidate && $0.isActive }) {
            var newNodes = state.nodes
            
            // 候補者をリーダーに設定
            newNodes[candidateIndex] = ElectionNodeState(
                id: newNodes[candidateIndex].id,
                role: .leader,
                term: state.currentTerm,
                isActive: true
            )
            
            nextStates.insert(LeaderElectionSystemState(nodes: newNodes, currentTerm: state.currentTerm))
        }
        
        // 3. ノードの障害と回復
        for nodeIndex in 0..<state.nodes.count {
            // 障害
            if state.nodes[nodeIndex].isActive {
                var newNodes = state.nodes
                newNodes[nodeIndex] = ElectionNodeState(
                    id: newNodes[nodeIndex].id,
                    role: newNodes[nodeIndex].role,
                    term: newNodes[nodeIndex].term,
                    isActive: false
                )
                nextStates.insert(LeaderElectionSystemState(nodes: newNodes, currentTerm: state.currentTerm))
            }
            
            // 回復
            if !state.nodes[nodeIndex].isActive {
                var newNodes = state.nodes
                newNodes[nodeIndex] = ElectionNodeState(
                    id: newNodes[nodeIndex].id,
                    role: .unknown,  // 回復時は役割が不明
                    term: state.currentTerm,
                    isActive: true
                )
                nextStates.insert(LeaderElectionSystemState(nodes: newNodes, currentTerm: state.currentTerm))
            }
        }
        
        // 現在の状態も後続状態に含める
        nextStates.insert(state)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // リーダー選出に関する命題
        let hasLeader = state.nodes.contains { $0.role == .leader && $0.isActive }
        if hasLeader {
            trueProps.insert("hasLeader")
        }
        
        let hasMultipleLeaders = state.nodes.filter { $0.role == .leader && $0.isActive }.count > 1
        if hasMultipleLeaders {
            trueProps.insert("hasMultipleLeaders")
        }
        
        // 特定のノードに関する命題
        for (index, node) in state.nodes.enumerated() {
            if node.isActive {
                trueProps.insert("node\(index)Active")
                
                if node.role == .leader {
                    trueProps.insert("node\(index)IsLeader")
                } else if node.role == .follower {
                    trueProps.insert("node\(index)IsFollower")
                } else if node.role == .candidate {
                    trueProps.insert("node\(index)IsCandidate")
                }
            } else {
                trueProps.insert("node\(index)Inactive")
            }
        }
        
        return trueProps
    }
}
```

## ステップ7: リーダー選出プロパティの検証

リーダー選出プロトコルのプロパティを検証します。

```swift
// リーダー選出に関する命題
let hasLeader = TemporalKit.makeProposition(
    id: "hasLeader",
    name: "リーダーが存在する",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in
        state.nodes.contains { $0.role == .leader && $0.isActive }
    }
)

let hasMultipleLeaders = TemporalKit.makeProposition(
    id: "hasMultipleLeaders",
    name: "複数のリーダーが存在する",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in
        state.nodes.filter { $0.role == .leader && $0.isActive }.count > 1
    }
)

let node0IsLeader = TemporalKit.makeProposition(
    id: "node0IsLeader",
    name: "ノード0がリーダー",
    evaluate: { (state: LeaderElectionSystemState) -> Bool in
        guard state.nodes.indices.contains(0) else { return false }
        return state.nodes[0].role == .leader && state.nodes[0].isActive
    }
)

// リーダー選出プロパティ定義
typealias ElectionProp = ClosureTemporalProposition<LeaderElectionSystemState, Bool>
typealias ElectionLTL = LTLFormula<ElectionProp>

// プロパティ1: 「最終的には必ずリーダーが選出される」
let eventuallyLeader = ElectionLTL.eventually(.atomic(hasLeader))

// プロパティ2: 「複数のリーダーが存在することはない（安全性）」
let singleLeader = ElectionLTL.globally(.not(.atomic(hasMultipleLeaders)))

// プロパティ3: 「一旦リーダーが選出されると、そのリーダーは変わらない（安定性）」
let stableLeadership = ElectionLTL.implies(
    .atomic(hasLeader),
    .globally(.atomic(hasLeader))
)

// プロパティ4: 「どのノードもリーダーになる可能性がある（公平性）」
let fairLeaderElection = ElectionLTL.eventually(.atomic(node0IsLeader))

// リーダー選出プロトコルの検証実行
let electionSystem = LeaderElectionSystem(nodeCount: 3)
let electionModelChecker = LTLModelChecker<LeaderElectionSystem>()

do {
    // プロパティごとに検証を実行
    let electionResult1 = try electionModelChecker.check(formula: eventuallyLeader, model: electionSystem)
    let electionResult2 = try electionModelChecker.check(formula: singleLeader, model: electionSystem)
    let electionResult3 = try electionModelChecker.check(formula: stableLeadership, model: electionSystem)
    let electionResult4 = try electionModelChecker.check(formula: fairLeaderElection, model: electionSystem)
    
    // 結果の出力
    print("\nリーダー選出検証結果:")
    print("1. 最終的なリーダー選出: \(electionResult1.holds ? "成立" : "不成立")")
    print("2. 単一リーダー保証: \(electionResult2.holds ? "成立" : "不成立")")
    print("3. リーダーシップの安定性: \(electionResult3.holds ? "成立" : "不成立")")
    print("4. 公平なリーダー選出: \(electionResult4.holds ? "成立" : "不成立")")
    
} catch {
    print("検証エラー: \(error)")
}
```

## まとめ

このチュートリアルでは、TemporalKitを使用して分散システムのモデル化と検証を行う方法を学びました。具体的には以下の点に焦点を当てました：

1. シンプルな分散システムとリーダー選出プロトコルのKripke構造としてのモデル化方法
2. 分散システムの重要なプロパティ（一貫性、耐障害性、リーダー選出など）をLTL式で表現する方法
3. 通信遅延やノード障害などの現実的な挙動をモデルに取り込む方法
4. 分散アルゴリズムの安全性と活性質を検証する方法

分散システムの形式的検証により、複雑な分散アルゴリズムの誤りや共有状態の矛盾を早期に発見し、より堅牢なシステムを構築することができます。

## 次のステップ

- [パフォーマンスの最適化](./OptimizingPerformance.md)で、大規模な分散システムの検証を効率的に行う方法を学びましょう。
- [リアクティブシステムの検証](./VerifyingReactiveSystems.md)で、イベント駆動型の分散システムの検証方法を学びましょう。 
