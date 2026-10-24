import Foundation

// MARK: - Merged services
// Android版の「結合」モードと同じ方針: 両プロバイダを問い合わせ、同一エンティティをマージし、
// 一方が失敗 (SofaScore 403 等) したら他方で継続する。strict モードでは指定プロバイダのみ使う。

public struct FootballService {
    public static let shared = FootballService()
    private var mode: DataSourceMode { SharedStore.shared.dataSourceMode }
    private let fotmob = FotMobClient.shared
    private let sofa = SofaScoreClient.shared

    // MARK: Search teams

    public func searchTeams(term: String) async -> [FavoriteTeam] {
        var results: [FavoriteTeam] = []
        if mode.allowsFotMob {
            if let r = try? await searchTeamsFotMob(term: term) { results = mergeTeams(results, r) }
        }
        if mode.allowsSofaScore {
            if let r = try? await searchTeamsSofa(term: term) { results = mergeTeams(results, r) }
        }
        return results
    }

    private func searchTeamsFotMob(term: String) async throws -> [FavoriteTeam] {
        let root = try await fotmob.searchSuggest(term: term)
        // suggest の応答形式は {"data":[...]} / {"suggestions":[...]} の両形式があるため全体を走査する
        var out: [FavoriteTeam] = []
        var seen = Set<Int>()
        func walk(_ node: Any) {
            if let d = node as? [String: Any] {
                let type = JSONHelp.string(d["type"]) ?? ""
                if type == "team", let id = JSONHelp.int(d["id"]), let name = JSONHelp.string(d["name"]), seen.insert(id).inserted {
                    out.append(FavoriteTeam(fotmobId: id, name: name))
                }
                for v in d.values { walk(v) }
            } else if let a = node as? [Any] { for v in a { walk(v) } }
        }
        walk(root)
        return out
    }

    private func searchTeamsSofa(term: String) async throws -> [FavoriteTeam] {
        let root = try await sofa.search(term: term)
        var out: [FavoriteTeam] = []
        for item in JSONHelp.array(root["results"]) ?? [] {
            guard let d = JSONHelp.dict(item), JSONHelp.string(d["type"]) == "team",
                  let entity = JSONHelp.dict(d["entity"]),
                  let id = JSONHelp.int(entity["id"]), let name = JSONHelp.string(entity["name"]) else { continue }
            out.append(FavoriteTeam(sofascoreId: id, name: name))
        }
        return out
    }

    private func mergeTeams(_ a: [FavoriteTeam], _ b: [FavoriteTeam]) -> [FavoriteTeam] {
        var out = a
        for t in b {
            if let i = out.firstIndex(where: { normalize($0.name) == normalize(t.name) }) {
                if out[i].fotmobId == nil { out[i].fotmobId = t.fotmobId }
                if out[i].sofascoreId == nil { out[i].sofascoreId = t.sofascoreId }
            } else { out.append(t) }
        }
        return out
    }

    // MARK: Search players

    public func searchPlayers(term: String) async -> [FavoritePlayer] {
        var out: [FavoritePlayer] = []
        if mode.allowsSofaScore, let r = try? await searchPlayersSofa(term: term) { out.append(contentsOf: r) }
        if mode.allowsFotMob, let r = try? await searchPlayersFotMob(term: term) {
            for p in r where !out.contains(where: { normalize($0.name) == normalize(p.name) }) { out.append(p) }
        }
        return out
    }

    private func searchPlayersSofa(term: String) async throws -> [FavoritePlayer] {
        let root = try await sofa.search(term: term)
        var out: [FavoritePlayer] = []
        for item in JSONHelp.array(root["results"]) ?? [] {
            guard let d = JSONHelp.dict(item), JSONHelp.string(d["type"]) == "player",
                  let e = JSONHelp.dict(d["entity"]), let id = JSONHelp.int(e["id"]),
                  let name = JSONHelp.string(e["name"]) else { continue }
            let team = JSONHelp.dict(e["team"])
            out.append(FavoritePlayer(sofascoreId: id, name: name,
                                      teamName: JSONHelp.string(team?["name"]),
                                      teamSofascoreId: JSONHelp.int(team?["id"]),
                                      position: JSONHelp.string(e["position"])))
        }
        return out
    }

    private func searchPlayersFotMob(term: String) async throws -> [FavoritePlayer] {
        let root = try await fotmob.searchSuggest(term: term)
        var out: [FavoritePlayer] = []
        func walk(_ node: Any) {
            if let d = node as? [String: Any] {
                if JSONHelp.string(d["type"]) == "player", let id = JSONHelp.int(d["id"]), let name = JSONHelp.string(d["name"]) {
                    out.append(FavoritePlayer(fotmobId: id, name: name, teamName: JSONHelp.string(d["teamName"])))
                }
                for v in d.values { walk(v) }
            } else if let a = node as? [Any] { for v in a { walk(v) } }
        }
        walk(root)
        return out
    }

    // MARK: League directory

    public func leagueDirectory() async -> [FavoriteLeague] {
        var out: [FavoriteLeague] = []
        if mode.allowsFotMob, let r = try? await leagueDirectoryFotMob() { out = r }
        if mode.allowsSofaScore, let r = try? await leagueDirectorySofa() {
            for l in r {
                if let i = out.firstIndex(where: { normalize($0.name) == normalize(l.name) }) {
                    if out[i].sofascoreId == nil { out[i].sofascoreId = l.sofascoreId }
                } else { out.append(l) }
            }
        }
        return out.sorted { $0.name < $1.name }
    }

    private func leagueDirectoryFotMob() async throws -> [FavoriteLeague] {
        let root = try await fotmob.allLeagues()
        var out: [FavoriteLeague] = []
        func walk(_ node: Any) {
            if let d = node as? [String: Any] {
                // "leagues" 配列を持つ国などのコンテナ自体はリーグとして拾わない
                if let id = JSONHelp.int(d["id"]), let name = JSONHelp.string(d["name"]),
                   JSONHelp.dict(d["parentLeague"]) == nil, d["leagues"] == nil,
                   d["localizedName"] != nil || d["ccode"] != nil {
                    out.append(FavoriteLeague(fotmobId: id, name: name, country: JSONHelp.string(d["ccode"])))
                }
                for v in d.values { walk(v) }
            } else if let a = node as? [Any] { for v in a { walk(v) } }
        }
        walk(root)
        // 重複除去
        var seen = Set<String>(); return out.filter { seen.insert($0.name).inserted }
    }

    private func leagueDirectorySofa() async throws -> [FavoriteLeague] {
        let root = try await sofa.uniqueTournaments()
        var out: [FavoriteLeague] = []
        for g in JSONHelp.array(root["groups"]) ?? [] {
            for t in JSONHelp.array(JSONHelp.dict(g)?["uniqueTournaments"]) ?? [] {
                guard let d = JSONHelp.dict(t), let id = JSONHelp.int(d["id"]), let name = JSONHelp.string(d["name"]) else { continue }
                out.append(FavoriteLeague(sofascoreId: id, name: name))
            }
        }
        return out
    }

    // MARK: Next fixture

    public func nextFixture(for team: FavoriteTeam) async -> Fixture? {
        var candidates: [Fixture] = []
        if mode.allowsFotMob, let id = team.fotmobId, let f = try? await nextFixtureFotMob(teamId: id) { candidates.append(f) }
        if mode.allowsSofaScore, let id = team.sofascoreId, let f = try? await nextFixtureSofa(teamId: id) { candidates.append(f) }
        // 実施中・未来の試合の中で最も早いキックオフを採用する。
        // 単純な min だと終了済みの過去試合が「次節」として選ばれてしまう。
        let upcoming = candidates.filter { ($0.kickoff ?? .distantPast) >= Date().addingTimeInterval(-3 * 3600) && $0.status != .finished }
        let pool = upcoming.isEmpty ? candidates : upcoming
        let picked = pool.min { ($0.kickoff ?? .distantFuture) < ($1.kickoff ?? .distantFuture) }
        if let picked { SharedStore.shared.cacheFixture(picked, key: team.id) }
        return picked ?? SharedStore.shared.cachedFixture(key: team.id)
    }

    private func nextFixtureFotMob(teamId: Int) async throws -> Fixture? {
        let root = try await fotmob.team(id: teamId)
        var matches: [Any] = []
        JSONHelp.findAll(root, key: "nextMatch", into: &matches)
        if !matches.isEmpty {
            for m in matches {
                if let d = JSONHelp.dict(m), let f = parseFotMobMatch(d) { return f }
                if let a = JSONHelp.array(m) {
                    for item in a { if let d = JSONHelp.dict(item), let f = parseFotMobMatch(d) { return f } }
                }
            }
            return nil
        }
        // nextMatch が無い場合のみ fixtures にフォールバックする。
        // fixtures (allMatches) は過去の試合から並ぶため、終了済みは後回しにして未終了の最も早い試合を選ぶ。
        JSONHelp.findAll(root, key: "fixtures", into: &matches)
        var parsed: [Fixture] = []
        for m in matches {
            if let d = JSONHelp.dict(m), let f = parseFotMobMatch(d) { parsed.append(f) }
            if let a = JSONHelp.array(m) {
                for item in a { if let d = JSONHelp.dict(item), let f = parseFotMobMatch(d) { parsed.append(f) } }
            }
        }
        let active = parsed.filter { $0.status != .finished }
        return (active.isEmpty ? parsed : active).min { ($0.kickoff ?? .distantFuture) < ($1.kickoff ?? .distantFuture) }
    }

    private func parseFotMobMatch(_ d: [String: Any]) -> Fixture? {
        let home = JSONHelp.dict(d["home"]); let away = JSONHelp.dict(d["away"])
        let status = JSONHelp.dict(d["status"])
        guard let homeName = JSONHelp.string(home?["name"]) ?? JSONHelp.string(d["homeTeam"]),
              let awayName = JSONHelp.string(away?["name"]) ?? JSONHelp.string(d["awayTeam"]) else { return nil }
        let started = (status?["started"] as? Bool) ?? false
        let finished = (status?["finished"] as? Bool) ?? false
        let kickoff = JSONHelp.parseDate(status?["utcTime"]) ?? JSONHelp.parseDate(d["kickoff"]) ?? JSONHelp.parseDate(JSONHelp.dict(d["matchTimeUTC"])?["utcTime"])
        let id = JSONHelp.int(d["id"]).map { "fotmob-\($0)" } ?? "fotmob-\(homeName)-\(awayName)"
        return Fixture(id: id,
                       competitionName: JSONHelp.string(JSONHelp.dict(d["tournament"])?["name"]) ?? JSONHelp.string(d["leagueName"]) ?? "",
                       homeTeam: homeName, awayTeam: awayName,
                       homeTeamId: JSONHelp.int(home?["id"]), awayTeamId: JSONHelp.int(away?["id"]),
                       kickoff: kickoff,
                       status: finished ? .finished : (started ? .live : .notStarted),
                       homeScore: JSONHelp.int(home?["score"]), awayScore: JSONHelp.int(away?["score"]),
                       liveMinute: started && !finished ? JSONHelp.liveMinute(kickoff: kickoff, statusDisplay: JSONHelp.string(JSONHelp.dict(status?["liveTime"])?["short"])) : nil)
    }

    private func nextFixtureSofa(teamId: Int) async throws -> Fixture? {
        let root = try await sofa.teamNextEvents(teamId: teamId)
        for e in JSONHelp.array(root["events"]) ?? [] {
            if let d = JSONHelp.dict(e), let f = parseSofaEvent(d) { return f }
        }
        return nil
    }

    public func parseSofaEvent(_ d: [String: Any]) -> Fixture? {
        let home = JSONHelp.dict(d["homeTeam"]); let away = JSONHelp.dict(d["awayTeam"])
        guard let homeName = JSONHelp.string(home?["name"]), let awayName = JSONHelp.string(away?["name"]) else { return nil }
        let statusType = JSONHelp.string(JSONHelp.dict(d["status"])?["type"])
        let kickoff = JSONHelp.parseDate(d["startTimestamp"])
        let tournament = JSONHelp.dict(JSONHelp.dict(d["tournament"])?["uniqueTournament"]) ?? JSONHelp.dict(d["tournament"])
        let id = JSONHelp.int(d["id"]).map { "sofa-\($0)" } ?? "sofa-\(homeName)-\(awayName)"
        let live = statusType == "inprogress"
        return Fixture(id: id,
                       competitionName: JSONHelp.string(tournament?["name"]) ?? "",
                       homeTeam: homeName, awayTeam: awayName,
                       homeTeamId: JSONHelp.int(home?["id"]), awayTeamId: JSONHelp.int(away?["id"]),
                       kickoff: kickoff,
                       status: statusType == "finished" ? .finished : (live ? .live : .notStarted),
                       homeScore: JSONHelp.int(JSONHelp.dict(d["homeScore"])?["current"]),
                       awayScore: JSONHelp.int(JSONHelp.dict(d["awayScore"])?["current"]),
                       liveMinute: live ? JSONHelp.liveMinute(kickoff: kickoff, statusDisplay: nil) : nil)
    }

    // MARK: Team extras (AdvancedStatsRepository 相当)

    public func teamExtras(for team: FavoriteTeam) async -> TeamExtras {
        var extras = SharedStore.shared.cachedTeamExtras(teamName: team.name) ?? TeamExtras()
        if let id = team.sofascoreId, mode.allowsSofaScore,
           let root = try? await sofa.teamLastEvents(teamId: id) {
            let fixtures = (JSONHelp.array(root["events"]) ?? []).compactMap { JSONHelp.dict($0).flatMap(parseSofaEvent) }
            if !fixtures.isEmpty { extras.recentResults = fixtures }
        }
        if let next = await nextFixture(for: team) { extras.upcoming = [next] }
        extras.updatedAt = Date()
        SharedStore.shared.cacheTeamExtras(extras, teamName: team.name)
        return extras
    }

    // MARK: League next fixtures (LeagueWidget 用: お気に入りリーグの直近ラウンド)

    public func leagueNextFixtures(for league: FavoriteLeague) async -> LeagueRound? {
        if let cached = SharedStore.shared.cachedLeagueRound(leagueName: league.name),
           let at = cached.updatedAt, Date().timeIntervalSince(at) < 1800 { return cached }
        var round: LeagueRound?
        if let id = league.sofascoreId, mode.allowsSofaScore,
           let seasons = try? await sofa.tournamentSeasons(id: id),
           let seasonId = JSONHelp.int(JSONHelp.dict((JSONHelp.array(seasons["seasons"]) ?? []).first)?["id"]),
           let root = try? await sofa.seasonEvents(tournamentId: id, seasonId: seasonId, suffix: "next/0") {
            let fixtures = (JSONHelp.array(root["events"]) ?? []).compactMap { JSONHelp.dict($0).flatMap(parseSofaEvent) }
            if !fixtures.isEmpty { round = LeagueRound(roundName: "次節", fixtures: fixtures, updatedAt: Date()) }
        }
        if round == nil, let id = league.fotmobId, mode.allowsFotMob,
           let root = try? await fotmob.league(id: id) {
            var matches: [Any] = []
            JSONHelp.findAll(root, key: "matches", into: &matches)
            var fixtures: [Fixture] = []
            for m in matches { if let a = JSONHelp.array(m) { for it in a { if let d = JSONHelp.dict(it), let f = parseFotMobMatch(d), f.status == .notStarted { fixtures.append(f) } } } }
            fixtures.sort { ($0.kickoff ?? .distantFuture) < ($1.kickoff ?? .distantFuture) }
            if !fixtures.isEmpty { round = LeagueRound(roundName: "次節", fixtures: Array(fixtures.prefix(10)), updatedAt: Date()) }
        }
        if let round { SharedStore.shared.cacheLeagueRound(round, leagueName: league.name) }
        return round ?? SharedStore.shared.cachedLeagueRound(leagueName: league.name)
    }

    // MARK: Player extras

    public func playerExtras(for player: FavoritePlayer) async -> PlayerExtras {
        var extras = SharedStore.shared.cachedPlayerExtras(playerName: player.name) ?? PlayerExtras()
        // 所属チームの次節を選手の次節として表示する (Android版 hydratePlayerTeam 相当)
        if let teamName = player.teamName {
            let team = FavoriteTeam(fotmobId: player.teamFotmobId, sofascoreId: player.teamSofascoreId, name: teamName)
            extras.nextFixture = await nextFixture(for: team)
        }
        extras.updatedAt = Date()
        SharedStore.shared.cachePlayerExtras(extras, playerName: player.name)
        return extras
    }

    private func normalize(_ s: String) -> String {
        s.lowercased().folding(options: .diacriticInsensitive, locale: .current).filter { $0.isLetter || $0.isNumber }
    }
}

// MARK: - Formatting (Android版 formatDate / formatUpdatedAt / remaining 相当)

public enum FormatHelp {
    public static func kickoffText(_ date: Date?) -> String {
        guard let date else { return "日時未定" }
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d (E) HH:mm"
        return f.string(from: date)
    }
    public static func updatedText(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "HH:mm"
        return "更新 \(f.string(from: date))"
    }
    public static func countdownText(to date: Date?) -> String {
        guard let date else { return "" }
        let remain = date.timeIntervalSinceNow
        if remain <= 0 { return "" }
        let totalMinutes = Int(remain / 60)
        let d = totalMinutes / (60 * 24), h = (totalMinutes / 60) % 24, m = totalMinutes % 60
        if d > 0 { return "あと\(d)日\(h)時間" }
        if h > 0 { return "あと\(h)時間\(m)分" }
        return "あと\(m)分"
    }
}
