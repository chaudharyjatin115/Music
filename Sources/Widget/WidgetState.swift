import Foundation
import AppKit

public struct WidgetPlaybackSnapshot: Codable {
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    public var duration: Double
    public var currentTime: Double
    public var hasArtwork: Bool
    public var timestamp: Date

    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        isPlaying: Bool = false,
        duration: Double = 0,
        currentTime: Double = 0,
        hasArtwork: Bool = false,
        timestamp: Date = Date()
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.currentTime = currentTime
        self.hasArtwork = hasArtwork
        self.timestamp = timestamp
    }
}

public enum WidgetBridge {
    public static let sharedDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MusicWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    public static var stateFileURL: URL {
        sharedDirectory.appendingPathComponent("playback_state.json")
    }

    public static var artworkFileURL: URL {
        sharedDirectory.appendingPathComponent("artwork.jpg")
    }

    public static let toggleNotification = NSNotification.Name("com.music.app.widget.toggle")
    public static let nextNotification = NSNotification.Name("com.music.app.widget.next")
    public static let previousNotification = NSNotification.Name("com.music.app.widget.previous")

    public static func writeState(_ snapshot: WidgetPlaybackSnapshot, artworkData: Data? = nil) {
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: stateFileURL, options: .atomic)
        }
        if let art = artworkData {
            try? art.write(to: artworkFileURL, options: .atomic)
        }
    }

    public static func readState() -> WidgetPlaybackSnapshot {
        guard let data = try? Data(contentsOf: stateFileURL),
              let snapshot = try? JSONDecoder().decode(WidgetPlaybackSnapshot.self, from: data) else {
            return WidgetPlaybackSnapshot()
        }
        return snapshot
    }
}
