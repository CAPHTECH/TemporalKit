# 状態マシンの検証

このチュートリアルでは、TemporalKitを使用して状態マシンの検証を行う方法について詳しく学びます。状態マシンは多くのシステムの中核となる概念であり、その正確な振る舞いを検証することは重要です。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- 状態マシンをKripke構造として適切にモデル化する
- 状態マシンの重要なプロパティをLTL式で表現する
- 状態マシンの検証を効率的に行い、結果を解釈する
- 複雑な状態マシンに対するテスト戦略を実装する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること（[はじめてのTemporalKit](./BasicUsage.md)と[簡単なモデル検査](./SimpleModelChecking.md)を参照）
- LTL式に関する基本的な知識（[高度なLTL式](./AdvancedLTLFormulas.md)を参照）

## ステップ1: 状態マシンのモデリング

実際のアプリケーションで使用される状態マシンを例に挙げて、モデル化してみましょう。ここでは、オーディオプレーヤーの状態マシンを例として使用します。

```swift
import TemporalKit

// オーディオプレーヤーの状態
enum AudioPlayerState: Hashable, CustomStringConvertible {
    case stopped
    case loading
    case playing
    case paused
    case buffering
    case error(code: Int)
    
    var description: String {
        switch self {
        case .stopped: return "停止中"
        case .loading: return "読み込み中"
        case .playing: return "再生中"
        case .paused: return "一時停止中"
        case .buffering: return "バッファリング中"
        case let .error(code): return "エラー(コード: \(code))"
        }
    }
    
    // Hashableプロトコルに準拠するため
    func hash(into hasher: inout Hasher) {
        switch self {
        case .stopped: hasher.combine(0)
        case .loading: hasher.combine(1)
        case .playing: hasher.combine(2)
        case .paused: hasher.combine(3)
        case .buffering: hasher.combine(4)
        case let .error(code): 
            hasher.combine(5)
            hasher.combine(code)
        }
    }
    
    // Equatableプロトコルに準拠するため
    static func == (lhs: AudioPlayerState, rhs: AudioPlayerState) -> Bool {
        switch (lhs, rhs) {
        case (.stopped, .stopped): return true
        case (.loading, .loading): return true
        case (.playing, .playing): return true
        case (.paused, .paused): return true
        case (.buffering, .buffering): return true
        case let (.error(code1), .error(code2)): return code1 == code2
        default: return false
        }
    }
}
```

## ステップ2: 状態マシンのKripke構造の実装

次に、オーディオプレーヤーの状態遷移をKripke構造として実装します。

```swift
// オーディオプレーヤーの状態マシン
struct AudioPlayerStateMachine: KripkeStructure {
    typealias State = AudioPlayerState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State> = [.stopped]
    
    init() {
        // 可能なすべての状態を定義
        var states: Set<State> = [.stopped, .loading, .playing, .paused, .buffering]
        
        // エラー状態を追加（一般的なエラーコードのみ）
        states.insert(.error(code: 404)) // ファイルが見つからない
        states.insert(.error(code: 500)) // 内部エラー
        states.insert(.error(code: 403)) // アクセス拒否
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        switch state {
        case .stopped:
            nextStates.insert(.loading)  // 停止 → 読み込み
            
        case .loading:
            nextStates.insert(.playing)  // 読み込み → 再生
            nextStates.insert(.error(code: 404))  // 読み込み → エラー(ファイルが見つからない)
            nextStates.insert(.error(code: 403))  // 読み込み → エラー(アクセス拒否)
            
        case .playing:
            nextStates.insert(.paused)    // 再生 → 一時停止
            nextStates.insert(.buffering) // 再生 → バッファリング
            nextStates.insert(.stopped)   // 再生 → 停止（曲の終わりなど）
            
        case .paused:
            nextStates.insert(.playing)  // 一時停止 → 再生
            nextStates.insert(.stopped)  // 一時停止 → 停止
            
        case .buffering:
            nextStates.insert(.playing)  // バッファリング → 再生
            nextStates.insert(.error(code: 500))  // バッファリング → エラー(内部エラー)
            
        case .error:
            nextStates.insert(.stopped)  // エラー → 停止（リセット）
        }
        
        return nextStates
    }
    
    // 状態に関連する命題を定義
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // 基本状態に関する命題
        switch state {
        case .stopped:
            trueProps.insert(isStopped.id)
        case .loading:
            trueProps.insert(isLoading.id)
        case .playing:
            trueProps.insert(isPlaying.id)
            trueProps.insert(isActive.id)  // 再生中はアクティブ
        case .paused:
            trueProps.insert(isPaused.id)
            trueProps.insert(isActive.id)  // 一時停止中もアクティブ
        case .buffering:
            trueProps.insert(isBuffering.id)
            trueProps.insert(isActive.id)  // バッファリング中もアクティブ
        case .error:
            trueProps.insert(isError.id)
        }
        
        // 特別な状態に関する命題
        if case .error = state {
            trueProps.insert(isInErrorState.id)
        }
        
        // すべてのエラーコードを個別に処理
        if case let .error(code) = state {
            switch code {
            case 404:
                trueProps.insert(isFileNotFoundError.id)
            case 500:
                trueProps.insert(isInternalError.id)
            case 403:
                trueProps.insert(isAccessDeniedError.id)
            default:
                trueProps.insert(isUnknownError.id)
            }
        }
        
        return trueProps
    }
}
```

## ステップ3: 命題の定義

オーディオプレーヤーの状態に関する命題を定義します。

```swift
// 基本状態命題
let isStopped = TemporalKit.makeProposition(
    id: "isStopped",
    name: "プレーヤーが停止中",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .stopped = state { return true }
        return false
    }
)

let isLoading = TemporalKit.makeProposition(
    id: "isLoading",
    name: "プレーヤーが読み込み中",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .loading = state { return true }
        return false
    }
)

let isPlaying = TemporalKit.makeProposition(
    id: "isPlaying",
    name: "プレーヤーが再生中",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .playing = state { return true }
        return false
    }
)

let isPaused = TemporalKit.makeProposition(
    id: "isPaused",
    name: "プレーヤーが一時停止中",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .paused = state { return true }
        return false
    }
)

let isBuffering = TemporalKit.makeProposition(
    id: "isBuffering",
    name: "プレーヤーがバッファリング中",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .buffering = state { return true }
        return false
    }
)

// エラー関連の命題
let isError = TemporalKit.makeProposition(
    id: "isError",
    name: "プレーヤーがエラー状態",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error = state { return true }
        return false
    }
)

let isInErrorState = TemporalKit.makeProposition(
    id: "isInErrorState",
    name: "何らかのエラー状態",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error = state { return true }
        return false
    }
)

let isFileNotFoundError = TemporalKit.makeProposition(
    id: "isFileNotFoundError",
    name: "ファイルが見つからないエラー",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error(404) = state { return true }
        return false
    }
)

let isInternalError = TemporalKit.makeProposition(
    id: "isInternalError",
    name: "内部エラー",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error(500) = state { return true }
        return false
    }
)

let isAccessDeniedError = TemporalKit.makeProposition(
    id: "isAccessDeniedError",
    name: "アクセス拒否エラー",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case .error(403) = state { return true }
        return false
    }
)

let isUnknownError = TemporalKit.makeProposition(
    id: "isUnknownError",
    name: "不明なエラー",
    evaluate: { (state: AudioPlayerState) -> Bool in
        if case let .error(code) = state, code != 404, code != 500, code != 403 {
            return true
        }
        return false
    }
)

// 複合状態命題
let isActive = TemporalKit.makeProposition(
    id: "isActive",
    name: "プレーヤーがアクティブ（再生中、一時停止中、またはバッファリング中）",
    evaluate: { (state: AudioPlayerState) -> Bool in
        switch state {
        case .playing, .paused, .buffering:
            return true
        default:
            return false
        }
    }
)
```

## ステップ4: 検証プロパティの定義

オーディオプレーヤーの状態マシンに対して検証したいプロパティをLTL式として定義します。

```swift
// 型エイリアス（見やすさのため）
typealias AudioProp = ClosureTemporalProposition<AudioPlayerState, Bool>
typealias AudioLTL = LTLFormula<AudioProp>

// プロパティ1: 「読み込み後は必ず再生状態か何らかのエラー状態になる」
let loadingLeadsToPlayingOrError = AudioLTL.globally(
    .implies(
        .atomic(isLoading),
        .next(
            .or(
                .atomic(isPlaying),
                .atomic(isError)
            )
        )
    )
)

// プロパティ2: 「エラー状態からは必ず停止状態に戻る」
let errorLeadsToStopped = AudioLTL.globally(
    .implies(
        .atomic(isError),
        .next(.atomic(isStopped))
    )
)

// プロパティ3: 「一度再生が始まったら、停止するまでに一時停止とバッファリングの状態のみを通過する」
let playingUntilStopped = AudioLTL.globally(
    .implies(
        .atomic(isPlaying),
        .until(
            .or(
                .atomic(isPlaying),
                .atomic(isPaused),
                .atomic(isBuffering)
            ),
            .atomic(isStopped)
        )
    )
)

// プロパティ4: 「バッファリング状態からは、必ず再生状態か内部エラーに遷移する」
let bufferingLeadsToPlayingOrError = AudioLTL.globally(
    .implies(
        .atomic(isBuffering),
        .next(
            .or(
                .atomic(isPlaying),
                .atomic(isInternalError)
            )
        )
    )
)

// プロパティ5: 「停止状態からは、読み込み状態を経由せずに再生状態にならない」
let stoppedToPlayingViaLoading = AudioLTL.globally(
    .implies(
        .and(
            .atomic(isStopped),
            .next(.eventually(.atomic(isPlaying)))
        ),
        .next(
            .until(
                .not(.atomic(isPlaying)),
                .atomic(isLoading)
            )
        )
    )
)

// DSL記法を使った例
import TemporalKit.DSL

let dslLoadingLeadsToPlayingOrError = G(
    .implies(
        .atomic(isLoading),
        X(
            .or(
                .atomic(isPlaying),
                .atomic(isError)
            )
        )
    )
)
```

## ステップ5: モデル検査の実行

モデル検査を実行して、定義したプロパティをオーディオプレーヤーの状態マシンが満たすかどうかを検証します。

```swift
let modelChecker = LTLModelChecker<AudioPlayerStateMachine>()
let audioPlayerModel = AudioPlayerStateMachine()

do {
    // プロパティごとに検証を実行
    let result1 = try modelChecker.check(formula: loadingLeadsToPlayingOrError, model: audioPlayerModel)
    let result2 = try modelChecker.check(formula: errorLeadsToStopped, model: audioPlayerModel)
    let result3 = try modelChecker.check(formula: playingUntilStopped, model: audioPlayerModel)
    let result4 = try modelChecker.check(formula: bufferingLeadsToPlayingOrError, model: audioPlayerModel)
    let result5 = try modelChecker.check(formula: stoppedToPlayingViaLoading, model: audioPlayerModel)
    
    // 結果の出力
    print("検証結果:")
    print("1. 読み込み後は必ず再生状態か何らかのエラー状態になる: \(result1.holds ? "成立" : "不成立")")
    print("2. エラー状態からは必ず停止状態に戻る: \(result2.holds ? "成立" : "不成立")")
    print("3. 一度再生が始まったら、停止するまでに一時停止とバッファリングの状態のみを通過する: \(result3.holds ? "成立" : "不成立")")
    print("4. バッファリング状態からは、必ず再生状態か内部エラーに遷移する: \(result4.holds ? "成立" : "不成立")")
    print("5. 停止状態からは、読み込み状態を経由せずに再生状態にならない: \(result5.holds ? "成立" : "不成立")")
    
    // 反例の表示（必要に応じて）
    if case .fails(let counterexample) = result3 {
        print("\nプロパティ3の反例:")
        print("  前置: \(counterexample.prefix.map { $0.description }.joined(separator: " -> "))")
        print("  サイクル: \(counterexample.cycle.map { $0.description }.joined(separator: " -> "))")
    }
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ6: 反例の分析と修正

反例を分析して、状態マシンの修正が必要な箇所を特定します。

```swift
// 修正したオーディオプレーヤーの状態マシン
struct ImprovedAudioPlayerStateMachine: KripkeStructure {
    typealias State = AudioPlayerState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State> = [.stopped]
    
    init() {
        // 従来と同じ状態定義
        var states: Set<State> = [.stopped, .loading, .playing, .paused, .buffering]
        states.insert(.error(code: 404))
        states.insert(.error(code: 500))
        states.insert(.error(code: 403))
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        switch state {
        case .stopped:
            // 停止からは必ず読み込みを経由する
            nextStates.insert(.loading)
            
        case .loading:
            nextStates.insert(.playing)
            nextStates.insert(.error(code: 404))
            nextStates.insert(.error(code: 403))
            
        case .playing:
            // 再生中は停止、一時停止、バッファリングのみに遷移可能
            nextStates.insert(.paused)
            nextStates.insert(.buffering)
            nextStates.insert(.stopped)
            
        case .paused:
            // 一時停止からは再生か停止のみに遷移可能
            nextStates.insert(.playing)
            nextStates.insert(.stopped)
            
        case .buffering:
            // バッファリングからは再生か内部エラーのみに遷移可能
            nextStates.insert(.playing)
            nextStates.insert(.error(code: 500))
            
        case .error:
            // エラーからは必ず停止状態に戻る
            nextStates.insert(.stopped)
        }
        
        return nextStates
    }
    
    // atomicPropositionsTrue メソッドは変更なし
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        // 元の実装と同じ
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        switch state {
        case .stopped:
            trueProps.insert(isStopped.id)
        case .loading:
            trueProps.insert(isLoading.id)
        case .playing:
            trueProps.insert(isPlaying.id)
            trueProps.insert(isActive.id)
        case .paused:
            trueProps.insert(isPaused.id)
            trueProps.insert(isActive.id)
        case .buffering:
            trueProps.insert(isBuffering.id)
            trueProps.insert(isActive.id)
        case .error:
            trueProps.insert(isError.id)
        }
        
        if case .error = state {
            trueProps.insert(isInErrorState.id)
        }
        
        if case let .error(code) = state {
            switch code {
            case 404:
                trueProps.insert(isFileNotFoundError.id)
            case 500:
                trueProps.insert(isInternalError.id)
            case 403:
                trueProps.insert(isAccessDeniedError.id)
            default:
                trueProps.insert(isUnknownError.id)
            }
        }
        
        return trueProps
    }
}
```

## ステップ7: 修正した状態マシンの再検証

修正した状態マシンで再度プロパティの検証を行います。

```swift
let improvedModel = ImprovedAudioPlayerStateMachine()

do {
    // 問題のあったプロパティを再検証
    let improvedResult3 = try modelChecker.check(formula: playingUntilStopped, model: improvedModel)
    let improvedResult5 = try modelChecker.check(formula: stoppedToPlayingViaLoading, model: improvedModel)
    
    print("\n修正後の結果:")
    print("3. 一度再生が始まったら、停止するまでに一時停止とバッファリングの状態のみを通過する: \(improvedResult3.holds ? "成立" : "不成立")")
    print("5. 停止状態からは、読み込み状態を経由せずに再生状態にならない: \(improvedResult5.holds ? "成立" : "不成立")")
    
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ8: 実際のコードとの統合

状態マシンの検証結果を実際のコードに統合する方法の例を示します。

```swift
// 実際のオーディオプレーヤークラス
class AudioPlayer {
    private var state: AudioPlayerState = .stopped
    private var url: URL?
    
    // 検証済みの状態遷移に基づく実装
    
    func play(url: URL) {
        self.url = url
        
        // 停止状態からは必ず読み込み状態を経由する
        if case .stopped = state {
            state = .loading
            
            // 実際の読み込み処理
            loadAudio { [weak self] success, errorCode in
                guard let self = self else { return }
                
                if success {
                    // 読み込み成功時は再生状態に遷移
                    self.state = .playing
                    // 実際の再生処理
                } else if let errorCode = errorCode {
                    // エラー発生時は対応するエラー状態に遷移
                    self.state = .error(code: errorCode)
                    // エラー処理後は停止状態に自動的に戻る
                    self.state = .stopped
                }
            }
        } else if case .paused = state {
            // 一時停止状態からは再生状態に直接遷移可能
            state = .playing
            // 実際の再生再開処理
        }
    }
    
    func pause() {
        // 再生中の場合のみ一時停止可能
        if case .playing = state {
            state = .paused
            // 実際の一時停止処理
        }
    }
    
    func stop() {
        // アクティブ状態（再生中、一時停止中、バッファリング中）からのみ停止可能
        if case .playing = state || case .paused = state || case .buffering = state {
            state = .stopped
            // 実際の停止処理
        }
    }
    
    // ネットワーク状態の変化などによるバッファリング
    func handleNetworkChange(isGood: Bool) {
        if case .playing = state, !isGood {
            // 再生中にネットワーク状態が悪化した場合はバッファリング状態に遷移
            state = .buffering
            // バッファリング処理
        } else if case .buffering = state, isGood {
            // バッファリング中にネットワーク状態が回復した場合は再生状態に戻る
            state = .playing
            // 再生再開処理
        }
    }
    
    // プライベートヘルパーメソッド（実際の実装は省略）
    private func loadAudio(completion: @escaping (Bool, Int?) -> Void) {
        // 実際の読み込み処理
    }
}

// テスト
func testAudioPlayerStateMachine() {
    let player = AudioPlayer()
    
    // 停止→読み込み→再生のシーケンスをテスト
    player.play(url: URL(string: "https://example.com/audio.mp3")!)
    
    // 再生→一時停止→再生のシーケンスをテスト
    player.pause()
    player.play(url: URL(string: "https://example.com/audio.mp3")!)
    
    // 再生→停止のシーケンスをテスト
    player.stop()
}
```

## まとめ

このチュートリアルでは、TemporalKitを使用して状態マシンの検証を行う方法を学びました。特に以下の点に焦点を当てました：

1. 実際の状態マシン（オーディオプレーヤー）をKripke構造としてモデル化する方法
2. 状態マシンに関する重要なプロパティをLTL式として表現する方法
3. モデル検査を実行して問題を特定する方法
4. 反例を分析して状態マシンを修正する方法
5. 検証済みの状態マシンを実際のコードに統合する方法

状態マシンの適切な検証は、システムの信頼性を高め、予期しない挙動やエッジケースを早期に発見するのに役立ちます。TemporalKitを使用することで、これらの検証をSwiftで直接行うことができます。

## 次のステップ

- [テストとの統合](./IntegratingWithTests.md)で、状態マシンの検証をテストスイートに組み込む方法を理解しましょう。
- [高度なLTL式](./AdvancedLTLFormulas.md)で、より複雑なプロパティを表現する方法を学びましょう。
- [並行システムの検証](./ConcurrentSystemVerification.md)で、複数の状態マシンが相互作用するシステムの検証方法を学びましょう。 
