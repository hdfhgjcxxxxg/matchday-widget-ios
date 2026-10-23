# MatchDay Widget for iOS

Android 版 **MatchDay Widget**（`football-fixture-widget` v13.0）の iOS 移植版。
SwiftUI + WidgetKit で、Android 版と全く同じ機能を搭載することを目標に開発します。
機能対応表は [FEATURE_PARITY.md](FEATURE_PARITY.md) を参照。

## 機能（Android 版と共通）
- データ取得元: **結合（自動統合）/ FotMob / SofaScore** の3モード。SofaScore が 403 の場合は FotMob へ自動フォールバック
- お気に入り: チーム / 選手 / リーグ（無制限、FotMob・SofaScore 両 ID を保持）
- ウィジェット 3 種: チーム / 選手 / リーグ。ウィジェットごとに表示対象・文字サイズ（1〜100）・フォント・背景色を設定可能
- 次節カウントダウン、ライブ中の試合分数、チーム詳細スタッツ、選手パフォーマンス、リーグの節別日程
- タップで FotMob / SofaScore 等の外部アプリを開く、アプリアイコンのスタイル切替

## ビルド
GitHub Actions（macOS ランナー）が XcodeGen でプロジェクトを生成し、未署名 IPA をビルドして
GitHub Release にアップロードします（`Build IPA` ワークフローを手動実行）。

ローカルで開く場合（Mac + Xcode）:
```sh
brew install xcodegen
xcodegen generate
open MatchDayWidget.xcodeproj
```

## 配布について
当面は未署名 IPA を SideStore / AltStore 等で再署名してインストールする想定です。
Apple Developer Program 登録後は、署名付きビルド / TestFlight へ切り替えます。

### AltStore / SideStore への追加
以下のソース URL を AltStore（Classic）または SideStore の「ソース」に追加すると、
インストールとアップデートがアプリ内からできます。

```
https://raw.githubusercontent.com/hdfhgjcxxxxg/matchday-widget-ios/main/altstore-source.json
```

IPA を直接入れる場合は、GitHub Release（v13.0-2000000026）の `MatchDayWidget.ipa` を使ってください。

※ AltStore PAL で配布するには Apple の公証（Apple Developer Program 登録が必要）が前提のため、
現時点では未対応です。対応手順は FEATURE_PARITY.md の配布セクションの方針どおり進めます。
