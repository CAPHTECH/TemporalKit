# LTLModelChecker 実装メモ

## 概要
LTLModelCheckerはLTL（線形時相論理）のモデル検査を行うクラスです。KripkeStructureで表現されたシステムモデルに対して、LTL式が成り立つかを検証します。

## 主要なプライベートメソッド

### extractPropositions
- LTL式とモデルから全ての命題識別子を収集
- LTL式の再帰的な探索で命題を抽出
- モデル内で真となる全ての命題も追加（アルファベットの互換性を保証）

### convertModelToBuchi
- KripkeStructureをBüchi Automatonに変換
- 全ての状態を受理状態として設定
- 後続状態がない状態には自己ループを追加

### constructProductAutomaton
- モデルオートマトンと式オートマトンの積を構築
- シンボルの厳密な一致でのみ遷移を作成
- 式オートマトンの受理状態を含む積状態のみが受理状態

### projectRunToModelStates
- 積オートマトンの実行をモデル状態の列に射影
- ProductStateからモデル状態（s1）を抽出

## テスト時の注意点
- プライベートメソッドの直接テストは不可能
- publicなcheck()メソッドを通じて間接的にテスト
- 特定のロジックパスを通るようなテストケースの設計が必要
- カバレッジレポートで各分岐が実行されていることを確認