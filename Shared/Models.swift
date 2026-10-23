import Foundation

// MARK: - Favorites (Android版と同じく FotMob / SofaScore 両 ID を保持する)

public struct FavoriteTeam: Codable, Identifiable, Equatable, Hashable {
    public var fotmobId: Int?
    public var sofascoreId: Int?
    public var name: String
    public var shortName: String?
    public var id: String { "team-\(fotmobId ?? 0)-\(sofascoreId ?? 0)-\(name)" }
    public init(fotmobId: Int? = nil, sofascoreId: Int? = nil, name: String, shortName: String? = nil) {
        self.fotmobId = fotmobId; self.sofascoreId = sofascoreId; self.name = name; self.shortName = shortName
    }
}

public struct FavoritePlayer: Codable, Identifiable, Equatable, Hashable {
    public var fotmobId: Int?
    public var sofascoreId: Int?
    public var name: String
    public var teamName: String?
    public var teamFotmobId: Int?
    public var teamSofascoreId: Int?
    public var position: String?
    public var id: String { "player-\(fotmobId ?? 0)-\(sofascoreId ?? 0)-\(name)" }
    public init(fotmobId: Int? = nil, sofascoreId: Int? = nil, name: String, teamName: String? = nil, teamFotmobId: Int? = nil, teamSofascoreId: Int? = nil, position: String? = nil) {
        self.fotmobId = fotmobId; self.sofascoreId = sofascoreId; self.name = name
        self.teamName = teamName; self.teamFotmobId = teamFotmobId; self.teamSofascoreId = teamSofascoreId; self.position = position
    }
}

public struct FavoriteLeague: Codable, Identifiable, Equatable, Hashable {
    public var fotmobId: Int?
    public var sofascoreId: Int?
    public var name: String
    public var country: String?
    public var id: String { "league-\(fotmobId ?? 0)-\(sofascoreId ?? 0)-\(name)" }
    public init(fotmobId: Int? = nil, sofascoreId: Int? = nil, name: String, country: String? = nil) {
        self.fotmobId = fotmobId; self.sofascoreId = sofascoreId; self.name = name; self.country = country
    }
}

// MARK: - Fixture

public enum MatchStatus: String, Codable {
    case notStarted, live, finished, postponed, unknown
}

public struct Fixture: Codable, Identifiable, Equatable {
    public var id: String
    public var competitionName: String
    public var homeTeam: String
    public var awayTeam: String
    public var homeTeamId: Int?
    public var awayTeamId: Int?
    public var kickoff: Date?
    public var status: MatchStatus
    public var homeScore: Int?
    public var awayScore: Int?
    /// ライブ中の経過分数 (Android版 computeLiveMinute / extractFotMobLiveMinute 相当)
    public var liveMinute: String?

    public init(id: String, competitionName: String, homeTeam: String, awayTeam: String,
                homeTeamId: Int? = nil, awayTeamId: Int? = nil, kickoff: Date? = nil,
                status: MatchStatus = .notStarted, homeScore: Int? = nil, awayScore: Int? = nil, liveMinute: String? = nil) {
        self.id = id; self.competitionName = competitionName; self.homeTeam = homeTeam; self.awayTeam = awayTeam
        self.homeTeamId = homeTeamId; self.awayTeamId = awayTeamId; self.kickoff = kickoff
        self.status = status; self.homeScore = homeScore; self.awayScore = awayScore; self.liveMinute = liveMinute
    }

    public func isHome(team name: String) -> Bool { homeTeam == name }
    public func opponent(of name: String) -> String { homeTeam == name ? awayTeam : homeTeam }
    public func homeAwayLabel(for name: String) -> String { homeTeam == name ? "H" : "A" }
}

// MARK: - Extras (AdvancedStatsRepository 相当)

public struct TeamExtras: Codable, Equatable {
    public var recentResults: [Fixture] = []
    public var upcoming: [Fixture] = []
    public var leaguePosition: Int?
    public var form: String? // 例: "WWDLW"
    public var updatedAt: Date?
}

public struct PlayerExtras: Codable, Equatable {
    public var rating: Double?
    public var goals: Int?
    public var assists: Int?
    public var appearances: Int?
    public var isInLineup: Bool?
    public var nextFixture: Fixture?
    public var updatedAt: Date?
}

public struct LeagueRound: Codable, Equatable {
    public var roundName: String
    public var fixtures: [Fixture]
    public var updatedAt: Date?
}

// MARK: - Image URLs (Android版と同じURL規則)

public enum ImageURLBuilder {
    public static func teamLogo(fotmobId: Int?) -> URL? {
        guard let id = fotmobId else { return nil }
        return URL(string: "https://images.fotmob.com/image_resources/logo/teamlogo/\(id).png")
    }
    public static func teamLogo(sofascoreId: Int?) -> URL? {
        guard let id = sofascoreId else { return nil }
        return URL(string: "https://img.sofascore.com/api/v1/team/\(id)/image")
    }
    public static func playerImage(sofascoreId: Int?) -> URL? {
        guard let id = sofascoreId else { return nil }
        return URL(string: "https://img.sofascore.com/api/v1/player/\(id)/image")
    }
}
