import SwiftUI
import AppKit

public struct VinylWidgetView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var progress = PlaybackProgress.shared
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("vinylWidgetThemeMode") private var themeMode: Int = 0 // 0 = system, 1 = light, 2 = dark
    @AppStorage("vinylWidgetAlwaysOnTop") private var alwaysOnTop = true
    @State private var isHoveringWindow = false
    @State private var isRPM45 = false
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    private var isDark: Bool {
        if themeMode == 1 { return false }
        if themeMode == 2 { return true }
        return systemColorScheme == .dark
    }

    public init() {}

    public var body: some View {
        let currentSong = player.currentSong
        let title = currentSong?.title.isEmpty == false ? currentSong!.title : "Not Playing"
        let artist = currentSong?.artist.isEmpty == false ? currentSong!.artist : "YouTube Music"
        let timeString = progress.currentTime.formattedPlaybackTime
        let durationString = player.duration.formattedPlaybackTime
        let subtitle = "\(artist) / \(timeString)"

        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isDark ? .white : Color(red: 0.11, green: 0.11, blue: 0.13))
                            .lineLimit(1)

                        Text(subtitle)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(isDark ? Color.white.opacity(0.55) : Color(red: 0.46, green: 0.46, blue: 0.50))
                            .lineLimit(1)

                        if let album = currentSong?.album, !album.isEmpty {
                            Text(album)
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundColor(isDark ? Color.white.opacity(0.35) : Color(red: 0.58, green: 0.58, blue: 0.62))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        TactileVerticalSlider(
                            value: $player.volume,
                            isDark: isDark,
                            height: 48,
                            width: 16
                        )
                        .help("Volume: \(Int(player.volume * 100))%")

                        Text("VOL")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(isDark ? Color.white.opacity(0.4) : Color.black.opacity(0.35))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer(minLength: 4)

                ZStack(alignment: .topTrailing) {
                    Circle()
                        .strokeBorder(
                            isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.08),
                            lineWidth: 5
                        )
                        .background(
                            Circle()
                                .fill(isDark ? Color.black.opacity(0.25) : Color.black.opacity(0.04))
                        )
                        .frame(width: 224, height: 224)
                        .overlay(
                            PlatterStrobeRing(diameter: 224, isDark: isDark)
                        )
                        .offset(x: -16, y: 6)

                    DetailedVinylRecordView(
                        diameter: 216,
                        artworkURL: currentSong?.thumbnailUrl.isEmpty == false ? URL(string: currentSong!.thumbnailUrl.thumbnailSized(for: 500)) : nil,
                        rotationAngle: 0
                    )
                    .offset(x: -16, y: 6)

                    DetailedTonearmView(
                        height: 125,
                        isPlaying: player.isPlaying,
                        isDark: isDark
                    )
                    .offset(x: 10, y: 14)
                }
                .frame(width: 280, height: 226)

                Spacer(minLength: 6)

                VStack(spacing: 3) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let cur = isDraggingSlider ? sliderValue : progress.currentTime
                        let ratio = player.duration > 0 ? max(0, min(1, cur / player.duration)) : 0

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                                .frame(height: 3)

                            Capsule()
                                .fill(isDark ? Color.white.opacity(0.85) : Color(red: 0.22, green: 0.22, blue: 0.25))
                                .frame(width: max(3, CGFloat(ratio) * w), height: 3)
                        }
                        .frame(height: 3)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    isDraggingSlider = true
                                    let frac = max(0, min(1, g.location.x / w))
                                    sliderValue = frac * player.duration
                                }
                                .onEnded { _ in
                                    player.seek(to: sliderValue)
                                    isDraggingSlider = false
                                }
                        )
                    }
                    .frame(height: 6)

                    HStack {
                        Text(timeString)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.4))

                        Spacer()

                        Text(durationString)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(isDark ? Color.white.opacity(0.45) : Color.black.opacity(0.4))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 6)

                HStack(spacing: 16) {
                    Button {
                        isRPM45.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(player.isPlaying ? Color.red : Color.gray.opacity(0.5))
                                .frame(width: 5, height: 5)
                            Text(isRPM45 ? "45 RPM" : "33 ⅓ RPM")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(isDark ? Color.white.opacity(0.7) : Color(red: 0.40, green: 0.40, blue: 0.45))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Toggle Turntable Speed")

                    Spacer()

                    TactilePaperControls(
                        isPlaying: player.isPlaying,
                        isDark: isDark,
                        onPrevious: { player.previous() },
                        onTogglePlayPause: { player.togglePlayPause() },
                        onNext: { player.next() }
                    )

                    Spacer()

                    if let song = currentSong {
                        Button {
                            Task {
                                try? await InnerTubeService.shared.toggleLike(videoId: song.id, isLiked: !song.isLiked)
                            }
                        } label: {
                            Image(systemName: song.isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 13))
                                .foregroundColor(song.isLiked ? Color.pink : (isDark ? Color.white.opacity(0.6) : Color.black.opacity(0.4)))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer().frame(width: 28)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .frame(width: 330, height: 388)
            .background(
                PaperWidgetBackground(isDark: isDark, cornerRadius: 28)
            )

            HStack(spacing: 8) {
                Button {
                    themeMode = isDark ? 1 : 2
                } label: {
                    Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isDark ? .white : Color(red: 0.2, green: 0.2, blue: 0.25))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Toggle Paper Theme (Light/Dark)")

                Button {
                    alwaysOnTop.toggle()
                    VinylWidgetWindowController.shared.setAlwaysOnTop(alwaysOnTop)
                } label: {
                    Image(systemName: alwaysOnTop ? "pin.fill" : "pin.slash")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(alwaysOnTop ? Color.pink : (isDark ? .white.opacity(0.6) : Color.black.opacity(0.4)))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help(alwaysOnTop ? "Always on Top: Active" : "Always on Top: Inactive")

                Button {
                    VinylWidgetWindowController.shared.close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(isDark ? .white.opacity(0.7) : Color.black.opacity(0.5))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Close Vinyl Widget")
            }
            .padding(.top, 10)
            .padding(.trailing, 12)
            .opacity(isHoveringWindow ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.18), value: isHoveringWindow)
        }
        .frame(width: 330, height: 388)
        .onHover { isHoveringWindow = $0 }
    }
}

// Strobe Dots on Platter Rim
struct PlatterStrobeRing: View {
    let diameter: CGFloat
    let isDark: Bool

    var body: some View {
        let count = 48
        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let angle = Double(i) * (360.0 / Double(count))
                Rectangle()
                    .fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.10))
                    .frame(width: 1.5, height: 3)
                    .offset(y: -(diameter / 2) + 2)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: diameter, height: diameter)
    }
}
