import Foundation

@MainActor
public final class DownloadManager: ObservableObject {
    public static let shared = DownloadManager()

    @Published public var downloadedSongs: [Song] = []
    @Published public var activeDownloads: Set<String> = [] // set of videoIds currently downloading

    private let downloadsDirectory: URL
    private let indexFileUrl: URL
    private let session = URLSession(configuration: .default)

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

                let safeTitle = song.title.replacingOccurrences(of: "/", with: "-")
                let safeArtist = song.artist.replacingOccurrences(of: "/", with: "-")
                let destFileName = "\(safeArtist) - \(safeTitle).m4a"
                let destUrl = downloadsDirectory.appendingPathComponent(destFileName)

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
}
