# MatchDay Widget iOS — Android版との機能対応表

Android版 `football-fixture-widget` v13.0（Kotlin）の全機能を iOS（SwiftUI + WidgetKit）で再現するための対応表。
「全く同じ機能」が目標。iOS のプラットフォーム仕様で直接再現できないものは、等価な代替方法を明記する。

## データ取得
| Android版 | iOS版 | 備考 |
|---|---|---|
| データソース切替（結合 / FotMob / SofaScore） | `DataSourceMode`（both / fotmob / sofascore）として同一実装 | SofaScore が 403 の場合は結合モードで FotMob に自動フォールバック（Android版と同じ挙動） |
| リーグ一覧（両プロバイダ統合・同一リーグのマージ） | `LeagueDirectoryService` | FotMob `api/data/allLeagues`、SofaScore `unique-tournaments` |
| リーグ所属チーム一覧 | 同一エンドポイントで実装 | |
| チーム検索（両プロバイダ統合） | `TeamSearchService` | FotMob suggest / SofaScore search/all |
| 選手検索（両プロバイダ統合）＋所属チーム補完 | `PlayerSearchService` | |
| 次節取得（チーム、両プロバイダ統合） | `NextFixtureService` | FotMob `api/data/teams`、SofaScore `team/{id}/events/next/0` |
| チーム詳細スタッツ（直近試合・順位など） | `TeamExtrasService`（AdvancedStatsRepository 相当） | |
| 選手パフォーマンス（レーティング・出場状況） | `PlayerExtrasService` | |
| リーグの節別日程（ラウンド） | `LeagueRoundsService` | |
| ライブ中の試合分数表示 | 同一ロジック（キックオフ時刻から算出、HT表示含む） | |
| チームロゴ / 選手画像の取得 | FotMob 画像 CDN / SofaScore 画像 API（Android版と同じURL規則） | |
| オフラインキャッシュ（取得失敗時に前回データを表示） | App Group 共有キャッシュに同一方針で実装 | |

## お気に入り
| Android版 | iOS版 | 備考 |
|---|---|---|
| お気に入りチーム（無制限、追加/削除/先頭へ移動） | App Group の共有ストアに保存 | FotMob/SofaScore 両IDを保持し、プロバイダ切替後も再登録不要（Android版と同じ） |
| お気に入り選手（無制限） | 同上 | |
| お気に入りリーグ（無制限） | 同上 | |
| 旧形式からの移行 | 初回起動時に移行処理を用意 | iOS版は新規のため形式は最初から両ID形式 |

## ウィジェット
| Android版 | iOS版 | 備考 |
|---|---|---|
| チームウィジェット | WidgetKit `TeamWidget` | 次節・カウントダウン・ロゴ |
| 選手ウィジェット | WidgetKit `PlayerWidget` | 所属チームの次節＋選手スタッツ概要 |
| リーグウィジェット | WidgetKit `LeagueWidget` | 次節（次ラウンド）一覧 |
| ウィジェットごとに表示対象を選択 | iOS 17 AppIntent 設定（ウィジェット長押し→編集）で再現 | |
| カウントダウン表示ON/OFF | 設定を共有しウィジェットに反映。カウントダウン自体は iOS のタイマーテキストでライブ表示 | |
| ウィジェットごとに文字サイズ 1〜100（50=従来） | 設定として同一仕様で実装し、各ウィジェットに反映 | |
| フォント選択（標準 / NType82 / NDot57） | 同一設定項目。ドット系フォントは同等フォントに割当 | フォントファイルの権利確認後に同梱 |
| ウィジェット背景色（カラー設定） | 同一設定項目（16進カラー保存、文字色は自動で可読色を選択） | |
| 試合フェーズに合わせた自動更新（キックオフ/HT/FT前後） | Timeline のリロードポリシーで等価実装 | **iOS 制約**: 更新タイミングは OS が管理するため、Android版ほど厳密な時刻指定はできない |
| 30分ごとの定期更新 | Timeline リロード間隔で等価実装 | **iOS 制約**: OS の予算管理により前後する |

## アプリ本体
| Android版 | iOS版 | 備考 |
|---|---|---|
| チーム/選手/リーグの検索・登録画面 | SwiftUI で同構成（タブ＋検索） | |
| データ取得元メニュー（結合/SofaScore/FotMob の3択、絞り込み問題の修正含む） | Picker で実装（Android版の AutoComplete 絞り込み問題は iOS では発生しない） | |
| ウィジェットをタップして外部アプリを開く（FotMob / SofaScore / Flashscore 等） | タップ先設定＋各アプリの URL スキーム / ユニバーサルリンクで再現 | |
| ランチャーアイコンのスタイル切替（4種） | iOS の代替アイコン（Alternate App Icon）で再現 | アイコン素材は同デザインで書き出し |
| アプリ内アップデート通知（GitHub APK） | **iOS では対象外**（App Store / TestFlight / サイドロードの仕組みに従う） | Android 固有機能のため代替なし |
| 起動時クラッシュ回避・エラー表示 | 同一方針（失敗時はキャッシュ表示＋状態表示） | |

## 配布
| Android版 | iOS版 |
|---|---|
| GitHub Actions で署名済み APK / AAB を自動ビルドし Release へ | GitHub Actions（macOS ランナー）で IPA を自動ビルドし Release へ。署名は当面「未署名IPA（サイドロード時に再署名）」とし、Apple Developer 登録後は署名付きに切替可能な構成にする |
