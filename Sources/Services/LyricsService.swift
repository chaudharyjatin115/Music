import Foundation

public actor LyricsService {
    public static let shared = LyricsService()

    private var cache: [String: [LyricLine]] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheEntries = 30

    private init() {}

    private func storeInCache(id: String, lyrics: [LyricLine]) {
        if cache[id] == nil {
            cacheOrder.append(id)
        }
        cache[id] = lyrics
        while cacheOrder.count > maxCacheEntries {
            cache.removeValue(forKey: cacheOrder.removeFirst())
        }
    }

    public func fetchLyrics(song: Song) async -> [LyricLine] {
        if let cached = cache[song.id], !cached.isEmpty {
            return cached
        }

        let primary = await AppSettings.shared.lyricsProvider
        let fallbackEnabled = await AppSettings.shared.fallbackLyricsEnabled

        var order: [LyricsProvider] = [primary]
        if fallbackEnabled {
            let all = LyricsProvider.allCases
            for p in all where p != primary {
                order.append(p)
            }
        }

        for provider in order {
            if let lines = await fetch(from: provider, song: song), !lines.isEmpty {
                storeInCache(id: song.id, lyrics: lines)
                return lines
            }
        }

        return []
    }

    private func fetch(from provider: LyricsProvider, song: Song) async -> [LyricLine]? {
        switch provider {
        case .lrclib:
            return await fetchFromLRCLIB(song: song)
        case .youtubeMusic:
            let lines = await InnerTubeService.shared.fetchLyrics(videoId: song.id)
            return lines.isEmpty ? nil : lines
        case .musixmatch:
            let query = LyricsQuery(
                videoId: song.id,
                title: cleanTitle(song.title, artist: song.artist),
                artist: cleanArtist(song.artist),
                album: song.album,
                duration: song.duration
            )
            return (try? await MusixmatchClient.shared.lyrics(for: query))?.lines
        case .lyricsOvh:
            return await fetchFromLyricsOvh(song: song)
        case .saavn:
            return await fetchFromSaavn(song: song)
        }
    }

    private func extractLyrics(from json: [String: Any], duration: Double) -> [LyricLine]? {
        if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
            let parsed = LRCParser.parse(synced)
            if !parsed.isEmpty { return parsed }
        }
        if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
            return parsePlainLyrics(plain, duration: duration)
        }
        return nil
    }

    private func fetchFromLRCLIB(song: Song) async -> [LyricLine]? {
        let title = cleanTitle(song.title, artist: song.artist).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let artist = cleanArtist(song.artist).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let durationParam = song.duration > 0 ? "&duration=\(Int(song.duration))" : ""

        if let url = URL(string: "https://lrclib.net/api/get?track_name=\(title)&artist_name=\(artist)\(durationParam)"),
           let json = await requestJSON(url: url) as? [String: Any],
           let lines = extractLyrics(from: json, duration: song.duration) {
            return lines
        }

        let query = "\(cleanTitle(song.title, artist: song.artist)) \(cleanArtist(song.artist))".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://lrclib.net/api/search?q=\(query)"),
           let list = await requestJSON(url: url) as? [[String: Any]] {
            for item in list {
                if let lines = extractLyrics(from: item, duration: song.duration) {
                    return lines
                }
            }
        }

        return nil
    }

    private func fetchFromLyricsOvh(song: Song) async -> [LyricLine]? {
        let artist = cleanArtist(song.artist).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let title = cleanTitle(song.title, artist: song.artist).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        guard let url = URL(string: "https://api.lyrics.ovh/v1/\(artist)/\(title)"),
              let json = await requestJSON(url: url) as? [String: Any],
              let text = json["lyrics"] as? String, !text.isEmpty else {
            return nil
        }
        return parsePlainLyrics(text, duration: song.duration)
    }

    private func fetchFromSaavn(song: Song) async -> [LyricLine]? {
        let query = "\(cleanTitle(song.title, artist: song.artist)) \(cleanArtist(song.artist))".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let searchUrl = URL(string: "https://www.jiosaavn.com/api.php?__call=search.getResults&_format=json&_marker=0&ctx=web6dot0&p=1&n=5&q=\(query)"),
              let json = await requestJSON(url: searchUrl) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else {
            return nil
        }

        for item in results {
            guard let hasLyrics = item["has_lyrics"] as? String, hasLyrics == "true",
                  let id = item["id"] as? String else { continue }
            guard let lrcUrl = URL(string: "https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&ctx=web6dot0&_format=json&_marker=0&lyrics_id=\(id)"),
              let lrcJson = await requestJSON(url: lrcUrl) as? [String: Any],
              let lyrics = lrcJson["lyrics"] as? String, !lyrics.isEmpty else { continue }
            let cleaned = lyrics.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            return parsePlainLyrics(cleaned, duration: song.duration)
        }
        return nil
    }

    private func requestJSON(url: URL, timeout: TimeInterval = 5) async -> Any? {
        var req = URLRequest(url: url)
        req.setValue("Music/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = timeout
        guard let (data, resp) = try? await NetworkSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return json
    }

    private func parsePlainLyrics(_ plain: String, duration: Double = 0) -> [LyricLine] {
        let lines = plain.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }

        let stepMs = duration > 10 ? Int((duration * 1000.0) / Double(lines.count)) : 3500
        return lines.enumerated().map { index, text in
            LyricLine(startTimeMs: index * stepMs, text: text)
        }
    }

    private func cleanTitle(_ title: String, artist: String? = nil) -> String {
        SaavnStreamingService.cleanTitle(title, artist: artist)
    }

    private func cleanArtist(_ artist: String) -> String {
        SaavnStreamingService.cleanArtist(artist)
    }
}
