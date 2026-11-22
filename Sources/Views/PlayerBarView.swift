import SwiftUI
import AppKit

public struct PlayerBarView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @Binding var showNowPlaying: Bool
    @State private var showLyricsPopover = false
    @State private var showQueuePopover = false
    @State private var isHoveringPlay = false

    public init(showNowPlaying: Binding<Bool> = .constant(false)) {
        self._showNowPlaying = showNowPlaying
    }

    public var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Button {
                    player.isShuffle.toggle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(player.isShuffle ? Color.pink : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Shuffle")

                Button {
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
                .help("Previous")

                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(isHoveringPlay ? Color.primary.opacity(0.18) : Color.primary.opacity(0.10))
                            .frame(width: 32, height: 32)

                        if player.isLoading {
                            ProgressView()
                                .scaleEffect(0.55)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .offset(x: player.isPlaying ? 0 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .onHover { isHoveringPlay = $0 }
                .help(player.isPlaying ? "Pause" : "Play")

                Button {
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
                .help("Next")

                Button {
                    switch player.repeatMode {
                    case .off: player.repeatMode = .all
                    case .all: player.repeatMode = .one
                    case .one: player.repeatMode = .off
                    }
                } label: {
                    Image(systemName: player.repeatMode == .one ? "repeat.1" : "repeat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(player.repeatMode != .off ? Color.pink : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Repeat")
            }
            .frame(width: 145)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                        showNowPlaying = true
                    }
                } label: {
                    let thumbUrl: String = {
                        guard let song = player.currentSong else { return "" }
                        if !song.thumbnailUrl.isEmpty { return song.thumbnailUrl }
                        return "https://i.ytimg.com/vi/\(song.id)/hqdefault.jpg"
                    }()

                    if !thumbUrl.isEmpty {
                        CachedAsyncImage(url: URL(string: thumbUrl.thumbnailSized(for: 100)), targetDimension: 100) { phase in
                            if let img = phase.image {
                                img.resizable()
                                   .scaledToFill()
                                   .frame(width: 40, height: 40)
                                   .clipped()
                            } else {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.secondary.opacity(0.2))
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Image(systemName: "music.note")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .buttonStyle(.plain)
                .help("Open Now Playing")

                VStack(alignment: .leading, spacing: 3) {
                    // Title, Artist and Like Heart
                    HStack(spacing: 6) {
                        if let song = player.currentSong {
                            Button {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                                    showNowPlaying = true
                                }
                            } label: {
                                Text(song.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.primary)
                            }
                            .buttonStyle(.plain)
                            .help("Open Now Playing")

                            Text("•")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)

                            let resolvedArtist: String = {
                                if !song.artist.isEmpty && song.artist != "Unknown Artist" { return song.artist }
                                if !song.album.isEmpty { return song.album }
                                return "Unknown Artist"
                            }()

                            Text(resolvedArtist)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            if player.isLossless {
                                HStack(spacing: 3) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 7, weight: .bold))
                                    Text(player.audioQualityTitle.contains("Saavn") ? "Saavn 320k" : "Lossless")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .foregroundStyle(Color.pink)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(Color.pink.opacity(0.14))
                                )
                                .help(player.audioQualityTitle)
                            }

                            Spacer(minLength: 4)

                            Button {
                                Task {
                                    try? await InnerTubeService.shared.toggleLike(videoId: song.id, isLiked: !song.isLiked)
                                }
                            } label: {
                                Image(systemName: song.isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 11))
                                    .foregroundStyle(song.isLiked ? Color.pink : Color.secondary.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help(song.isLiked ? "Unlike" : "Like")
                        } else {
                            Text("Not Playing")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    PlayerBarProgressRow(player: player)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)

                    Slider(value: $player.volume, in: 0...1)
                        .controlSize(.mini)
                        .frame(width: 65)
                        .tint(Color.primary.opacity(0.7))

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 14)
                    .padding(.horizontal, 2)

                Button {
                    showLyricsPopover.toggle()
                } label: {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(showLyricsPopover ? Color.pink : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Lyrics")
                .popover(isPresented: $showLyricsPopover, arrowEdge: .top) {
                    LyricsPopoverView()
                        .frame(width: 360, height: 460)
                }

                Button {
                    showQueuePopover.toggle()
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(showQueuePopover ? Color.pink : Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Playing Next")
                .popover(isPresented: $showQueuePopover, arrowEdge: .top) {
                    QueuePopoverView()
                        .frame(width: 340, height: 440)
                }

                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                        showNowPlaying.toggle()
                    }
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Open Full Now Playing")
            }
            .frame(width: 200)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(height: 64)
        .frame(maxWidth: 800)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .withinWindow)
                    .clipShape(Capsule(style: .continuous))

                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.04))

                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.40),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            }
            .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }
}

struct LyricsPopoverView: View {
    @ObservedObject var player = AudioPlayerService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Lyrics")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                if let song = player.currentSong {
                    Text(song.title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    if player.currentLyrics.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 32))
                            Text("No synced lyrics available")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                    } else {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(player.currentLyrics.enumerated()), id: \.offset) { index, line in
                                Text(line.text)
                                    .font(.system(
                                        size: index == player.currentLyricIndex ? 18 : 15,
                                        weight: index == player.currentLyricIndex ? .bold : .medium
                                    ))
                                    .foregroundStyle(
                                        index == player.currentLyricIndex ? Color.pink : Color.secondary.opacity(0.6)
                                    )
                                    .scaleEffect(index == player.currentLyricIndex ? 1.02 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: player.currentLyricIndex)
                                    .id(index)
                                    .onTapGesture {
                                        player.seek(to: line.startTimeSeconds)
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                }
                .onChange(of: player.currentLyricIndex) { _, newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
    }
}

struct QueuePopoverView: View {
    @ObservedObject var player = AudioPlayerService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Playing Next")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                if !player.queue.isEmpty {
                    Text("\(player.queue.count) tracks")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    if let current = player.currentSong {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOW PLAYING")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)

                            QueueTrackRow(song: current, isPlayingNow: true) {
                            }
                        }
                        .padding(.bottom, 10)
                    }

                    if player.queue.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 28))
                            Text("Queue is empty")
                                .font(.system(size: 12))
                            Text("Tracks will autoplay via algorithmic radio")
                                .font(.system(size: 11))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.vertical, 40)
                        .padding(.horizontal, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("UP NEXT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)

                            ForEach(player.queue) { song in
                                QueueTrackRow(song: song, isPlayingNow: false) {
                                    player.play(song: song)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .background(.ultraThinMaterial)
    }
}

struct QueueTrackRow: View {
    let song: Song
    let isPlayingNow: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                if !song.thumbnailUrl.isEmpty {
                    CachedAsyncImage(url: URL(string: song.thumbnailSized(for: 100)), targetDimension: 80) { phase in
                        if let img = phase.image {
                            img.resizable()
                               .scaledToFill()
                               .frame(width: 32, height: 32)
                               .clipped()
                        } else {
                            RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.2))
                        }
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .font(.system(size: 12, weight: isPlayingNow ? .bold : .medium))
                        .foregroundStyle(isPlayingNow ? Color.pink : Color.primary)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isPlayingNow {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.pink)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPlayingNow ? Color.pink.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 8)
    }
}

private struct PlayerBarProgressRow: View {
    @ObservedObject var progress = PlaybackProgress.shared
    @ObservedObject var player: AudioPlayerService
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    var body: some View {
        HStack(spacing: 6) {
            let cur = isDraggingSlider ? sliderValue : progress.currentTime
            Text(cur.formattedPlaybackTime)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)

            Slider(
                value: Binding(
                    get: { isDraggingSlider ? sliderValue : progress.currentTime },
                    set: { sliderValue = $0 }
                ),
                in: 0...max(player.duration, 1.0)
            ) { editing in
                isDraggingSlider = editing
                if !editing {
                    player.seek(to: sliderValue)
                }
            }
            .controlSize(.mini)
            .tint(Color.pink)

            Button {
                AppSettings.shared.showRemainingTime.toggle()
            } label: {
                let remaining = max(0, player.duration - cur)
                let text = AppSettings.shared.showRemainingTime ? ("-" + remaining.formattedPlaybackTime) : player.duration.formattedPlaybackTime
                Text(text)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .leading)
            }
            .buttonStyle(.plain)
            .help(AppSettings.shared.showRemainingTime ? "Showing remaining time" : "Showing total duration")
        }
    }
}
