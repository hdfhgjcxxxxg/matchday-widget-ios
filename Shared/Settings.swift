import Foundation
import SwiftUI

// MARK: - Data source (DataSourceManager 相当)

public enum DataSourceMode: String, Codable, CaseIterable, Identifiable {
    case both, fotmob, sofascore
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .both: return "結合"
        case .fotmob: return "FotMob"
        case .sofascore: return "SofaScore"
        }
    }
    public var allowsFotMob: Bool { self != .sofascore }
    public var allowsSofaScore: Bool { self != .fotmob }
}

// MARK: - Widget appearance (Android版 v13 の設定項目と同一仕様)

public enum WidgetFontChoice: String, Codable, CaseIterable, Identifiable {
    case standard, nType82, nDot57
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .standard: return "標準"
        case .nType82: return "NType82"
        case .nDot57: return "NDot57"
        }
    }
    /// テキストに適用するフォント。ドット系は等幅・太字で代替表現する。
    public func makeFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .standard: return .system(size: size, weight: weight)
        case .nType82: return .system(size: size, weight: weight, design: .rounded)
        case .nDot57: return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

public enum TapTarget: String, Codable, CaseIterable, Identifiable {
    case app, fotmob, sofascore, flashscore, liveScore
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .app: return "アプリ内"
        case .fotmob: return "FotMob"
        case .sofascore: return "SofaScore"
        case .flashscore: return "Flashscore"
        case .liveScore: return "LiveScore"
        }
    }
    public func url(for fixture: Fixture?) -> URL? {
        switch self {
        case .app: return nil
        case .fotmob:
            if let id = fixture?.id, id.hasPrefix("fotmob-") {
                return URL(string: "https://www.fotmob.com/match/\(id.dropFirst("fotmob-".count))")
            }
            return URL(string: "https://www.fotmob.com/")
        case .sofascore: return URL(string: "https://www.sofascore.com/")
        case .flashscore: return URL(string: "https://www.flashscore.com/")
        case .liveScore: return URL(string: "https://www.livescore.com/")
        }
    }
}

public struct WidgetStyleSettings: Codable, Equatable {
    /// ウィジェットごとに文字サイズ 1〜100 (50 = 従来サイズ) — Android版 v13.0 と同一仕様
    public var textSize: Int = 50
    public var font: WidgetFontChoice = .standard
    public var showCountdown: Bool = true
    public var backgroundColorHex: String = "#101418"
    public var tapTarget: TapTarget = .app

    public init() {}
    /// 50 を基準 (1.0倍) とするスケール。Android版と同じ線形換算。
    public var textScale: CGFloat { CGFloat(textSize) / 50.0 }
    public func scaled(_ base: CGFloat) -> CGFloat { base * textScale }
}

public enum LauncherIconStyle: String, Codable, CaseIterable, Identifiable {
    case style1, style2, style3, style4
    public var id: String { rawValue }
    public var label: String { "スタイル \(rawValue.dropFirst("style".count))" }
    /// UIApplication alternate icon name (style1 はプライマリ)
    public var alternateIconName: String? {
        switch self {
        case .style1: return nil
        case .style2: return "IconStyle2"
        case .style3: return "IconStyle3"
        case .style4: return "IconStyle4"
        }
    }
}

// MARK: - Shared store (App Group 経由でアプリとウィジェットが共有)

public final class SharedStore {
    public static let appGroupId = "group.com.example.matchdaywidget"
    public static let shared = SharedStore()

    private let defaults: UserDefaults
    public init() {
        defaults = UserDefaults(suiteName: SharedStore.appGroupId) ?? .standard
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    // Settings
    public var dataSourceMode: DataSourceMode {
        get { decode(DataSourceMode.self, key: "data_source_mode_v12") ?? .both }
        set { encode(newValue, key: "data_source_mode_v12") }
    }
    public var style: WidgetStyleSettings {
        get { decode(WidgetStyleSettings.self, key: "widget_style_v13") ?? WidgetStyleSettings() }
        set { encode(newValue, key: "widget_style_v13") }
    }
    public var launcherIconStyle: LauncherIconStyle {
        get { decode(LauncherIconStyle.self, key: "launcher_icon_style") ?? .style1 }
        set { encode(newValue, key: "launcher_icon_style") }
    }

    // Favorites
    public var favoriteTeams: [FavoriteTeam] {
        get { decode([FavoriteTeam].self, key: "favorite_teams") ?? [] }
        set { encode(newValue, key: "favorite_teams") }
    }
    public var favoritePlayers: [FavoritePlayer] {
        get { decode([FavoritePlayer].self, key: "favorite_players") ?? [] }
        set { encode(newValue, key: "favorite_players") }
    }
    public var favoriteLeagues: [FavoriteLeague] {
        get { decode([FavoriteLeague].self, key: "favorite_leagues") ?? [] }
        set { encode(newValue, key: "favorite_leagues") }
    }

    public func addTeam(_ team: FavoriteTeam) {
        var list = favoriteTeams
        if let i = list.firstIndex(where: { $0.name == team.name }) {
            // 両 ID をマージして保持する (Android版 mergeTeam 相当)
            if list[i].fotmobId == nil { list[i].fotmobId = team.fotmobId }
            if list[i].sofascoreId == nil { list[i].sofascoreId = team.sofascoreId }
        } else { list.append(team) }
        favoriteTeams = list
    }
    public func removeTeam(_ team: FavoriteTeam) { favoriteTeams = favoriteTeams.filter { $0.id != team.id } }
    public func moveTeamToTop(_ team: FavoriteTeam) {
        var list = favoriteTeams
        guard let i = list.firstIndex(of: team) else { return }
        let item = list.remove(at: i); list.insert(item, at: 0); favoriteTeams = list
    }
    public func addPlayer(_ player: FavoritePlayer) {
        var list = favoritePlayers
        if !list.contains(where: { $0.name == player.name }) { list.append(player) }
        favoritePlayers = list
    }
    public func removePlayer(_ player: FavoritePlayer) { favoritePlayers = favoritePlayers.filter { $0.id != player.id } }
    public func addLeague(_ league: FavoriteLeague) {
        var list = favoriteLeagues
        if let i = list.firstIndex(where: { $0.name == league.name }) {
            if list[i].fotmobId == nil { list[i].fotmobId = league.fotmobId }
            if list[i].sofascoreId == nil { list[i].sofascoreId = league.sofascoreId }
        } else { list.append(league) }
        favoriteLeagues = list
    }
    public func removeLeague(_ league: FavoriteLeague) { favoriteLeagues = favoriteLeagues.filter { $0.id != league.id } }

    // Offline caches (Android版 saveCache/loadCache 相当)
    public func cacheFixture(_ fixture: Fixture?, key: String) {
        if let fixture { encode(fixture, key: "cache_fixture_\(key)") }
        defaults.set(Date().timeIntervalSince1970, forKey: "cache_fixture_at_\(key)")
    }
    public func cachedFixture(key: String) -> Fixture? { decode(Fixture.self, key: "cache_fixture_\(key)") }
    public func cacheTeamExtras(_ extras: TeamExtras, teamName: String) { encode(extras, key: "cache_teamextras_\(teamName)") }
    public func cachedTeamExtras(teamName: String) -> TeamExtras? { decode(TeamExtras.self, key: "cache_teamextras_\(teamName)") }
    public func cachePlayerExtras(_ extras: PlayerExtras, playerName: String) { encode(extras, key: "cache_playerextras_\(playerName)") }
    public func cachedPlayerExtras(playerName: String) -> PlayerExtras? { decode(PlayerExtras.self, key: "cache_playerextras_\(playerName)") }
    public func cacheLeagueRound(_ round: LeagueRound, leagueName: String) { encode(round, key: "cache_leagueround_\(leagueName)") }
    public func cachedLeagueRound(leagueName: String) -> LeagueRound? { decode(LeagueRound.self, key: "cache_leagueround_\(leagueName)") }
}

// MARK: - Color helpers (Android版 preferredTextColor 相当: 背景から可読文字色を自動選択)

public extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if s.count == 6 { s = "FF" + s }
        let v = UInt64(s, radix: 16) ?? 0xFF101418
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: Double((v >> 24) & 0xFF) / 255)
    }
    func toHex() -> String {
        guard let c = UIColor(self).cgColor.components, c.count >= 3 else { return "#101418" }
        return String(format: "#%02X%02X%02X", Int(c[0] * 255), Int(c[1] * 255), Int(c[2] * 255))
    }
    /// 背景色の輝度から白/黒どちらの文字が読みやすいか
    var readableTextColor: Color {
        guard let c = UIColor(self).cgColor.components, c.count >= 3 else { return .white }
        let luminance = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
        return luminance > 0.6 ? .black : .white
    }
}
