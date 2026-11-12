import SwiftUI
import AppKit

public struct NowPlayingView: View {
    @Binding var isPresented: Bool
    @ObservedObject var player = AudioPlayerService.shared
    @State private var isHoveringVolume = false
    @State private var isDraggingVolume = false
    @State private var activeTab: NowPlayingTab = .lyrics

    public enum NowPlayingTab: String, CaseIterable, Identifiable {
        case lyrics = "Lyrics"
        case queue = "Playing Next"
        public var id: String { rawValue }
    }

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        GeometryReader { windowGeo in
            let totalW = windowGeo.size.width
            let totalH = windowGeo.size.height
            let isCompactH = totalH < 680
            let isVeryCompactH = totalH < 580
            let isCompactW = totalW < 960
            let isNarrow = totalW < 760
            let topBarH: CGFloat = 48
            let contentH = max(100, totalH - topBarH)

            ZStack(alignment: .topLeading) {
                AmbientBlurBackgroundView(thumbUrl: currentThumbUrl)
                    .equatable()
                    .frame(width: totalW, height: totalH)

                VStack(spacing: 0) {
                    topNavigationBar
                        .frame(width: totalW, height: topBarH)

                    splitMainContent(
                        totalW: totalW,
                        contentH: contentH,
                        isCompactH: isCompactH,
                        isVeryCompactH: isVeryCompactH,
                        isCompactW: isCompactW,
                        isNarrow: isNarrow
                    )
                    .frame(width: totalW, height: contentH)
                }
                .frame(width: totalW, height: totalH)
            }
            .frame(width: totalW, height: totalH)
        }
        .ignoresSafeArea(.all)
        .background(WindowConfigurator(showNowPlaying: true))
    }

    private var topNavigationBar: some View {
        HStack(alignment: .center, spacing: 14) {
            Spacer().frame(width: 78)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isPresented = false
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                    Text("Close")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
                        )
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Close Now Playing (Esc)")

            Spacer()

            AppleMusicTabSelector(activeTab: $activeTab, queueCount: player.queue.count)

            if activeTab == .queue && !player.queue.isEmpty {
                Button("Clear Queue") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        player.queue.removeAll()
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.pink)
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.pink.opacity(0.14))
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(height: 48)
    }

    @ViewBuilder
    private func splitMainContent(
        totalW: CGFloat,
        contentH: CGFloat,
        isCompactH: Bool,
        isVeryCompactH: Bool,
        isCompactW: Bool,
        isNarrow: Bool
    ) -> some View {
        let leftColWidth = isNarrow ? totalW - 48 : min(max(totalW * 0.40, 310), 450)
        let maxArtByHeight = isVeryCompactH ? contentH * 0.30 : (isCompactH ? contentH * 0.34 : contentH * 0.40)
        let artSize = min(leftColWidth - 44, isCompactH ? 200 : 340, maxArtByHeight)
        let vSpacing: CGFloat = isVeryCompactH ? 6 : (isCompactH ? 10 : 16)
        let colSpacing: CGFloat = isCompactW ? 24 : 36
        let hPadding: CGFloat = isCompactW ? 24 : 38

        HStack(spacing: colSpacing) {
            VStack(spacing: vSpacing) {
                Spacer(minLength: 2)

                artworkView(size: artSize)

                trackInfoView(compact: isCompactH)

                scrubberView

                transportControlsView(compact: isCompactH)

                volumeBarView

                Spacer(minLength: 2)
            }
            .frame(width: leftColWidth)

            if !isNarrow {
                Divider()
                    .overlay(Color.white.opacity(0.12))

                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if activeTab == .lyrics {
                            lyricsView(compact: isCompactH)
                        } else {
                            queueView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, hPadding)
        .padding(.bottom, 16)
    }

    private var currentThumbUrl: String {
        guard let song = player.currentSong else { return "" }
        return !song.thumbnailUrl.isEmpty ? song.thumbnailUrl : "https://i.ytimg.com/vi/\(song.id)/hqdefault.jpg"
    }

    private func artworkView(size: CGFloat) -> some View {
        ZStack {
            if !currentThumbUrl.isEmpty {
                CachedAsyncImage(url: URL(string: currentThumbUrl.thumbnailSized(for: 512))) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill().frame(width: size, height: size).clipped()
                    } else if phase.error != nil {
                        Image(systemName: "music.note").font(.system(size: 44)).foregroundStyle(.white.opacity(0.5))
                    } else {
                        ProgressView().scaleEffect(0.8)
                    }
                }
            } else {
                Image(systemName: "music.note").font(.system(size: 44)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.24), lineWidth: 0.75)
        )
        .shadow(color: Color.black.opacity(0.55), radius: 28, x: 0, y: 14)
        .scaleEffect(player.isPlaying ? 1.0 : 0.94)
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: player.isPlaying)
    }

    private func trackInfoView(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                Text(player.currentSong?.title ?? "Not Playing")
                    .font(.system(size: compact ? 19 : 23, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                let resolvedArtist: String = {
                    guard let song = player.currentSong else { return "Select a track to stream" }
                    if !song.artist.isEmpty && song.artist != "Unknown Artist" { return song.artist }
                    if !song.album.isEmpty { return song.album }
                    return "Unknown Artist"
                }()

                Text(resolvedArtist)
                    .font(.system(size: compact ? 13.5 : 15.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let album = player.currentSong?.album, !album.isEmpty {
                        Text(album)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                    }

                    if player.isLossless {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 8, weight: .bold))
                            Text(player.audioQualityTitle.contains("Saavn") ? "Saavn 320k (HQ)" : "Lossless")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                        )
                        .help(player.audioQualityTitle)
                    }
                }
            }

            Spacer()

            if let song = player.currentSong {
                Button {
                    Task {
                        try? await InnerTubeService.shared.toggleLike(videoId: song.id, isLiked: !song.isLiked)
                        if let idx = player.queue.firstIndex(where: { $0.id == song.id }) {
                            player.queue[idx].isLiked.toggle()
                        }
                    }
                } label: {
                    Image(systemName: song.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: compact ? 19 : 22))
                        .foregroundStyle(song.isLiked ? Color.pink : Color.white.opacity(0.75))
                        .scaleEffect(song.isLiked ? 1.08 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: song.isLiked)
                }
                .buttonStyle(.plain)
                .help(song.isLiked ? "Loved" : "Love Track")
            }
        }
        .padding(.horizontal, 4)
    }

    private var scrubberView: some View {
        NowPlayingScrubberView(player: player)
    }

    private func transportControlsView(compact: Bool) -> some View {
        HStack(spacing: compact ? 22 : 30) {
            Button {
                player.isShuffle.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: compact ? 15 : 17, weight: .semibold))
                    .foregroundStyle(player.isShuffle ? Color.pink : Color.white.opacity(0.75))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(player.isShuffle ? Color.pink.opacity(0.2) : Color.clear)
                    )
            }
            .buttonStyle(.plain)

            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: compact ? 20 : 23))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)

            Button {
                player.togglePlayPause()
            } label: {
                let btnSize: CGFloat = compact ? 52 : 62
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 5)

                    if player.isLoading {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.black)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: compact ? 22 : 25, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .offset(x: player.isPlaying ? 0 : 2)
                    }
                }
                .frame(width: btnSize, height: btnSize)
            }
            .buttonStyle(.plain)

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: compact ? 20 : 23))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)

            Button {
                switch player.repeatMode {
                case .off: player.repeatMode = .all
                case .all: player.repeatMode = .one
                case .one: player.repeatMode = .off
                }
            } label: {
                Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(.system(size: compact ? 15 : 17, weight: .semibold))
                    .foregroundStyle(player.repeatMode != .off ? Color.pink : Color.white.opacity(0.75))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(player.repeatMode != .off ? Color.pink.opacity(0.2) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var volumeBarView: some View {
        HStack(spacing: 10) {
            Button {
                player.volume = player.volume > 0 ? 0 : 0.8
            } label: {
                Image(systemName: player.volume > 0 ? "speaker.fill" : "speaker.slash.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Toggle Mute")

            GeometryReader { volGeo in
                let w = volGeo.size.width
                let vol = CGFloat(min(max(player.volume, 0), 1))
                let barH: CGFloat = isHoveringVolume || isDraggingVolume ? 6 : 4

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.20)).frame(height: barH)
                    Capsule().fill(Color.white.opacity(0.92)).frame(width: max(0, w * vol), height: barH)

                    if isHoveringVolume || isDraggingVolume {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 11, height: 11)
                            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
                            .offset(x: max(0, min(w - 11, w * vol - 5.5)))
                    }
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .onHover { isHoveringVolume = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            isDraggingVolume = true
                            player.volume = Float(max(0, min(1, g.location.x / w)))
                        }
                        .onEnded { _ in isDraggingVolume = false }
                )
            }
            .frame(height: 16)

            Button {
                player.volume = 1.0
            } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("Set Max Volume")
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func lyricsView(compact: Bool) -> some View {
        let activeSize = compact ? AppSettings.shared.lyricsFontSize.titleFontSize - 4 : AppSettings.shared.lyricsFontSize.titleFontSize
        let inactiveSize = compact ? AppSettings.shared.lyricsFontSize.inactiveFontSize - 3 : AppSettings.shared.lyricsFontSize.inactiveFontSize

        VStack(alignment: .leading, spacing: 0) {
            if player.currentLyrics.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No synchronized lyrics available for this track.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: compact ? 16 : 22) {
                            ForEach(Array(player.currentLyrics.enumerated()), id: \.offset) { index, line in
                                LyricLineRow(
                                    line: line,
                                    isCurrent: index == player.currentLyricIndex,
                                    activeSize: activeSize,
                                    inactiveSize: inactiveSize,
                                    reduceMotion: AppSettings.shared.reduceMotion,
                                    onSelect: { player.seek(to: line.startTimeSeconds) }
                                )
                                .id(index)
                            }
                        }
                        .padding(.vertical, compact ? 28 : 42)
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.08),
                                .init(color: .black, location: 0.90),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .onChange(of: player.currentLyricIndex) { _, newIndex in
                        guard AppSettings.shared.autoScrollLyrics else { return }
                        if AppSettings.shared.reduceMotion {
                            proxy.scrollTo(newIndex, anchor: .center)
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 0.75))
        )
    }

    private var queueView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if player.queue.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("Queue is empty")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Autoplay will automatically queue similar music.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(player.queue.enumerated()), id: \.element.id) { idx, song in
                            NowPlayingQueueRow(
                                song: song,
                                onSelect: { player.play(song: song) },
                                onRemove: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        if let itemIdx = player.queue.firstIndex(where: { $0.id == song.id }) {
                                            player.queue.remove(at: itemIdx)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 0.75))
        )
    }
}

private struct AppleMusicTabSelector: View {
    @Binding var activeTab: NowPlayingView.NowPlayingTab
    let queueCount: Int
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 3) {
            tabButton(.lyrics, title: "Lyrics", icon: "quote.bubble.fill", badge: nil)
            tabButton(.queue, title: "Playing Next", icon: "list.bullet", badge: queueCount > 0 ? "\(queueCount)" : nil)
        }
        .padding(3)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.75)
                )
        )
    }

    @ViewBuilder
    private func tabButton(_ tab: NowPlayingView.NowPlayingTab, title: String, icon: String, badge: String?) -> some View {
        let isSelected = activeTab == tab
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                activeTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))

                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
                        )
                }
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.65))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.24))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.75)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
                        .matchedGeometryEffect(id: "activeTabBackground", in: tabNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct NowPlayingQueueRow: View {
    let song: Song
    let onSelect: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            let thumbUrl: String = {
                if !song.thumbnailUrl.isEmpty { return song.thumbnailUrl }
                return "https://i.ytimg.com/vi/\(song.id)/hqdefault.jpg"
            }()

            CachedAsyncImage(url: URL(string: thumbUrl.thumbnailSized(for: 100))) { phase in
                if let img = phase.image {
                    img.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.white.opacity(0.1)
                }
            }
            .frame(width: 42, height: 42)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                let artistName = (!song.artist.isEmpty && song.artist != "Unknown Artist") ? song.artist : (song.album.isEmpty ? "Artist" : song.album)
                Text(artistName)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer()

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Remove from Queue")
            } else {
                Text(song.duration.formattedPlaybackTime)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onSelect() }
    }
}

struct AmbientBlurBackgroundView: View, Equatable {
    let thumbUrl: String

    nonisolated static func == (lhs: AmbientBlurBackgroundView, rhs: AmbientBlurBackgroundView) -> Bool {
        lhs.thumbUrl == rhs.thumbUrl
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.07, blue: 0.10)

            if !thumbUrl.isEmpty {
                if AppSettings.shared.reduceMotion {
                    LinearGradient(
                        colors: [Color.pink.opacity(0.18), Color.purple.opacity(0.12), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    CachedAsyncImage(url: URL(string: thumbUrl.thumbnailSized(for: 160))) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .saturation(1.7)
                                .contrast(1.15)
                                .blur(radius: 70)
                                .scaleEffect(1.3)
                                .opacity(0.75)
                        }
                    }

                    CachedAsyncImage(url: URL(string: thumbUrl.thumbnailSized(for: 80))) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .saturation(1.9)
                                .contrast(1.1)
                                .blur(radius: 90)
                                .scaleEffect(1.6)
                                .rotationEffect(.degrees(180))
                                .opacity(0.35)
                                .blendMode(.screen)
                        }
                    }
                }
            } else {
                RadialGradient(
                    colors: [
                        Color(red: 0.20, green: 0.15, blue: 0.28),
                        Color(red: 0.07, green: 0.06, blue: 0.10)
                    ],
                    center: .center,
                    startRadius: 60,
                    endRadius: 650
                )
            }

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.75)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.40),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.50)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct LyricLineRow: View {
    let line: LyricLine
    let isCurrent: Bool
    let activeSize: CGFloat
    let inactiveSize: CGFloat
    let reduceMotion: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Text(line.text)
                .font(.system(
                    size: isCurrent ? activeSize : inactiveSize,
                    weight: isCurrent ? .bold : .medium
                ))
                .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.38))
                .shadow(
                    color: isCurrent && !reduceMotion ? Color.white.opacity(0.35) : Color.clear,
                    radius: 8,
                    x: 0,
                    y: 0
                )
                .scaleEffect(isCurrent ? 1.02 : 1.0, anchor: .leading)
                .animation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.75), value: isCurrent)
                .multilineTextAlignment(.leading)
        }
        .buttonStyle(.plain)
    }
}

private struct NowPlayingScrubberView: View {
    @ObservedObject var progress = PlaybackProgress.shared
    @ObservedObject var player: AudioPlayerService
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0
    @State private var isHoveringScrubber = false

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { barGeo in
                let w = barGeo.size.width
                let cur = isDraggingSlider ? sliderValue : progress.currentTime
                let prog = player.duration > 0 ? min(max(cur / player.duration, 0), 1) : 0
                let barH: CGFloat = isHoveringScrubber || isDraggingSlider ? 6 : 4

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.20)).frame(height: barH)
                    Capsule().fill(Color.white).frame(width: max(0, w * prog), height: barH)

                    Circle()
                        .fill(Color.white)
                        .frame(width: isHoveringScrubber || isDraggingSlider ? 13 : 10,
                               height: isHoveringScrubber || isDraggingSlider ? 13 : 10)
                        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                        .offset(x: max(0, min(w - 12, w * prog - 6)))
                }
                .frame(height: 18)
                .contentShape(Rectangle())
                .onHover { isHoveringScrubber = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            isDraggingSlider = true
                            sliderValue = max(0, min(1, g.location.x / w)) * max(player.duration, 1)
                        }
                        .onEnded { _ in
                            isDraggingSlider = false
                            player.seek(to: sliderValue)
                        }
                )
            }
            .frame(height: 18)

            HStack {
                let cur = isDraggingSlider ? sliderValue : progress.currentTime
                Text(cur.formattedPlaybackTime)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text("-" + max(0, player.duration - cur).formattedPlaybackTime)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }
}
