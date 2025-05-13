# 簡単なモデル検査

このチュートリアルでは、TemporalKitを使用して簡単なシステムモデルの検査を行う方法を学びます。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- Kripke構造を使ってシステムをモデル化する
- 検証したい性質をLTL式で表現する
- モデル検査を実行して結果を解釈する
- 反例が見つかった場合に問題を特定する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること（[はじめてのTemporalKit](./BasicUsage.md)をご覧ください）

## ステップ1: 単純な状態機械のモデル化

まずは、検証したい状態機械をモデル化します。例として、シンプルなドアの状態をモデル化しましょう。

```swift
import TemporalKit

// ドアの状態
enum DoorState: Hashable, CustomStringConvertible {
    case closed
    case opening
    case open
    case closing
    case locked
    
    var description: String {
        switch self {
        case .closed: return "閉じている"
        case .opening: return "開いている途中"
        case .open: return "開いている"
        case .closing: return "閉じている途中"
        case .locked: return "ロックされている"
        }
    }
}
```

## ステップ2: 命題の定義

次に、ドアの状態に関する命題を定義します。

```swift
// 命題の定義
let isClosed = TemporalKit.makeProposition(
    id: "isClosed",
    name: "ドアが閉じている",
    evaluate: { (state: DoorState) -> Bool in state == .closed }
)

let isOpen = TemporalKit.makeProposition(
    id: "isOpen",
    name: "ドアが開いている",
    evaluate: { (state: DoorState) -> Bool in state == .open }
)

let isMoving = TemporalKit.makeProposition(
    id: "isMoving",
    name: "ドアが動いている",
    evaluate: { (state: DoorState) -> Bool in 
        return state == .opening || state == .closing 
    }
)

let isLocked = TemporalKit.makeProposition(
    id: "isLocked",
    name: "ドアがロックされている",
    evaluate: { (state: DoorState) -> Bool in state == .locked }
)
```

## ステップ3: Kripke構造の実装

ドアの状態遷移をKripke構造として実装します。

```swift
struct DoorModel: KripkeStructure {
    typealias State = DoorState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State> = Set(arrayLiteral: .closed, .opening, .open, .closing, .locked)
    let initialStates: Set<State> = [.closed]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .closed:
            return [.opening, .locked]
        case .opening:
            return [.open]
        case .open:
            return [.closing]
        case .closing:
            return [.closed]
        case .locked:
            return [.closed]
        }
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .closed:
            trueProps.insert(isClosed.id)
        case .opening:
            trueProps.insert(isMoving.id)
        case .open:
            trueProps.insert(isOpen.id)
        case .closing:
            trueProps.insert(isMoving.id)
        case .locked:
            trueProps.insert(isLocked.id)
            trueProps.insert(isClosed.id) // ロックされている時は閉じているとみなす
        }
        
        return trueProps
    }
}
```

## ステップ4: 検証したいプロパティのLTL式の定義

次に、検証したいプロパティをLTL式として定義します。

```swift
// 検証プロパティの定義
// 1. 「ドアが開いたら、必ず最終的に閉じる」
let eventuallyCloses = LTLFormula<ClosureTemporalProposition<DoorState, Bool>>.globally(
    .implies(
        .atomic(isOpen),
        .eventually(.atomic(isClosed))
    )
)

// 2. 「ドアがロックされた状態では、開かない」
let lockedStaysClosed = LTLFormula<ClosureTemporalProposition<DoorState, Bool>>.globally(
    .implies(
        .atomic(isLocked),
        .not(.next(.atomic(isOpen)))
    )
)

// 3. 「ドアが閉じている状態からは、必ず開くことができる」
let canEventuallyOpen = LTLFormula<ClosureTemporalProposition<DoorState, Bool>>.globally(
    .implies(
        .atomic(isClosed),
        .eventually(.atomic(isOpen))
    )
)

// DSL記法を使った別の表現方法
let alwaysEventuallyCloses = G(F(.atomic(isClosed)))
```

## ステップ5: モデル検査の実行

モデル検査を実行して、モデルがプロパティを満たすかどうかを検証します。

```swift
// モデルチェッカーのインスタンス化
let modelChecker = LTLModelChecker<DoorModel>()
let doorModel = DoorModel()

// プロパティの検証
do {
    let result1 = try modelChecker.check(formula: eventuallyCloses, model: doorModel)
    let result2 = try modelChecker.check(formula: lockedStaysClosed, model: doorModel)
    let result3 = try modelChecker.check(formula: canEventuallyOpen, model: doorModel)
    let result4 = try modelChecker.check(formula: alwaysEventuallyCloses, model: doorModel)
    
    print("ドアが開いたら、必ず最終的に閉じる: \(result1.holds ? "成立" : "不成立")")
    print("ドアがロックされた状態では、開かない: \(result2.holds ? "成立" : "不成立")")
    print("ドアが閉じている状態からは、必ず開くことができる: \(result3.holds ? "成立" : "不成立")")
    print("常に最終的に閉じる: \(result4.holds ? "成立" : "不成立")")
    
    // 反例の確認
    if case .fails(let counterexample) = result3 {
        print("プロパティ3の反例:")
        print("  前置: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("  サイクル: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ6: 結果の解釈と問題の修正

モデル検査の結果、プロパティ3「ドアが閉じている状態からは、必ず開くことができる」が成立しないことがわかりました。その理由は、ドアがロックされた状態から開くことができないためです。

反例を見てみましょう：
- 前置: 閉じている -> ロックされている
- サイクル: ロックされている -> 閉じている -> ロックされている

この反例は、ドアがロックされた状態からは開くことができず、ロックと閉じた状態の間を行き来するだけであることを示しています。

問題を解決するために、モデルを修正してみましょう：

```swift
struct ImprovedDoorModel: KripkeStructure {
    typealias State = DoorState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State> = Set(arrayLiteral: .closed, .opening, .open, .closing, .locked)
    let initialStates: Set<State> = [.closed]
    
    func successors(of state: State) -> Set<State> {
        switch state {
        case .closed:
            return [.opening, .locked]
        case .opening:
            return [.open]
        case .open:
            return [.closing]
        case .closing:
            return [.closed]
        case .locked:
            return [.closed, .opening] // ロックされた状態からも開けるように修正
        }
    }
    
    // atomicPropositionsTrue メソッドは同じ
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .closed:
            trueProps.insert(isClosed.id)
        case .opening:
            trueProps.insert(isMoving.id)
        case .open:
            trueProps.insert(isOpen.id)
        case .closing:
            trueProps.insert(isMoving.id)
        case .locked:
            trueProps.insert(isLocked.id)
            trueProps.insert(isClosed.id)
        }
        
        return trueProps
    }
}
```

修正したモデルで再度検証を行いましょう：

```swift
let improvedDoorModel = ImprovedDoorModel()

do {
    let result3_improved = try modelChecker.check(formula: canEventuallyOpen, model: improvedDoorModel)
    print("ドアが閉じている状態からは、必ず開くことができる (改善版): \(result3_improved.holds ? "成立" : "不成立")")
} catch {
    print("検証エラー: \(error)")
}
```

## まとめ

このチュートリアルでは、TemporalKitを使って簡単な状態機械をモデル化し、モデル検査を行う方法を学びました。特に以下のことを学びました：

1. 状態機械をKripke構造としてモデル化する方法
2. 検証したいプロパティをLTL式として表現する方法
3. モデル検査を実行して結果を解釈する方法
4. 反例を分析して問題を特定し、モデルを修正する方法

モデル検査は、システムが必要なプロパティを満たしていることを数学的に検証する強力な手法です。TemporalKitを使うことで、Swiftでこのような検証を簡単に行うことができます。

## 次のステップ

- [命題の定義と使用](./WorkingWithPropositions.md)を読んで、より複雑な命題の作成方法を学びましょう。
- より複雑なシステムのモデル化と検証に挑戦してみましょう。
- [高度なLTL式](./AdvancedLTLFormulas.md)を学んで、より複雑なプロパティを表現する方法を理解しましょう。 
