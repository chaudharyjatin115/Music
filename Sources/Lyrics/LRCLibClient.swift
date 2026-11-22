//
//  LRCLibClient.swift
//  YT Music
//

import Foundation

nonisolated final class LRCLibClient: LyricsProviding, Sendable {
    static let shared = LRCLibClient()

    private let session: URLSession
    private let baseURL = URL(string: "https://lrclib.net/api/")!
    // LRCLIB asks clients to identify themselves in the User-Agent.
    private let userAgent = "YT Music (macOS; https://github.com/tenshii/YT-Music)"

    init(session: URLSession? = nil) {
        self.session = session ?? NetworkSession.shared
    }

    private struct LRCLibTrack: Decodable {
        let id: Int?
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let plainLyrics: String?
        let syncedLyrics: String?
        let instrumental: Bool?
    }

    func lyrics(for query: LyricsQuery) async throws -> Lyrics? {
        let title = query.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        if let exact = try await exactMatch(query) { return exact }
        return try await searchMatch(query)
    }

    /// LRCLIB returns 404 for no exact match; treated as none.
    private func exactMatch(_ query: LyricsQuery) async throws -> Lyrics? {
        guard !query.artist.isEmpty else { return nil }   // get requires an artist
        var items = [
            URLQueryItem(name: "track_name", value: query.title),
            URLQueryItem(name: "artist_name", value: query.artist),
        ]
        if !query.album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: query.album))
        }
        if let duration = query.duration, duration > 0 {
            items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        if let track: LRCLibTrack = try await get("get", query: items),
           let lyrics = self.lyrics(from: track), !lyrics.lines.isEmpty {
            return lyrics
        }

        // Try exact match without album name if album-specific get failed
        if !query.album.isEmpty {
            var relaxedItems = [
                URLQueryItem(name: "track_name", value: query.title),
                URLQueryItem(name: "artist_name", value: query.artist),
            ]
            if let duration = query.duration, duration > 0 {
                relaxedItems.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
            }
            if let track: LRCLibTrack = try await get("get", query: relaxedItems),
               let lyrics = self.lyrics(from: track), !lyrics.lines.isEmpty {
                return lyrics
            }
        }

        return nil
    }

    private func searchMatch(_ query: LyricsQuery) async throws -> Lyrics? {
        let q = [query.title, query.artist].filter { !$0.isEmpty }.joined(separator: " ")
        let items = [URLQueryItem(name: "q", value: q)]
        guard let results: [LRCLibTrack] = try await get("search", query: items), !results.isEmpty else { return nil }

        // Prioritize tracks that have syncedLyrics and match duration closest to playback
        let syncedResults = results.filter { ($0.syncedLyrics?.isEmpty == false) }
        let pool = syncedResults.isEmpty ? results : syncedResults

        if let targetDuration = query.duration, targetDuration > 0 {
            let sorted = pool.sorted { a, b in
                let diffA = abs((a.duration ?? 0) - targetDuration)
                let diffB = abs((b.duration ?? 0) - targetDuration)
                return diffA < diffB
            }
            for candidate in sorted {
                if let lyrics = self.lyrics(from: candidate) {
                    return lyrics
                }
            }
        }

        return pool.lazy.compactMap { self.lyrics(from: $0) }.first
    }

    private func get<T: Decodable>(_ endpoint: String, query items: [URLQueryItem]) async throws -> T? {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func lyrics(from track: LRCLibTrack) -> Lyrics? {
        if track.instrumental == true {
            return Lyrics(text: String(localized: "lyrics.instrumental"), source: "LRCLIB")
        }
        let synced = track.syncedLyrics.map(LRCParser.parse) ?? []
        // Flatten synced lyrics to plain text when no plain text exists.
        let plain = track.plainLyrics.flatMap { $0.isEmpty ? nil : $0 }
            ?? synced.map(\.text).joined(separator: "\n")
        guard !plain.isEmpty else { return nil }
        return Lyrics(text: plain, source: String(format: String(localized: "lyrics.source"), "LRCLIB"), lines: synced)
    }
}
