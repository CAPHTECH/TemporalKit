# パフォーマンスの最適化

このチュートリアルでは、TemporalKitを使用したモデル検査のパフォーマンスを最適化する方法を学びます。大規模なシステムやより複雑なプロパティを検証する際に発生する可能性のある状態爆発問題に対処するためのテクニックを紹介します。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- 状態空間爆発の問題を理解し対処する
- モデル検査のパフォーマンスを向上させるテクニックを適用する
- 大規模システムに対してTemporalKitを効率的に使用する
- パフォーマンスボトルネックを特定し解決する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること
- [簡単なモデル検査](./SimpleModelChecking.md)のチュートリアルを完了していること

## ステップ1: 状態爆発問題の理解

状態爆発は、モデル検査において最も一般的な課題の1つです。システムの状態数が変数や並行コンポーネントの数に対して指数関数的に増加する現象です。

```swift
import TemporalKit

// n個のバイナリ変数を持つシステムの状態数は2^n
func stateSpaceSize(variableCount: Int) -> Int {
    return Int(pow(2.0, Double(variableCount)))
}

print("変数の数と状態空間サイズの関係:")
for i in 1...20 {
    print("\(i)個の変数: \(stateSpaceSize(variableCount: i))状態")
}

// たとえば10個の変数があるシステムでは、1024の状態が存在する可能性があります
// 20個の変数では、1,048,576の状態が存在する可能性があります
```

## ステップ2: 状態空間の削減テクニック

状態空間を削減するいくつかのテクニックを見ていきましょう。

### 2.1 到達可能状態の制限

システムの初期状態から実際に到達可能な状態のみを考慮することで、状態空間を大幅に削減できます。

```swift
// 例: より効率的なKripke構造の実装
struct OptimizedCounterModel: KripkeStructure {
    typealias State = Int
    typealias AtomicPropositionIdentifier = PropositionID
    
    let minValue: Int
    let maxValue: Int
    let initialState: Int
    
    // 遅延計算のための保存済み状態リスト
    private var _allStates: Set<State>?
    private let _initialStates: Set<State>
    
    init(minValue: Int = 0, maxValue: Int = 100, initialState: Int = 0) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.initialState = initialState
        self._initialStates = [initialState]
    }
    
    var initialStates: Set<State> {
        return _initialStates
    }
    
    var allStates: Set<State> {
        // 必要なときだけ計算し、以後はキャッシュを使用
        if let states = _allStates {
            return states
        }
        
        // 初期状態からの到達可能な状態のみを計算
        var states = Set<State>()
        var frontier = [initialState]
        
        while !frontier.isEmpty {
            let state = frontier.removeFirst()
            
            if states.contains(state) {
                continue
            }
            
            states.insert(state)
            
            // 次の状態を計算
            let nextStates = successors(of: state)
            for nextState in nextStates {
                if !states.contains(nextState) {
                    frontier.append(nextState)
                }
            }
        }
        
        _allStates = states
        return states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // インクリメント
        if state + 1 <= maxValue {
            nextStates.insert(state + 1)
        }
        
        // デクリメント
        if state - 1 >= minValue {
            nextStates.insert(state - 1)
        }
        
        // リセット
        nextStates.insert(0)
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        if state == 0 {
            trueProps.insert("isZero")
        }
        
        if state > 0 {
            trueProps.insert("isPositive")
        }
        
        if state % 2 == 0 {
            trueProps.insert("isEven")
        }
        
        return trueProps
    }
}
```

### 2.2 状態の対称性を活用

多くのシステムには対称性があり、等価な状態を1つにまとめることで状態空間を削減できます。

```swift
// 例: 対称性を活用したシステム状態の定義
struct SymmetricSystemState: Hashable {
    let processes: [ProcessState]
    
    // プロセスの状態を表す列挙型
    enum ProcessState: Int, Hashable {
        case idle
        case active
        case finished
    }
    
    // 対称性を考慮したHashableの実装
    func hash(into hasher: inout Hasher) {
        // プロセス状態の数を数える（順序を無視）
        var counts = [0, 0, 0] // idle, active, finishedの数
        for state in processes {
            counts[state.rawValue] += 1
        }
        
        // 各状態の数だけをハッシュ化
        for count in counts {
            hasher.combine(count)
        }
    }
    
    // 対称性を考慮した等価性チェック
    static func == (lhs: SymmetricSystemState, rhs: SymmetricSystemState) -> Bool {
        guard lhs.processes.count == rhs.processes.count else { return false }
        
        // プロセス状態の数を数える
        var lhsCounts = [0, 0, 0]
        var rhsCounts = [0, 0, 0]
        
        for state in lhs.processes {
            lhsCounts[state.rawValue] += 1
        }
        
        for state in rhs.processes {
            rhsCounts[state.rawValue] += 1
        }
        
        // 各状態の数が同じであれば等価とみなす
        return lhsCounts == rhsCounts
    }
}
```

### 2.3 抽象化とモデル縮小

システムの詳細度を下げて抽象モデルを作成することで、状態空間を削減できます。

```swift
// 例: 抽象化を使用したシステムモデルの定義
enum AbstractTemperature: Hashable {
    case cold    // 0°C未満
    case normal  // 0-30°C
    case hot     // 30°C以上
    
    // 具体的な温度値から抽象値への変換
    static func fromActual(_ temperature: Double) -> AbstractTemperature {
        if temperature < 0 {
            return .cold
        } else if temperature < 30 {
            return .normal
        } else {
            return .hot
        }
    }
}

// 抽象化された温度制御システム
struct AbstractTemperatureControlSystem: KripkeStructure {
    typealias State = AbstractTemperature
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State> = [.cold, .normal, .hot]
    let initialStates: Set<State> = [.normal]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .cold:
            return [.cold, .normal]
        case .normal:
            return [.cold, .normal, .hot]
        case .hot:
            return [.normal, .hot]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var props = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .cold:
            props.insert("isCold")
        case .normal:
            props.insert("isNormal")
        case .hot:
            props.insert("isHot")
        }
        
        return props
    }
}
```

## ステップ3: アルゴリズム最適化

TemporalKitのモデル検査アルゴリズムを最適化する方法をいくつか見ていきましょう。

### 3.1 バッチ処理とタスク分割

大きなモデルを検証する場合、検証作業を小さなバッチに分けると効率的です。

```swift
// 大規模モデルをバッチで検証するヘルパー関数
func verifyInBatches<M: KripkeStructure, P: TemporalProposition>(
    formula: LTLFormula<P>,
    model: M,
    batchSize: Int = 1000,
    progressHandler: ((Double) -> Void)? = nil
) throws -> ModelCheckResult<M.State> where P.Value == Bool {
    let modelChecker = LTLModelChecker<M>()
    
    // モデルの初期状態から到達可能な状態をすべて列挙
    var allStates = Set<M.State>()
    var frontier = Array(model.initialStates)
    var visited = Set<M.State>()
    
    while !frontier.isEmpty {
        let state = frontier.removeFirst()
        
        if visited.contains(state) {
            continue
        }
        
        visited.insert(state)
        allStates.insert(state)
        
        let successors = model.successors(of: state)
        for successor in successors {
            if !visited.contains(successor) {
                frontier.append(successor)
            }
        }
    }
    
    // 状態をバッチに分割
    let statesArray = Array(allStates)
    let totalBatches = (statesArray.count + batchSize - 1) / batchSize
    
    // 各バッチに対して検証を行う
    for batchIndex in 0..<totalBatches {
        let start = batchIndex * batchSize
        let end = min(start + batchSize, statesArray.count)
        let batchStates = Set(statesArray[start..<end])
        
        // ここでbatchStatesに対する検証を行う
        // （実際のTemporalKitの内部実装には直接アクセスできないため、
        // これは概念的な例となります）
        
        // 進捗報告
        let progress = Double(batchIndex + 1) / Double(totalBatches)
        progressHandler?(progress)
    }
    
    // 最終的な検証結果を返す
    return try modelChecker.check(formula: formula, model: model)
}
```

### 3.2 キャッシングとメモ化

中間結果をキャッシュすることで、重複計算を避けることができます。

```swift
// キャッシングを使用したLTL式評価の例
class CachingLTLEvaluator<S, P: TemporalProposition> where P.Value == Bool {
    // 評価結果のキャッシュ
    private var cache: [ObjectIdentifier: [S: Bool]] = [:]
    
    // キャッシュを使用した式の評価
    func evaluate(formula: LTLFormula<P>, state: S, context: EvaluationContext) -> Bool {
        let formulaId = ObjectIdentifier(formula)
        
        // キャッシュを確認
        if let stateCache = cache[formulaId], let result = stateCache[state] {
            return result
        }
        
        // キャッシュがない場合は評価を実行
        var result: Bool
        
        switch formula {
        case let .atomic(proposition):
            result = proposition.evaluate(with: context)
            
        case let .or(left, right):
            result = evaluate(formula: left, state: state, context: context) ||
                    evaluate(formula: right, state: state, context: context)
            
        case let .and(left, right):
            result = evaluate(formula: left, state: state, context: context) &&
                    evaluate(formula: right, state: state, context: context)
            
        // その他の式についても同様に実装...
        default:
            // 簡略化のため、他のケースは省略
            result = false
        }
        
        // 結果をキャッシュに保存
        if cache[formulaId] == nil {
            cache[formulaId] = [:]
        }
        cache[formulaId]?[state] = result
        
        return result
    }
    
    // キャッシュをクリア
    func clearCache() {
        cache.removeAll()
    }
}
```

### 3.3 並行処理の活用

マルチコアプロセッサを活用するために、検証作業を並列化することもできます。

```swift
// 並行処理を使用したモデル検査
func parallelModelCheck<M: KripkeStructure, P: TemporalProposition>(
    formula: LTLFormula<P>,
    model: M,
    concurrencyLevel: Int = ProcessInfo.processInfo.activeProcessorCount
) throws -> ModelCheckResult<M.State> where P.Value == Bool {
    // 状態空間を分割
    let allStates = Array(model.allStates)
    let chunkSize = max(1, allStates.count / concurrencyLevel)
    
    // 各チャンクを処理するDispatchGroup
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "com.temporalkit.modelcheck", attributes: .concurrent)
    
    // 各チャンクの結果を保存
    var results: [ModelCheckResult<M.State>?] = Array(repeating: nil, count: concurrencyLevel)
    var errors: [Error?] = Array(repeating: nil, count: concurrencyLevel)
    
    // 各チャンクを並行処理
    for i in 0..<concurrencyLevel {
        let start = i * chunkSize
        let end = i == concurrencyLevel - 1 ? allStates.count : (i + 1) * chunkSize
        
        guard start < end, start < allStates.count else { continue }
        
        group.enter()
        queue.async {
            let chunkStates = Set(allStates[start..<min(end, allStates.count)])
            
            // 各チャンクに対するモデル検査を実行
            // （実際のTemporalKitの内部実装には直接アクセスできないため、
            // これは概念的な例となります）
            
            // ここで本来はチャンクに対するLTLモデル検査を実行し、結果をresults[i]に格納
            
            group.leave()
        }
    }
    
    // すべての処理が完了するのを待つ
    group.wait()
    
    // エラーがあればスロー
    for error in errors {
        if let error = error {
            throw error
        }
    }
    
    // 結果を統合（実装は簡略化）
    let modelChecker = LTLModelChecker<M>()
    return try modelChecker.check(formula: formula, model: model)
}
```

## ステップ4: メモリ効率の向上

メモリ使用量を削減するテクニックを見ていきましょう。

### 4.1 メモリ効率の良いデータ構造

状態表現に効率的なデータ構造を使用することでメモリ使用量を削減できます。

```swift
// メモリ効率の良い状態表現
struct CompactSystemState: Hashable {
    // フラグのビットマスクとして状態を表現
    private let stateBits: UInt64
    
    // 状態のインデックスとその値のエンコード/デコード
    init(values: [Bool]) {
        var bits: UInt64 = 0
        for (index, value) in values.enumerated() {
            if value && index < 64 {
                bits |= (1 << index)
            }
        }
        self.stateBits = bits
    }
    
    // 特定のインデックスの状態を取得
    func value(at index: Int) -> Bool {
        guard index < 64 else { return false }
        return (stateBits & (1 << index)) != 0
    }
    
    // メモリ使用量の比較
    static func compareMemoryUsage() {
        let standardState = Array(repeating: false, count: 64)
        let compactState = CompactSystemState(values: standardState)
        
        print("標準的な状態表現（[Bool]）: \(MemoryLayout<[Bool]>.size(ofValue: standardState)) バイト")
        print("コンパクトな状態表現: \(MemoryLayout<CompactSystemState>.size) バイト")
    }
}

// ビット圧縮を使用した小さい整数の配列
struct CompactIntArray: Hashable {
    // 4ビットの整数をUInt64に詰め込む（16個まで格納可能）
    private let storage: [UInt64]
    private let count: Int
    private let bitsPerValue: Int
    
    init(values: [Int], bitsPerValue: Int = 4) {
        self.bitsPerValue = bitsPerValue
        self.count = values.count
        
        let valuesPerWord = 64 / bitsPerValue
        let wordCount = (values.count + valuesPerWord - 1) / valuesPerWord
        
        var result = [UInt64](repeating: 0, count: wordCount)
        
        for (index, value) in values.enumerated() {
            let wordIndex = index / valuesPerWord
            let bitPosition = (index % valuesPerWord) * bitsPerValue
            let mask = UInt64((1 << bitsPerValue) - 1)
            
            result[wordIndex] |= UInt64(value & Int(mask)) << bitPosition
        }
        
        self.storage = result
    }
    
    func value(at index: Int) -> Int {
        guard index < count else { return 0 }
        
        let valuesPerWord = 64 / bitsPerValue
        let wordIndex = index / valuesPerWord
        let bitPosition = (index % valuesPerWord) * bitsPerValue
        let mask = UInt64((1 << bitsPerValue) - 1)
        
        return Int((storage[wordIndex] >> bitPosition) & mask)
    }
}
```

### 4.2 遅延評価とストリーミング

遅延評価を使用して、必要なときだけ状態を生成するようにすることでメモリ使用量を削減できます。

```swift
// 遅延状態生成を使用した効率的なモデル表現
struct LazyKripkeStructure<S: Hashable>: KripkeStructure {
    typealias State = S
    typealias AtomicPropositionIdentifier = PropositionID
    
    private let _initialStates: Set<State>
    private let _successorsFunction: (State) -> Set<State>
    private let _propositionFunction: (State) -> Set<AtomicPropositionIdentifier>
    
    init(
        initialStates: Set<State>,
        successorsFunction: @escaping (State) -> Set<State>,
        propositionFunction: @escaping (State) -> Set<AtomicPropositionIdentifier>
    ) {
        self._initialStates = initialStates
        self._successorsFunction = successorsFunction
        self._propositionFunction = propositionFunction
    }
    
    var initialStates: Set<State> {
        return _initialStates
    }
    
    // 注意: すべての状態を事前に計算しない
    var allStates: Set<State> {
        // 実際の実装では、ここで初期状態から到達可能なすべての状態を計算します
        // 大規模システムでは、この操作は避けるべきです
        var result = Set<State>()
        var frontier = Array(initialStates)
        
        while !frontier.isEmpty {
            let state = frontier.removeFirst()
            if result.contains(state) {
                continue
            }
            
            result.insert(state)
            
            let successors = self.successors(of: state)
            for successor in successors {
                if !result.contains(successor) {
                    frontier.append(successor)
                }
            }
        }
        
        return result
    }
    
    func successors(of state: State) -> Set<State> {
        return _successorsFunction(state)
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        return _propositionFunction(state)
    }
}
```

## ステップ5: 実践的な最適化例

以上のテクニックを組み合わせた、実践的な最適化例を見てみましょう。

```swift
// 巨大な状態空間を持つトラフィックライトシステムの例
enum LightColor: UInt8 {
    case red = 0
    case yellow = 1
    case green = 2
}

// 効率的な状態表現
struct OptimizedTrafficLightState: Hashable {
    // 交差点の各方向のライトの色を圧縮して格納
    // 各ライトは2ビットで表現でき、32方向まで対応可能
    private let northSouth: UInt64
    private let eastWest: UInt64
    
    init(directions: Int = 16) {
        // 初期状態として、全方向が赤
        self.northSouth = 0
        self.eastWest = 0
    }
    
    // カスタムイニシャライザ（特定の方向に特定の色を設定）
    init(northSouth: [LightColor], eastWest: [LightColor]) {
        var nsValue: UInt64 = 0
        var ewValue: UInt64 = 0
        
        for (i, color) in northSouth.enumerated() where i < 32 {
            nsValue |= UInt64(color.rawValue) << (i * 2)
        }
        
        for (i, color) in eastWest.enumerated() where i < 32 {
            ewValue |= UInt64(color.rawValue) << (i * 2)
        }
        
        self.northSouth = nsValue
        self.eastWest = ewValue
    }
    
    // 特定の方向と向きのライトの色を取得
    func lightColor(direction: Int, isNorthSouth: Bool) -> LightColor {
        guard direction < 32 else { return .red }
        
        let bits = isNorthSouth ? northSouth : eastWest
        let shift = direction * 2
        let colorValue = (bits >> shift) & 0b11
        
        return LightColor(rawValue: UInt8(colorValue)) ?? .red
    }
    
    // 新しい状態を生成（特定の方向と向きのライトの色を変更）
    func changing(direction: Int, isNorthSouth: Bool, to color: LightColor) -> OptimizedTrafficLightState {
        guard direction < 32 else { return self }
        
        let shift = direction * 2
        let mask: UInt64 = ~(0b11 << shift)
        let colorBits = UInt64(color.rawValue) << shift
        
        if isNorthSouth {
            let newNS = (northSouth & mask) | colorBits
            return OptimizedTrafficLightState(northSouthBits: newNS, eastWestBits: eastWest)
        } else {
            let newEW = (eastWest & mask) | colorBits
            return OptimizedTrafficLightState(northSouthBits: northSouth, eastWestBits: newEW)
        }
    }
    
    // 内部ビット表現を使用した直接初期化（パフォーマンス向上のため）
    private init(northSouthBits: UInt64, eastWestBits: UInt64) {
        self.northSouth = northSouthBits
        self.eastWest = eastWestBits
    }
}

// 最適化されたトラフィックシステムモデル
struct OptimizedTrafficSystem: KripkeStructure {
    typealias State = OptimizedTrafficLightState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let directions: Int
    let initialStates: Set<State>
    
    init(directions: Int = 16) {
        self.directions = directions
        self.initialStates = [OptimizedTrafficLightState(directions: directions)]
    }
    
    var allStates: Set<State> {
        // 遅延計算または抽象化を使用
        fatalError("状態空間が大きすぎるため、明示的に計算しません")
    }
    
    func successors(of state: State) -> Set<State> {
        var result = Set<State>()
        
        // 各方向のライトを変更する可能性を考慮
        // （実際のロジックは信号機のルールに基づく）
        
        // 簡略化のため、ここでは最初の方向のみ考慮
        let currentNS = state.lightColor(direction: 0, isNorthSouth: true)
        let currentEW = state.lightColor(direction: 0, isNorthSouth: false)
        
        // 信号機の状態遷移ルール（簡略化）
        switch (currentNS, currentEW) {
        case (.red, .red):
            // 北南が緑になる可能性
            result.insert(state.changing(direction: 0, isNorthSouth: true, to: .green))
            
        case (.green, .red):
            // 北南が黄色になる可能性
            result.insert(state.changing(direction: 0, isNorthSouth: true, to: .yellow))
            
        case (.yellow, .red):
            // 北南が赤になり、東西が緑になる可能性
            let newState = state.changing(direction: 0, isNorthSouth: true, to: .red)
            result.insert(newState.changing(direction: 0, isNorthSouth: false, to: .green))
            
        case (.red, .green):
            // 東西が黄色になる可能性
            result.insert(state.changing(direction: 0, isNorthSouth: false, to: .yellow))
            
        case (.red, .yellow):
            // 東西が赤になる可能性
            result.insert(state.changing(direction: 0, isNorthSouth: false, to: .red))
            
        default:
            // 不正な状態（同時に緑など）は考慮しない
            break
        }
        
        return result
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var result = Set<AtomicPropositionIdentifier>()
        
        // 必要な命題のみを計算（メモリ効率のため）
        // 例: 北南方向の最初の信号が緑かどうか
        if state.lightColor(direction: 0, isNorthSouth: true) == .green {
            result.insert("ns0_green")
        }
        
        // 例: 東西方向の最初の信号が赤かどうか
        if state.lightColor(direction: 0, isNorthSouth: false) == .red {
            result.insert("ew0_red")
        }
        
        // 安全性プロパティ: 対向する方向が同時に緑になっていないか
        if state.lightColor(direction: 0, isNorthSouth: true) != .green ||
           state.lightColor(direction: 0, isNorthSouth: false) != .green {
            result.insert("safe_intersection")
        }
        
        return result
    }
}
```

## ステップ6: パフォーマンス計測とプロファイリング

最適化の効果を測定する方法を見てみましょう。

```swift
// パフォーマンスを計測する簡単なユーティリティ
struct PerformanceMeasurement {
    static func measure(description: String, iterations: Int = 1, operation: () throws -> Void) rethrows {
        let start = Date()
        
        for _ in 0..<iterations {
            try operation()
        }
        
        let end = Date()
        let elapsed = end.timeIntervalSince(start)
        let average = elapsed / Double(iterations)
        
        print("\(description):")
        print("  合計時間: \(elapsed) 秒")
        print("  平均時間: \(average) 秒")
        print("  反復回数: \(iterations)")
    }
}

// メモリ使用量を計測する簡単なユーティリティ
struct MemoryMeasurement {
    static func currentMemoryUsage() -> Int64 {
        // 実際の実装はプラットフォーム依存
        // macOSの例（簡略化）
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return -1
        }
    }
    
    static func measure(description: String, operation: () throws -> Void) rethrows {
        let before = currentMemoryUsage()
        try operation()
        let after = currentMemoryUsage()
        
        print("\(description):")
        print("  使用前メモリ: \(before / 1024 / 1024) MB")
        print("  使用後メモリ: \(after / 1024 / 1024) MB")
        print("  差分: \((after - before) / 1024 / 1024) MB")
    }
}

// 最適化前後のパフォーマンス比較
func compareOptimizations() {
    // 最適化前のシンプルなモデル
    struct SimpleTrafficState: Hashable {
        let lights: [[LightColor]]
    }
    
    struct SimpleTrafficSystem: KripkeStructure {
        typealias State = SimpleTrafficState
        typealias AtomicPropositionIdentifier = PropositionID
        
        let directions: Int
        let initialStates: Set<State>
        
        // 他のメソッドは省略
        func successors(of state: State) -> Set<State> { return [] }
        func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> { return [] }
        var allStates: Set<State> { return initialStates }
    }
    
    // メモリ使用量の比較
    print("状態表現のメモリ使用量比較:")
    
    MemoryMeasurement.measure(description: "単純な表現") {
        let simpleStates = (0..<1000).map { _ in
            SimpleTrafficState(lights: Array(repeating: Array(repeating: .red, count: 32), count: 2))
        }
        _ = simpleStates.count
    }
    
    MemoryMeasurement.measure(description: "最適化された表現") {
        let optimizedStates = (0..<1000).map { _ in
            OptimizedTrafficLightState(directions: 32)
        }
        _ = optimizedStates.count
    }
    
    // 実行時間の比較
    print("\n状態遷移計算の実行時間比較:")
    
    let simpleState = SimpleTrafficState(lights: Array(repeating: Array(repeating: .red, count: 16), count: 2))
    let optimizedState = OptimizedTrafficLightState(directions: 16)
    
    let simpleSystem = SimpleTrafficSystem(directions: 16, initialStates: [simpleState])
    let optimizedSystem = OptimizedTrafficSystem(directions: 16)
    
    // 実際にはここで状態遷移計算のパフォーマンスを計測
}
```

## まとめ

このチュートリアルでは、TemporalKitを使用したモデル検査のパフォーマンスを最適化するさまざまなテクニックを学びました。特に以下の点に焦点を当てました：

1. 状態爆発問題の理解と対処方法
2. 状態空間を削減するテクニック（到達可能状態の制限、対称性の活用、抽象化）
3. アルゴリズムの最適化（バッチ処理、キャッシング、並行処理）
4. メモリ効率の向上（効率的なデータ構造、遅延評価）
5. 実践的な最適化例と効果の測定方法

これらのテクニックを適切に組み合わせることで、大規模なシステムでもTemporalKitを効果的に使用できるようになります。

## 次のステップ

- [並行システムの検証](./ConcurrentSystemVerification.md)で、並行性に特化した最適化テクニックを学びましょう。
- [分散システムのモデル化](./ModelingDistributedSystems.md)で、分散システムのモデル化と検証方法を学びましょう。
- [リアクティブシステムの検証](./VerifyingReactiveSystems.md)で、イベント駆動型システムの効率的な検証方法を学びましょう。 
