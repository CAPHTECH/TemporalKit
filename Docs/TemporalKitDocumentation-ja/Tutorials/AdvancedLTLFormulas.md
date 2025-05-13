# 高度なLTL式

このチュートリアルでは、TemporalKitを使って高度なLTL（線形時相論理）式を記述し、複雑なシステムプロパティを表現する方法を学びます。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- 複雑なLTL式を作成して理解する
- 一般的なシステムプロパティパターンをLTL式で表現する
- LTL式の等価性や包含関係を理解する
- DSL（ドメイン特化言語）を使って読みやすいLTL式を作成する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること（[はじめてのTemporalKit](./BasicUsage.md)と[簡単なモデル検査](./SimpleModelChecking.md)をご覧ください）

## ステップ1: LTL演算子の復習

まず、基本的なLTL演算子を復習します：

```swift
import TemporalKit

// プロパティの例として使用する命題
let isReady = TemporalKit.makeProposition(
    id: "isReady",
    name: "システムが準備完了",
    evaluate: { (state: Bool) -> Bool in state }
)

let isProcessing = TemporalKit.makeProposition(
    id: "isProcessing",
    name: "システムが処理中",
    evaluate: { (state: Bool) -> Bool in state }
)

let isCompleted = TemporalKit.makeProposition(
    id: "isCompleted",
    name: "システムが完了状態",
    evaluate: { (state: Bool) -> Bool in state }
)

// 基本的なLTL演算子

// 1. Next (X): 次の状態で成立
let nextReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.next(.atomic(isReady))

// 2. Eventually (F): いつか将来的に成立
let eventuallyCompleted = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.eventually(.atomic(isCompleted))

// 3. Globally (G): 常に成立
let alwaysReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(.atomic(isReady))

// 4. Until (U): 第2引数が成立するまで第1引数が成立し続ける
let processingUntilCompleted = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.until(
    .atomic(isProcessing),
    .atomic(isCompleted)
)

// 5. Release (R): 第2引数が第1引数によって「解放」されるまで成立
let completedReleasedByReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.release(
    .atomic(isReady),
    .atomic(isCompleted)
)

// DSL記法
import TemporalKit.DSL

let dslNextReady = X(.atomic(isReady))
let dslEventuallyCompleted = F(.atomic(isCompleted))
let dslAlwaysReady = G(.atomic(isReady))
let dslProcessingUntilCompleted = U(.atomic(isProcessing), .atomic(isCompleted))
let dslCompletedReleasedByReady = R(.atomic(isReady), .atomic(isCompleted))
```

## ステップ2: 複雑なLTL式の構築

基本的な演算子を組み合わせて、より複雑なプロパティを表現します。

```swift
// 例: 「システムが準備完了した後、最終的に処理が完了する」
let readyLeadsToCompletion = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isReady),
        .eventually(.atomic(isCompleted))
    )
)

// DSL記法では:
let dslReadyLeadsToCompletion = G(.implies(.atomic(isReady), F(.atomic(isCompleted))))

// 例: 「処理中に準備状態に戻らない」
let noReadyDuringProcessing = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isProcessing),
        .not(.atomic(isReady))
    )
)

// 例: 「処理完了後は、再び準備状態になるまで処理中にならない」
let noProcessingAfterCompletionUntilReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isCompleted),
        .until(
            .not(.atomic(isProcessing)),
            .atomic(isReady)
        )
    )
)

// 例: 「システムは常に最終的に準備状態に戻る」
let alwaysEventuallyReady = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .eventually(.atomic(isReady))
)

// DSL記法では:
let dslAlwaysEventuallyReady = G(F(.atomic(isReady)))
```

## ステップ3: 一般的なプロパティパターンの表現

実際のシステムで頻繁に使用されるプロパティパターンを見ていきます。

```swift
// 安全性 (Safety): 「悪いことは決して起きない」
// 例: 「システムがエラー状態になることはない」
let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "システムがエラー状態",
    evaluate: { (state: Bool) -> Bool in state }
)

let safety = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .not(.atomic(isError))
)

// 生存性 (Liveness): 「良いことはいつか必ず起きる」
// 例: 「リクエストされたタスクは最終的に完了する」
let isRequested = TemporalKit.makeProposition(
    id: "isRequested",
    name: "タスクがリクエストされた",
    evaluate: { (state: Bool) -> Bool in state }
)

let liveness = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isRequested),
        .eventually(.atomic(isCompleted))
    )
)

// 公平性 (Fairness): 「特定の条件が無限に多く満たされる」
// 例: 「システムが準備状態になることは無限に何度も起こる」
let fairness = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .eventually(.atomic(isReady))
)

// 応答性 (Responsiveness): 「刺激に対して必ず反応がある」
// 例: 「ボタンが押されたら、いつか必ずライトが点灯する」
let buttonPressed = TemporalKit.makeProposition(
    id: "buttonPressed",
    name: "ボタンが押された",
    evaluate: { (state: Bool) -> Bool in state }
)

let lightOn = TemporalKit.makeProposition(
    id: "lightOn",
    name: "ライトが点灯",
    evaluate: { (state: Bool) -> Bool in state }
)

let responsiveness = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(buttonPressed),
        .eventually(.atomic(lightOn))
    )
)

// 優先度 (Precedence): 「あるイベントは別のイベントの後にのみ発生する」
// 例: 「認証が成功した後でのみ、アクセスが許可される」
let isAuthenticated = TemporalKit.makeProposition(
    id: "isAuthenticated",
    name: "認証済み",
    evaluate: { (state: Bool) -> Bool in state }
)

let accessGranted = TemporalKit.makeProposition(
    id: "accessGranted",
    name: "アクセス許可",
    evaluate: { (state: Bool) -> Bool in state }
)

let precedence = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(accessGranted),
        .or(
            .atomic(isAuthenticated),
            .previously(.atomic(isAuthenticated))
        )
    )
)
```

## ステップ4: ネストされた演算子と複雑なパターン

より高度な表現をするために、演算子をネストさせた複雑なパターンを構築します。

```swift
// 例: 「リクエストが来たら、必ず処理が開始され、その後処理が完了し、さらにそのあとで報告が行われる」
let isReported = TemporalKit.makeProposition(
    id: "isReported",
    name: "報告完了",
    evaluate: { (state: Bool) -> Bool in state }
)

let complexSequence = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isRequested),
        .eventually(
            .and(
                .atomic(isProcessing),
                .eventually(
                    .and(
                        .atomic(isCompleted),
                        .eventually(.atomic(isReported))
                    )
                )
            )
        )
    )
)

// DSL記法を使うとより読みやすくなります
let dslComplexSequence = G(
    .implies(
        .atomic(isRequested),
        F(
            .and(
                .atomic(isProcessing),
                F(
                    .and(
                        .atomic(isCompleted),
                        F(.atomic(isReported))
                    )
                )
            )
        )
    )
)

// 例: 「処理が開始されたら、エラーが発生するか完了するまで処理中の状態が続く」
let processUntilErrorOrCompletion = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .implies(
        .atomic(isProcessing),
        .until(
            .atomic(isProcessing),
            .or(
                .atomic(isError),
                .atomic(isCompleted)
            )
        )
    )
)

// 例: 「システムは常に、次のようなサイクルを繰り返す: 準備→処理中→完了→準備」
let cyclicBehavior = LTLFormula<ClosureTemporalProposition<Bool, Bool>>.globally(
    .and(
        .implies(
            .atomic(isReady),
            .eventually(.atomic(isProcessing))
        ),
        .and(
            .implies(
                .atomic(isProcessing),
                .eventually(.atomic(isCompleted))
            ),
            .implies(
                .atomic(isCompleted),
                .eventually(.atomic(isReady))
            )
        )
    )
)
```

## ステップ5: リアルな例: 通信プロトコルの検証

実際の例として、シンプルな通信プロトコルのプロパティを表現します。

```swift
// プロトコル状態を表す型
enum ProtocolState {
    case idle
    case connecting
    case connected
    case transmitting
    case disconnecting
    case error
}

// 通信プロトコルの命題
let isIdle = TemporalKit.makeProposition(
    id: "isIdle",
    name: "アイドル状態",
    evaluate: { (state: ProtocolState) -> Bool in state == .idle }
)

let isConnecting = TemporalKit.makeProposition(
    id: "isConnecting",
    name: "接続中",
    evaluate: { (state: ProtocolState) -> Bool in state == .connecting }
)

let isConnected = TemporalKit.makeProposition(
    id: "isConnected",
    name: "接続済み",
    evaluate: { (state: ProtocolState) -> Bool in state == .connected }
)

let isTransmitting = TemporalKit.makeProposition(
    id: "isTransmitting",
    name: "データ送信中",
    evaluate: { (state: ProtocolState) -> Bool in state == .transmitting }
)

let isDisconnecting = TemporalKit.makeProposition(
    id: "isDisconnecting",
    name: "切断中",
    evaluate: { (state: ProtocolState) -> Bool in state == .disconnecting }
)

let isProtocolError = TemporalKit.makeProposition(
    id: "isProtocolError",
    name: "エラー状態",
    evaluate: { (state: ProtocolState) -> Bool in state == .error }
)

// プロトコルの検証プロパティ

// 1. 「アイドル状態からは必ず接続中状態を経由して接続済み状態になる」
let properConnectionSequence = LTLFormula<ClosureTemporalProposition<ProtocolState, Bool>>.globally(
    .implies(
        .atomic(isIdle),
        .implies(
            .eventually(.atomic(isConnected)),
            .not(
                .until(
                    .not(.atomic(isConnecting)),
                    .atomic(isConnected)
                )
            )
        )
    )
)

// 2. 「データ送信は接続済み状態でのみ可能」
let transmitOnlyWhenConnected = LTLFormula<ClosureTemporalProposition<ProtocolState, Bool>>.globally(
    .implies(
        .atomic(isTransmitting),
        .previously(.atomic(isConnected))
    )
)

// 3. 「エラー状態に入った場合、必ずアイドル状態にリセットされる」
let errorRecovers = LTLFormula<ClosureTemporalProposition<ProtocolState, Bool>>.globally(
    .implies(
        .atomic(isProtocolError),
        .eventually(.atomic(isIdle))
    )
)

// 4. 「接続済みからアイドルに戻るには、必ず切断中状態を経由する」
let properDisconnectionSequence = LTLFormula<ClosureTemporalProposition<ProtocolState, Bool>>.globally(
    .implies(
        .and(
            .atomic(isConnected),
            .next(.eventually(.atomic(isIdle)))
        ),
        .next(
            .until(
                .not(.atomic(isIdle)),
                .atomic(isDisconnecting)
            )
        )
    )
)
```

## ステップ6: LTL式のカスタマイズと拡張

より読みやすく再利用可能なLTL式を作成する方法を学びます。

```swift
// 型エイリアスを使用して簡潔に
typealias ProtocolProp = ClosureTemporalProposition<ProtocolState, Bool>
typealias ProtocolLTL = LTLFormula<ProtocolProp>

// ヘルパー関数を作成してパターンを抽出
func eventually<State, P: TemporalProposition>(_ prop: P) -> LTLFormula<P> where P.Value == Bool {
    return LTLFormula<P>.eventually(.atomic(prop))
}

func always<State, P: TemporalProposition>(_ prop: P) -> LTLFormula<P> where P.Value == Bool {
    return LTLFormula<P>.globally(.atomic(prop))
}

func followedBy<State, P: TemporalProposition>(_ first: P, _ second: P) -> LTLFormula<P> where P.Value == Bool {
    return LTLFormula<P>.globally(
        .implies(
            .atomic(first),
            .eventually(.atomic(second))
        )
    )
}

// 実際のコード例:
let idleLeadsToConnected = followedBy(isIdle, isConnected)
let errorLeadsToIdle = followedBy(isProtocolError, isIdle)
```

## ステップ7: DSLを使用したLTL式の記述

DSLを活用して、より表現力豊かで読みやすいLTL式を作成します。

```swift
import TemporalKit.DSL

// DSLを使用した例
let dslProperConnectionSequence = G(
    .implies(
        .atomic(isIdle),
        .implies(
            F(.atomic(isConnected)),
            .not(
                U(
                    .not(.atomic(isConnecting)),
                    .atomic(isConnected)
                )
            )
        )
    )
)

let dslTransmitOnlyWhenConnected = G(
    .implies(
        .atomic(isTransmitting),
        P(.atomic(isConnected))
    )
)

// DSLを使用したヘルパー関数
func implies<P: TemporalProposition>(_ antecedent: LTLFormula<P>, _ consequent: LTLFormula<P>) -> LTLFormula<P> where P.Value == Bool {
    return .implies(antecedent, consequent)
}

func atomic<P: TemporalProposition>(_ prop: P) -> LTLFormula<P> where P.Value == Bool {
    return .atomic(prop)
}

// より読みやすいDSL表現
let readableFormula = G(
    implies(
        atomic(isConnected),
        F(atomic(isTransmitting))
    )
)
```

## ステップ8: LTLの等価性と変換

LTL式の等価変換と最適化について学びます。

```swift
// LTL式の等価関係の例

// 1. 二重否定の除去: ¬¬φ ≡ φ
let doubleNegation = LTLFormula<ProtocolProp>.not(.not(.atomic(isConnected)))
let simplified = LTLFormula<ProtocolProp>.atomic(isConnected)
// この2つの式は等価

// 2. ドモルガンの法則: ¬(φ ∧ ψ) ≡ ¬φ ∨ ¬ψ
let notAnd = LTLFormula<ProtocolProp>.not(
    .and(.atomic(isConnected), .atomic(isTransmitting))
)
let orNot = LTLFormula<ProtocolProp>.or(
    .not(.atomic(isConnected)),
    .not(.atomic(isTransmitting))
)
// この2つの式は等価

// 3. いくつかのLTL特有の等価関係
// F(F(φ)) ≡ F(φ)
let eventuallyEventually = LTLFormula<ProtocolProp>.eventually(.eventually(.atomic(isConnected)))
let justEventually = LTLFormula<ProtocolProp>.eventually(.atomic(isConnected))
// この2つの式は等価

// G(G(φ)) ≡ G(φ)
let alwaysAlways = LTLFormula<ProtocolProp>.globally(.globally(.atomic(isConnected)))
let justAlways = LTLFormula<ProtocolProp>.globally(.atomic(isConnected))
// この2つの式は等価

// FG(φ) と GF(φ) の違い
// 「最終的にずっとφが成立する」 vs 「常に最終的にφが成立する」
let eventuallyAlways = LTLFormula<ProtocolProp>.eventually(.globally(.atomic(isConnected)))
let alwaysEventually = LTLFormula<ProtocolProp>.globally(.eventually(.atomic(isConnected)))
// これらは一般に等価ではない
```

## まとめ

このチュートリアルでは、TemporalKitを使用して高度なLTL式を記述する方法を学びました。特に以下の点を学びました：

1. 基本的なLTL演算子を組み合わせて複雑な式を構築する方法
2. 一般的なプロパティパターン（安全性、生存性、公平性など）の表現方法
3. 実際の通信プロトコルなどのリアルなシステムに適用する方法
4. DSLを使用して読みやすいLTL式を記述する方法
5. LTL式の等価性と最適化について

LTL式を上手に活用することで、複雑なシステムの挙動を正確に指定し、モデル検査によって設計の誤りを早期に発見することができます。

## 次のステップ

- [状態マシンの検証](./StateMachineVerification.md)で、実際の状態マシンに対してLTL式を適用する方法を学びましょう。
- [テストとの統合](./IntegratingWithTests.md)で、LTL検証をテストスイートに組み込む方法を理解しましょう。
- [Kripke構造の応用](./AdvancedKripkeStructures.md)で、より複雑なシステムモデルを構築する方法を学びましょう。 
