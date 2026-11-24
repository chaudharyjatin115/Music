//
//  Downloader.swift
//  YT Music
//
//

import Foundation

@MainActor
@Observable
final class Downloader {
    struct Progress: Equatable {
        var collection: String?     // album/playlist name; nil for a single track
        var currentTitle: String
        var index: Int              // 1-based position in the batch
        var total: Int
        var fraction: Double?       // current file's download fraction, if known
    }

    enum Status: Equatable {
        case idle
        case running(Progress)
        case finished(summary: String, folder: URL?)
        case failed(String)
    }

    private struct Job {
        let videoId: String
        let title: String
        let artist: String
    }

    private(set) var status: Status = .idle
    private(set) var completed: [URL] = []
    var isEnabled = false

    private let resolver: StreamResolving
    private var task: Task<Void, Never>?

    init(resolver: StreamResolving? = nil) {
        self.resolver = resolver ?? StreamResolver.shared
    }

    var isBusy: Bool {
        if case .running = status { return true }
        return false
    }

    // MARK: - Entry points

    func download(_ snapshot: PlaybackSnapshot, to directory: URL, preferences: StreamPreferences) {
        start([Job(videoId: snapshot.videoId, title: snapshot.title, artist: snapshot.artist)],
              collection: nil, directory: directory, preferences: preferences)
    }

    func download(_ tracks: [Track], collection: String, to directory: URL, preferences: StreamPreferences) {
        let jobs = tracks.compactMap { track -> Job? in
            guard let videoId = track.videoId else { return nil }
            return Job(videoId: videoId, title: track.title, artist: track.subtitle)
        }
        start(jobs, collection: collection, directory: directory, preferences: preferences)
    }

    func cancel() {
        task?.cancel()
        status = .idle
    }

    // MARK: - Batch run

    private func start(_ jobs: [Job], collection: String?, directory: URL, preferences: StreamPreferences) {
        guard !jobs.isEmpty else { return }
        task?.cancel()
        task = Task { await run(jobs, collection: collection, directory: directory, preferences: preferences) }
    }

    private func run(_ jobs: [Job], collection: String?, directory: URL, preferences: StreamPreferences) async {
        let targetDir = collection.map { directory.appendingPathComponent(Self.sanitize($0), isDirectory: true) } ?? directory
        if collection != nil {
            try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        }

        var downloaded = 0
        var failed = 0
        for (offset, job) in jobs.enumerated() {
            if Task.isCancelled { status = .idle; return }
            func report(_ fraction: Double?) {
                status = .running(Progress(
                    collection: collection, currentTitle: job.title,
                    index: offset + 1, total: jobs.count, fraction: fraction
                ))
            }
            report(nil)
            do {
                let url = try await downloadOne(job, to: targetDir, preferences: preferences, progress: report)
                completed.insert(url, at: 0)
                downloaded += 1
            } catch {
                if Task.isCancelled { status = .idle; return }
                failed += 1   // skip the failed track and keep going
            }
        }

        if Task.isCancelled { status = .idle; return }
        let savedFormat = downloaded == 1
            ? String(localized: "plugins.downloader.saved.one")
            : String(localized: "plugins.downloader.saved.other")
        var summary = String(format: savedFormat, downloaded)
        if failed > 0 {
            let failedFormat = failed == 1
                ? String(localized: "plugins.downloader.failed.one")
                : String(localized: "plugins.downloader.failed.other")
            summary += String(format: failedFormat, failed)
        }
        if let collection { summary = String(format: String(localized: "plugins.downloader.collection_summary"), collection, summary) }
        status = .finished(summary: summary, folder: collection != nil ? targetDir : nil)
    }

    private func downloadOne(_ job: Job, to directory: URL, preferences: StreamPreferences,
                             progress: (Double?) -> Void) async throws -> URL {
        let resolved = try await resolver.audioStream(videoId: job.videoId, preferences: preferences)
        try Task.checkCancellation()

        let destination = directory.appendingPathComponent(Self.fileName(for: job)).standardizedFileURL
        guard destination.path.hasPrefix(directory.standardizedFileURL.path) else {
            throw URLError(.badURL)
        }

        let (bytes, response) = try await NetworkSession.shared.bytes(from: resolved.url)
        let total = response.expectedContentLength

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: tempURL)
        }

        var received: Int64 = 0
        var chunk = Data()
        chunk.reserveCapacity(1 << 16)
        for try await byte in bytes {
            try Task.checkCancellation()
            chunk.append(byte)
            received += 1
            if chunk.count >= (1 << 16) {
                try handle.write(contentsOf: chunk)
                chunk.removeAll(keepingCapacity: true)
                progress(total > 0 ? Double(received) / Double(total) : nil)
            }
        }
        if !chunk.isEmpty {
            try handle.write(contentsOf: chunk)
        }
        try handle.close()
        try Task.checkCancellation()

        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    // MARK: - Naming

    /// "<artist> - <title>.m4a", with filesystem-illegal characters stripped.
    private static func fileName(for job: Job) -> String {
        let base = job.artist.isEmpty ? job.title : "\(job.artist) - \(job.title)"
        let cleaned = sanitize(base)
        return "\(cleaned.isEmpty ? job.videoId : cleaned).m4a"
    }

    private static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.controlCharacters)
            .union(.newlines)
        return name.components(separatedBy: invalid)
            .joined(separator: "_")
            .replacingOccurrences(of: "..", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
