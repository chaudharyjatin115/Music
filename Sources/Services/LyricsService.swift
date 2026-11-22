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
            let preferred: [LyricsProvider] = [.lrclib, .musixmatch]
            for p in preferred where !order.contains(p) {
                order.append(p)
            }
            for p in LyricsProvider.allCases where !order.contains(p) {
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
        let query = LyricsQuery(
            videoId: song.id,
            title: cleanTitle(song.title, artist: song.artist),
            artist: cleanArtist(song.artist),
            album: song.album,
            duration: song.duration
        )
        switch provider {
        case .lrclib:
            return (try? await LRCLibClient.shared.lyrics(for: query))?.lines
        case .musixmatch:
            return (try? await MusixmatchClient.shared.lyrics(for: query))?.lines
        case .youtubeMusic:
            let lines = await InnerTubeService.shared.fetchLyrics(videoId: song.id)
            return lines.isEmpty ? nil : lines
        case .saavn, .lyricsOvh:
            return nil
        }
    }

    private func cleanTitle(_ title: String, artist: String? = nil) -> String {
        SaavnStreamingService.cleanTitle(title, artist: artist)
    }

    private func cleanArtist(_ artist: String) -> String {
        SaavnStreamingService.cleanArtist(artist)
    }
}
