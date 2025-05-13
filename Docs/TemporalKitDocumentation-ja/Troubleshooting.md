# TemporalKit トラブルシューティングガイド

このガイドでは、TemporalKitを使用する際に発生する可能性のある一般的な問題とその解決策について説明します。

## 目次

- [モデル検査の問題](#モデル検査の問題)
- [パフォーマンスの問題](#パフォーマンスの問題)
- [反例の解釈](#反例の解釈)
- [命題定義の問題](#命題定義の問題)
- [クリプケ構造の問題](#クリプケ構造の問題)
- [LTL式の問題](#ltl式の問題)
- [コンパイルエラー](#コンパイルエラー)

## モデル検査の問題

### 問題: 検査が長時間実行される

**症状**: モデル検査が完了しない、または非常に長い時間がかかる

**考えられる原因**:
- 状態空間が大きすぎる
- 複雑なLTL式
- 非効率的なクリプケ構造の実装

**解決策**:

1. モデルを簡素化する:
   ```swift
   // 元のモデル
   var allStates: Set<State> {
       var states = Set<State>()
       // 数百の状態を生成...
       return states
   }
   
   // 簡素化されたモデル
   var allStates: Set<State> {
       // 最も重要な状態のみに焦点を当てる
       return [.state1, .state2, .state3]
   }
   ```

2. LTL式を単純化する:
   ```swift
   // 複雑な式
   let complexFormula = .globally(.implies(
       .or(.atomic(p1), .atomic(p2)), 
       .eventually(.and(.atomic(q1), .atomic(q2)))
   ))
   
   // 単純化した式
   let simplifiedFormula1 = .globally(.implies(.atomic(p1), .eventually(.atomic(q1))))
   let simplifiedFormula2 = .globally(.implies(.atomic(p2), .eventually(.atomic(q2))))
   // 個別に検証する
   ```

3. 状態の抽象化を使用する:
   ```swift
   // 詳細な状態
   enum DetailedState {
       case initializing(progress: Double)
       case processing(stage: Int, progress: Double)
       case finalizing(status: String)
       // ...
   }
   
   // 抽象化された状態
   enum AbstractState {
       case initializing
       case processing
       case finalizing
       // ...
   }
   ```

### 問題: 予期しない結果

**症状**: モデル検査の結果が予想と異なる

**考えられる原因**:
- LTL式が意図を正確に表現していない
- クリプケ構造の遷移関係が誤っている
- 命題の評価が誤っている

**解決策**:

1. モデル検査のステップをデバッグする:
   ```swift
   // デバッグ情報を追加
   struct MyModel: KripkeStructure {
       func successors(of state: State) -> Set<State> {
           let successors = // 通常の実装
           print("Successors of \(state): \(successors)")
           return successors
       }
       
       func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
           let props = // 通常の実装
           print("Propositions true in \(state): \(props)")
           return props
       }
   }
   ```

2. より小さなモデルとシンプルな式からテストを始める

3. 反例を注意深く検証し、理解する

## パフォーマンスの問題

### 問題: メモリ使用量が多い

**症状**: 大規模なモデルの検査時にメモリ不足エラーが発生する

**考えられる原因**:
- 状態空間が大きすぎる
- メモリリーク
- 非効率的なデータ構造

**解決策**:

1. 状態空間を縮小する:
   - 関連のない詳細を抽象化する
   - 対称性の削減を使用する
   - 検証に必要な状態のみを含める

2. メモリ効率の良いデータ構造を使用する:
   ```swift
   // 非効率的
   var visited = [State: Bool]() // すべての状態を格納
   
   // 効率的
   var visited = Set<State>() // 訪問済みの状態のみを格納
   ```

3. 段階的に検証する:
   - サブコンポーネントを個別に検証する
   - 重要なプロパティから始めて徐々に拡張する

### 問題: 検査速度が遅い

**症状**: 検査の完了に非常に時間がかかる

**考えられる原因**:
- 複雑なLTL式
- 効率の悪いクリプケ構造の実装
- 大きな状態空間

**解決策**:

1. クリプケ構造の実装を最適化する:
   ```swift
   // 非効率的な実装
   func successors(of state: State) -> Set<State> {
       var result = Set<State>()
       for potentialSuccessor in allStates {
           if canTransition(from: state, to: potentialSuccessor) {
               result.insert(potentialSuccessor)
           }
       }
       return result
   }
   
   // 効率的な実装
   func successors(of state: State) -> Set<State> {
       switch state {
       case .s0: return [.s1, .s2]
       case .s1: return [.s3]
       // ...
       }
   }
   ```

2. LTL式を単純化し、複数の小さな検証に分割する

3. 可能であれば並列処理を使用する

## 反例の解釈

### 問題: 反例を理解できない

**症状**: モデル検査で返された反例が複雑すぎて理解できない

**考えられる原因**:
- 複雑なモデル構造
- デバッグ情報の欠如
- 反例の表示形式が読みにくい

**解決策**:

1. 段階的に反例をデバッグする:
   ```swift
   if case .fails(let counterexample) = result {
       print("Prefix (initial path):")
       for (index, state) in counterexample.prefix.enumerated() {
           print("  Step \(index): \(state)")
           // 各状態で真となる命題を表示
           print("    True propositions: \(model.atomicPropositionsTrue(in: state))")
       }
       
       print("Cycle (repeating path):")
       for (index, state) in counterexample.cycle.enumerated() {
           print("  Step \(index): \(state)")
           print("    True propositions: \(model.atomicPropositionsTrue(in: state))")
       }
   }
   ```

2. 視覚化ツールを使用する（独自に実装、または外部ツールと連携）

3. まずは単純なプロパティとモデルで検証し、徐々に複雑さを増やす

## 命題定義の問題

### 問題: 命題が正しく評価されない

**症状**: 命題が期待通りに評価されず、検証結果が誤っている

**考えられる原因**:
- 命題の`evaluate`関数の実装が誤っている
- クリプケ構造の`atomicPropositionsTrue`が誤った結果を返す
- 命題IDの不一致

**解決策**:

1. 命題の評価を個別にテストする:
   ```swift
   // 命題の評価をテスト
   let testState = MyState.someState
   let context = SimpleEvaluationContext(input: testState, traceIndex: 0)
   
   do {
       let result = try myProposition.evaluate(with: context)
       print("Proposition evaluated to: \(result)")
   } catch {
       print("Evaluation error: \(error)")
   }
   ```

2. クリプケ構造の`atomicPropositionsTrue`を検証する:
   ```swift
   for state in model.allStates {
       let trueProps = model.atomicPropositionsTrue(in: state)
       print("State \(state): true propositions = \(trueProps)")
   }
   ```

3. 命題IDの一貫性を確保する:
   ```swift
   // 一貫した命題IDを使用
   let p1ID = PropositionID(rawValue: "p1")
   
   let p1 = TemporalKit.makeProposition(
       id: p1ID,
       name: "Proposition P1",
       evaluate: { /* ... */ }
   )
   
   // クリプケ構造でも同じIDを使用
   func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
       switch state {
       case .s0: return [p1ID]
       // ...
       }
   }
   ```

## クリプケ構造の問題

### 問題: 遷移関係が正しくない

**症状**: モデル検査結果が期待と異なる、または特定の状態に到達できない

**考えられる原因**:
- `successors`関数の実装が誤っている
- 初期状態が正しく設定されていない
- 状態のモデル化が適切でない

**解決策**:

1. 遷移関係を視覚化して確認する:
   ```swift
   func printTransitions() {
       for state in allStates {
           let successorStates = successors(of: state)
           print("\(state) -> \(successorStates)")
       }
   }
   ```

2. 到達可能性分析を実施する:
   ```swift
   func checkReachability(from initialState: State, to targetState: State) -> Bool {
       var visited = Set<State>()
       var queue = [initialState]
       
       while !queue.isEmpty {
           let current = queue.removeFirst()
           if current == targetState { return true }
           if visited.contains(current) { continue }
           
           visited.insert(current)
           queue.append(contentsOf: successors(of: current))
       }
       
       return false
   }
   ```

3. 初期状態から始めて、すべての状態が到達可能かを確認する

### 問題: 状態空間が大きすぎる

**症状**: モデル検査が実行できないか、非常に遅い

**考えられる原因**:
- 状態の表現が詳細すぎる
- 関連のない要素が状態に含まれている
- 状態爆発の問題

**解決策**:

1. 状態の表現を抽象化する:
   ```swift
   // 詳細な状態
   struct DetailedState: Hashable {
       let user: User
       let cart: ShoppingCart
       let orderHistory: [Order]
       let preferences: UserPreferences
       // ...
   }
   
   // 抽象化された状態
   struct AbstractState: Hashable {
       let isLoggedIn: Bool
       let hasItemsInCart: Bool
       let hasCompletedOrders: Bool
       // ...
   }
   ```

2. 対称性の削減テクニックを使用する

3. サブコンポーネントを個別に検証する

## LTL式の問題

### 問題: 式が意図を正確に表現していない

**症状**: 検証結果が期待と異なる、または式が間違っていると思われる

**考えられる原因**:
- LTL式の論理が間違っている
- 時相演算子の誤用
- 複雑な式で考慮漏れがある

**解決策**:

1. 式を段階的に構築し、各ステップでテストする:
   ```swift
   // ステップ1: 基本命題のテスト
   let basicProp = .atomic(p)
   
   // ステップ2: 単純な時相式のテスト
   let simpleFormula = .eventually(basicProp)
   
   // ステップ3: より複雑な式の構築
   let complexFormula = .globally(.implies(conditionProp, simpleFormula))
   ```

2. パターンライブラリを使用する:
   ```swift
   // 再利用可能なパターン
   func alwaysEventually<P: TemporalProposition>(prop: P) -> LTLFormula<P> {
       return .globally(.eventually(.atomic(prop)))
   }
   
   func response<P: TemporalProposition>(trigger: P, response: P) -> LTLFormula<P> {
       return .globally(.implies(.atomic(trigger), .eventually(.atomic(response))))
   }
   ```

3. 式を論理的に分解して理解する:
   ```swift
   // 複雑な式
   let formula = .globally(.implies(
       .and(.atomic(p), .not(.atomic(q))),
       .eventually(.atomic(r))
   ))
   
   // 意味:
   // 常に(p かつ not q の場合、最終的に r が成り立つ)
   ```

## コンパイルエラー

### 問題: 型の不一致エラー

**症状**: `KripkeStructure`、`TemporalProposition`、または`LTLFormula`関連のコンパイルエラー

**考えられる原因**:
- 関連型の不一致
- 命題IDの型の不一致
- ジェネリクスの制約違反

**解決策**:

1. 関連型の一貫性を確保する:
   ```swift
   struct MyModel: KripkeStructure {
       // 明示的に関連型を定義
       typealias State = MyState
       typealias AtomicPropositionIdentifier = String
       
       // ...
   }
   
   // 命題はモデルのAtomicPropositionIdentifierと互換性のあるIDを持つ必要がある
   let myProp = TemporalKit.makeProposition(
       id: "myProp", // String型のID
       name: "My Proposition",
       evaluate: { /* ... */ }
   )
   ```

2. 型パラメータを明示的に指定する:
   ```swift
   // 曖昧さを避けるために型パラメータを明示的に指定
   let formula: LTLFormula<MyProposition> = .eventually(.atomic(myProp))
   ```

3. `.atomic`の使用が正しいことを確認する:
   ```swift
   // 命題型が一致していることを確認
   let formula = LTLFormula<MyProposition>.atomic(myProp)
   // MyPropositionはTemporalPropositionに適合する必要がある
   ```

### 問題: プロトコル要件実装の問題

**症状**: `KripkeStructure`または`TemporalProposition`の実装がコンパイルエラーを引き起こす

**考えられる原因**:
- プロトコル要件の欠落
- 要件の誤った実装
- `Hashable`準拠の問題

**解決策**:

1. すべてのプロトコル要件を実装していることを確認する:
   ```swift
   // KripkeStructureに必要なすべてのメソッドと計算プロパティを実装
   struct MyModel: KripkeStructure {
       typealias State = MyState
       typealias AtomicPropositionIdentifier = String
       
       var allStates: Set<State> { /* ... */ }
       var initialStates: Set<State> { /* ... */ }
       
       func successors(of state: State) -> Set<State> { /* ... */ }
       func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> { /* ... */ }
   }
   ```

2. `Hashable`準拠を正しく実装する:
   ```swift
   struct ComplexState: Hashable {
       let id: String
       let data: [String: Any]
       
       // Hashableの一部の実装
       func hash(into hasher: inout Hasher) {
           hasher.combine(id)
           // 注: Anyは直接ハッシュできないので、idのみを使用
       }
       
       // Equatableの実装
       static func == (lhs: ComplexState, rhs: ComplexState) -> Bool {
           return lhs.id == rhs.id
       }
   }
   ```

3. 適切な型制約を使用する:
   ```swift
   // 型制約を明示的に指定する
   func evaluate<C: EvaluationContext<State>>(with context: C) throws -> Bool where C.Input == State {
       // ...
   }
   ```

このトラブルシューティングガイドが、TemporalKitを使用する際に発生する可能性のある問題の解決に役立つことを願っています。さらに質問や問題がある場合は、GitHubのイシューを通じてご連絡ください。 
