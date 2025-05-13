# TemporalKit インストールガイド

このガイドでは、SwiftプロジェクトにTemporalKitを追加し、設定する方法を説明します。

## 要件

TemporalKitは以下の環境で動作します：

- Swift 5.9 以上
- iOS 16.0 以上
- macOS 13.0 以上
- Xcode 15.0 以上

## Swift Package Managerを使用したインストール

TemporalKitは主にSwift Package Manager（SPM）を通じて配布されています。以下の手順で追加できます：

### Xcodeプロジェクトでの追加

1. Xcodeでプロジェクトを開きます
2. メニューから「File」→「Swift Packages」→「Add Package Dependency...」を選択します
3. 表示されるダイアログに以下のURLを入力します：
   ```
   https://github.com/CAPHTECH/TemporalKit.git
   ```
4. バージョンルールを選択します（通常は「Up to Next Major」が推奨されます）
5. 「Next」をクリックし、その後「Finish」をクリックしてパッケージを追加します

### Package.swiftファイルでの追加

Package.swiftファイルを使用する場合は、依存関係を以下のように追加します：

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YourPackage",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/CAPHTECH/TemporalKit.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: ["TemporalKit"]
        )
    ]
)
```

## 基本的な使用方法

パッケージをインストールした後、以下のようにimport文を追加してTemporalKitを使用できます：

```swift
import TemporalKit

// TemporalKitの機能を使用する
```

## 依存関係の更新

依存関係を更新したい場合は以下の方法があります：

### Xcodeでの更新
1. メニューから「File」→「Swift Packages」→「Update to Latest Package Versions」を選択します

### コマンドラインでの更新
1. プロジェクトのルートディレクトリに移動します
2. 以下のコマンドを実行します：
   ```bash
   swift package update
   ```

## トラブルシューティング

### パッケージの解決に関する問題

パッケージの解決に問題がある場合は、以下の手順を試してください：

1. Xcodeを閉じる
2. プロジェクトの`.build`ディレクトリを削除する：
   ```bash
   rm -rf .build
   ```
3. パッケージキャッシュをクリアする：
   ```bash
   rm -rf ~/Library/Caches/org.swift.swiftpm/
   ```
4. Xcodeを再起動し、パッケージを再度解決する

### ビルドエラー

ビルドエラーが発生した場合は、以下を確認してください：

1. 互換性のあるSwiftとXcodeのバージョンを使用していることを確認する
2. 依存関係が正しく設定されていることを確認する
3. キャッシュをクリアして再度ビルドする：
   ```bash
   xcodebuild clean
   ```

## 次のステップ

TemporalKitを正常にインストールしたら、以下のドキュメントをご覧ください：

- [コア概念](./CoreConcepts.md) - TemporalKitの基本概念を学ぶ
- [APIリファレンス](./APIReference.md) - 利用可能なAPIの詳細なドキュメント
- [チュートリアル](./Tutorials/README.md) - ステップバイステップのチュートリアル 
