//
//  AppSettings.swift
//  YT Music
//

import SwiftUI

/// Mapped onto bitrate-ranked adaptive streams, not fixed kbps (YouTube's ladder varies).
nonisolated enum AudioQuality: String, Codable, CaseIterable, Sendable, Identifiable {
    case low
    case medium
    case high
    case auto

    var id: Self { self }

    var label: String {
        switch self {
        case .auto:   "Auto (Adaptive)"
        case .high:   "High (256kbps AAC)"
        case .medium: "Normal (128kbps)"
        case .low:    "Low (64kbps)"
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case fr

    var id: Self { self }

    var label: String {
        switch self {
        case .system: String(localized: "settings.general.language.system")
        case .en:     "English"
        case .fr:     "Français"
        }
    }
}

public enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case dark
    case light

    public var id: Self { self }

    public var label: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }
}

public enum LyricsFontSize: String, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large

    public var id: Self { self }

    public var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }

    public var titleFontSize: CGFloat {
        switch self {
        case .small: 22
        case .medium: 28
        case .large: 34
        }
    }

    public var inactiveFontSize: CGFloat {
        switch self {
        case .small: 16
        case .medium: 20
        case .large: 24
        }
    }
}

nonisolated struct StreamPreferences: Sendable, Equatable {
    var audioQuality: AudioQuality = .auto
    var preferAudioOverVideo: Bool = true
}

@MainActor
@Observable
final class AppSettings {
    public static let shared = AppSettings()

    var theme: AppTheme {
        didSet {
            store(theme.rawValue, for: .theme)
            applyTheme()
        }
    }

    public func applyTheme() {
        switch theme {
        case .system:
            NSApp?.appearance = nil
        case .dark:
            NSApp?.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp?.appearance = NSAppearance(named: .aqua)
        }
        if let windows = NSApp?.windows {
            for window in windows {
                guard !(window is NSPanel), window.frame.origin.x > -1000 else { continue }
                switch theme {
                case .system:
                    window.appearance = nil
                case .dark:
                    window.appearance = NSAppearance(named: .darkAqua)
                case .light:
                    window.appearance = NSAppearance(named: .aqua)
                }
            }
        }
    }

    var enableSaavnStreaming: Bool {
        didSet { store(enableSaavnStreaming, for: .enableSaavnStreaming) }
    }

    var enableAppleMusicMetadata: Bool {
        didSet { store(enableAppleMusicMetadata, for: .enableAppleMusicMetadata) }
    }

    var audioQuality: AudioQuality {
        didSet { store(audioQuality.rawValue, for: .audioQuality) }
    }

    var preferAudioOverVideo: Bool {
        didSet { store(preferAudioOverVideo, for: .preferAudioOverVideo) }
    }

    var volumeNormalization: Bool {
        didSet {
            store(volumeNormalization, for: .volumeNormalization)
            onVolumeNormalizationChange?(volumeNormalization)
        }
    }

    @ObservationIgnored var onVolumeNormalizationChange: ((Bool) -> Void)?

    var autoplay: Bool {
        didSet { store(autoplay, for: .autoplay) }
    }

    var proxyURL: String {
        didSet { store(proxyURL.isEmpty ? nil : proxyURL, for: .proxyURL) }
    }

    var language: AppLanguage {
        didSet {
            if language == .system {
                defaults.removeObject(forKey: Self.appleLanguagesKey)
            } else {
                defaults.set([language.rawValue], forKey: Self.appleLanguagesKey)
            }
        }
    }

    private static let appleLanguagesKey = "AppleLanguages"
    @ObservationIgnored private let launchLanguage: AppLanguage
    var needsRelaunchForLanguage: Bool { language != launchLanguage }

    func relaunch() {
        let relauncher = Process()
        relauncher.executableURL = URL(fileURLWithPath: "/bin/sh")
        relauncher.arguments = ["-c", "sleep 0.5; /usr/bin/open -n \"$0\"", Bundle.main.bundlePath]
        try? relauncher.run()
        NSApp.terminate(nil)
    }

    var playOnSingleClick: Bool {
        didSet { store(playOnSingleClick, for: .playOnSingleClick) }
    }

    var playClickCount: Int { playOnSingleClick ? 1 : 2 }

    var lyricsProvider: LyricsProvider {
        didSet { store(lyricsProvider.rawValue, for: .lyricsProvider) }
    }

    var fallbackLyricsEnabled: Bool {
        didSet { store(fallbackLyricsEnabled, for: .fallbackLyricsEnabled) }
    }

    var preferSyncedLyrics: Bool {
        didSet { store(preferSyncedLyrics, for: .preferSyncedLyrics) }
    }

    var autoScrollLyrics: Bool {
        didSet { store(autoScrollLyrics, for: .autoScrollLyrics) }
    }

    var lyricsFontSize: LyricsFontSize {
        didSet { store(lyricsFontSize.rawValue, for: .lyricsFontSize) }
    }

    var reduceMotion: Bool {
        didSet { store(reduceMotion, for: .reduceMotion) }
    }

    var showRemainingTime: Bool {
        didSet { store(showRemainingTime, for: .showRemainingTime) }
    }

    var enableTrackNotifications: Bool {
        didSet { store(enableTrackNotifications, for: .enableTrackNotifications) }
    }

    var compactSidebar: Bool {
        didSet { store(compactSidebar, for: .compactSidebar) }
    }

    var volume: Double {
        didSet { store(volume, for: .volume) }
    }

    var isMuted: Bool {
        didSet { store(isMuted, for: .isMuted) }
    }

    var podcastPlaybackRate: Double {
        didSet { store(podcastPlaybackRate, for: .podcastPlaybackRate) }
    }

    var crossfadeEnabled: Bool {
        didSet { store(crossfadeEnabled, for: .crossfadeEnabled) }
    }

    var crossfadeSeconds: Double {
        didSet { store(crossfadeSeconds, for: .crossfadeSeconds) }
    }

    var nextTrackPreloadSeconds: Double {
        didSet { store(nextTrackPreloadSeconds, for: .nextTrackPreloadSeconds) }
    }

    var equalizerEnabled: Bool {
        didSet {
            store(equalizerEnabled, for: .equalizerEnabled)
            notifyEqualizerChanged()
        }
    }

    var equalizerGains: [Double] {
        didSet {
            store(try? JSONEncoder().encode(equalizerGains), for: .equalizerGains)
            notifyEqualizerChanged()
        }
    }

    @ObservationIgnored var onEqualizerChange: ((EqualizerSettings) -> Void)?

    var equalizerSettings: EqualizerSettings {
        EqualizerSettings(isEnabled: equalizerEnabled, gains: equalizerGains)
    }

    func applyEqualizerPreset(_ preset: EqualizerPreset) {
        equalizerGains = preset.gains
    }

    private func notifyEqualizerChanged() {
        onEqualizerChange?(equalizerSettings)
    }

    var openAtLogin: Bool {
        didSet { LoginItem.setEnabled(openAtLogin) }
    }

    private(set) var downloadDirectory: URL?

    var streamPreferences: StreamPreferences {
        StreamPreferences(audioQuality: audioQuality,
                          preferAudioOverVideo: preferAudioOverVideo)
    }

    var effectiveDownloadDirectory: URL {
        downloadDirectory ?? FileManager.default
            .urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enableSaavnStreaming = defaults.object(forKey: Key.enableSaavnStreaming.rawValue) as? Bool ?? true
        self.enableAppleMusicMetadata = defaults.object(forKey: Key.enableAppleMusicMetadata.rawValue) as? Bool ?? true
        self.audioQuality = (defaults.string(forKey: Key.audioQuality.rawValue)
            .flatMap(AudioQuality.init)) ?? .auto
        self.preferAudioOverVideo = defaults.object(forKey: Key.preferAudioOverVideo.rawValue) as? Bool ?? true
        self.volumeNormalization = defaults.bool(forKey: Key.volumeNormalization.rawValue)
        self.autoplay = defaults.object(forKey: Key.autoplay.rawValue) as? Bool ?? true
        self.proxyURL = defaults.string(forKey: Key.proxyURL.rawValue) ?? ""
        let language = (defaults.stringArray(forKey: Self.appleLanguagesKey)?.first)
            .flatMap { AppLanguage(rawValue: String($0.prefix(2))) } ?? .system
        self.language = language
        self.launchLanguage = language
        self.playOnSingleClick = defaults.bool(forKey: Key.playOnSingleClick.rawValue)
        self.lyricsProvider = (defaults.string(forKey: Key.lyricsProvider.rawValue)
            .flatMap(LyricsProvider.init)) ?? .lrclib
        self.fallbackLyricsEnabled = defaults.object(forKey: Key.fallbackLyricsEnabled.rawValue) as? Bool ?? true
        self.preferSyncedLyrics = defaults.object(forKey: Key.preferSyncedLyrics.rawValue) as? Bool ?? true
        self.autoScrollLyrics = defaults.object(forKey: Key.autoScrollLyrics.rawValue) as? Bool ?? true
        self.lyricsFontSize = (defaults.string(forKey: Key.lyricsFontSize.rawValue)
            .flatMap(LyricsFontSize.init)) ?? .medium
        self.reduceMotion = defaults.bool(forKey: Key.reduceMotion.rawValue)
        self.showRemainingTime = defaults.bool(forKey: Key.showRemainingTime.rawValue)
        self.enableTrackNotifications = defaults.bool(forKey: Key.enableTrackNotifications.rawValue)
        self.compactSidebar = defaults.bool(forKey: Key.compactSidebar.rawValue)
        self.volume = defaults.object(forKey: Key.volume.rawValue) as? Double ?? 1
        self.isMuted = defaults.bool(forKey: Key.isMuted.rawValue)
        self.podcastPlaybackRate = defaults.object(forKey: Key.podcastPlaybackRate.rawValue) as? Double ?? 1
        self.crossfadeEnabled = defaults.bool(forKey: Key.crossfadeEnabled.rawValue)
        self.crossfadeSeconds = defaults.object(forKey: Key.crossfadeSeconds.rawValue) as? Double ?? 6
        self.nextTrackPreloadSeconds = defaults.object(forKey: Key.nextTrackPreloadSeconds.rawValue) as? Double ?? 0
        self.equalizerEnabled = defaults.bool(forKey: Key.equalizerEnabled.rawValue)
        self.equalizerGains = Self.decodeGains(defaults.data(forKey: Key.equalizerGains.rawValue))
        self.downloadDirectory = Self.resolveBookmark(defaults.data(forKey: Key.downloadDirectory.rawValue))
        self.openAtLogin = LoginItem.isEnabled
        self.theme = (defaults.string(forKey: Key.theme.rawValue)
            .flatMap(AppTheme.init)) ?? .system
        applyTheme()
    }

    /// Always returns exactly `EqualizerBands.count` entries.
    private static func decodeGains(_ data: Data?) -> [Double] {
        guard let data,
              let gains = try? JSONDecoder().decode([Double].self, from: data) else {
            return EqualizerSettings.flat.gains
        }
        return EqualizerSettings(isEnabled: false, gains: gains).normalizedGains
    }

    func setDownloadDirectory(_ url: URL?) {
        guard let url else {
            downloadDirectory = nil
            store(nil, for: .downloadDirectory)
            return
        }
        downloadDirectory = url
        let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        store(bookmark, for: .downloadDirectory)
    }

    /// Held open for the app's lifetime.
    private static func resolveBookmark(_ data: Data?) -> URL? {
        guard let data else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    // MARK: - Persistence

    private enum Key: String {
        case enableSaavnStreaming     = "settings.enableSaavnStreaming"
        case enableAppleMusicMetadata = "settings.enableAppleMusicMetadata"
        case audioQuality             = "settings.audioQuality"
        case preferAudioOverVideo = "settings.preferAudioOverVideo"
        case volumeNormalization = "settings.volumeNormalization"
        case autoplay            = "settings.autoplay"
        case proxyURL            = "settings.proxyURL"
        case playOnSingleClick   = "settings.playOnSingleClick"
        case lyricsProvider      = "settings.lyricsProvider"
        case fallbackLyricsEnabled = "settings.fallbackLyricsEnabled"
        case preferSyncedLyrics  = "settings.preferSyncedLyrics"
        case autoScrollLyrics    = "settings.autoScrollLyrics"
        case lyricsFontSize      = "settings.lyricsFontSize"
        case reduceMotion        = "settings.reduceMotion"
        case showRemainingTime   = "settings.showRemainingTime"
        case enableTrackNotifications = "settings.enableTrackNotifications"
        case compactSidebar      = "settings.compactSidebar"
        case volume              = "settings.volume"
        case isMuted             = "settings.isMuted"
        case podcastPlaybackRate = "settings.podcastPlaybackRate"
        case crossfadeEnabled    = "settings.crossfadeEnabled"
        case crossfadeSeconds    = "settings.crossfadeSeconds"
        case nextTrackPreloadSeconds = "settings.nextTrackPreloadSeconds"
        case equalizerEnabled    = "settings.equalizerEnabled"
        case equalizerGains      = "settings.equalizerGains"
        case downloadDirectory   = "settings.downloadDirectory"
        case theme               = "settings.theme"
    }

    private func store(_ value: Any?, for key: Key) {
        if let value {
            defaults.set(value, forKey: key.rawValue)
        } else {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}
