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
    public var volume: Float
    public var timestamp: Date

    public init(
        title: String = "",
        artist: String = "",
        album: String = "",
        isPlaying: Bool = false,
        duration: Double = 0,
        currentTime: Double = 0,
        hasArtwork: Bool = false,
        volume: Float = 0.8,
        timestamp: Date = Date()
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.currentTime = currentTime
        self.hasArtwork = hasArtwork
        self.volume = volume
        self.timestamp = timestamp
    }

    private enum CodingKeys: String, CodingKey {
        case title, artist, album, isPlaying, duration, currentTime, hasArtwork, volume, timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? ""
        self.album = try container.decodeIfPresent(String.self, forKey: .album) ?? ""
        self.isPlaying = try container.decodeIfPresent(Bool.self, forKey: .isPlaying) ?? false
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        self.currentTime = try container.decodeIfPresent(Double.self, forKey: .currentTime) ?? 0
        self.hasArtwork = try container.decodeIfPresent(Bool.self, forKey: .hasArtwork) ?? false
        self.volume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? 0.8
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
    }
}

public struct WidgetCommand: Sendable {
    public let action: String
    public let id: String
    public let timestamp: TimeInterval
}

public enum WidgetBridge {
    public static func realUserHome() -> URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir))
        }
        return URL(fileURLWithPath: NSHomeDirectory())
    }

    public static let standardDirectory: URL = {
        let home = realUserHome()
        let dir = home.appendingPathComponent("Library/Application Support/MusicWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    public static let containerDirectory: URL = {
        let home = realUserHome()
        let dir = home.appendingPathComponent("Library/Containers/com.music.app.widget/Data/Library/Application Support/MusicWidget", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    public static var candidateDirectories: [URL] {
        var dirs: [URL] = []
        dirs.append(standardDirectory)
        dirs.append(containerDirectory)
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let d = appSupport.appendingPathComponent("MusicWidget", isDirectory: true)
            if !dirs.contains(d) {
                dirs.append(d)
            }
        }
        return dirs
    }

    public static let toggleDarwinNotification = "com.music.app.widget.toggle"
    public static let nextDarwinNotification = "com.music.app.widget.next"
    public static let previousDarwinNotification = "com.music.app.widget.previous"

    public static let toggleNotification = NSNotification.Name("com.music.app.widget.toggle")
    public static let nextNotification = NSNotification.Name("com.music.app.widget.next")
    public static let previousNotification = NSNotification.Name("com.music.app.widget.previous")

    public static func postCommand(_ command: String) {
        // Write command.txt before posting notifications so observers can deduplicate it.
        let cmdId = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970
        let payload = "\(command):\(cmdId):\(timestamp)"
        for dir in candidateDirectories {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let cmdURL = dir.appendingPathComponent("command.txt")
            try? payload.write(to: cmdURL, atomically: true, encoding: .utf8)
        }

        let (darwinName, distName): (String, NSNotification.Name) = {
            switch command {
            case "next":
                return (nextDarwinNotification, nextNotification)
            case "previous":
                return (previousDarwinNotification, previousNotification)
            default:
                return (toggleDarwinNotification, toggleNotification)
            }
        }()

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinName as CFString),
            nil,
            nil,
            true
        )
        DistributedNotificationCenter.default().postNotificationName(
            distName,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public static func readLatestCommand() -> WidgetCommand? {
        var newest: WidgetCommand?
        for dir in candidateDirectories {
            let cmdURL = dir.appendingPathComponent("command.txt")
            guard let content = try? String(contentsOf: cmdURL, encoding: .utf8) else { continue }
            let parts = content.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
            if parts.count >= 3, let ts = Double(parts[2]) {
                let cmd = WidgetCommand(action: String(parts[0]), id: String(parts[1]), timestamp: ts)
                if newest == nil || cmd.timestamp > newest!.timestamp {
                    newest = cmd
                }
            }
        }
        return newest
    }

    public static func writeState(_ snapshot: WidgetPlaybackSnapshot, artworkData: Data? = nil) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        for dir in candidateDirectories {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let art = artworkData, !art.isEmpty {
                let artURL = dir.appendingPathComponent("artwork.jpg")
                try? art.write(to: artURL, options: .atomic)
            }
            let stateURL = dir.appendingPathComponent("playback_state.json")
            try? data.write(to: stateURL, options: .atomic)
        }
    }

    public static func readState() -> WidgetPlaybackSnapshot {
        var bestNonEmpty: WidgetPlaybackSnapshot?
        var bestAny: WidgetPlaybackSnapshot?
        for dir in candidateDirectories {
            let stateURL = dir.appendingPathComponent("playback_state.json")
            if let data = try? Data(contentsOf: stateURL),
               let snapshot = try? JSONDecoder().decode(WidgetPlaybackSnapshot.self, from: data) {
                if !snapshot.title.isEmpty {
                    if bestNonEmpty == nil || snapshot.timestamp > bestNonEmpty!.timestamp {
                        bestNonEmpty = snapshot
                    }
                }
                if bestAny == nil || snapshot.timestamp > bestAny!.timestamp {
                    bestAny = snapshot
                }
            }
        }
        return bestNonEmpty ?? bestAny ?? WidgetPlaybackSnapshot()
    }

    public static func readArtworkData() -> Data? {
        for dir in candidateDirectories {
            let artURL = dir.appendingPathComponent("artwork.jpg")
            if let data = try? Data(contentsOf: artURL), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    public static func readArtworkImage() -> NSImage? {
        guard let data = readArtworkData() else { return nil }
        return NSImage(data: data)
    }
}
