//
//  Lyrics.swift
//  YT Music
//
//  View-facing model for a track's lyrics, as served by YouTube Music's lyrics
//  tab (plain text) or LRCLIB (which may also provide time-synced LRC lines).
//

import Foundation

public struct LyricLine: Sendable, Equatable, Identifiable, Hashable, Codable {
    public var time: Double
    public var text: String
    /// Folds in the ordinal: lyric text repeats (choruses, blank lines).
    public var id: Int
    public var words: [TimedWord] = []
    /// Content end (richsync `te`); tells a real interlude from a line still being sung.
    public var end: Double? = nil

    public var startTimeMs: Int { Int(time * 1000) }
    public var startTimeSeconds: Double { time }

    public init(time: Double, text: String, id: Int = 0, words: [TimedWord] = [], end: Double? = nil) {
        self.time = time
        self.text = text
        self.id = id
        self.words = words
        self.end = end
    }

    public init(startTimeMs: Int, text: String, id: Int = 0) {
        self.init(time: Double(startTimeMs) / 1000.0, text: text, id: id)
    }
}

public struct TimedWord: Sendable, Equatable, Hashable, Codable {
    public var time: Double
    public var text: String

    public init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

public struct Lyrics: Sendable, Equatable {
    public var text: String
    public var source: String?
    public var lines: [LyricLine] = []

    public var isSynced: Bool { !lines.isEmpty }

    public init(text: String, source: String? = nil, lines: [LyricLine] = []) {
        self.text = text
        self.source = source
        self.lines = lines
    }
}

nonisolated enum LyricsFocus: Equatable {
    case none
    case line(Int)
    case interlude(before: Int, progress: Double)

    static let interludeThreshold = 6.0
    static let assumedLineDuration = 6.0

    static func resolve(_ lines: [LyricLine], at now: Double) -> LyricsFocus {
        guard !lines.isEmpty else { return .none }
        let pending = lines.firstIndex { $0.time > now }
        let currentIndex: Int? = if let pending { pending == 0 ? nil : pending - 1 } else { lines.count - 1 }

        if let pending {
            let gapStart = currentIndex.map { contentEnd(of: $0, in: lines) } ?? 0
            let gap = lines[pending].time - gapStart
            if gap >= interludeThreshold, now >= gapStart {
                let progress = gap > 0 ? (now - gapStart) / gap : 1
                return .interlude(before: pending, progress: min(max(progress, 0), 1))
            }
        }
        return currentIndex.map(LyricsFocus.line) ?? .none
    }

    private static func contentEnd(of i: Int, in lines: [LyricLine]) -> Double {
        if let end = lines[i].end { return end }
        if let lastWord = lines[i].words.last?.time { return lastWord }
        let nextStart = i + 1 < lines.count ? lines[i + 1].time : .greatestFiniteMagnitude
        return min(lines[i].time + assumedLineDuration, nextStart)
    }
}

nonisolated enum LyricsProvider: String, Codable, CaseIterable, Sendable, Identifiable {
    case lrclib
    case youtubeMusic
    case musixmatch
    case lyricsOvh
    case saavn

    var id: Self { self }

    var label: String {
        switch self {
        case .lrclib:       "LRCLIB (Synchronized)"
        case .youtubeMusic: "YouTube Music"
        case .musixmatch:   "Musixmatch"
        case .lyricsOvh:    "Lyrics.ovh"
        case .saavn:        "JioSaavn"
        }
    }
}

nonisolated struct LyricsQuery: Sendable, Equatable {
    var videoId: String
    var title: String
    var artist: String
    var album: String
    var duration: Double?

    init(videoId: String, title: String = "", artist: String = "", album: String = "", duration: Double? = nil) {
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
}
