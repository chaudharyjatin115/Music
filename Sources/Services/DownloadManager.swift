import Foundation
import AppKit

@MainActor
public final class DownloadManager: ObservableObject {
    public static let shared = DownloadManager()

    @Published public var downloadedSongs: [Song] = []
    @Published public var activeDownloads: Set<String> = [] // set of videoIds currently downloading

    private let downloadsDirectory: URL
    private let indexFileUrl: URL
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    private init() {
        let fileManager = FileManager.default
        let musicDir = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first ??
                       fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Music")
        self.downloadsDirectory = musicDir.appendingPathComponent("Downloaded")
        self.indexFileUrl = downloadsDirectory.appendingPathComponent("index.json")

        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        loadIndex()
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexFileUrl),
              let list = try? JSONDecoder().decode([Song].self, from: data) else {
            return
        }
        self.downloadedSongs = list
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(downloadedSongs) else { return }
        try? data.write(to: indexFileUrl)
    }

    public func isDownloaded(songId: String) -> Bool {
        downloadedSongs.contains { $0.id == songId }
    }

    public func isDownloading(songId: String) -> Bool {
        activeDownloads.contains(songId)
    }

    private static func sanitizeFilenameComponent(_ string: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\":<>")
            .union(.controlCharacters)
            .union(.newlines)
        var sanitized = string.components(separatedBy: invalidCharacters).joined(separator: "_")
        sanitized = sanitized.replacingOccurrences(of: "..", with: "_")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "Unknown" : sanitized
    }

    public func downloadSong(_ song: Song) {
        guard !isDownloaded(songId: song.id), !isDownloading(songId: song.id) else { return }
        activeDownloads.insert(song.id)

        Task {
            do {
                let streamUrlString = try await InnerTubeService.shared.resolveAudioStreamUrl(videoId: song.id, song: song)
                guard let streamUrl = URL(string: streamUrlString) else {
                    self.activeDownloads.remove(song.id)
                    return
                }

                let (tempUrl, _) = try await session.download(from: streamUrl)

                let safeTitle = Self.sanitizeFilenameComponent(song.title)
                let safeArtist = Self.sanitizeFilenameComponent(song.artist)
                let destFileName = "\(safeArtist) - \(safeTitle).m4a"
                let destUrl = downloadsDirectory.appendingPathComponent(destFileName).standardizedFileURL

                guard destUrl.path.hasPrefix(downloadsDirectory.standardizedFileURL.path) else {
                    try? FileManager.default.removeItem(at: tempUrl)
                    self.activeDownloads.remove(song.id)
                    return
                }

                try? FileManager.default.removeItem(at: destUrl)
                try FileManager.default.moveItem(at: tempUrl, to: destUrl)

                var updatedSong = song
                updatedSong.isDownloaded = true
                updatedSong.localFilePath = destUrl.path

                self.downloadedSongs.append(updatedSong)
                self.saveIndex()
                self.activeDownloads.remove(song.id)
            } catch {
                print("Failed to download song: \(error)")
                self.activeDownloads.remove(song.id)
            }
        }
    }

    public func deleteDownload(songId: String) {
        guard let index = downloadedSongs.firstIndex(where: { $0.id == songId }) else { return }
        let song = downloadedSongs[index]
        if let path = song.localFilePath {
            try? FileManager.default.removeItem(atPath: path)
        }
        downloadedSongs.remove(at: index)
        saveIndex()
    }

    public var totalDownloadedSizeFormatted: String {
        var totalBytes: Int64 = 0
        let fm = FileManager.default
        for song in downloadedSongs {
            if let path = song.localFilePath, let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? Int64 {
                totalBytes += size
            }
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }

    public func deleteAllDownloads() {
        for song in downloadedSongs {
            if let path = song.localFilePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
        downloadedSongs.removeAll()
        saveIndex()
    }

    public func openDownloadsFolder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadsDirectory.path)
    }
}
