import Foundation
import AVFoundation
import MediaPlayer
import AppKit
import UserNotifications
import WidgetKit

public enum RepeatMode {
    case off
    case one
    case all
}

public struct ResolvedPlaybackStream: Sendable {
    public let url: URL
    public let duration: Double?
    public let qualityTitle: String
    public let isLossless: Bool
    public let artworkURL: String?
    public var historyURL: URL? = nil
    public var watchtimeURL: URL? = nil
    public var cpn: String? = nil
    public var loudnessDb: Double? = nil
    public var streamEnd: Double? = nil
    public var isEpisode: Bool = false
    public var source: String = "saavn" // "saavn", "youtube", "server", "local"
}

@MainActor
public final class PlaybackProgress: ObservableObject {
    public static let shared = PlaybackProgress()
    @Published public var currentTime: TimeInterval = 0
    @Published public var bufferedTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
}

@MainActor
public final class AudioPlayerService: ObservableObject {
    public static let shared = AudioPlayerService()

    @Published public var currentSong: Song?
    @Published public var isPlaying: Bool = false
    @Published public var isLoading: Bool = false

    public var currentTime: TimeInterval {
        get { PlaybackProgress.shared.currentTime }
        set { PlaybackProgress.shared.currentTime = newValue }
    }
    public var bufferedTime: TimeInterval {
        get { PlaybackProgress.shared.bufferedTime }
        set { PlaybackProgress.shared.bufferedTime = newValue }
    }
    public var duration: TimeInterval {
        get { PlaybackProgress.shared.duration }
        set {
            if PlaybackProgress.shared.duration != newValue {
                PlaybackProgress.shared.duration = newValue
                objectWillChange.send()
            }
        }
    }
    @Published public var volume: Float = 0.8 {
        didSet {
            audioPlayer.volume = Double(volume)
        }
    }
    @Published public var isShuffle: Bool = false
    @Published public var repeatMode: RepeatMode = .off
    @Published public var queue: [Song] = []
    @Published public var history: [Song] = []
    @Published public var autoplayRadio: Bool = true
    @Published public var lastPlayedPlaylist: Playlist? {
        didSet {
            if let p = lastPlayedPlaylist, let data = try? JSONEncoder().encode(p) {
                UserDefaults.standard.set(data, forKey: "lastPlayedPlaylist")
            }
        }
    }

    @Published public var currentLyrics: [LyricLine] = []
    @Published public var currentLyricIndex: Int = 0

    @Published public var isLossless: Bool = false
    @Published public var audioQualityTitle: String = "AAC 256kbps"

    private let audioPlayer = AudioPlayer()
    private var activeStreamTask: Task<Void, Never>? = nil
    private var preloadTask: Task<Void, Never>? = nil
    private var preloadedSongId: String? = nil
    private var preloadedStream: ResolvedStream? = nil
    private var preloadedPlaybackStream: ResolvedPlaybackStream? = nil
    private var lastResolvedStream: ResolvedStream? = nil
    private var lastAdvancedSongId: String? = nil
    private var lastWatchtimePing: TimeInterval = 0

    private init() {
        if let data = UserDefaults.standard.data(forKey: "lastPlayedPlaylist"),
           let p = try? JSONDecoder().decode(Playlist.self, from: data) {
            self.lastPlayedPlaylist = p
        }

        setupNativeAudioEngine()
        setupRemoteCommands()
    }

    private func setupNativeAudioEngine() {
        audioPlayer.volume = Double(volume)
        audioPlayer.normalizesVolume = AppSettings.shared.volumeNormalization
        AppSettings.shared.onVolumeNormalizationChange = { [weak self] enabled in
            self?.audioPlayer.normalizesVolume = enabled
        }

        audioPlayer.onPlaybackStart = { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.isPlaying = true
            self.updateNowPlayingInfo()
            if let song = self.currentSong {
                self.postTrackNotification(song: song)
            }
        }

        audioPlayer.onProgress = { [weak self] cur, dur in
            guard let self = self else { return }
            self.currentTime = cur
            if dur > 0 && !dur.isNaN && (self.duration == 0 || abs(self.duration - dur) > 1) {
                self.duration = dur
            }

            if let song = self.currentSong {
                ListenBrainzService.shared.onTrackProgress(song: song, currentTime: cur, duration: self.duration)
                LastfmService.shared.onTrackProgress(song: song, currentTime: cur, duration: self.duration)
            }
            self.updateCurrentLyric(for: cur)

            // Periodic watchtime ping (every 10s or near end) for YouTube History syncing
            if cur - self.lastWatchtimePing >= 10.0 {
                self.lastWatchtimePing = cur
                if let stream = self.lastResolvedStream,
                   let watchtimeURL = stream.watchtimeURL,
                   let cpn = stream.cpn {
                    Task {
                        await InnerTubeClient.shared.reportWatchtime(
                            watchtimeURL: watchtimeURL,
                            cpn: cpn,
                            position: cur,
                            length: self.duration
                        )
                    }
                }
            }
        }

        audioPlayer.onTrackFinished = { [weak self] in
            guard let self = self else { return }
            self.advanceTrackIfAppropriate()
        }

        audioPlayer.onTogglePlayPause = { [weak self] in
            self?.togglePlayPause()
        }

        audioPlayer.onNext = { [weak self] in
            self?.next()
        }

        audioPlayer.onPrevious = { [weak self] in
            self?.previous()
        }
    }

    private func advanceTrackIfAppropriate() {
        guard let currentId = currentSong?.id else { return }
        guard lastAdvancedSongId != currentId else { return }
        lastAdvancedSongId = currentId

        if repeatMode == .one {
            seek(to: 0)
            audioPlayer.resume()
            isPlaying = true
        } else {
            next()
        }
    }

    public func play(song: Song, newQueue: [Song]? = nil) {
        lastAdvancedSongId = nil
        lastWatchtimePing = 0
        activeStreamTask?.cancel()

        var resolvedSong = song
        if resolvedSong.thumbnailUrl.isEmpty {
            resolvedSong.thumbnailUrl = "https://i.ytimg.com/vi/\(resolvedSong.id)/hqdefault.jpg"
        }

        if let newQueue = newQueue {
            if let idx = newQueue.firstIndex(where: { $0.id == resolvedSong.id }) {
                self.queue = Array(newQueue.suffix(from: idx + 1))
                self.history = Array(newQueue.prefix(upTo: idx))
            } else {
                self.queue = newQueue.filter { $0.id != resolvedSong.id }
            }
        } else {
            self.queue = []
            Task {
                let radioTracks = await InnerTubeService.shared.fetchRadioQueue(videoId: resolvedSong.id)
                if self.queue.isEmpty && self.currentSong?.id == resolvedSong.id {
                    self.queue = radioTracks.filter { $0.id != resolvedSong.id }
                    self.preloadNextTrack()
                }
            }
        }

        if let current = currentSong {
            history.append(current)
            if history.count > 50 {
                history.removeFirst(history.count - 50)
            }
        }

        self.currentSong = resolvedSong
        self.currentTime = 0
        self.duration = resolvedSong.duration
        self.isLoading = true
        self.isPlaying = false
        self.currentLyrics = []
        self.currentLyricIndex = 0

        // Determine Lossless Audio Status
        if resolvedSong.id.starts(with: "eclipse:") {
            self.isLossless = true
            self.audioQualityTitle = "Lossless 24-bit/48kHz FLAC"
        } else {
            self.isLossless = false
            self.audioQualityTitle = "Native AAC 256kbps"
        }

        // Prefill radio if queue is empty
        if self.queue.isEmpty {
            Task {
                let radioTracks = await InnerTubeService.shared.fetchRadioQueue(videoId: resolvedSong.id)
                if self.queue.isEmpty && self.currentSong?.id == resolvedSong.id {
                    self.queue = radioTracks.filter { $0.id != resolvedSong.id }
                    self.preloadNextTrack()
                }
            }
        }

        Task {
            let lyrics = await LyricsService.shared.fetchLyrics(song: resolvedSong)
            self.currentLyrics = lyrics
        }

        // Notify ListenBrainz and Last.fm
        ListenBrainzService.shared.onTrackStart(song: resolvedSong)
        LastfmService.shared.onTrackStart(song: resolvedSong)

        // Check offline local playback
        let localPath: String? = {
            if let path = resolvedSong.localFilePath, FileManager.default.fileExists(atPath: path) { return path }
            if DownloadManager.shared.isDownloaded(songId: resolvedSong.id),
               let downloaded = DownloadManager.shared.downloadedSongs.first(where: { $0.id == resolvedSong.id }),
               let path = downloaded.localFilePath,
               FileManager.default.fileExists(atPath: path) { return path }
            return nil
        }()

        if let localPath = localPath {
            let fileURL = URL(fileURLWithPath: localPath)
            let metadata = NowPlayingMetadata(
                title: resolvedSong.title,
                artist: resolvedSong.artist,
                album: resolvedSong.album,
                artworkURL: URL(string: resolvedSong.thumbnailUrl),
                knownDuration: resolvedSong.duration
            )
            audioPlayer.load(url: fileURL, metadata: metadata)
            preloadNextTrack()
            return
        }

        if AppSettings.shared.enableAppleMusicMetadata {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let appleArt = await AppleMusicMetadataService.shared.getAlbumArt(
                    title: resolvedSong.title,
                    artist: resolvedSong.artist,
                    album: resolvedSong.album
                ) {
                    if self.currentSong?.id == resolvedSong.id {
                        self.currentSong?.thumbnailUrl = appleArt
                        self.audioPlayer.updateArtworkURL(URL(string: appleArt))
                    }
                }
            }
        }

        // Check if track was preloaded
        if preloadedSongId == resolvedSong.id, let stream = preloadedPlaybackStream {
            preloadedSongId = nil
            preloadedPlaybackStream = nil
            applyPlaybackStream(stream, for: resolvedSong, isPreloaded: true)
            return
        }

        activeStreamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard let playback = await self.resolvePlaybackStream(for: resolvedSong) else {
                guard !Task.isCancelled else { return }
                self.isLoading = false
                return
            }
            guard !Task.isCancelled else { return }
            self.applyPlaybackStream(playback, for: resolvedSong)
        }
    }

    private func applyPlaybackStream(_ playback: ResolvedPlaybackStream, for song: Song, isPreloaded: Bool = false) {
        self.audioQualityTitle = playback.qualityTitle
        self.isLossless = playback.isLossless
        self.lastResolvedStream = playback.source == "youtube" ? ResolvedStream(
            url: playback.url,
            duration: playback.duration,
            historyURL: playback.historyURL,
            watchtimeURL: playback.watchtimeURL,
            cpn: playback.cpn,
            loudnessDb: playback.loudnessDb,
            streamEnd: playback.streamEnd,
            isEpisode: playback.isEpisode
        ) : nil

        if let d = playback.duration, d > 0 {
            self.duration = d
        }

        let metadata = NowPlayingMetadata(
            title: song.title,
            artist: song.artist,
            album: song.album,
            artworkURL: URL(string: song.thumbnailUrl),
            knownDuration: playback.duration ?? song.duration,
            loudnessDb: playback.loudnessDb,
            streamEnd: playback.streamEnd,
            isEpisode: playback.isEpisode
        )

        if isPreloaded {
            audioPlayer.loadPreloaded(url: playback.url, metadata: metadata)
        } else {
            audioPlayer.load(url: playback.url, metadata: metadata)
        }

        if let historyURL = playback.historyURL, let cpn = playback.cpn {
            Task {
                await InnerTubeClient.shared.reportPlaybackStart(
                    playbackURL: historyURL,
                    cpn: cpn,
                    position: 0,
                    length: self.duration
                )
            }
        }

        preloadNextTrack()
    }

    private func preloadNextTrack() {
        preloadTask?.cancel()
        guard let nextSong = queue.first else { return }

        preloadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            guard let playback = await self.resolvePlaybackStream(for: nextSong) else { return }
            guard !Task.isCancelled else { return }

            let metadata = NowPlayingMetadata(
                title: nextSong.title,
                artist: nextSong.artist,
                album: nextSong.album,
                artworkURL: URL(string: nextSong.thumbnailUrl),
                knownDuration: playback.duration ?? nextSong.duration,
                loudnessDb: playback.loudnessDb,
                streamEnd: playback.streamEnd,
                isEpisode: playback.isEpisode
            )

            self.audioPlayer.preload(url: playback.url, metadata: metadata)
            self.preloadedSongId = nextSong.id
            self.preloadedPlaybackStream = playback
        }
    }

    /// Resolves audio stream following the priority chain:
    /// 1. JioSaavn (320kbps AAC High Quality)
    /// 2. YouTube Music (Native StreamResolver)
    /// 3. User-provided self-hosted server (Eclipse Addons)
    public func resolvePlaybackStream(for song: Song) async -> ResolvedPlaybackStream? {
        // Priority 1: Saavn (JioSaavn) audio streaming (if enabled in settings)
        if AppSettings.shared.enableSaavnStreaming, !song.id.starts(with: "eclipse:") {
            if let saavn = await SaavnStreamingService.shared.resolveStream(
                title: song.title,
                artist: song.artist,
                duration: song.duration
            ) {
                return ResolvedPlaybackStream(
                    url: saavn.url,
                    duration: saavn.duration ?? song.duration,
                    qualityTitle: saavn.qualityTitle,
                    isLossless: true,
                    artworkURL: saavn.artworkURL,
                    source: "saavn"
                )
            }
        }

        // Priority 2: YouTube Music
        if !song.id.starts(with: "eclipse:") {
            do {
                let stream = try await StreamResolver.shared.audioStream(videoId: song.id)
                let quality = stream.details?.audioQuality ?? "256k"
                return ResolvedPlaybackStream(
                    url: stream.url,
                    duration: stream.duration ?? song.duration,
                    qualityTitle: "Native AAC (\(quality))",
                    isLossless: false,
                    artworkURL: nil,
                    historyURL: stream.historyURL,
                    watchtimeURL: stream.watchtimeURL,
                    cpn: stream.cpn,
                    loudnessDb: stream.loudnessDb,
                    streamEnd: stream.streamEnd,
                    isEpisode: stream.isEpisode,
                    source: "youtube"
                )
            } catch {
                print("⚠️ YouTube Music resolution failed for \(song.id): \(error.localizedDescription)")
            }
        }

        // Priority 3: User-provided self-hosted server
        if let serverStream = await resolveUserServerStream(for: song) {
            return ResolvedPlaybackStream(
                url: serverStream.url,
                duration: song.duration,
                qualityTitle: "Self-Hosted (\(serverStream.addonName))",
                isLossless: true,
                artworkURL: nil,
                source: "server"
            )
        }

        return nil
    }

    /// Resolves stream from user-provided self-hosted Eclipse addons
    private func resolveUserServerStream(for song: Song) async -> (url: URL, addonName: String)? {
        let enabled = EclipseAddonService.shared.addons.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return nil }

        // If track is explicitly from an eclipse addon
        if song.id.starts(with: "eclipse:") {
            if let streamUrl = await EclipseAddonService.shared.resolveStreamUrl(songId: song.id),
               let url = URL(string: streamUrl) {
                let comps = song.id.components(separatedBy: ":")
                let addonId = comps.count > 1 ? comps[1] : ""
                let name = enabled.first(where: { $0.id == addonId })?.name ?? "Custom Server"
                return (url, name)
            }
        }

        // Search enabled user addons for song title
        let results = await EclipseAddonService.shared.search(query: song.title)
        if let match = results.first(where: {
            $0.title.localizedCaseInsensitiveContains(song.title) ||
            song.title.localizedCaseInsensitiveContains($0.title)
        }) {
            if let streamUrl = await EclipseAddonService.shared.resolveStreamUrl(songId: match.id),
               let url = URL(string: streamUrl) {
                let comps = match.id.components(separatedBy: ":")
                let addonId = comps.count > 1 ? comps[1] : ""
                let name = enabled.first(where: { $0.id == addonId })?.name ?? "Custom Server"
                return (url, name)
            }
        }

        return nil
    }

    public func recordPlaylistPlayed(playlist: Playlist) {
        self.lastPlayedPlaylist = playlist
    }

    public func recordPlaylistPlayed(id: String, title: String, author: String? = nil, thumbnailUrl: String = "") {
        self.lastPlayedPlaylist = Playlist(
            id: id,
            title: title,
            description: nil,
            author: author ?? "YouTube Music",
            thumbnailUrl: thumbnailUrl,
            songCount: 0,
            songs: []
        )
    }

    private var lastToggleTime: TimeInterval = 0
    private var lastSkipTime: TimeInterval = 0

    public func togglePlayPause() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastToggleTime > 0.35 else { return }
        lastToggleTime = now

        audioPlayer.togglePlayPause()
        isPlaying = audioPlayer.isPlaying
        updateNowPlayingInfo()
    }

    public func pause() {
        guard isPlaying else { return }
        lastToggleTime = ProcessInfo.processInfo.systemUptime
        audioPlayer.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    public func resume() {
        guard !isPlaying else { return }
        lastToggleTime = ProcessInfo.processInfo.systemUptime
        audioPlayer.resume()
        isPlaying = true
        updateNowPlayingInfo()
    }

    public func next() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSkipTime > 0.35 else { return }
        lastSkipTime = now

        if !queue.isEmpty {
            let nextSong = queue.removeFirst()
            play(song: nextSong)

            if queue.count < 5, let current = currentSong {
                Task {
                    let more = await InnerTubeService.shared.fetchRadioQueue(videoId: current.id)
                    let existingIds = Set(self.queue.map(\.id) + [current.id])
                    let filtered = more.filter { !existingIds.contains($0.id) }
                    self.queue.append(contentsOf: filtered)
                    self.preloadNextTrack()
                }
            }
        } else if autoplayRadio, let current = currentSong {
            Task {
                let radioSongs = await InnerTubeService.shared.fetchRadioQueue(videoId: current.id)
                let filtered = radioSongs.filter { $0.id != current.id }
                if let first = filtered.first {
                    self.queue = Array(filtered.dropFirst())
                    self.play(song: first)
                }
            }
        } else if repeatMode == .all, !history.isEmpty {
            let all = history + (currentSong.map { [$0] } ?? [])
            history.removeAll()
            if let first = all.first {
                play(song: first, newQueue: Array(all.dropFirst()))
            }
        } else {
            audioPlayer.pause()
            isPlaying = false
        }
    }

    public func previous() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSkipTime > 0.35 else { return }
        lastSkipTime = now

        if currentTime > 3.0 {
            seek(to: 0)
        } else if let previousSong = history.popLast() {
            if let current = currentSong {
                queue.insert(current, at: 0)
            }
            play(song: previousSong)
        } else {
            seek(to: 0)
        }
    }

    public func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
        self.currentTime = time
        updateCurrentLyric(for: time)
    }

    public func addToQueue(song: Song) {
        queue.append(song)
        if queue.count == 1 {
            preloadNextTrack()
        }
    }

    public func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        queue.remove(at: index)
        if index == 0 {
            preloadNextTrack()
        }
    }

    private func updateCurrentLyric(for time: TimeInterval) {
        guard !currentLyrics.isEmpty else { return }
        let idx = currentLyricIndex
        if idx >= 0 && idx < currentLyrics.count {
            let start = currentLyrics[idx].startTimeSeconds
            let nextStart = idx + 1 < currentLyrics.count ? currentLyrics[idx + 1].startTimeSeconds : Double.greatestFiniteMagnitude
            if time >= start && time < nextStart { return }
        }
        if idx + 1 < currentLyrics.count && time >= currentLyrics[idx + 1].startTimeSeconds {
            let nextNextStart = idx + 2 < currentLyrics.count ? currentLyrics[idx + 2].startTimeSeconds : Double.greatestFiniteMagnitude
            if time < nextNextStart {
                currentLyricIndex = idx + 1
                return
            }
        }
        for (i, line) in currentLyrics.enumerated() {
            if line.startTimeSeconds <= time {
                if i == currentLyrics.count - 1 || currentLyrics[i + 1].startTimeSeconds > time {
                    if self.currentLyricIndex != i {
                        self.currentLyricIndex = i
                    }
                    break
                }
            }
        }
    }

    private func postTrackNotification(song: Song) {
        guard AppSettings.shared.enableTrackNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = song.title
        content.subtitle = song.artist
        content.body = song.album
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.next()
            }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previous()
            }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                Task { @MainActor in
                    self?.seek(to: posEvent.positionTime)
                }
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = currentSong else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            WidgetBridge.writeState(WidgetPlaybackSnapshot())
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album.isEmpty ? song.title : song.album,
            MPMediaItemPropertyPlaybackDuration: max(duration, 0.0),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(currentTime, 0.0),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        var artworkData: Data? = nil
        if let existingArtwork = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            info[MPMediaItemPropertyArtwork] = existingArtwork
            if let image = existingArtwork.image(at: CGSize(width: 300, height: 300)) {
                artworkData = image.tiffRepresentation
            }
        }

        let nsDict = NSDictionary(dictionary: info)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nsDict as? [String: Any]
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused

        let snapshot = WidgetPlaybackSnapshot(
            title: song.title,
            artist: song.artist,
            album: song.album,
            isPlaying: isPlaying,
            duration: max(duration, 0.0),
            currentTime: max(currentTime, 0.0),
            hasArtwork: artworkData != nil
        )
        WidgetBridge.writeState(snapshot, artworkData: artworkData)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
