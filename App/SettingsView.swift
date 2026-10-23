import SwiftUI
import WidgetKit

struct SettingsView: View {
    @State private var mode: DataSourceMode = SharedStore.shared.dataSourceMode
    @State private var style: WidgetStyleSettings = SharedStore.shared.style
    @State private var iconStyle: LauncherIconStyle = SharedStore.shared.launcherIconStyle
    @State private var bgColor: Color = Color(hex: SharedStore.shared.style.backgroundColorHex)
    @State private var iconError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("データ取得元") {
                    // Android版 v12.1 と同じ3択 (結合 / SofaScore / FotMob)
                    Picker("取得元", selection: $mode) {
                        ForEach(DataSourceMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("結合は FotMob と SofaScore を統合し、片方が使えない場合はもう一方で継続します。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("ウィジェット表示") {
                    Toggle("カウントダウン表示", isOn: $style.showCountdown)
                    VStack(alignment: .leading) {
                        Text("文字サイズ: \(style.textSize) (50 = 従来サイズ)")
                        Slider(value: Binding(get: { Double(style.textSize) }, set: { style.textSize = Int($0) }), in: 1...100, step: 1)
                    }
                    Picker("フォント", selection: $style.font) {
                        ForEach(WidgetFontChoice.allCases) { Text($0.label).tag($0) }
                    }
                    ColorPicker("背景色", selection: $bgColor, supportsOpacity: false)
                    Picker("タップで開く", selection: $style.tapTarget) {
                        ForEach(TapTarget.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("アプリアイコン") {
                    Picker("アイコンスタイル", selection: $iconStyle) {
                        ForEach(LauncherIconStyle.allCases) { Text($0.label).tag($0) }
                    }
                    if let iconError { Text(iconError).font(.footnote).foregroundStyle(.red) }
                }
                Section("このアプリについて") {
                    LabeledContent("バージョン", value: "13.0 (iOS版)")
                    LabeledContent("データ", value: "FotMob / SofaScore")
                    Text("非公式アプリです。各データ・ロゴの権利は提供元に帰属します。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .onChange(of: mode) { _, v in SharedStore.shared.dataSourceMode = v; reloadWidgets() }
            .onChange(of: style) { _, v in SharedStore.shared.style = v; reloadWidgets() }
            .onChange(of: bgColor) { _, v in
                style.backgroundColorHex = v.toHex()
            }
            .onChange(of: iconStyle) { _, v in
                SharedStore.shared.launcherIconStyle = v
                applyIcon(v)
            }
        }
    }

    private func reloadWidgets() { WidgetCenter.shared.reloadAllTimelines() }

    private func applyIcon(_ style: LauncherIconStyle) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconError = "この端末ではアイコン変更に未対応です"
            return
        }
        UIApplication.shared.setAlternateIconName(style.alternateIconName) { error in
            if let error { iconError = "アイコン変更に失敗: \(error.localizedDescription)" }
        }
    }
}
