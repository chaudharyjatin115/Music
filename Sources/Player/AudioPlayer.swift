//
//  AudioPlayer.swift
//  YT Music
//
//  AVPlayer wrapper that publishes to Now Playing; two players enable crossfade.
//

@preconcurrency import AVFoundation
import MediaPlayer
import AppKit
import Observation
import ImageIO

@MainActor
@Observable
final class AudioPlayer: AudioOutput {
    private let playerA = AVPlayer()
    private let playerB = AVPlayer()
    /// Drives the now-playing track; crossfade swaps it.
    @ObservationIgnored private var active: AVPlayer
    @ObservationIgnored private var timeObservers: [(AVPlayer, Any)] = []
    @ObservationIgnored private var timeControlObservers: [NSKeyValueObservation] = []
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    /// How far past the known length the playhead may run before the track counts as finished.
    private static let pastKnownEndTolerance: Double = 1.0
    @ObservationIgnored private var fadeTask: Task<Void, Never>?
    /// Bumped per crossfade so a superseded fade's cleanup can't clear the newer `fadeTask`.
    @ObservationIgnored private var fadeGeneration = 0
    /// Fires once per item when playback completes.
    @ObservationIgnored private var hasSignalledEnd = false
    @ObservationIgnored private var preloadedURL: URL?
    @ObservationIgnored private let proxiedLoader = ProxiedStreamLoader()
    /// Loudness of the item loaded on each player, keyed by player identity.
    @ObservationIgnored private var loudness: [ObjectIdentifier: Double] = [:]

    /// Shared with every item's tap; changes apply on the next audio block.
    @ObservationIgnored private let equalizerBox = EqualizerSettingsBox()

    @ObservationIgnored let spectrum: SpectrumAnalyzer? = nil

    private(set) var isPlaying = false
    private(set) var isBuffering = false
    /// True only once AVPlayer really advances; `load()` marks playing before the stream flows.
    var isActuallyPlaying: Bool { isPlaying && active.timeControlStatus == .playing }
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var bufferedTime: Double = 0

    /// Master gain (0...1); crossfade ramps are scaled by it.
    var volume: Double = 1 {
        didSet {
            // During a crossfade the fade loop picks up the new gain.
            if fadeTask == nil { active.volume = level(for: active) }
        }
    }

    var normalizesVolume = false {
        didSet {
            if fadeTask == nil { active.volume = level(for: active) }
        }
    }

    var playbackRate: Double = 1 {
        didSet {
            playerA.defaultRate = Float(playbackRate)
            playerB.defaultRate = Float(playbackRate)
            if isPlaying, active.timeControlStatus != .paused { active.rate = Float(playbackRate) }
            updateNowPlayingInfo()
        }
    }

    private static let skipBackSeconds: Double = 15
    private static let skipForwardSeconds: Double = 30

    private var clampedVolume: Float { Float(min(max(volume, 0), 1)) }

    private func level(for player: AVPlayer) -> Float {
        guard normalizesVolume else { return clampedVolume }
        let gain = VolumeNormalization.gain(loudnessDb: loudness[ObjectIdentifier(player)])
        return clampedVolume * Float(gain)
    }

    @ObservationIgnored var onTrackFinished: (() -> Void)?
    @ObservationIgnored var onNext: (() -> Void)?
    @ObservationIgnored var onPrevious: (() -> Void)?
    @ObservationIgnored var onTogglePlayPause: (() -> Void)?
    @ObservationIgnored var onProgress: ((Double, Double) -> Void)?
    @ObservationIgnored var onPlaybackStart: (() -> Void)?

    @ObservationIgnored private let infoCenter = MPNowPlayingInfoCenter.default()
    @ObservationIgnored private let commandCenter = MPRemoteCommandCenter.shared()
    @ObservationIgnored private var metadata = NowPlayingMetadata(title: "", artist: "", album: "", artworkURL: nil)
    @ObservationIgnored private var artwork: MPMediaItemArtwork?
    @ObservationIgnored private var loadedArtworkURL: URL?

    init() {
        active = playerA
        for player in [playerA, playerB] {
            // Start on first available data to cut time-to-first-audio; may stall more on poor networks.
            player.automaticallyWaitsToMinimizeStalling = false
            addPeriodicObserver(to: player)
            observeTimeControl(of: player)
        }
    }

    // No deinit: the single AudioPlayer lives for the app's lifetime.

    private var idle: AVPlayer { active === playerA ? playerB : playerA }

    /// Skips precise duration scanning; `knownDuration` is authoritative and the scan stalls the start.
    private func makeItem(url: URL) -> AVPlayerItem {
        let asset = AVURLAsset(url: proxiedLoader == nil ? url : ProxiedStreamLoader.loaderURL(for: url), options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: false
        ])
        if let proxiedLoader {
            asset.resourceLoader.setDelegate(proxiedLoader, queue: proxiedLoader.queue)
        }
        let item = AVPlayerItem(asset: asset)
        // 12s forward buffer
        item.preferredForwardBufferDuration = 12.0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        installEqualizer(on: item, asset: asset)
        return item
    }

    /// The audio track loads asynchronously, so the mix is set once it's available.
    private func installEqualizer(on item: AVPlayerItem, asset: AVURLAsset) {
        let box = equalizerBox
        let meter = spectrum
        Task { @MainActor [weak item] in
            guard let track = try? await asset.loadTracks(withMediaType: .audio).first
            else { return }
            let processor = EqualizerProcessor(box: box, spectrum: meter)
            if let mix = makeEqualizerAudioMix(for: track, processor: processor) {
                item?.audioMix = mix
            }
        }
    }

    // MARK: - Transport

    func load(url: URL, metadata: NowPlayingMetadata) {
        cancelFade()
        clearIdlePlayer()
        preloadedURL = nil

        let item = makeItem(url: url)
        active.replaceCurrentItem(with: item)
        loudness[ObjectIdentifier(active)] = metadata.loudnessDb
        activate(item: item, metadata: metadata)
    }

    func preload(url: URL, metadata: NowPlayingMetadata) {
        guard url != preloadedURL else { return }
        let item = makeItem(url: url)
        // Preloaded standby item buffers only 4s for instant start without duplicating RAM
        item.preferredForwardBufferDuration = 4.0
        idle.pause()
        idle.replaceCurrentItem(with: item)
        idle.volume = 0
        loudness[ObjectIdentifier(idle)] = metadata.loudnessDb
        preloadedURL = url
    }

    func loadPreloaded(url: URL, metadata: NowPlayingMetadata) {
        guard url == preloadedURL, idle.currentItem != nil else {
            load(url: url, metadata: metadata)
            return
        }
        cancelFade()
        active.pause()
        active.replaceCurrentItem(with: nil)
        active = idle
        active.currentItem?.preferredForwardBufferDuration = 12.0
        preloadedURL = nil
        activate(item: active.currentItem!, metadata: metadata)
    }

    func updateArtworkURL(_ url: URL?) {
        guard let url else { return }
        self.metadata = NowPlayingMetadata(
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            artworkURL: url,
            knownDuration: metadata.knownDuration,
            loudnessDb: metadata.loudnessDb,
            streamEnd: metadata.streamEnd,
            isEpisode: metadata.isEpisode
        )
        self.loadedArtworkURL = nil
        loadArtwork(url)
    }

    func crossfade(to url: URL, metadata: NowPlayingMetadata, duration: Double) {
        guard duration > 0 else {
            load(url: url, metadata: metadata)
            return
        }
        cancelFade()
        fadeGeneration += 1
        let generation = fadeGeneration

        let outgoing = active
        let incoming = idle
        let item = makeItem(url: url)
        preloadedURL = nil
        incoming.volume = 0
        incoming.replaceCurrentItem(with: item)
        loudness[ObjectIdentifier(incoming)] = metadata.loudnessDb

        // Swap before observing so end-of-track routes from the incoming track.
        active = incoming
        activate(item: item, metadata: metadata, volume: 0)
        startFade(outgoing: outgoing, incoming: incoming, seconds: duration, generation: generation)
    }

    func crossfadePreloaded(url: URL, metadata: NowPlayingMetadata, duration: Double) {
        guard url == preloadedURL, idle.currentItem != nil else {
            crossfade(to: url, metadata: metadata, duration: duration)
            return
        }
        preloadedURL = nil
        cancelFade()
        fadeGeneration += 1
        let generation = fadeGeneration
        let outgoing = active
        let incoming = idle
        incoming.volume = 0
        active = incoming
        active.currentItem?.preferredForwardBufferDuration = 12.0
        activate(item: incoming.currentItem!, metadata: metadata, volume: 0)
        startFade(outgoing: outgoing, incoming: incoming, seconds: duration, generation: generation)
    }

    private func activate(item: AVPlayerItem, metadata: NowPlayingMetadata,
                          volume: Float? = nil) {
        // Without precise timing AVPlayer can over-estimate the length and play silence past the end.
        if let end = metadata.streamEnd, end > 0 {
            item.forwardPlaybackEndTime = CMTime(seconds: end, preferredTimescale: 1000)
        }
        observeEnd(of: item)
        hasSignalledEnd = false
        active.volume = volume ?? level(for: active)
        self.metadata = metadata
        currentTime = 0
        bufferedTime = 0
        duration = metadata.knownDuration ?? 0
        active.playImmediately(atRate: Float(playbackRate))
        isPlaying = true
        commandCenter.skipBackwardCommand.isEnabled = metadata.isEpisode
        commandCenter.skipForwardCommand.isEnabled = metadata.isEpisode
        artwork = nil
        loadArtwork(metadata.artworkURL)
        updateNowPlayingInfo()
    }

    private func startFade(outgoing: AVPlayer, incoming: AVPlayer, seconds: Double,
                           generation: Int) {
        fadeTask = Task { [weak self] in
            await self?.runFade(outgoing: outgoing, incoming: incoming, seconds: seconds)
            if self?.fadeGeneration == generation { self?.fadeTask = nil }
        }
    }

    private func cancelFade() {
        fadeTask?.cancel()
        fadeTask = nil
    }

    private func clearIdlePlayer() {
        idle.pause()
        idle.replaceCurrentItem(with: nil)
        idle.volume = clampedVolume
    }

    private func runFade(outgoing: AVPlayer, incoming: AVPlayer, seconds: Double) async {
        let stepInterval = 0.05
        let steps = max(1, Int(seconds / stepInterval))
        for step in 1...steps {
            try? await Task.sleep(nanoseconds: UInt64(stepInterval * 1_000_000_000))
            if Task.isCancelled { return }
            let progress = Float(step) / Float(steps)
            outgoing.volume = level(for: outgoing) * (1 - progress)
            incoming.volume = level(for: incoming) * progress
        }
        if Task.isCancelled { return }
        outgoing.pause()
        outgoing.replaceCurrentItem(with: nil)
        outgoing.volume = clampedVolume
        incoming.volume = level(for: incoming)
    }

    func togglePlayPause() {
        guard active.currentItem != nil else { return }
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        guard active.currentItem != nil, isPlaying else { return }
        active.pause()
        if fadeTask != nil { idle.pause() }
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        guard active.currentItem != nil, !isPlaying else { return }
        active.play()
        if fadeTask != nil { idle.play() }
        isPlaying = true
        updateNowPlayingInfo()
    }

    func stop() {
        cancelFade()
        active.pause()
        active.replaceCurrentItem(with: nil)
        clearIdlePlayer()
        isPlaying = false
        currentTime = 0
        duration = 0
        updateNowPlayingInfo()
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        // Tolerance lets AVPlayer snap to a keyframe instead of decoding to the exact frame.
        let tolerance = CMTime(seconds: 0.75, preferredTimescale: 600)
        active.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance)
        currentTime = seconds
        // Seeking away from the end re-arms end detection.
        if duration <= 0 || seconds < duration - 0.5 { hasSignalledEnd = false }
        updateNowPlayingInfo()
    }

    func restart() {
        guard active.currentItem != nil else { return }
        active.seek(to: .zero)
        currentTime = 0
        hasSignalledEnd = false
        active.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func applyEqualizer(_ settings: EqualizerSettings) {
        equalizerBox.settings = settings
    }

    // MARK: - Now Playing

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: metadata.title,
            MPMediaItemPropertyArtist: metadata.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackRate : 0.0,
        ]
        if !metadata.album.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = metadata.album
        }
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        let nsDict = NSDictionary(dictionary: info)
        infoCenter.nowPlayingInfo = nsDict as? [String: Any]
        infoCenter.playbackState = isPlaying ? .playing : .paused
    }

    private func loadArtwork(_ url: URL?) {
        guard let url, url != loadedArtworkURL else { return }
        loadedArtworkURL = url
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            let (downscaledData, size) = downscaleArtwork(data: data, maxDimension: 512)
            self.artwork = makeMediaArtwork(data: downscaledData, size: size)
            self.updateNowPlayingInfo()
        }
    }



    // MARK: - Observation

    /// `.playing` only once really advancing; excludes load/buffer but not brief mid-track stalls.
    private func observeTimeControl(of player: AVPlayer) {
        let observation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in
                guard let self, player === self.active else { return }
                self.isBuffering = self.isPlaying && status == .waitingToPlayAtSpecifiedRate
                if status == .playing, self.isPlaying { self.onPlaybackStart?() }
            }
        }
        timeControlObservers.append(observation)
    }

    private func addPeriodicObserver(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        let observer = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.tick(time, from: player)
            }
        }
        timeObservers.append((player, observer))
    }

    private func tick(_ time: CMTime, from player: AVPlayer) {
        // Ignore ticks from the player fading out.
        guard player === active else { return }
        let raw = time.seconds.isFinite ? time.seconds : 0
        // AVPlayer's estimate can over-report while buffering.
        if let known = metadata.knownDuration, known > 0 {
            duration = known
        } else if let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite {
            duration = itemDuration
        }
        let hadZeroDuration = duration == 0
        currentTime = duration > 0 ? min(raw, duration) : raw
        bufferedTime = bufferedEnd(of: player.currentItem, around: currentTime, cappedTo: duration)
        if hadZeroDuration && duration > 0 {
            updateNowPlayingInfo()
        }
        onProgress?(currentTime, duration)

        // Backstop for a missed end notification.
        if isPlaying, duration > 0, raw >= duration - 0.5,
           player.timeControlStatus != .playing {
            signalEnd()
        }
        // Backstop for a playhead running past the known length.
        if isPlaying, let known = metadata.knownDuration, known > 0,
           raw >= known + Self.pastKnownEndTolerance {
            signalEnd()
        }
    }

    /// Falls back to the furthest range when none contains `time` (e.g. after a seek).
    private func bufferedEnd(of item: AVPlayerItem?, around time: Double, cappedTo duration: Double) -> Double {
        guard let item else { return 0 }
        var furthest = 0.0
        for value in item.loadedTimeRanges {
            let range = value.timeRangeValue
            let start = range.start.seconds
            let end = (range.start + range.duration).seconds
            guard start.isFinite, end.isFinite else { continue }
            if time >= start - 1, time <= end + 0.5 {
                furthest = end
                break
            }
            furthest = max(furthest, end)
        }
        return duration > 0 ? min(furthest, duration) : furthest
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.signalEnd()
            }
        }
    }

    private func signalEnd() {
        guard !hasSignalledEnd else { return }
        hasSignalledEnd = true
        isPlaying = false
        updateNowPlayingInfo()
        onTrackFinished?()
    }
}

private nonisolated func makeMediaArtwork(data: Data, size: CGSize) -> MPMediaItemArtwork {
    let cachedImage = NSImage(data: data) ?? NSImage(size: size)
    return MPMediaItemArtwork(boundsSize: size) { _ in
        cachedImage
    }
}

private nonisolated func downscaleArtwork(data: Data, maxDimension: CGFloat = 320) -> (Data, CGSize) {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
        return (data, CGSize(width: 320, height: 320))
    }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxDimension
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
        return (data, CGSize(width: 320, height: 320))
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
        return (data, CGSize(width: cgImage.width, height: cgImage.height))
    }
    return (jpeg, CGSize(width: cgImage.width, height: cgImage.height))
}
