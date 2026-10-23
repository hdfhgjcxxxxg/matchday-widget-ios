import Foundation

// MARK: - HTTP (Android版 PlatformHttpEngineClient / SofaScoreHttp 相当)

public enum APIError: Error { case http(Int), empty, decode }

public struct HTTPClient {
    public static let shared = HTTPClient()
    public func json(_ urlString: String) async throws -> Any {
        guard let url = URL(string: urlString) else { throw APIError.empty }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 { throw APIError.http(http.statusCode) }
        return try JSONSerialization.jsonObject(with: data)
    }
    public func object(_ urlString: String) async throws -> [String: Any] {
        let v = try await json(urlString)
        guard let o = v as? [String: Any] else { throw APIError.decode }
        return o
    }
}

// MARK: - JSON helpers (Android版 walkJson 相当の防御的パース)

public enum JSONHelp {
    public static func int(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) }
        return nil
    }
    public static func string(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }
    public static func dict(_ v: Any?) -> [String: Any]? { v as? [String: Any] }
    public static func array(_ v: Any?) -> [Any]? { v as? [Any] }

    /// 深い階層からキーを再帰探索する
    public static func findAll(_ node: Any, key: String, into: inout [Any]) {
        if let d = node as? [String: Any] {
            if let v = d[key] { into.append(v) }
            for v in d.values { findAll(v, key: key, into: &into) }
        } else if let a = node as? [Any] {
            for v in a { findAll(v, key: key, into: &into) }
        }
    }
    public static func parseDate(_ v: Any?) -> Date? {
        if let s = v as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: s) { return d }
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: s) { return d }
            let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC")
            for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd HH:mm:ss"] {
                f.dateFormat = fmt
                if let d = f.date(from: s) { return d }
            }
        }
        if let n = v as? NSNumber {
            let t = n.doubleValue
            return Date(timeIntervalSince1970: t > 1e12 ? t / 1000 : t)
        }
        return nil
    }
    /// ライブ分数の算出 (Android版 computeLiveMinute 相当)
    public static func liveMinute(kickoff: Date?, statusDisplay: String?) -> String? {
        if let s = statusDisplay, !s.isEmpty { return s }
        guard let kickoff else { return nil }
        let mins = Int(Date().timeIntervalSince(kickoff) / 60)
        if mins < 0 { return nil }
        if mins <= 45 { return "\(max(mins, 1))'" }
        if mins <= 60 { return "HT" }
        return "\(min(mins - 15, 90))'"
    }
}

// MARK: - FotMob

public struct FotMobClient {
    public static let shared = FotMobClient()
    private let http = HTTPClient.shared

    public func searchSuggest(term: String) async throws -> Any {
        let q = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        return try await http.json("https://www.fotmob.com/api/data/search/suggest?hits=80&lang=en,ja&term=\(q)")
    }
    public func team(id: Int) async throws -> [String: Any] {
        try await http.object("https://www.fotmob.com/api/data/teams?id=\(id)&ccode3=JPN")
    }
    public func league(id: Int) async throws -> [String: Any] {
        try await http.object("https://www.fotmob.com/api/data/leagues?id=\(id)&ccode3=JPN")
    }
    public func allLeagues() async throws -> Any {
        try await http.json("https://www.fotmob.com/api/data/allLeagues?locale=en")
    }
}

// MARK: - SofaScore

public struct SofaScoreClient {
    public static let shared = SofaScoreClient()
    private let http = HTTPClient.shared
    private let base = "https://api.sofascore.com/api/v1"

    public func search(term: String) async throws -> [String: Any] {
        let q = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? term
        return try await http.object("\(base)/search/all?q=\(q)")
    }
    public func teamNextEvents(teamId: Int) async throws -> [String: Any] {
        try await http.object("\(base)/team/\(teamId)/events/next/0")
    }
    public func teamLastEvents(teamId: Int) async throws -> [String: Any] {
        try await http.object("\(base)/team/\(teamId)/events/last/0")
    }
    public func uniqueTournaments() async throws -> [String: Any] {
        try await http.object("\(base)/sport/football/unique-tournaments")
    }
    public func tournamentSeasons(id: Int) async throws -> [String: Any] {
        try await http.object("\(base)/unique-tournament/\(id)/seasons")
    }
    public func seasonEvents(tournamentId: Int, seasonId: Int, suffix: String) async throws -> [String: Any] {
        try await http.object("\(base)/unique-tournament/\(tournamentId)/season/\(seasonId)/events/\(suffix)")
    }
}
