import SwiftUI
import WidgetKit

struct ContentView: View {
    var body: some View {
        TabView {
            FavoritesView()
                .tabItem { Label("お気に入り", systemImage: "star.fill") }
            SearchView()
                .tabItem { Label("検索", systemImage: "magnifyingglass") }
            LeagueDirectoryView()
                .tabItem { Label("リーグ", systemImage: "trophy.fill") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
    }
}

// MARK: - Favorites + next fixtures

struct FavoritesView: View {
    @State private var teams: [FavoriteTeam] = []
    @State private var players: [FavoritePlayer] = []
    @State private var leagues: [FavoriteLeague] = []
    @State private var fixtures: [String: Fixture] = [:]
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List {
                Section("チーム") {
                    ForEach(teams) { team in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(team.name).font(.headline)
                            if let f = fixtures[team.id] {
                                Text("\(f.homeAwayLabel(for: team.name)) \(f.opponent(of: team.name)) ・ \(FormatHelp.kickoffText(f.kickoff))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                if f.status == .live {
                                    Text("LIVE \(f.liveMinute ?? "") \(f.homeScore ?? 0)-\(f.awayScore ?? 0)")
                                        .font(.subheadline).foregroundStyle(.red)
                                } else if let cd = Optional(FormatHelp.countdownText(to: f.kickoff)), !cd.isEmpty {
                                    Text(cd).font(.subheadline).foregroundStyle(.secondary)
                                }
                            } else {
                                Text(loading ? "取得中…" : "次節未取得").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) { SharedStore.shared.removeTeam(team); reload() } label: { Label("削除", systemImage: "trash") }
                            Button { SharedStore.shared.moveTeamToTop(team); reload() } label: { Label("先頭へ", systemImage: "arrow.up.to.line") }.tint(.blue)
                        }
                    }
                    if teams.isEmpty { Text("検索タブからチームを追加してください").foregroundStyle(.secondary) }
                }
                Section("選手") {
                    ForEach(players) { p in
                        HStack { Text(p.name); Spacer(); Text(p.teamName ?? "").foregroundStyle(.secondary) }
                            .swipeActions { Button(role: .destructive) { SharedStore.shared.removePlayer(p); reload() } label: { Label("削除", systemImage: "trash") } }
                    }
                    if players.isEmpty { Text("選手は未登録です").foregroundStyle(.secondary) }
                }
                Section("リーグ") {
                    ForEach(leagues) { l in
                        HStack { Text(l.name); Spacer(); Text(l.country ?? "").foregroundStyle(.secondary) }
                            .swipeActions { Button(role: .destructive) { SharedStore.shared.removeLeague(l); reload() } label: { Label("削除", systemImage: "trash") } }
                    }
                    if leagues.isEmpty { Text("リーグは未登録です").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("MatchDay Widget")
            .toolbar { Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") } }
            .task { reload(); await refresh() }
            .refreshable { await refresh() }
        }
    }

    private func reload() {
        teams = SharedStore.shared.favoriteTeams
        players = SharedStore.shared.favoritePlayers
        leagues = SharedStore.shared.favoriteLeagues
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func refresh() async {
        loading = true
        for team in teams {
            if let f = await FootballService.shared.nextFixture(for: team) { fixtures[team.id] = f }
        }
        loading = false
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Search (teams / players / leagues)

struct SearchView: View {
    enum Kind: String, CaseIterable { case team = "チーム", player = "選手", league = "リーグ" }
    @State private var kind: Kind = .team
    @State private var term: String = ""
    @State private var teamResults: [FavoriteTeam] = []
    @State private var playerResults: [FavoritePlayer] = []
    @State private var leagueResults: [FavoriteLeague] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            VStack {
                Picker("種別", selection: $kind) {
                    ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).padding(.horizontal)
                List {
                    switch kind {
                    case .team:
                        ForEach(teamResults) { t in
                            HStack { Text(t.name); Spacer() }
                                .contentShape(Rectangle())
                                .onTapGesture { SharedStore.shared.addTeam(t) }
                                .swipeActions { Button("追加") { SharedStore.shared.addTeam(t) }.tint(.green) }
                        }
                    case .player:
                        ForEach(playerResults) { p in
                            HStack { Text(p.name); Spacer(); Text(p.teamName ?? "").foregroundStyle(.secondary) }
                                .contentShape(Rectangle())
                                .onTapGesture { SharedStore.shared.addPlayer(p) }
                                .swipeActions { Button("追加") { SharedStore.shared.addPlayer(p) }.tint(.green) }
                        }
                    case .league:
                        ForEach(leagueResults) { l in
                            HStack { Text(l.name); Spacer(); Text(l.country ?? "").foregroundStyle(.secondary) }
                                .contentShape(Rectangle())
                                .onTapGesture { SharedStore.shared.addLeague(l) }
                                .swipeActions { Button("追加") { SharedStore.shared.addLeague(l) }.tint(.green) }
                        }
                    }
                    if searching { HStack { ProgressView(); Text("検索中…") } }
                }
            }
            .navigationTitle("検索・追加")
            .searchable(text: $term, prompt: "チーム・選手・リーグ名")
            .onSubmit(of: .search) { Task { await runSearch() } }
        }
    }

    private func runSearch() async {
        guard !term.isEmpty else { return }
        searching = true
        switch kind {
        case .team: teamResults = await FootballService.shared.searchTeams(term: term)
        case .player: playerResults = await FootballService.shared.searchPlayers(term: term)
        case .league:
            let all = await FootballService.shared.leagueDirectory()
            leagueResults = all.filter { $0.name.localizedCaseInsensitiveContains(term) }
        }
        searching = false
    }
}

// MARK: - League directory

struct LeagueDirectoryView: View {
    @State private var leagues: [FavoriteLeague] = []
    @State private var loading = false
    var body: some View {
        NavigationStack {
            List {
                if loading && leagues.isEmpty { HStack { ProgressView(); Text("リーグ一覧を取得中…") } }
                ForEach(leagues) { l in
                    HStack { Text(l.name); Spacer(); Text(l.country ?? "").foregroundStyle(.secondary) }
                        .contentShape(Rectangle())
                        .onTapGesture { SharedStore.shared.addLeague(l) }
                        .swipeActions { Button("追加") { SharedStore.shared.addLeague(l) }.tint(.green) }
                }
            }
            .navigationTitle("リーグ一覧")
            .task {
                loading = true
                leagues = await FootballService.shared.leagueDirectory()
                loading = false
            }
        }
    }
}
