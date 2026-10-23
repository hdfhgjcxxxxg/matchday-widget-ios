import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget entities (お気に入りから選択。Android版のウィジェットごと設定画面相当)

struct FavoriteTeamEntity: AppEntity, Identifiable {
    var id: String
    var name: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "お気に入りチーム"
    static var defaultQuery = FavoriteTeamQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct FavoriteTeamQuery: EntityQuery {
    func entities(for identifiers: [FavoriteTeamEntity.ID]) async throws -> [FavoriteTeamEntity] {
        SharedStore.shared.favoriteTeams.filter { identifiers.contains($0.id) }.map { FavoriteTeamEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [FavoriteTeamEntity] {
        SharedStore.shared.favoriteTeams.map { FavoriteTeamEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> FavoriteTeamEntity? {
        SharedStore.shared.favoriteTeams.first.map { FavoriteTeamEntity(id: $0.id, name: $0.name) }
    }
}

struct FavoritePlayerEntity: AppEntity, Identifiable {
    var id: String
    var name: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "お気に入り選手"
    static var defaultQuery = FavoritePlayerQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct FavoritePlayerQuery: EntityQuery {
    func entities(for identifiers: [FavoritePlayerEntity.ID]) async throws -> [FavoritePlayerEntity] {
        SharedStore.shared.favoritePlayers.filter { identifiers.contains($0.id) }.map { FavoritePlayerEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [FavoritePlayerEntity] {
        SharedStore.shared.favoritePlayers.map { FavoritePlayerEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> FavoritePlayerEntity? {
        SharedStore.shared.favoritePlayers.first.map { FavoritePlayerEntity(id: $0.id, name: $0.name) }
    }
}

struct FavoriteLeagueEntity: AppEntity, Identifiable {
    var id: String
    var name: String
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "お気に入りリーグ"
    static var defaultQuery = FavoriteLeagueQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct FavoriteLeagueQuery: EntityQuery {
    func entities(for identifiers: [FavoriteLeagueEntity.ID]) async throws -> [FavoriteLeagueEntity] {
        SharedStore.shared.favoriteLeagues.filter { identifiers.contains($0.id) }.map { FavoriteLeagueEntity(id: $0.id, name: $0.name) }
    }
    func suggestedEntities() async throws -> [FavoriteLeagueEntity] {
        SharedStore.shared.favoriteLeagues.map { FavoriteLeagueEntity(id: $0.id, name: $0.name) }
    }
    func defaultResult() async -> FavoriteLeagueEntity? {
        SharedStore.shared.favoriteLeagues.first.map { FavoriteLeagueEntity(id: $0.id, name: $0.name) }
    }
}

// MARK: - Configuration intents

struct SelectTeamIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "チームを選択"
    static var description = IntentDescription("ウィジェットに表示するお気に入りチームを選びます。")
    @Parameter(title: "チーム") var team: FavoriteTeamEntity?
}
struct SelectPlayerIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "選手を選択"
    static var description = IntentDescription("ウィジェットに表示するお気に入り選手を選びます。")
    @Parameter(title: "選手") var player: FavoritePlayerEntity?
}
struct SelectLeagueIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "リーグを選択"
    static var description = IntentDescription("ウィジェットに表示するお気に入りリーグを選びます。")
    @Parameter(title: "リーグ") var league: FavoriteLeagueEntity?
}

// MARK: - Entries

struct TeamEntry: TimelineEntry {
    let date: Date
    let team: FavoriteTeam?
    let fixture: Fixture?
    let style: WidgetStyleSettings
}
struct PlayerEntry: TimelineEntry {
    let date: Date
    let player: FavoritePlayer?
    let extras: PlayerExtras?
    let style: WidgetStyleSettings
}
struct LeagueEntry: TimelineEntry {
    let date: Date
    let league: FavoriteLeague?
    let round: LeagueRound?
    let style: WidgetStyleSettings
}

// MARK: - Providers
// Android版 MatchPhaseScheduler 相当: 次回リロードをキックオフ等の節目に合わせる。
// iOS では最終的な更新可否は OS が決めるため、方針提示として実装する。

struct TeamProvider: AppIntentTimelineProvider {
    typealias Entry = TeamEntry
    typealias Intent = SelectTeamIntent
    func placeholder(in context: Context) -> TeamEntry {
        TeamEntry(date: Date(), team: SharedStore.shared.favoriteTeams.first, fixture: nil, style: SharedStore.shared.style)
    }
    func snapshot(for configuration: SelectTeamIntent, in context: Context) async -> TeamEntry {
        await entry(for: configuration)
    }
    func timeline(for configuration: SelectTeamIntent, in context: Context) async -> Timeline<TeamEntry> {
        let e = await entry(for: configuration)
        var dates: [Date] = [Date().addingTimeInterval(1800)]
        if let k = e.fixture?.kickoff, k > Date() {
            dates.append(k); dates.append(k.addingTimeInterval(46 * 60)); dates.append(k.addingTimeInterval(106 * 60))
        }
        let next = dates.filter { $0 > Date() }.min() ?? Date().addingTimeInterval(1800)
        return Timeline(entries: [e], policy: .after(next))
    }
    private func entry(for configuration: SelectTeamIntent) async -> TeamEntry {
        let store = SharedStore.shared
        let team = configuration.team.flatMap { e in store.favoriteTeams.first { $0.id == e.id } } ?? store.favoriteTeams.first
        var fixture: Fixture?
        if let team { fixture = await FootballService.shared.nextFixture(for: team) }
        return TeamEntry(date: Date(), team: team, fixture: fixture, style: store.style)
    }
}

struct PlayerProvider: AppIntentTimelineProvider {
    typealias Entry = PlayerEntry
    typealias Intent = SelectPlayerIntent
    func placeholder(in context: Context) -> PlayerEntry {
        PlayerEntry(date: Date(), player: SharedStore.shared.favoritePlayers.first, extras: nil, style: SharedStore.shared.style)
    }
    func snapshot(for configuration: SelectPlayerIntent, in context: Context) async -> PlayerEntry { await entry(for: configuration) }
    func timeline(for configuration: SelectPlayerIntent, in context: Context) async -> Timeline<PlayerEntry> {
        let e = await entry(for: configuration)
        return Timeline(entries: [e], policy: .after(Date().addingTimeInterval(1800)))
    }
    private func entry(for configuration: SelectPlayerIntent) async -> PlayerEntry {
        let store = SharedStore.shared
        let player = configuration.player.flatMap { e in store.favoritePlayers.first { $0.id == e.id } } ?? store.favoritePlayers.first
        var extras: PlayerExtras?
        if let player { extras = await FootballService.shared.playerExtras(for: player) }
        return PlayerEntry(date: Date(), player: player, extras: extras, style: store.style)
    }
}

struct LeagueProvider: AppIntentTimelineProvider {
    typealias Entry = LeagueEntry
    typealias Intent = SelectLeagueIntent
    func placeholder(in context: Context) -> LeagueEntry {
        LeagueEntry(date: Date(), league: SharedStore.shared.favoriteLeagues.first, round: nil, style: SharedStore.shared.style)
    }
    func snapshot(for configuration: SelectLeagueIntent, in context: Context) async -> LeagueEntry { await entry(for: configuration) }
    func timeline(for configuration: SelectLeagueIntent, in context: Context) async -> Timeline<LeagueEntry> {
        let e = await entry(for: configuration)
        return Timeline(entries: [e], policy: .after(Date().addingTimeInterval(1800)))
    }
    private func entry(for configuration: SelectLeagueIntent) async -> LeagueEntry {
        let store = SharedStore.shared
        let league = configuration.league.flatMap { e in store.favoriteLeagues.first { $0.id == e.id } } ?? store.favoriteLeagues.first
        var round: LeagueRound?
        if let league { round = await FootballService.shared.leagueNextFixtures(for: league) }
        return LeagueEntry(date: Date(), league: league, round: round, style: store.style)
    }
}

// MARK: - Views

struct TeamWidgetView: View {
    let entry: TeamEntry
    var body: some View {
        let style = entry.style
        let bg = Color(hex: style.backgroundColorHex)
        VStack(alignment: .leading, spacing: style.scaled(4)) {
            if let team = entry.team {
                Text(team.name)
                    .font(style.font.makeFont(size: style.scaled(15), weight: .bold))
                    .lineLimit(1)
                if let f = entry.fixture {
                    Text("\(f.homeAwayLabel(for: team.name)). \(f.opponent(of: team.name))")
                        .font(style.font.makeFont(size: style.scaled(13)))
                        .lineLimit(1)
                    Text(FormatHelp.kickoffText(f.kickoff))
                        .font(style.font.makeFont(size: style.scaled(12)))
                        .foregroundStyle(.secondary)
                    if f.status == .live {
                        Text("LIVE \(f.liveMinute ?? "")  \(f.homeScore ?? 0) - \(f.awayScore ?? 0)")
                            .font(style.font.makeFont(size: style.scaled(13), weight: .bold)).foregroundStyle(.red)
                    } else if style.showCountdown, let k = f.kickoff, k > Date() {
                        Text(timerInterval: Date()...k, countsDown: true)
                            .font(style.font.makeFont(size: style.scaled(13), weight: .semibold))
                            .monospacedDigit()
                    }
                    if !f.competitionName.isEmpty {
                        Text(f.competitionName).font(style.font.makeFont(size: style.scaled(11))).foregroundStyle(.secondary).lineLimit(1)
                    }
                } else {
                    Text("次節を取得できません").font(style.font.makeFont(size: style.scaled(12))).foregroundStyle(.secondary)
                }
            } else {
                Text("アプリでチームをお気に入りに追加してください").font(style.font.makeFont(size: style.scaled(12)))
            }
            Spacer(minLength: 0)
            Text(FormatHelp.updatedText(entry.date)).font(style.font.makeFont(size: style.scaled(10))).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(style.scaled(10))
        .background(bg)
        .foregroundStyle(bg.readableTextColor)
        .widgetURL(entry.fixture.flatMap { entry.style.tapTarget.url(for: $0) })
    }
}

struct PlayerWidgetView: View {
    let entry: PlayerEntry
    var body: some View {
        let style = entry.style
        let bg = Color(hex: style.backgroundColorHex)
        VStack(alignment: .leading, spacing: style.scaled(4)) {
            if let p = entry.player {
                Text(p.name).font(style.font.makeFont(size: style.scaled(15), weight: .bold)).lineLimit(1)
                if let team = p.teamName { Text(team).font(style.font.makeFont(size: style.scaled(12))).foregroundStyle(.secondary) }
                if let ex = entry.extras {
                    if let r = ex.rating { Text(String(format: "レーティング %.2f", r)).font(style.font.makeFont(size: style.scaled(12))) }
                    if let f = ex.nextFixture {
                        Text("次節: \(f.opponent(of: p.teamName ?? "")) ・ \(FormatHelp.kickoffText(f.kickoff))")
                            .font(style.font.makeFont(size: style.scaled(12))).lineLimit(2)
                        if style.showCountdown, let k = f.kickoff, k > Date() {
                            Text(FormatHelp.countdownText(to: k)).font(style.font.makeFont(size: style.scaled(12), weight: .semibold))
                        }
                    }
                }
            } else {
                Text("アプリで選手をお気に入りに追加してください").font(style.font.makeFont(size: style.scaled(12)))
            }
            Spacer(minLength: 0)
            Text(FormatHelp.updatedText(entry.date)).font(style.font.makeFont(size: style.scaled(10))).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(style.scaled(10))
        .background(bg)
        .foregroundStyle(bg.readableTextColor)
    }
}

struct LeagueWidgetView: View {
    let entry: LeagueEntry
    var body: some View {
        let style = entry.style
        let bg = Color(hex: style.backgroundColorHex)
        VStack(alignment: .leading, spacing: style.scaled(3)) {
            if let league = entry.league {
                Text(league.name).font(style.font.makeFont(size: style.scaled(14), weight: .bold)).lineLimit(1)
                if let round = entry.round {
                    ForEach(round.fixtures.prefix(4)) { f in
                        HStack(spacing: 4) {
                            Text("\(f.homeTeam) v \(f.awayTeam)").font(style.font.makeFont(size: style.scaled(11))).lineLimit(1)
                            Spacer()
                            Text(FormatHelp.kickoffText(f.kickoff)).font(style.font.makeFont(size: style.scaled(10))).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("日程を取得できません").font(style.font.makeFont(size: style.scaled(12))).foregroundStyle(.secondary)
                }
            } else {
                Text("アプリでリーグをお気に入りに追加してください").font(style.font.makeFont(size: style.scaled(12)))
            }
            Spacer(minLength: 0)
            Text(FormatHelp.updatedText(entry.date)).font(style.font.makeFont(size: style.scaled(10))).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(style.scaled(10))
        .background(bg)
        .foregroundStyle(bg.readableTextColor)
    }
}

// MARK: - Widgets

struct TeamWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "TeamWidget", intent: SelectTeamIntent.self, provider: TeamProvider()) { entry in
            TeamWidgetView(entry: entry)
        }
        .configurationDisplayName("チーム")
        .description("お気に入りチームの次節とカウントダウン")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
struct PlayerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PlayerWidget", intent: SelectPlayerIntent.self, provider: PlayerProvider()) { entry in
            PlayerWidgetView(entry: entry)
        }
        .configurationDisplayName("選手")
        .description("お気に入り選手と所属チームの次節")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
struct LeagueWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "LeagueWidget", intent: SelectLeagueIntent.self, provider: LeagueProvider()) { entry in
            LeagueWidgetView(entry: entry)
        }
        .configurationDisplayName("リーグ")
        .description("お気に入りリーグの次節一覧")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct MatchDayWidgets: WidgetBundle {
    var body: some Widget {
        TeamWidget()
        PlayerWidget()
        LeagueWidget()
    }
}
