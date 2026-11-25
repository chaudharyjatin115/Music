import WidgetKit
import SwiftUI
import AppIntents
import AppKit

// MARK: - App Intents

struct WidgetTogglePlayPauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Play/Pause"
    static let description = IntentDescription("Toggles music playback")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let isAppRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.music.app").isEmpty
        WidgetBridge.postCommand("toggle")
        if isAppRunning {
            var current = WidgetBridge.readState()
            current.isPlaying.toggle()
            current.timestamp = Date()
            WidgetBridge.writeState(current)
            WidgetCenter.shared.reloadTimelines(ofKind: "MusicWidget")
        } else {
            try? await Task.sleep(nanoseconds: 150_000_000)
            WidgetCenter.shared.reloadTimelines(ofKind: "MusicWidget")
        }
        return .result()
    }
}

struct WidgetNextTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Track"
    static let description = IntentDescription("Skips to the next track")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.postCommand("next")
        try? await Task.sleep(nanoseconds: 150_000_000)
        WidgetCenter.shared.reloadTimelines(ofKind: "MusicWidget")
        return .result()
    }
}

struct WidgetPreviousTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Previous Track"
    static let description = IntentDescription("Plays previous track or seeks to start")
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.postCommand("previous")
        try? await Task.sleep(nanoseconds: 150_000_000)
        WidgetCenter.shared.reloadTimelines(ofKind: "MusicWidget")
        return .result()
    }
}

// MARK: - Timeline

struct MusicEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPlaybackSnapshot
    let artwork: NSImage?
}

struct MusicTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MusicEntry {
        let state = WidgetBridge.readState()
        let art = WidgetBridge.readArtworkImage()
        let snap: WidgetPlaybackSnapshot = state.title.isEmpty
            ? WidgetPlaybackSnapshot(title: "Not Playing", artist: "Open Music to start")
            : state
        return MusicEntry(date: Date(), snapshot: snap, artwork: art)
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> Void) {
        completion(MusicEntry(date: Date(), snapshot: WidgetBridge.readState(), artwork: WidgetBridge.readArtworkImage()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicEntry>) -> Void) {
        let entry = MusicEntry(date: Date(), snapshot: WidgetBridge.readState(), artwork: WidgetBridge.readArtworkImage())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

// MARK: - Shared Components

struct WidgetPaperBackground: View {
    let isDark: Bool

    var body: some View {
        let gradientColors = isDark
            ? [Color(red: 0.16, green: 0.16, blue: 0.18), Color(red: 0.11, green: 0.11, blue: 0.13)]
            : [Color(red: 0.98, green: 0.98, blue: 0.99), Color(red: 0.935, green: 0.935, blue: 0.95)]
        let strokeColor = isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)

        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(strokeColor, lineWidth: 0.75))
    }
}

private struct WidgetGroove {
    let ratio: CGFloat
    let color: Color
    let width: CGFloat
}

private let widgetGrooves: [WidgetGroove] = [
    WidgetGroove(ratio: 0.93, color: .white.opacity(0.05), width: 0.6),
    WidgetGroove(ratio: 0.88, color: .white.opacity(0.04), width: 0.5),
    WidgetGroove(ratio: 0.84, color: .white.opacity(0.06), width: 0.5),
    WidgetGroove(ratio: 0.80, color: .white.opacity(0.03), width: 0.5),
    WidgetGroove(ratio: 0.76, color: .black.opacity(0.55), width: 1.0),
    WidgetGroove(ratio: 0.72, color: .white.opacity(0.05), width: 0.5),
    WidgetGroove(ratio: 0.67, color: .white.opacity(0.03), width: 0.5),
    WidgetGroove(ratio: 0.62, color: .white.opacity(0.05), width: 0.5),
    WidgetGroove(ratio: 0.57, color: .black.opacity(0.55), width: 1.0),
    WidgetGroove(ratio: 0.52, color: .white.opacity(0.05), width: 0.5),
    WidgetGroove(ratio: 0.46, color: .white.opacity(0.03), width: 0.5),
    WidgetGroove(ratio: 0.42, color: .white.opacity(0.05), width: 0.6),
]

struct WidgetVinylDiscView: View {
    let diameter: CGFloat
    let artwork: NSImage?
    let isDark: Bool

    var body: some View {
        let labelDiameter = diameter * 0.36
        let spindleRingDiameter = labelDiameter * 0.30
        let spindleHoleDiameter = spindleRingDiameter * 0.42

        ZStack {
            Circle()
                .fill(Color.black.opacity(isDark ? 0.5 : 0.35))
                .frame(width: diameter, height: diameter)
                .offset(y: 3)
                .blur(radius: 5)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.08, green: 0.08, blue: 0.09),
                                Color(red: 0.03, green: 0.03, blue: 0.04)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter / 2
                        )
                    )
                    .frame(width: diameter, height: diameter)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.22),
                                        Color.white.opacity(0.04),
                                        Color.black.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.0
                            )
                    )

                ForEach(widgetGrooves.indices, id: \.self) { index in
                    let groove = widgetGrooves[index]
                    Circle()
                        .strokeBorder(groove.color, lineWidth: groove.width)
                        .frame(width: diameter * groove.ratio, height: diameter * groove.ratio)
                }

                ZStack {
                    if let artwork = artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: labelDiameter, height: labelDiameter)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.16, green: 0.32, blue: 0.65),
                                        Color(red: 0.08, green: 0.16, blue: 0.38)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: labelDiameter / 2
                                )
                            )
                            .frame(width: labelDiameter, height: labelDiameter)

                        VStack(spacing: 1) {
                            Text("HI-FI")
                                .font(.system(size: max(4, labelDiameter * 0.11), weight: .black))
                                .foregroundColor(.white.opacity(0.9))
                            Text("33 ⅓")
                                .font(.system(size: max(3.5, labelDiameter * 0.09), weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Circle()
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
                        .frame(width: labelDiameter, height: labelDiameter)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.92, green: 0.92, blue: 0.95),
                                    Color(red: 0.62, green: 0.62, blue: 0.65),
                                    Color(red: 0.96, green: 0.96, blue: 0.98),
                                    Color(red: 0.55, green: 0.55, blue: 0.58)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: spindleRingDiameter, height: spindleRingDiameter)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 0.5))
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 0.5)

                    Circle()
                        .fill(Color(red: 0.04, green: 0.04, blue: 0.05))
                        .frame(width: spindleHoleDiameter, height: spindleHoleDiameter)
                }
            }

            // Specular highlight masked to the grooved surface outside the paper label
            Circle()
                .fill(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.15), location: 0.12),
                            .init(color: .white.opacity(0.04), location: 0.18),
                            .init(color: .clear, location: 0.28),
                            .init(color: .clear, location: 0.50),
                            .init(color: .white.opacity(0.15), location: 0.62),
                            .init(color: .white.opacity(0.04), location: 0.68),
                            .init(color: .clear, location: 0.78),
                            .init(color: .clear, location: 1.0)
                        ]),
                        center: .center
                    )
                )
                .frame(width: diameter, height: diameter)
                .mask(
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: diameter * 0.96, height: diameter * 0.96)
                        Circle()
                            .fill(Color.black)
                            .frame(width: labelDiameter, height: labelDiameter)
                    }
                    .compositingGroup()
                    .luminanceToAlpha()
                )
                .blendMode(.screen)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct TonearmSWand: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let startX = rect.midX
        path.move(to: CGPoint(x: startX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: startX - rect.width * 0.16, y: rect.maxY),
            control1: CGPoint(x: startX + rect.width * 0.18, y: rect.minY + rect.height * 0.35),
            control2: CGPoint(x: startX - rect.width * 0.08, y: rect.minY + rect.height * 0.70)
        )
        return path
    }
}

struct TurntableTonearmView: View {
    let armLength: CGFloat
    let isPlaying: Bool
    let isDark: Bool

    var body: some View {
        let totalW = armLength * 0.44
        let totalH = armLength * 1.15
        let pivotX = totalW * 0.58
        let pivotY = armLength * 0.24
        let pivotSize = max(11.0, armLength * 0.16)
        let armAngle: Double = isPlaying ? 22.0 : 2.0

        ZStack(alignment: .topLeading) {
            // Base plate and parked arm rest
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.88, blue: 0.92),
                            Color(red: 0.60, green: 0.60, blue: 0.64),
                            Color(red: 0.45, green: 0.45, blue: 0.48)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: pivotSize * 1.45, height: pivotSize * 1.45)
                .overlay(
                    Circle().strokeBorder(isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.25), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                .position(x: pivotX, y: pivotY)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .strokeBorder(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.6), lineWidth: 1.0)
                    .frame(width: max(4.0, armLength * 0.05), height: max(3.0, armLength * 0.035))
                Rectangle()
                    .fill(LinearGradient(colors: [Color.gray, Color.black.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(1.6, armLength * 0.02), height: max(6.0, armLength * 0.08))
            }
            .position(x: pivotX + armLength * 0.03, y: pivotY + armLength * 0.42)

            // Rotating tonearm assembly
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.94, green: 0.94, blue: 0.96),
                                Color(red: 0.65, green: 0.65, blue: 0.70),
                                Color(red: 0.45, green: 0.45, blue: 0.50)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(2.2, armLength * 0.03), height: armLength * 0.20)
                    .position(x: pivotX, y: pivotY - armLength * 0.10)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                        .frame(width: max(2.0, armLength * 0.03), height: max(7.0, armLength * 0.11))
                        .overlay(
                            Rectangle().fill(Color.white.opacity(0.4)).frame(width: 0.75, height: max(5.0, armLength * 0.08)),
                            alignment: .center
                        )
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.90, green: 0.90, blue: 0.94),
                                    Color(red: 0.62, green: 0.62, blue: 0.66),
                                    Color(red: 0.42, green: 0.42, blue: 0.46)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: max(6.5, armLength * 0.11), height: max(8.5, armLength * 0.13))
                        .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 1, y: 1)
                }
                .position(x: pivotX, y: pivotY - armLength * 0.11)

                TonearmSWand()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.96, blue: 0.98),
                                Color(red: 0.75, green: 0.75, blue: 0.78),
                                Color(red: 0.48, green: 0.48, blue: 0.52)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: max(2.0, armLength * 0.026), lineCap: .round)
                    )
                    .frame(width: armLength * 0.22, height: armLength * 0.78)
                    .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 1, y: 1)
                    .position(x: pivotX - armLength * 0.015, y: pivotY + armLength * 0.39)

                let tipX = pivotX - armLength * 0.05
                let tipY = pivotY + armLength * 0.79
                ZStack {
                    RoundedRectangle(cornerRadius: 1.2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.25, blue: 0.28),
                                    Color(red: 0.12, green: 0.12, blue: 0.14)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: max(5.0, armLength * 0.065), height: max(11.5, armLength * 0.15))
                        .overlay(
                            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 0.8, height: max(9.0, armLength * 0.12)),
                            alignment: .leading
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 1.5, x: 1, y: 1)

                    Path { p in
                        p.move(to: CGPoint(x: max(2.5, armLength * 0.032), y: 0))
                        p.addQuadCurve(
                            to: CGPoint(x: max(6.0, armLength * 0.08), y: -max(3.0, armLength * 0.04)),
                            control: CGPoint(x: max(5.5, armLength * 0.075), y: 0)
                        )
                    }
                    .stroke(Color(red: 0.85, green: 0.85, blue: 0.88), lineWidth: max(0.8, armLength * 0.012))

                    Circle()
                        .fill(Color(red: 0.95, green: 0.22, blue: 0.22))
                        .frame(width: max(2.2, armLength * 0.026), height: max(2.2, armLength * 0.026))
                        .offset(x: -max(1.0, armLength * 0.012), y: max(6.0, armLength * 0.075))
                }
                .rotationEffect(.degrees(-22))
                .position(x: tipX, y: tipY)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.92, green: 0.92, blue: 0.95),
                                    Color(red: 0.65, green: 0.65, blue: 0.70),
                                    Color(red: 0.96, green: 0.96, blue: 0.98),
                                    Color(red: 0.50, green: 0.50, blue: 0.55)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: pivotSize, height: pivotSize)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 0.6))
                        .shadow(color: Color.black.opacity(0.25), radius: 1.5, x: 0, y: 1)

                    Circle()
                        .fill(Color(red: 0.26, green: 0.26, blue: 0.30))
                        .frame(width: pivotSize * 0.4, height: pivotSize * 0.4)
                }
                .position(x: pivotX, y: pivotY)
            }
            .frame(width: totalW, height: totalH)
            .rotationEffect(.degrees(armAngle), anchor: UnitPoint(x: pivotX / totalW, y: pivotY / totalH))
            .animation(.spring(response: 0.58, dampingFraction: 0.76), value: isPlaying)
        }
        .frame(width: totalW, height: totalH)
    }
}

struct WidgetTactileSlider: View {
    let value: Float
    let isDark: Bool
    var height: CGFloat = 42
    var width: CGFloat = 14

    var body: some View {
        let thumbHeight = width * 1.15
        let trackHeight = max(8, height - thumbHeight)
        let clamped = max(0, min(1, value))

        ZStack(alignment: .bottom) {
            Capsule(style: .continuous)
                .fill(isDark ? Color(red: 0.08, green: 0.08, blue: 0.10) : Color(red: 0.18, green: 0.18, blue: 0.20))
                .frame(width: width, height: height)
                .overlay(Capsule(style: .continuous).strokeBorder(Color.black.opacity(0.4), lineWidth: 0.8))

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.98, blue: 1.0),
                            Color(red: 0.91, green: 0.91, blue: 0.93)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width - 2.5, height: thumbHeight)
                .overlay(
                    Capsule()
                        .fill(Color.gray.opacity(0.45))
                        .frame(width: width * 0.45, height: 1.2)
                )
                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                .offset(y: -CGFloat(clamped) * trackHeight)
        }
        .frame(width: width, height: height)
    }
}

struct WidgetPlayPauseButton: View {
    let isPlaying: Bool
    let isDark: Bool
    let size: CGFloat
    let iconSize: CGFloat
    var strokeWidth: CGFloat = 1.0
    var playOffset: CGFloat = 1.0

    var body: some View {
        Button(intent: WidgetTogglePlayPauseIntent()) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isDark ? [
                                Color(red: 0.28, green: 0.28, blue: 0.32),
                                Color(red: 0.18, green: 0.18, blue: 0.22)
                            ] : [
                                Color(red: 0.98, green: 0.98, blue: 1.0),
                                Color(red: 0.90, green: 0.90, blue: 0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle().strokeBorder(
                            isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.9),
                            lineWidth: strokeWidth
                        )
                    )
                    .shadow(
                        color: isDark ? Color.black.opacity(0.4) : Color.black.opacity(0.12),
                        radius: size > 30 ? 3 : 2,
                        x: 0,
                        y: size > 30 ? 1.5 : 1
                    )

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundColor(isDark ? .white : Color(red: 0.15, green: 0.15, blue: 0.18))
                    .offset(x: isPlaying ? 0 : playOffset)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct WidgetTrackButton<IntentType: AppIntent>: View {
    let intent: IntentType
    let systemName: String
    let isDark: Bool
    let size: CGFloat
    let iconSize: CGFloat

    var body: some View {
        Button(intent: intent) {
            ZStack {
                Circle()
                    .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    .frame(width: size, height: size)
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(isDark ? Color.white.opacity(0.85) : Color(red: 0.22, green: 0.22, blue: 0.25))
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private func formatWidgetTime(_ seconds: Double) -> String {
    let total = max(0, Int(seconds))
    return String(format: "%d:%02d", total / 60, total % 60)
}

// MARK: - Widget Size Layouts

struct LargeWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    let entry: MusicEntry

    var body: some View {
        let isDark = (colorScheme == .dark)
        let hasTrack = !entry.snapshot.title.isEmpty
        let title = hasTrack ? entry.snapshot.title : "Not Playing"
        let artist = hasTrack ? entry.snapshot.artist : "Open Music to start"
        let timeString = entry.snapshot.duration > 0
            ? "\(formatWidgetTime(entry.snapshot.currentTime)) / \(formatWidgetTime(entry.snapshot.duration))"
            : ""
        let subtitle = timeString.isEmpty ? artist : "\(artist) • \(timeString)"

        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isDark ? .white : Color(red: 0.11, green: 0.11, blue: 0.13))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDark ? Color.white.opacity(0.6) : Color(red: 0.46, green: 0.46, blue: 0.50))
                        .lineLimit(1)
                }

                Spacer()

                WidgetTactileSlider(value: entry.snapshot.volume, isDark: isDark, height: 44, width: 15)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            ZStack(alignment: .topTrailing) {
                Circle()
                    .strokeBorder(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 4)
                    .background(Circle().fill(isDark ? Color.black.opacity(0.25) : Color.black.opacity(0.04)))
                    .frame(width: 194, height: 194)
                    .offset(x: -14, y: 4)

                WidgetVinylDiscView(diameter: 188, artwork: entry.artwork, isDark: isDark)
                    .offset(x: -14, y: 4)

                TurntableTonearmView(armLength: 106, isPlaying: entry.snapshot.isPlaying, isDark: isDark)
                    .offset(x: 12, y: 10)
            }
            .frame(width: 250, height: 194)

            Spacer()

            HStack(spacing: 18) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(entry.snapshot.isPlaying ? Color.red : Color.gray.opacity(0.5))
                        .frame(width: 5, height: 5)
                    Text("33 ⅓")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isDark ? Color.white.opacity(0.65) : Color(red: 0.45, green: 0.45, blue: 0.50))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))

                Spacer()

                WidgetTrackButton(intent: WidgetPreviousTrackIntent(), systemName: "backward.fill", isDark: isDark, size: 32, iconSize: 13)
                WidgetPlayPauseButton(isPlaying: entry.snapshot.isPlaying, isDark: isDark, size: 38, iconSize: 14)
                WidgetTrackButton(intent: WidgetNextTrackIntent(), systemName: "forward.fill", isDark: isDark, size: 32, iconSize: 13)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .containerBackground(for: .widget) {
            WidgetPaperBackground(isDark: isDark)
        }
    }
}

struct MediumWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    let entry: MusicEntry

    var body: some View {
        let isDark = (colorScheme == .dark)
        let hasTrack = !entry.snapshot.title.isEmpty
        let title = hasTrack ? entry.snapshot.title : "Not Playing"
        let artist = hasTrack ? entry.snapshot.artist : "Open Music"
        let timeString = entry.snapshot.duration > 0 ? formatWidgetTime(entry.snapshot.currentTime) : ""

        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .strokeBorder(isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 3)
                    .background(Circle().fill(isDark ? Color.black.opacity(0.2) : Color.black.opacity(0.03)))
                    .frame(width: 122, height: 122)
                    .offset(x: -8, y: 2)

                WidgetVinylDiscView(diameter: 116, artwork: entry.artwork, isDark: isDark)
                    .offset(x: -8, y: 2)

                TurntableTonearmView(armLength: 70, isPlaying: entry.snapshot.isPlaying, isDark: isDark)
                    .offset(x: 8, y: 8)
            }
            .frame(width: 132, height: 126)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isDark ? .white : Color(red: 0.11, green: 0.11, blue: 0.13))
                            .lineLimit(1)

                        Text(timeString.isEmpty ? artist : "\(artist) • \(timeString)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isDark ? Color.white.opacity(0.6) : Color(red: 0.46, green: 0.46, blue: 0.50))
                            .lineLimit(1)

                        if !entry.snapshot.album.isEmpty {
                            Text(entry.snapshot.album)
                                .font(.system(size: 9.5))
                                .foregroundColor(isDark ? Color.white.opacity(0.4) : Color(red: 0.58, green: 0.58, blue: 0.62))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    WidgetTactileSlider(value: entry.snapshot.volume, isDark: isDark, height: 38, width: 13)
                }

                Spacer()

                HStack(spacing: 12) {
                    WidgetTrackButton(intent: WidgetPreviousTrackIntent(), systemName: "backward.fill", isDark: isDark, size: 28, iconSize: 12)
                    WidgetPlayPauseButton(isPlaying: entry.snapshot.isPlaying, isDark: isDark, size: 34, iconSize: 13)
                    WidgetTrackButton(intent: WidgetNextTrackIntent(), systemName: "forward.fill", isDark: isDark, size: 28, iconSize: 12)

                    Spacer()

                    Text("33 ⅓")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(isDark ? Color.white.opacity(0.6) : Color(red: 0.50, green: 0.50, blue: 0.55))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)))
                }
            }
            .padding(.vertical, 8)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            WidgetPaperBackground(isDark: isDark)
        }
    }
}

struct SmallWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    let entry: MusicEntry

    var body: some View {
        let isDark = (colorScheme == .dark)
        let hasTrack = !entry.snapshot.title.isEmpty
        let title = hasTrack ? entry.snapshot.title : "Not Playing"
        let artist = hasTrack ? entry.snapshot.artist : "Open Music"

        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isDark ? .white : Color(red: 0.11, green: 0.11, blue: 0.13))
                        .lineLimit(1)

                    Text(artist)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isDark ? Color.white.opacity(0.6) : Color(red: 0.46, green: 0.46, blue: 0.50))
                        .lineLimit(1)
                }

                Spacer()

                WidgetPlayPauseButton(
                    isPlaying: entry.snapshot.isPlaying,
                    isDark: isDark,
                    size: 28,
                    iconSize: 10,
                    strokeWidth: 0.8,
                    playOffset: 0.8
                )
            }

            Spacer()

            HStack {
                Spacer()
                ZStack(alignment: .topTrailing) {
                    WidgetVinylDiscView(diameter: 90, artwork: entry.artwork, isDark: isDark)
                        .offset(x: -4, y: 2)

                    TurntableTonearmView(armLength: 54, isPlaying: entry.snapshot.isPlaying, isDark: isDark)
                        .offset(x: 6, y: 6)
                }
                Spacer()
            }

            Spacer()
        }
        .padding(12)
        .containerBackground(for: .widget) {
            WidgetPaperBackground(isDark: isDark)
        }
    }
}

// MARK: - Widget Entrypoint

struct MusicWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: MusicEntry

    var body: some View {
        switch family {
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

@main
struct MusicWidgetBundle: WidgetBundle {
    var body: some Widget {
        MusicWidget()
    }
}

struct MusicWidget: Widget {
    let kind: String = "MusicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicTimelineProvider()) { entry in
            MusicWidgetView(entry: entry)
        }
        .configurationDisplayName("Vinyl Music")
        .description("Analog paper vinyl player showing now playing song with album art and tactile controls.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
