# PropositionIDFactoryTests 実装における重要な知見

## 概要
PropositionIDFactoryTests.swift の実装とレビューを通じて得られた設計上の決定事項と注意点を記録します。

## 設計上の決定事項

### 1. パフォーマンス測定の精度
- クロスプラットフォーム対応のため `Date()` を使用
- Linux環境では `CFAbsoluteTimeGetCurrent()` が利用不可
- 将来的には `ContinuousClock` への移行を検討
  - 最小サポートバージョンが iOS 16/macOS 13 以上になった時点で移行
  - Package.swift の platforms 設定を確認して判断
  - より高精度な測定が可能になる

### 2. バリデーションロジックの効率化
- `isValidPropositionID` ヘルパーメソッドで再検証を避ける
- PropositionID は作成時に既に検証済みのため、空でないことのみ確認
- テストと実装の結合度を下げ、PropositionID の内部実装への依存を排除

### 3. Unicode 文字の扱い
- PropositionID は `char.isLetter` を使用するため、日本語やギリシャ文字などの Unicode 文字も有効
- テストでは有効な Unicode 文字と無効な絵文字を明確に区別

## 注意点

### エラーハンドリング
- 現在の実装では `PropositionIDFactory.create(from:)` が実質的にエラーを投げることはない
- UUID ベースのフォールバックが最終的なセーフティネットとして機能
- 将来の実装変更に備えて、エラーケースのドキュメンテーションを充実

### スレッドセーフティ
- 並行アクセステストで 100 回の同時実行を検証
- PropositionIDFactory の全メソッドがスレッドセーフであることを確認
- TaskGroup を使用した非同期テストパターンを採用

### テストカバレッジ
- 22 個の包括的なテストケースを実装
- エッジケース（空文字列、特殊文字、巨大入力）を網羅
- パフォーマンステストで 10,000 文字の入力でも 0.1 秒以内の処理を保証

## 今後の改善点
- UUID フォールバックの実際のテストは統合テストレベルで実施すべき
- ContinuousClock が利用可能になった際のパフォーマンス測定の更新