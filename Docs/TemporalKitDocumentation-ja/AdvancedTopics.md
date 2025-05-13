# TemporalKit 高度なトピック

このドキュメントでは、TemporalKitの高度な使用方法と技術的詳細について解説します。基本的な使用方法を既に理解していることを前提としています。

## 目次

- [カスタムアルゴリズムの実装](#カスタムアルゴリズムの実装)
- [高度なLTL式パターン](#高度なltl式パターン)
- [バックエンド検証エンジンの拡張](#バックエンド検証エンジンの拡張)
- [大規模モデルの最適化テクニック](#大規模モデルの最適化テクニック)
- [分散検証](#分散検証)
- [TemporalKitの内部アーキテクチャ](#temporalkitの内部アーキテクチャ)
- [形式検証の理論](#形式検証の理論)

## カスタムアルゴリズムの実装

TemporalKitは拡張可能なアーキテクチャを持っており、独自のモデル検査アルゴリズムを実装することができます。

### モデル検査アルゴリズムの作成

カスタムモデル検査アルゴリズムを実装するには、`LTLModelCheckingAlgorithm`プロトコルに準拠する必要があります：

```swift
public protocol LTLModelCheckingAlgorithm {
    associatedtype Model: KripkeStructure
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool
}
```

実装例：

```swift
struct MyCustomAlgorithm<M: KripkeStructure>: LTLModelCheckingAlgorithm {
    typealias Model = M
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // カスタムアルゴリズムの実装
        
        // 例: 特定のタイプの式に最適化された検証ロジック
        if formula.isSimpleSafetyProperty() {
            return try optimizedSafetyCheck(formula: formula, model: model)
        } else {
            // 一般的なケースには標準アルゴリズムを使用
            let standardAlgorithm = TableauBasedLTLModelChecking<Model>()
            return try standardAlgorithm.check(formula: formula, model: model)
        }
    }
    
    private func optimizedSafetyCheck<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // 安全性プロパティに最適化された実装
        // ...
    }
}
```

### カスタムアルゴリズムの使用

```swift
let customAlgorithm = MyCustomAlgorithm<MyModel>()
let modelChecker = LTLModelChecker<MyModel>(algorithm: customAlgorithm)

// あるいはカスタムモデルチェッカーを直接使用
let customModelChecker = CustomModelChecker<MyModel>(algorithm: customAlgorithm)
```

## 高度なLTL式パターン

複雑なシステム要件を表現するための高度なLTL式パターンを紹介します。

### 応答パターン（Response Pattern）

「イベントPが発生したら、最終的にイベントQが発生する」という応答パターンは、多くのリアルタイムシステムで必要とされます。

```swift
// 応答パターン: G(p -> F(q))
func responsePattern<P: TemporalProposition>(
    trigger: P,
    response: P
) -> LTLFormula<P> {
    return .globally(.implies(.atomic(trigger), .eventually(.atomic(response))))
}

// 境界付き応答: G(p -> F[0,k](q))
// これは「Pが発生したら、k時間単位以内にQが発生する」ことを示します
func boundedResponse<P: TemporalProposition>(
    trigger: P,
    response: P,
    steps: Int
) -> LTLFormula<P> {
    var result: LTLFormula<P> = .atomic(response)
    for _ in 0..<steps {
        result = .or(.atomic(response), .next(result))
    }
    return .globally(.implies(.atomic(trigger), result))
}
```

### 優先順位パターン（Precedence Pattern）

「イベントQが発生する前に、イベントPが発生する必要がある」という優先順位パターン：

```swift
// 優先順位パターン: !q U (p || G(!q))
func precedencePattern<P: TemporalProposition>(
    precondition: P,
    event: P
) -> LTLFormula<P> {
    return .until(
        .not(.atomic(event)),
        .or(.atomic(precondition), .globally(.not(.atomic(event))))
    )
}
```

### チェーンパターン（Chain Pattern）

イベントの特定のシーケンスを表現するためのチェーンパターン：

```swift
// チェーンパターン: G(p -> X(q -> X(r)))
func chainPattern<P: TemporalProposition>(
    events: [P]
) -> LTLFormula<P> {
    guard !events.isEmpty else {
        return .booleanLiteral(true)
    }
    
    var result: LTLFormula<P> = .atomic(events.last!)
    
    for event in events.dropLast().reversed() {
        result = .implies(.atomic(event), .next(result))
    }
    
    return .globally(result)
}
```

## バックエンド検証エンジンの拡張

TemporalKitの検証エンジンを拡張して外部の検証ツールと統合することができます。

### 外部検証ツールとの統合

NuSMV、SPINなどの検証ツールとの統合例：

```swift
class NuSMVIntegration<Model: KripkeStructure>: LTLModelCheckingAlgorithm {
    typealias Model = Model
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // 1. モデルをNuSMV形式に変換
        let smvModel = convertToSMV(model)
        
        // 2. LTL式をNuSMV形式に変換
        let smvFormula = convertFormulaToSMV(formula)
        
        // 3. NuSMVを実行して結果を解析
        let result = runNuSMV(model: smvModel, formula: smvFormula)
        
        // 4. NuSMVの結果をTemporalKitの結果形式に変換
        return convertNuSMVResult(result, model: model)
    }
    
    // NuSMV変換と実行の実装
    // ...
}
```

### マルチエンジン戦略

複数の検証エンジンを使用して結果の信頼性を高める：

```swift
class MultiEngineVerifier<Model: KripkeStructure> {
    let algorithms: [any LTLModelCheckingAlgorithm<Model>]
    
    init(algorithms: [any LTLModelCheckingAlgorithm<Model>]) {
        self.algorithms = algorithms
    }
    
    func verify<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> VerificationResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        var results: [ModelCheckResult<Model.State>] = []
        var errors: [Error] = []
        
        for algorithm in algorithms {
            do {
                let result = try algorithm.check(formula: formula, model: model)
                results.append(result)
            } catch {
                errors.append(error)
            }
        }
        
        return VerificationResult(results: results, errors: errors)
    }
}

struct VerificationResult<State: Hashable> {
    let results: [ModelCheckResult<State>]
    let errors: [Error]
    
    var isConsistent: Bool {
        // すべての結果が一致するかチェック
        if let first = results.first {
            return results.allSatisfy { $0.holds == first.holds }
        }
        return true
    }
    
    var consensus: ModelCheckResult<State>? {
        // 多数決で結果を決定
        // ...
    }
}
```

## 大規模モデルの最適化テクニック

大規模なモデルを効率的に検証するための高度な最適化手法です。

### シンボリックモデル検査

明示的な状態列挙ではなく、シンボリックに状態を表現する手法：

```swift
class SymbolicModelChecker<Model: KripkeStructure> {
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // シンボリックモデル検査の実装
        // 状態をBDDなどのデータ構造で表現
        
        // ...
    }
    
    private func encodeStates(_ states: Set<Model.State>) -> SymbolicRepresentation {
        // 状態をシンボリック表現にエンコード
        // ...
    }
    
    private func fixpointComputation(formula: SymbolicRepresentation, initialStates: SymbolicRepresentation) -> SymbolicRepresentation {
        // 不動点計算による検証
        // ...
    }
}
```

### 部分的順序削減（Partial Order Reduction）

並行システムでは、独立したアクションの順序を削減することでステート空間を縮小できます：

```swift
class PartialOrderReductionOptimizer<Model: KripkeStructure> {
    func optimizeModel(_ model: Model) -> Model {
        // 1. 独立したアクションを特定
        let independentActions = findIndependentActions(model)
        
        // 2. 縮小されたモデルを構築
        return buildReducedModel(model, independentActions: independentActions)
    }
    
    private func findIndependentActions(_ model: Model) -> Set<Action> {
        // 独立したアクションを特定するロジック
        // ...
    }
    
    private func buildReducedModel(_ model: Model, independentActions: Set<Action>) -> Model {
        // 削減されたモデルを構築
        // ...
    }
}
```

### 抽象化と具体化（Abstraction and Refinement）

抽象的なモデルを使って検証し、必要に応じて具体化する反復的アプローチ：

```swift
class AbstractionRefinementVerifier<Model: KripkeStructure> {
    func verifyWithRefinement<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // 初期の抽象化
        var abstractModel = createInitialAbstraction(model)
        let checker = LTLModelChecker<AbstractModel>()
        
        while true {
            // 抽象モデルで検証
            let result = try checker.check(formula: abstractFormula(formula), model: abstractModel)
            
            if case .holds = result {
                // 抽象モデルが満たすなら、元のモデルも満たす
                return .holds
            } else if case .fails(let counterexample) = result {
                // 反例が実際のモデルで有効か確認
                if isCounterexampleValid(counterexample, in: model) {
                    // 有効な反例を返す
                    return .fails(counterexample: mapToOriginalStates(counterexample))
                } else {
                    // 反例に基づいてモデルを精緻化
                    abstractModel = refineModel(abstractModel, counterexample: counterexample)
                }
            }
        }
    }
    
    // 抽象化と精緻化の実装
    // ...
}
```

## 分散検証

複数のマシンを使って大規模なモデル検査を行う手法：

```swift
class DistributedModelChecker<Model: KripkeStructure> {
    let workers: [WorkerNode]
    
    init(workers: [WorkerNode]) {
        self.workers = workers
    }
    
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // 1. モデルを分割
        let partitions = partitionModel(model, workerCount: workers.count)
        
        // 2. 各ワーカーに分割したモデルと式を送信
        let tasks = zip(workers, partitions).map { worker, partition in
            worker.verify(formula: formula, modelPartition: partition)
        }
        
        // 3. 結果を集約
        let results = try awaitAll(tasks)
        
        // 4. 最終結果を決定
        return combineResults(results)
    }
    
    // 分散検証の補助メソッド
    // ...
}
```

## TemporalKitの内部アーキテクチャ

TemporalKitの内部アーキテクチャと拡張点について詳細に解説します。

### コアコンポーネント

```
TemporalKit
├── Core
│   ├── LTLFormula.swift             // LTL式の表現
│   ├── KripkeStructure.swift        // モデルの状態と遷移の表現
│   ├── TemporalProposition.swift    // 命題の表現
│   └── ModelCheckResult.swift       // 検証結果の表現
├── Algorithms
│   ├── LTLModelChecker.swift        // モデル検査のメインクラス
│   ├── TableauGraphConstructor.swift // タブロー法によるグラフ構築
│   ├── LTLFormulaNNFConverter.swift // 否定標準形への変換
│   └── GBAToBAConverter.swift       // オートマトン変換
├── Evaluation
│   ├── EvaluationContext.swift      // 評価コンテキスト
│   ├── LTLFormulaEvaluator.swift    // 式の評価
│   └── LTLFormulaTraceEvaluator.swift // トレースに対する評価
└── DSL
    ├── LTLOperators.swift           // 演算子の定義
    └── LTLDSLExtensions.swift       // DSL構文の拡張
```

### 拡張ポイント

TemporalKitを拡張するための主要なポイント：

1. **カスタム命題の実装**:



   ```swift
   struct MyCustomProposition: TemporalProposition {
       // カスタム実装
   }
   ```



2. **カスタムモデルの実装**:

   ```swift
   struct MyCustomModel: KripkeStructure {
       // カスタム実装

   }
   ```


3. **カスタム検証アルゴリズムの実装**:

   ```swift

   struct MyCustomAlgorithm: LTLModelCheckingAlgorithm {
       // カスタム実装
   }

   ```

4. **カスタム評価コンテキストの実装**:

   ```swift
   struct MyCustomContext: EvaluationContext {
       // カスタム実装
   }
   ```

## 形式検証の理論

TemporalKitの基盤となる理論的背景について解説します。

### LTLとオートマトン理論

LTLの検証は通常、オートマトン理論に基づいて実装されます。主なステップは以下の通りです：

1. LTL式の否定を取る
2. 式を一般化ビューヒオートマトン（GBA）に変換する
3. GBAをビューヒオートマトン（BA）に変換する
4. モデルとBAの積を構築する
5. 受理サイクルを探索する

```swift
// 簡略化されたプロセス
func ltlToAutomaton<P: TemporalProposition>(formula: LTLFormula<P>) -> Automaton {
    // 1. 否定標準形に変換
    let nnfFormula = formula.toNNF()
    
    // 2. 式の構文からノード作成
    let nodes = createTableauNodes(from: nnfFormula)
    
    // 3. ノード間の遷移関係を構築
    let transitions = buildTransitions(between: nodes)
    
    // 4. 受理条件を構築
    let acceptanceConditions = buildAcceptanceConditions(for: nnfFormula, nodes: nodes)
    
    return Automaton(
        states: nodes,
        initialStates: nodesContainingFormula(nnfFormula),
        transitions: transitions,
        acceptanceConditions: acceptanceConditions
    )
}
```

### タブロー法

タブロー法は、LTL式から非決定性ビューヒオートマトンを構築するための手法です：

```swift
class TableauGraphConstructor<P: TemporalProposition> {
    func constructTableau(for formula: LTLFormula<P>) -> TableauGraph<P> {
        // 1. 式の要素分解（closure）を計算
        let closure = computeClosure(formula)
        
        // 2. 整合的な部分集合を見つける
        let consistentSubsets = findConsistentSubsets(closure)
        
        // 3. グラフノードを作成
        let nodes = consistentSubsets.map { TableauNode(formulas: $0) }
        
        // 4. 遷移関係を構築
        let edges = buildEdges(between: nodes)
        
        // 5. 受理集合を構築
        let acceptanceSets = buildAcceptanceSets(nodes: nodes, originalFormula: formula)
        
        return TableauGraph(
            nodes: nodes,
            initialNodes: findInitialNodes(nodes, formula: formula),
            edges: edges,
            acceptanceSets: acceptanceSets
        )
    }
    
    // タブロー法の補助メソッド
    // ...
}
```

### オンザフライモデル検査

メモリ使用量を抑えるためのオンザフライアルゴリズムの概念：

```swift
class OnTheFlyModelChecker<Model: KripkeStructure> {
    func check<P: TemporalProposition>(
        formula: LTLFormula<P>,
        model: Model
    ) throws -> ModelCheckResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // 1. LTL式の否定をとる
        let negatedFormula = LTLFormula<P>.not(formula)
        
        // 2. オンザフライでタブローを構築しながら探索
        let result = try searchProductGraph(model: model, formula: negatedFormula)
        
        // 3. 結果を解釈
        if result.acceptingCycleFound {
            return .fails(counterexample: result.counterexample)
        } else {
            return .holds
        }
    }
    
    private func searchProductGraph<P: TemporalProposition>(
        model: Model,
        formula: LTLFormula<P>
    ) throws -> SearchResult<Model.State> where P.ID == Model.AtomicPropositionIdentifier, P.Value == Bool {
        // ネスト深度優先探索を使用して受理サイクルを探索
        // 必要に応じてタブローノードを拡張
        // ...
    }
}
```

## まとめ

このドキュメントでは、TemporalKitの高度な使用方法と技術的詳細について説明しました。これらの高度なトピックを解し活用することで、より複雑なシステムを効率的に検証できるようになります。

特に大規模なモデルの検証には、最適化テクニックや分散検証の知識が重要です。また、カスタムアルゴリズムの実装により、特定のドメインや問題に特化した効率的な検証が可能になります。

形式検証の理論的背景を理解することで、TemporalKitをより効果的に使用し、必要に応じて拡張することができます。
