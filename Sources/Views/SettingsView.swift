import SwiftUI
import AppKit

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settings = AppSettings.shared
    @ObservedObject var lastfm = LastfmService.shared
    @ObservedObject var listenBrainz = ListenBrainzService.shared
    @ObservedObject var authManager = AuthManager.shared
    @ObservedObject var eclipseService = EclipseAddonService.shared

    @State private var selectedTab: SettingsTab = .appearance
    @State private var tokenInput: String = ""
    @State private var lastfmApiKeyInput: String = ""
    @State private var lastfmSecretInput: String = ""
    @State private var proxyInput: String = ""
    @State private var proxySavedMessage: String = ""
    @State private var newAddonUrl: String = ""
    @State private var isInstallingAddon = false
    @State private var addonInstallMessage: String = ""
    @State private var addonInstallSuccess = false
    @State private var cacheClearedMessage: String = ""
    @Binding var showSignInSheet: Bool

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case appearance = "Appearance"
        case audio = "Audio & Playback"
        case metadata = "Metadata & Lyrics"
        case scrobble = "Scrobble"
        case account = "Account"
        case system = "System & Storage"
        case addons = "Addons"

        public var id: String { rawValue }

        var icon: String {
            switch self {
            case .appearance: "circle.lefthalf.filled"
            case .audio: "speaker.wave.3.fill"
            case .metadata: "sparkles"
            case .scrobble: "music.note.tv"
            case .account: "person.crop.circle.fill"
            case .system: "gearshape.fill"
            case .addons: "server.rack"
            }
        }

        var iconGradient: [Color] {
            switch self {
            case .appearance: [.purple, .blue]
            case .audio: [.pink, .red]
            case .metadata: [.blue, .purple]
            case .scrobble: [.red, .orange]
            case .account: [.red, .pink]
            case .system: [.gray, .secondary]
            case .addons: [.purple, .indigo]
            }
        }

        var subtitle: String {
            switch self {
            case .appearance: "Appearance mode, themes, and motion effects"
            case .audio: "Audio streaming quality, crossfade, and playback preferences"
            case .metadata: "Lyrics providers, sync behavior, and artwork sources"
            case .scrobble: "Listening history scrobbling to Last.fm and ListenBrainz"
            case .account: "YouTube Music Google account credentials and session"
            case .system: "Startup, storage, native notifications, and network proxy"
            case .addons: "Third-party audio providers and community addons"
            }
        }
    }

    public init(showSignInSheet: Binding<Bool>) {
        self._showSignInSheet = showSignInSheet
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebarView
                .frame(width: 210)
                .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow))

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedTab.rawValue).font(.system(size: 22, weight: .bold))
                        Text(selectedTab.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    switch selectedTab {
                    case .appearance: appearanceSection
                    case .audio: audioSection
                    case .metadata: metadataSection
                    case .scrobble: scrobbleSection
                    case .account: accountSection
                    case .system: systemSection
                    case .addons: addonsSection
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color.ytBackground.ignoresSafeArea())
        }
        .frame(minWidth: 760, idealWidth: 820, minHeight: 520, idealHeight: 580)
        .onAppear {
            tokenInput = listenBrainz.apiToken
            lastfmApiKeyInput = lastfm.apiKey
            lastfmSecretInput = lastfm.apiSecret
            proxyInput = settings.proxyURL
        }
        .onDisappear {
            tokenInput = ""
            lastfmSecretInput = ""
        }
    }

    private var sidebarView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases) { tab in
                        let isSelected = selectedTab == tab
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                        } label: {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(LinearGradient(colors: tab.iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 22, height: 22)
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(isSelected ? Color.primary : Color.primary.opacity(0.85))
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.primary.opacity(0.10) : Color.clear)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer()
            Divider()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.pink)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "THEME SELECTION", icon: "circle.lefthalf.filled", colors: [.purple, .blue])

            HStack(spacing: 14) {
                themeCard(theme: .light, title: "Light", subtitle: "Clean, light canvas")
                themeCard(theme: .dark, title: "Dark", subtitle: "Deep, dark canvas")
                themeCard(theme: .system, title: "Auto", subtitle: "Matches macOS")
            }

            SettingsCard {
                SettingsToggleRow("Compact Sidebar", subtitle: "Reduces vertical padding for track and playlist navigation rows.", isOn: $settings.compactSidebar, showDivider: true)
                SettingsToggleRow("Reduce Motion & Visual Effects", subtitle: "Disables expensive multi-pass GPU blur shaders in Now Playing to conserve battery and GPU.", isOn: $settings.reduceMotion)
            }

            HStack(spacing: 12) {
                Image(systemName: "info.circle").font(.system(size: 13)).foregroundStyle(.secondary)
                Text(themeStatusText).font(.system(size: 11.5)).foregroundStyle(.secondary)
                Spacer()
                Button(settings.theme == .dark ? "Switch to Light" : "Switch to Dark") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settings.theme = (settings.theme == .dark) ? .light : .dark
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "STREAMING QUALITY", icon: "speaker.wave.3.fill", colors: [.pink, .red])

            SettingsCard {
                SettingsPickerRow("Audio Quality", subtitle: "Preferred playback bitrate ladder stream.", selection: $settings.audioQuality, showDivider: true) {
                    ForEach(AudioQuality.allCases) { Text($0.label).tag($0) }
                }
                SettingsToggleRow("Prefer Audio Over Video", subtitle: "Requests audio-only adaptive streams, reducing download bandwidth.", isOn: $settings.preferAudioOverVideo, showDivider: true)
                SettingsToggleRow("Volume Normalization", subtitle: "Applies ReplayGain target to equalize track volume levels.", isOn: $settings.volumeNormalization)
            }

            SectionHeader(title: "PLAYBACK BEHAVIOR", icon: "waveform", colors: [.orange, .red])

            SettingsCard {
                SettingsToggleRow("Crossfade Playback", subtitle: "Fades smoothly between consecutive tracks.", isOn: $settings.crossfadeEnabled, showDivider: settings.crossfadeEnabled)

                if settings.crossfadeEnabled {
                    SettingsRow(showDivider: true) {
                        HStack(spacing: 12) {
                            Text("Crossfade Duration").font(.system(size: 12, weight: .medium))
                            Slider(value: $settings.crossfadeSeconds, in: 1...12, step: 1).tint(Color.pink)
                            Text("\(Int(settings.crossfadeSeconds))s")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }

                SettingsPickerRow("Next Track Preload", subtitle: "Pre-resolves and buffers the next song before playback finishes.", selection: $settings.nextTrackPreloadSeconds, showDivider: true) {
                    Text("Off").tag(0.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("15 seconds").tag(15.0)
                }

                SettingsToggleRow("Single-Click to Play", subtitle: "Plays tracks immediately with a single click instead of double-click.", isOn: $settings.playOnSingleClick, showDivider: true)
                SettingsToggleRow("Autoplay Similar Tracks", subtitle: "Queues related music automatically when playback reaches the end.", isOn: $settings.autoplay, showDivider: true)
                SettingsToggleRow("Show Remaining Playback Time", subtitle: "Displays time left countdown (-02:15) in player bar instead of total length.", isOn: $settings.showRemainingTime)
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "SYNCHRONIZED LYRICS", icon: "sparkles", colors: [.blue, .purple])

            SettingsCard {
                SettingsPickerRow("Primary Lyrics Provider", subtitle: "Source engine for real-time word and line synchronized lyrics.", selection: $settings.lyricsProvider, showDivider: true) {
                    ForEach(LyricsProvider.allCases) { Text($0.label).tag($0) }
                }

                SettingsToggleRow("Fallback Lyrics Cascade", subtitle: "Automatically checks other providers if your primary provider returns no lyrics.", isOn: $settings.fallbackLyricsEnabled, showDivider: true)
                SettingsToggleRow("Prefer Synchronized Lyrics", subtitle: "Prioritizes timestamped lines over plain un-synced text.", isOn: $settings.preferSyncedLyrics, showDivider: true)
                SettingsToggleRow("Auto-Scroll Lyrics", subtitle: "Smoothly animates lyrics list to follow playback progress.", isOn: $settings.autoScrollLyrics, showDivider: true)

                SettingsRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lyrics Text Size").font(.system(size: 13, weight: .medium))
                            Text("Adjusts typography scale in Now Playing synced lyrics view.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Picker("", selection: $settings.lyricsFontSize) {
                            ForEach(LyricsFontSize.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                    }
                }
            }

            SectionHeader(title: "METADATA SOURCES", icon: "music.quarternote.3", colors: [.pink, .purple])

            SettingsCard {
                SettingsToggleRow("Apple Music Metadata", subtitle: "Fetches high-resolution album covers and animated artwork from Apple Music.", isOn: $settings.enableAppleMusicMetadata, showDivider: true)
                SettingsToggleRow("JioSaavn 320kbps Audio Streaming", subtitle: "Streams matching catalog tracks at pristine 320kbps AAC.", isOn: $settings.enableSaavnStreaming)
            }
        }
    }

    private var scrobbleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "LAST.FM SCROBBLER", icon: "music.note.tv", colors: [.red, .orange])

            SettingsCard {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle().fill(lastfm.isConnected ? Color.green : Color.orange).frame(width: 8, height: 8)
                            Text(lastfm.isConnected ? "Connected to Last.fm as @\(lastfm.username)" : "Last.fm Scrobbler")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if lastfm.isConnected {
                                Button("Disconnect", role: .destructive) { lastfm.disconnect() }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }

                        if !lastfm.isConnected {
                            if lastfm.awaitingAuthorization {
                                Text("Approve access in your browser, then click 'Finish Connecting'.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)

                                HStack {
                                    Button(lastfm.isWorking ? "Finishing..." : "Finish Connecting") {
                                        lastfm.completeAuthorization()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.pink)
                                    .disabled(lastfm.isWorking)

                                    Button("Cancel") { lastfm.cancelAuthorization() }
                                        .buttonStyle(.bordered)
                                }
                            } else {
                                Text("Scrobble tracks and sync favorites to your Last.fm profile.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    TextField("API Key", text: $lastfmApiKeyInput).textFieldStyle(.roundedBorder)
                                    SecureField("Shared Secret", text: $lastfmSecretInput).textFieldStyle(.roundedBorder)
                                    Button(lastfm.isWorking ? "Connecting..." : "Connect") {
                                        lastfm.beginAuthorization(apiKey: lastfmApiKeyInput, secret: lastfmSecretInput)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color.pink)
                                    .disabled(lastfmApiKeyInput.isEmpty || lastfmSecretInput.isEmpty || lastfm.isWorking)
                                }
                            }
                        }

                        if !lastfm.statusMessage.isEmpty {
                            Text(lastfm.statusMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(lastfm.isConnected ? Color.green : Color.secondary)
                        }
                    }
                }
            }

            SectionHeader(title: "LISTENBRAINZ SCROBBLING", icon: "brain.head.profile", colors: [.orange, .red])

            SettingsCard {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle().fill(listenBrainz.isValid ? Color.green : Color.orange).frame(width: 8, height: 8)
                            Text(listenBrainz.isValid ? "Connected to ListenBrainz as @\(listenBrainz.username)" : "Disconnected")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            SecureField("Paste ListenBrainz User Token...", text: $tokenInput).textFieldStyle(.roundedBorder)
                            Button("Save Token") { listenBrainz.apiToken = tokenInput }.buttonStyle(.bordered)
                        }
                        Text("Get your token at listenbrainz.org/profile.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "GOOGLE / YTM ACCOUNT", icon: "person.crop.circle.fill", colors: [.red, .pink])

            SettingsCard {
                SettingsRow {
                    if authManager.isLoggedIn {
                        HStack(spacing: 12) {
                            if !authManager.userAvatarUrl.isEmpty {
                                CachedAsyncImage(url: URL(string: authManager.userAvatarUrl.thumbnailSized(for: 80))) { phase in
                                    if let img = phase.image {
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Circle().fill(Color.pink.opacity(0.2))
                                    }
                                }
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.userDisplayName.isEmpty ? "Signed In User" : authManager.userDisplayName)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Connected via WebKit Session")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Sign Out", role: .destructive) { authManager.signOut() }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Not Signed In").font(.system(size: 14, weight: .semibold))
                                Text("Sign in to access your personal library, liked songs, and mixes.")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Sign In") { showSignInSheet = true }
                                .buttonStyle(.borderedProminent)
                                .tint(Color.pink)
                        }
                    }
                }
            }
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "APPLICATION STARTUP & SYSTEM", icon: "gearshape.fill", colors: [.gray, .secondary])

            SettingsCard {
                SettingsToggleRow("Open at Login", subtitle: "Starts YouTube Music automatically on macOS launch.", isOn: $settings.openAtLogin, showDivider: true)
                SettingsToggleRow("Track Change Notifications", subtitle: "Delivers a native macOS system notification banner whenever a new track begins playing.", isOn: $settings.enableTrackNotifications)
            }

            SectionHeader(title: "CACHE & OFFLINE STORAGE", icon: "internaldrive", colors: [.blue, .gray])

            SettingsCard {
                SettingsRow(showDivider: true) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Download Location").font(.system(size: 13, weight: .medium))
                            Text(settings.effectiveDownloadDirectory.path)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("Choose...") { chooseDownloadDirectory() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                SettingsRow(showDivider: true) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Downloaded Music Storage").font(.system(size: 13, weight: .medium))
                            Text("\(DownloadManager.shared.downloadedSongs.count) songs saved (\(DownloadManager.shared.totalDownloadedSizeFormatted))")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Button("Show in Finder") {
                                DownloadManager.shared.openDownloadsFolder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            if !DownloadManager.shared.downloadedSongs.isEmpty {
                                Button("Delete All", role: .destructive) {
                                    DownloadManager.shared.deleteAllDownloads()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                SettingsRow {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Purge Memory & Image Cache").font(.system(size: 13, weight: .medium))
                            Text(cacheClearedMessage.isEmpty ? "Frees transient artwork and metadata cache." : cacheClearedMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(cacheClearedMessage.isEmpty ? Color.secondary : Color.green)
                        }
                        Spacer()
                        Button("Clear Cache") {
                            URLCache.shared.removeAllCachedResponses()
                            ImageMemoryCache.shared.clear()
                            cacheClearedMessage = "Cache cleared successfully."
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            SectionHeader(title: "NETWORK PROXY", icon: "network", colors: [.purple, .blue])

            SettingsCard {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("http://host:port", text: $proxyInput).textFieldStyle(.roundedBorder)
                            Button("Save") {
                                let trimmed = proxyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed.isEmpty || NetworkProxy(string: trimmed) != nil {
                                    settings.proxyURL = trimmed
                                    proxySavedMessage = trimmed.isEmpty ? "Proxy cleared." : "Proxy saved."
                                } else {
                                    proxySavedMessage = "Invalid proxy URL (expected http:// or https:// with valid port)."
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        if !proxySavedMessage.isEmpty {
                            Text(proxySavedMessage).font(.system(size: 11)).foregroundStyle(Color.green)
                        }
                    }
                }
            }
        }
    }

    private var addonsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "ECLIPSE MUSIC ADDONS", icon: "server.rack", colors: [.purple, .indigo])

            SettingsCard {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            TextField("Addon URL (e.g. http://localhost:3000)", text: $newAddonUrl).textFieldStyle(.roundedBorder)

                            Button {
                                Task { await installAddon() }
                            } label: {
                                if isInstallingAddon {
                                    ProgressView().scaleEffect(0.6)
                                } else {
                                    Text("Add Addon")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.pink)
                            .disabled(newAddonUrl.trimmingCharacters(in: .whitespaces).isEmpty || isInstallingAddon)
                        }

                        if !addonInstallMessage.isEmpty {
                            Text(addonInstallMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(addonInstallSuccess ? Color.green : Color.red)
                        }

                        if eclipseService.addons.isEmpty {
                            Text("No addons installed yet. Add your self-hosted server above.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary.opacity(0.8))
                        } else {
                            VStack(spacing: 6) {
                                ForEach(eclipseService.addons) { addon in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(addon.name).font(.system(size: 12.5, weight: .semibold))
                                            Text("\(addon.baseUrl) • v\(addon.version)").font(.system(size: 10.5)).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Button("Remove") { eclipseService.removeAddon(id: addon.id) }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func themeCard(theme: AppTheme, title: String, subtitle: String) -> some View {
        let isSelected = settings.theme == theme
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { settings.theme = theme }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.14) : (theme == .light ? Color(red: 0.94, green: 0.94, blue: 0.96) : Color(red: 0.22, green: 0.22, blue: 0.26)))
                        .frame(height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? Color.pink : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
                        )

                    if theme == .light {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.white).frame(width: 44, height: 42)
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.pink.opacity(0.35)).frame(width: 22, height: 18)
                                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.25)).frame(width: 22, height: 18)
                            }
                        }
                    } else if theme == .dark {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.18, green: 0.18, blue: 0.20)).frame(width: 44, height: 42)
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.pink.opacity(0.65)).frame(width: 22, height: 18)
                                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.15)).frame(width: 22, height: 18)
                            }
                        }
                    } else {
                        HStack(spacing: 0) {
                            ZStack {
                                Color.white
                                Image(systemName: "sun.max.fill").font(.system(size: 16)).foregroundStyle(Color.orange)
                            }
                            ZStack {
                                Color(red: 0.10, green: 0.10, blue: 0.14)
                                Image(systemName: "moon.stars.fill").font(.system(size: 15)).foregroundStyle(Color.purple)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                HStack(spacing: 5) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.pink : Color.secondary)
                    Text(title).font(.system(size: 12, weight: isSelected ? .bold : .medium))
                }

                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.pink.opacity(0.8) : Color.primary.opacity(0.06), lineWidth: isSelected ? 1.5 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private var themeStatusText: String {
        switch settings.theme {
        case .light: "Light mode is locked on. Toggle anytime with ⇧⌘D."
        case .dark: "Dark mode is locked on. Toggle anytime with ⇧⌘D."
        case .system: "Following macOS appearance automatically. Toggle anytime with ⇧⌘D."
        }
    }

    private func chooseDownloadDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.setDownloadDirectory(url)
        }
    }

    private func installAddon() async {
        let trimmed = newAddonUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isInstallingAddon = true
        addonInstallMessage = ""
        do {
            _ = try await eclipseService.addAddon(urlString: trimmed)
            addonInstallSuccess = true
            addonInstallMessage = "Addon installed successfully!"
            newAddonUrl = ""
        } catch {
            addonInstallSuccess = false
            addonInstallMessage = error.localizedDescription
        }
        isInstallingAddon = false
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(nsColor: .controlBackgroundColor).opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.06), lineWidth: 0.8))
    }
}

struct SettingsRow<Content: View>: View {
    let showDivider: Bool
    @ViewBuilder let content: () -> Content

    init(showDivider: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.showDivider = showDivider
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            if showDivider {
                Divider().padding(.leading, 14)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsPickerRow<T: Hashable, PickerContent: View>: View {
    let title: String
    let subtitle: String?
    @Binding var selection: T
    let showDivider: Bool
    @ViewBuilder let content: () -> PickerContent

    init(_ title: String, subtitle: String? = nil, selection: Binding<T>, showDivider: Bool = false, @ViewBuilder content: @escaping () -> PickerContent) {
        self.title = title
        self.subtitle = subtitle
        self._selection = selection
        self.showDivider = showDivider
        self.content = content
    }

    var body: some View {
        SettingsRow(showDivider: showDivider) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker("", selection: $selection) {
                    content()
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let showDivider: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>, showDivider: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.showDivider = showDivider
    }

    var body: some View {
        SettingsRow(showDivider: showDivider) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color.pink)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    let colors: [Color]

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 18, height: 18)
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
        }
        .padding(.bottom, 2)
    }
}
