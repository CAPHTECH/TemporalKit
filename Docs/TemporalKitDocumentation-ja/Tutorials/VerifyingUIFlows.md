# UIフローの検証

このチュートリアルでは、TemporalKitを使用してiOSアプリケーションのユーザーインターフェース（UI）フローを検証する方法を学びます。

## 目標

このチュートリアルを終えると、以下のことができるようになります：

- UIフローを状態遷移モデルとして表現する
- ユーザーの操作シーケンスを時相論理式で記述する
- UIフローの検証をアプリケーションテストに統合する
- 一般的なUIフローの問題を発見して修正する

## 前提条件

- Swift 5.9以上
- Xcode 15.0以上
- TemporalKitの基本概念を理解していること
- SwiftUIの基本知識があると望ましい

## ステップ1: UIフローのモデル化

まず、検証したいUIフローをモデル化します。例として、シンプルなショッピングアプリのフローを表現してみましょう。

```swift
import TemporalKit

// UIフローの状態
enum ShoppingAppScreen: Hashable, CustomStringConvertible {
    case productList
    case productDetail
    case cart
    case checkout
    case paymentMethod
    case orderConfirmation
    case error
    
    var description: String {
        switch self {
        case .productList: return "商品リスト"
        case .productDetail: return "商品詳細"
        case .cart: return "カート"
        case .checkout: return "チェックアウト"
        case .paymentMethod: return "支払い方法"
        case .orderConfirmation: return "注文確認"
        case .error: return "エラー"
        }
    }
}

// UIフローの状態に関する追加情報
struct ShoppingAppState: Hashable {
    let currentScreen: ShoppingAppScreen
    let cartItemCount: Int
    let isLoggedIn: Bool
    let hasSelectedPaymentMethod: Bool
    
    // 初期状態のファクトリメソッド
    static func initial() -> ShoppingAppState {
        return ShoppingAppState(
            currentScreen: .productList,
            cartItemCount: 0,
            isLoggedIn: false,
            hasSelectedPaymentMethod: false
        )
    }
}
```

## ステップ2: UIフローの命題を定義する

次に、UIフロー状態を評価するための命題を定義します。

```swift
// 現在の画面を表す命題
let isOnProductList = TemporalKit.makeProposition(
    id: "isOnProductList",
    name: "商品リスト画面を表示中",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .productList }
)

let isOnProductDetail = TemporalKit.makeProposition(
    id: "isOnProductDetail",
    name: "商品詳細画面を表示中",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .productDetail }
)

let isOnCart = TemporalKit.makeProposition(
    id: "isOnCart",
    name: "カート画面を表示中",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .cart }
)

let isOnCheckout = TemporalKit.makeProposition(
    id: "isOnCheckout",
    name: "チェックアウト画面を表示中",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .checkout }
)

let isOnPaymentMethod = TemporalKit.makeProposition(
    id: "isOnPaymentMethod",
    name: "支払い方法画面を表示中",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .paymentMethod }
)

let isOnOrderConfirmation = TemporalKit.makeProposition(
    id: "isOnOrderConfirmation",
    name: "注文確認画面を表示中",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .orderConfirmation }
)

let isOnErrorScreen = TemporalKit.makeProposition(
    id: "isOnErrorScreen",
    name: "エラー画面を表示中",
    evaluate: { (state: ShoppingAppState) -> Bool in state.currentScreen == .error }
)

// アプリの状態に関する命題
let hasItemsInCart = TemporalKit.makeProposition(
    id: "hasItemsInCart",
    name: "カートに商品がある",
    evaluate: { (state: ShoppingAppState) -> Bool in state.cartItemCount > 0 }
)

let isUserLoggedIn = TemporalKit.makeProposition(
    id: "isUserLoggedIn",
    name: "ユーザーがログイン済み",
    evaluate: { (state: ShoppingAppState) -> Bool in state.isLoggedIn }
)

let hasSelectedPayment = TemporalKit.makeProposition(
    id: "hasSelectedPayment",
    name: "支払い方法が選択済み",
    evaluate: { (state: ShoppingAppState) -> Bool in state.hasSelectedPaymentMethod }
)
```

## ステップ3: UIフローのKripke構造を実装する

次に、UIフローの状態遷移を表すKripke構造を実装します。

```swift
struct ShoppingAppFlow: KripkeStructure {
    typealias State = ShoppingAppState
    typealias AtomicPropositionIdentifier = PropositionID
    
    let allStates: Set<State>
    let initialStates: Set<State> = [ShoppingAppState.initial()]
    
    init() {
        // 可能性のある全ての状態を列挙
        // 実際のアプリでは状態数が多くなることに注意（ここでは単純化のため一部のみを表現）
        var states: Set<State> = []
        
        // 可能な画面とアプリ状態の組み合わせを追加
        let screens: [ShoppingAppScreen] = [.productList, .productDetail, .cart, .checkout, .paymentMethod, .orderConfirmation, .error]
        let cartCounts: [Int] = [0, 1, 3]
        let loginStates: [Bool] = [false, true]
        let paymentStates: [Bool] = [false, true]
        
        for screen in screens {
            for count in cartCounts {
                for isLoggedIn in loginStates {
                    for hasPayment in paymentStates {
                        // 一部の組み合わせは無効（例：カートが空でチェックアウト画面）
                        if screen == .checkout && count == 0 { continue }
                        if screen == .orderConfirmation && !hasPayment { continue }
                        
                        states.insert(ShoppingAppState(
                            currentScreen: screen,
                            cartItemCount: count,
                            isLoggedIn: isLoggedIn,
                            hasSelectedPaymentMethod: hasPayment
                        ))
                    }
                }
            }
        }
        
        self.allStates = states
    }
    
    func successors(of state: State) -> Set<State> {
        var nextStates = Set<State>()
        
        // 現在の状態によって可能な遷移先を決定
        switch state.currentScreen {
        case .productList:
            // 商品リストから商品詳細へ
            nextStates.insert(ShoppingAppState(
                currentScreen: .productDetail,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // 商品リストからカートへ（カートに商品がある場合）
            if state.cartItemCount > 0 {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .cart,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
        case .productDetail:
            // 商品詳細から商品リストへ戻る
            nextStates.insert(ShoppingAppState(
                currentScreen: .productList,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // 商品詳細から商品をカートに追加
            nextStates.insert(ShoppingAppState(
                currentScreen: .productDetail,
                cartItemCount: state.cartItemCount + 1,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // 商品詳細からカートへ（カートに商品がある場合）
            if state.cartItemCount > 0 {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .cart,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
        case .cart:
            // カートから商品リストへ戻る
            nextStates.insert(ShoppingAppState(
                currentScreen: .productList,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // カートからチェックアウトへ（カートに商品がある場合）
            if state.cartItemCount > 0 {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .checkout,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
        case .checkout:
            // チェックアウトからカートへ戻る
            nextStates.insert(ShoppingAppState(
                currentScreen: .cart,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // ログインしていない場合は、ログイン状態になる（簡易化のため、ログイン画面は省略）
            if !state.isLoggedIn {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .checkout,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: true,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
            // チェックアウトから支払い方法選択へ（ログイン済みの場合）
            if state.isLoggedIn {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .paymentMethod,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: true,
                    hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
                ))
            }
            
        case .paymentMethod:
            // 支払い方法からチェックアウトへ戻る
            nextStates.insert(ShoppingAppState(
                currentScreen: .checkout,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // 支払い方法を選択
            nextStates.insert(ShoppingAppState(
                currentScreen: .paymentMethod,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: true
            ))
            
            // 支払い方法から注文確認へ（支払い方法が選択されている場合）
            if state.hasSelectedPaymentMethod {
                nextStates.insert(ShoppingAppState(
                    currentScreen: .orderConfirmation,
                    cartItemCount: state.cartItemCount,
                    isLoggedIn: state.isLoggedIn,
                    hasSelectedPaymentMethod: true
                ))
            }
            
        case .orderConfirmation:
            // 注文確認から商品リストへ（注文完了後）
            nextStates.insert(ShoppingAppState(
                currentScreen: .productList,
                cartItemCount: 0, // カートはクリア
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // 注文確認からエラー画面へ（エラーが発生した場合）
            nextStates.insert(ShoppingAppState(
                currentScreen: .error,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
        case .error:
            // エラーから商品リストへ
            nextStates.insert(ShoppingAppState(
                currentScreen: .productList,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
            
            // エラーから前の画面（チェックアウト）へ
            nextStates.insert(ShoppingAppState(
                currentScreen: .checkout,
                cartItemCount: state.cartItemCount,
                isLoggedIn: state.isLoggedIn,
                hasSelectedPaymentMethod: state.hasSelectedPaymentMethod
            ))
        }
        
        return nextStates
    }
    
    func atomicPropositionsTrue(in state: State) -> Set<AtomicPropositionIdentifier> {
        var trueProps = Set<AtomicPropositionIdentifier>()
        
        // 現在の画面に関する命題
        switch state.currentScreen {
        case .productList:
            trueProps.insert(isOnProductList.id)
        case .productDetail:
            trueProps.insert(isOnProductDetail.id)
        case .cart:
            trueProps.insert(isOnCart.id)
        case .checkout:
            trueProps.insert(isOnCheckout.id)
        case .paymentMethod:
            trueProps.insert(isOnPaymentMethod.id)
        case .orderConfirmation:
            trueProps.insert(isOnOrderConfirmation.id)
        case .error:
            trueProps.insert(isOnErrorScreen.id)
        }
        
        // アプリの状態に関する命題
        if state.cartItemCount > 0 {
            trueProps.insert(hasItemsInCart.id)
        }
        
        if state.isLoggedIn {
            trueProps.insert(isUserLoggedIn.id)
        }
        
        if state.hasSelectedPaymentMethod {
            trueProps.insert(hasSelectedPayment.id)
        }
        
        return trueProps
    }
}
```

## ステップ4: 検証したいUIフローのプロパティを定義する

UIフローに関して検証したいプロパティをLTL式として表現します。

```swift
// 命題型のエイリアス
typealias ShoppingProp = ClosureTemporalProposition<ShoppingAppState, Bool>

// プロパティ1: カートに商品がある場合のみチェックアウトが可能
let validCheckoutFlow = LTLFormula<ShoppingProp>.globally(
    .implies(
        .atomic(isOnCheckout),
        .atomic(hasItemsInCart)
    )
)

// プロパティ2: チェックアウトから注文確認に進むためには、ログインと支払い方法の選択が必要
let properCheckoutSequence = LTLFormula<ShoppingProp>.globally(
    .implies(
        .atomic(isOnCheckout),
        .not(
            .until(
                .not(.and(.atomic(isUserLoggedIn), .atomic(hasSelectedPayment))),
                .atomic(isOnOrderConfirmation)
            )
        )
    )
)

// プロパティ3: 注文確認画面の後はカートが空になる
let cartClearedAfterOrder = LTLFormula<ShoppingProp>.globally(
    .implies(
        .atomic(isOnOrderConfirmation),
        .next(
            .implies(
                .atomic(isOnProductList),
                .not(.atomic(hasItemsInCart))
            )
        )
    )
)

// プロパティ4: エラー状態からは常に復帰できる（いずれかの通常画面に戻れる）
let errorRecoverable = LTLFormula<ShoppingProp>.globally(
    .implies(
        .atomic(isOnErrorScreen),
        .eventually(
            .or(
                .atomic(isOnProductList),
                .atomic(isOnCheckout)
            )
        )
    )
)

// プロパティ5: 支払い方法が選択されたら、それが保持される
let paymentMethodPersists = LTLFormula<ShoppingProp>.globally(
    .implies(
        .atomic(hasSelectedPayment),
        .globally(.atomic(hasSelectedPayment))
    )
)
```

## ステップ5: UIフローのモデル検査を実行する

定義したUIフローモデルとプロパティに対してモデル検査を実行します。

```swift
let modelChecker = LTLModelChecker<ShoppingAppFlow>()
let shoppingFlow = ShoppingAppFlow()

// 各プロパティの検証
do {
    let result1 = try modelChecker.check(formula: validCheckoutFlow, model: shoppingFlow)
    let result2 = try modelChecker.check(formula: properCheckoutSequence, model: shoppingFlow)
    let result3 = try modelChecker.check(formula: cartClearedAfterOrder, model: shoppingFlow)
    let result4 = try modelChecker.check(formula: errorRecoverable, model: shoppingFlow)
    let result5 = try modelChecker.check(formula: paymentMethodPersists, model: shoppingFlow)
    
    print("検証結果:")
    print("1. カートに商品がある場合のみチェックアウトが可能: \(result1.holds ? "成立" : "不成立")")
    print("2. チェックアウトから注文確認に進むには認証と支払い方法が必要: \(result2.holds ? "成立" : "不成立")")
    print("3. 注文確認後はカートが空になる: \(result3.holds ? "成立" : "不成立")")
    print("4. エラー状態からは常に復帰できる: \(result4.holds ? "成立" : "不成立")")
    print("5. 支払い方法が選択されたら保持される: \(result5.holds ? "成立" : "不成立")")
    
    // 反例の表示
    if case .fails(let counterexample) = result5 {
        print("\nプロパティ5の反例:")
        print("  前置: \(counterexample.prefix.map { "(\($0.currentScreen), カート数:\($0.cartItemCount), ログイン:\($0.isLoggedIn), 支払い選択済:\($0.hasSelectedPaymentMethod))" }.joined(separator: " -> "))")
        print("  サイクル: \(counterexample.cycle.map { "(\($0.currentScreen), カート数:\($0.cartItemCount), ログイン:\($0.isLoggedIn), 支払い選択済:\($0.hasSelectedPaymentMethod))" }.joined(separator: " -> "))")
    }
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ6: 反例の分析と修正

モデル検査の結果、プロパティ5「支払い方法が選択されたら、それが保持される」が成立しないことがわかりました。反例を分析してみると、注文確認画面から商品リスト画面に戻るときに、支払い方法情報がリセットされています。

この問題を修正するために、`successors`メソッドを修正します。

```swift
// 修正版
func successors(of state: State) -> Set<State> {
    var nextStates = Set<State>()
    
    // (前のコードと同じ、orderConfirmationケースのみ修正)
    
    case .orderConfirmation:
        // 注文確認から商品リストへ（注文完了後、支払い方法情報は保持）
        nextStates.insert(ShoppingAppState(
            currentScreen: .productList,
            cartItemCount: 0, // カートはクリア
            isLoggedIn: state.isLoggedIn,
            hasSelectedPaymentMethod: true // 支払い方法情報を保持
        ))
        
        // 残りは同じ
        // ...
    
    // その他のケースはそのまま
    // ...
    
    return nextStates
}
```

## ステップ7: 修正したモデルで再検証

修正したモデルで再度検証を行います。

```swift
let improvedShoppingFlow = ImprovedShoppingAppFlow() // 修正版のモデル

do {
    let result5_improved = try modelChecker.check(formula: paymentMethodPersists, model: improvedShoppingFlow)
    print("5. 支払い方法が選択されたら保持される (修正後): \(result5_improved.holds ? "成立" : "不成立")")
} catch {
    print("検証エラー: \(error)")
}
```

## ステップ8: SwiftUIアプリとの統合

実際のSwiftUIアプリにUIフロー検証を統合する方法を示します。

```swift
import SwiftUI
import TemporalKit

// アプリの状態を管理するObservableObject
class ShoppingAppViewModel: ObservableObject {
    @Published var currentScreen: ShoppingAppScreen = .productList
    @Published var cartItemCount: Int = 0
    @Published var isLoggedIn: Bool = false
    @Published var hasSelectedPaymentMethod: Bool = false
    
    // 現在の状態をShoppingAppStateとして取得
    var currentState: ShoppingAppState {
        return ShoppingAppState(
            currentScreen: currentScreen,
            cartItemCount: cartItemCount,
            isLoggedIn: isLoggedIn,
            hasSelectedPaymentMethod: hasSelectedPaymentMethod
        )
    }
    
    // 状態遷移履歴
    private var stateHistory: [ShoppingAppState] = []
    
    // 状態の変更を記録
    func recordState() {
        stateHistory.append(currentState)
    }
    
    // 記録した状態履歴に対してLTL式を評価
    func verifyProperty<P: TemporalProposition>(formula: LTLFormula<P>) -> Bool where P.Value == Bool {
        guard !stateHistory.isEmpty else { return true }
        
        let evaluator = LTLFormulaTraceEvaluator()
        let contextProvider: (ShoppingAppState, Int) -> EvaluationContext = { state, index in
            return ShoppingAppContext(state: state, traceIndex: index)
        }
        
        do {
            return try evaluator.evaluate(formula: formula, trace: stateHistory, contextProvider: contextProvider)
        } catch {
            print("評価エラー: \(error)")
            return false
        }
    }
    
    // 状態遷移の前に検証
    func canTransitionTo(screen: ShoppingAppScreen) -> Bool {
        // チェックアウトに進むには商品が必要
        if screen == .checkout && cartItemCount == 0 {
            return false
        }
        
        // 注文確認に進むにはログインと支払い方法が必要
        if screen == .orderConfirmation && (!isLoggedIn || !hasSelectedPaymentMethod) {
            return false
        }
        
        return true
    }
}

// 評価コンテキスト
class ShoppingAppContext: EvaluationContext {
    let state: ShoppingAppState
    let traceIndex: Int?
    
    init(state: ShoppingAppState, traceIndex: Int? = nil) {
        self.state = state
        self.traceIndex = traceIndex
    }
    
    func currentStateAs<T>(_ type: T.Type) -> T? {
        return state as? T
    }
}

// SwiftUIビュー例
struct ShoppingApp: View {
    @StateObject private var viewModel = ShoppingAppViewModel()
    
    var body: some View {
        VStack {
            // 現在の画面に応じたコンテンツ
            switch viewModel.currentScreen {
            case .productList:
                ProductListView(viewModel: viewModel)
            case .productDetail:
                ProductDetailView(viewModel: viewModel)
            case .cart:
                CartView(viewModel: viewModel)
            case .checkout:
                CheckoutView(viewModel: viewModel)
            case .paymentMethod:
                PaymentMethodView(viewModel: viewModel)
            case .orderConfirmation:
                OrderConfirmationView(viewModel: viewModel)
            case .error:
                ErrorView(viewModel: viewModel)
            }
        }
        .onChange(of: viewModel.currentScreen) { newValue in
            // 画面遷移時に状態を記録
            viewModel.recordState()
            
            // デバッグモードで検証を実行
            #if DEBUG
            checkProperties()
            #endif
        }
    }
    
    // デバッグ用のプロパティ検証
    private func checkProperties() {
        let cartClearedAfterOrder = LTLFormula<ShoppingProp>.globally(
            .implies(
                .atomic(isOnOrderConfirmation),
                .next(
                    .implies(
                        .atomic(isOnProductList),
                        .not(.atomic(hasItemsInCart))
                    )
                )
            )
        )
        
        if !viewModel.verifyProperty(formula: cartClearedAfterOrder) {
            print("警告: 注文確認後のカートクリアのプロパティが満たされていません")
        }
    }
}
```

## まとめ

このチュートリアルでは、TemporalKitを使用してUIフローを検証する方法を学びました。具体的には：

1. UIフローを状態と遷移で表現する方法
2. UIフローに関する命題を定義する方法
3. 重要なプロパティをLTL式として表現する方法
4. モデル検査を実行して問題を特定する方法
5. 反例を元にUIフローのバグを修正する方法
6. 実際のSwiftUIアプリにUIフロー検証を統合する方法

UIフローの検証は、ユーザー体験の向上と入力エラーの防止、セキュリティの強化、またアプリの堅牢性向上に役立ちます。TemporalKitを使用することで、複雑なUIフローを体系的に検証し、高品質なアプリケーションを構築できます。

## 次のステップ

- [状態マシンの検証](./StateMachineVerification.md)を学んで、より複雑な状態マシンの検証に取り組みましょう。
- [テストとの統合](./IntegratingWithTests.md)で、UIテストとTemporalKitを組み合わせる方法を理解しましょう。
- [高度なLTL式](./AdvancedLTLFormulas.md)を学んで、より複雑なプロパティを表現する方法を理解しましょう。 
