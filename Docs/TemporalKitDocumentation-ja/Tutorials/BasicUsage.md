# はじめてのTemporalKit

このチュートリアルでは、TemporalKitの基本的な使い方を学びます。TemporalKitは線形時相論理（LTL）を使用してシステムの動作を検証するためのSwiftライブラリです。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- 基本的なLTL式を作成する
- 命題を定義する
- 簡単なシステムモデルを作成する
- モデル検査を実行する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- Swift Package Managerを使用してTemporalKitをインストール済み

## ステップ1: プロジェクトの設定

まず、Swiftプロジェクトを作成し、TemporalKitをインポートします。

```swift
import TemporalKit
```

## ステップ2: シンプルなシステムの状態をモデル化する

最初に、検証したいシステムの状態を表現する列挙型を作成します。例として、信号機のモデルを作成します。

```swift
// 信号機の状態
enum TrafficLightState: Hashable {
    case red
    case yellow
    case green
}
```

## ステップ3: 命題を定義する

次に、システムの状態に対して評価できる命題を定義します。各命題は状態に対する真偽値を返します。

```swift
// 信号機の命題
let isRed = TemporalKit.makeProposition(
    id: "isRed",
    name: "信号が赤色である",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .red
    }
)

let isYellow = TemporalKit.makeProposition(
    id: "isYellow",
    name: "信号が黄色である",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .yellow
    }
)

let isGreen = TemporalKit.makeProposition(
    id: "isGreen",
    name: "信号が緑色である",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .green
    }
)
```

## ステップ4: クリプケ構造を実装する

次に、システムの状態遷移モデルを表現するクリプケ構造を実装します。このモデルは、どの状態から他のどの状態に遷移できるかを定義します。

```swift
// 信号機モデル
struct TrafficLightModel: KripkeStructure {
    typealias State = TrafficLightState
    typealias AtomicPropositionIdentifier = String
    
    // すべての状態
    let allStates: Set<State> = [.red, .yellow, .green]
    
    // 初期状態（赤から始まる）
    let initialStates: Set<State> = [.red]
    
    // 状態遷移関数
    func successors(of state: State) -> Set<State> {
        switch state {
        case .red:
            return [.green]  // 赤 → 緑
        case .green:
            return [.yellow] // 緑 → 黄
        case .yellow:
            return [.red]    // 黄 → 赤
        }
    }
    
    // 各状態で真となる命題のID
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .red:
            return ["isRed"]
        case .yellow:
            return ["isYellow"]
        case .green:
            return ["isGreen"]
        }
    }
}
```

## ステップ5: LTL式を作成する

次に、検証したいプロパティをLTL式として表現します。例えば、以下のようなプロパティを検証できます：

1. 「黄色の後は必ず赤になる」
2. 「常に最終的に赤になる」
3. 「赤の次は緑になる」

```swift
// 「黄色の後は必ず赤になる」
let yellowThenRed = LTLFormula<ClosureTemporalProposition<TrafficLightState, Bool>>.globally(
    .implies(
        .atomic(isYellow),
        .next(.atomic(isRed))
    )
)

// 「常に最終的に赤になる」（DSL記法を使用）
let eventuallyRed = G(F(.atomic(isRed)))

// 「赤の次は緑になる」
let redThenGreen = G(.implies(.atomic(isRed), X(.atomic(isGreen))))
```

## ステップ6: モデル検査を実行する

最後に、作成したモデルに対してLTL式を検証します。

```swift
// モデルチェッカーを作成
let modelChecker = LTLModelChecker<TrafficLightModel>()
let model = TrafficLightModel()

do {
    // 各プロパティを検証
    let result1 = try modelChecker.check(formula: yellowThenRed, model: model)
    let result2 = try modelChecker.check(formula: eventuallyRed, model: model)
    let result3 = try modelChecker.check(formula: redThenGreen, model: model)
    
    // 結果を表示
    print("黄色の後は必ず赤になる: \(result1.holds ? "成立" : "不成立")")
    print("常に最終的に赤になる: \(result2.holds ? "成立" : "不成立")")
    print("赤の次は緑になる: \(result3.holds ? "成立" : "不成立")")
    
    // 反例がある場合は表示
    if case .fails(let counterexample) = result1 {
        print("反例：\(counterexample)")
    }
} catch {
    print("検証エラー：\(error)")
}
```

## ステップ7: 結果を分析する

モデル検査の結果を分析して、プロパティが成立するかどうか、また反例が存在する場合はその意味を理解します。例えば、以下のような出力が期待されます：

```
黄色の後は必ず赤になる: 成立
常に最終的に赤になる: 成立
赤の次は緑になる: 成立
```

これは我々のモデルが正しく動作していることを示しています。もし結果が「不成立」であれば、反例を分析して問題を特定することができます。

## 完全なコード例

以下は、ここまでのステップをまとめた完全なコード例です：

```swift
import TemporalKit

// 信号機の状態
enum TrafficLightState: Hashable {
    case red
    case yellow
    case green
}

// 信号機モデル
struct TrafficLightModel: KripkeStructure {
    typealias State = TrafficLightState
    typealias AtomicPropositionIdentifier = String
    
    let allStates: Set<State> = [.red, .yellow, .green]
    let initialStates: Set<State> = [.red]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .red:
            return [.green]
        case .green:
            return [.yellow]
        case .yellow:
            return [.red]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        switch state {
        case .red:
            return ["isRed"]
        case .yellow:
            return ["isYellow"]
        case .green:
            return ["isGreen"]
        }
    }
}

// 命題の定義
let isRed = TemporalKit.makeProposition(
    id: "isRed",
    name: "信号が赤色である",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .red
    }
)

let isYellow = TemporalKit.makeProposition(
    id: "isYellow",
    name: "信号が黄色である",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .yellow
    }
)

let isGreen = TemporalKit.makeProposition(
    id: "isGreen",
    name: "信号が緑色である",
    evaluate: { (state: TrafficLightState) -> Bool in
        return state == .green
    }
)

// LTL式の定義
let yellowThenRed = LTLFormula<ClosureTemporalProposition<TrafficLightState, Bool>>.globally(
    .implies(
        .atomic(isYellow),
        .next(.atomic(isRed))
    )
)

let eventuallyRed = G(F(.atomic(isRed)))

let redThenGreen = G(.implies(.atomic(isRed), X(.atomic(isGreen))))

// モデル検査の実行
func runTrafficLightVerification() {
    let modelChecker = LTLModelChecker<TrafficLightModel>()
    let model = TrafficLightModel()
    
    do {
        let result1 = try modelChecker.check(formula: yellowThenRed, model: model)
        let result2 = try modelChecker.check(formula: eventuallyRed, model: model)
        let result3 = try modelChecker.check(formula: redThenGreen, model: model)
        
        print("黄色の後は必ず赤になる: \(result1.holds ? "成立" : "不成立")")
        print("常に最終的に赤になる: \(result2.holds ? "成立" : "不成立")")
        print("赤の次は緑になる: \(result3.holds ? "成立" : "不成立")")
        
        if case .fails(let counterexample) = result1 {
            print("反例1：\(counterexample)")
        }
        
        if case .fails(let counterexample) = result2 {
            print("反例2：\(counterexample)")
        }
        
        if case .fails(let counterexample) = result3 {
            print("反例3：\(counterexample)")
        }
    } catch {
        print("検証エラー：\(error)")
    }
}

// 検証を実行
runTrafficLightVerification()
```

## 次のステップ

基本的なTemporalKitの使い方を学んだところで、次のステップとして以下のことに挑戦してみましょう：

- より複雑なシステムをモデル化する
- 複雑なLTL式を作成する
- 実世界のアプリケーションに統合する
- [中級チュートリアル：モデル検査の詳細](./SimpleModelChecking.md)に進む

## まとめ

このチュートリアルでは、TemporalKitの基本的な使い方を学びました。具体的には、以下のことを行いました：

- システムの状態をモデル化する方法
- 命題を定義する方法
- クリプケ構造を実装する方法
- LTL式を作成する方法
- モデル検査を実行する方法

これらの基本的な要素を理解することで、より複雑なシステムの検証に進むことができます。
