import WidgetKit
import SwiftUI
import AppIntents

struct WidgetTogglePlayPauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Play/Pause"
    static let description = IntentDescription("Toggles music playback")

    func perform() async throws -> some IntentResult {
        DistributedNotificationCenter.default().postNotificationName(
            WidgetBridge.toggleNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        // Optimistically toggle isPlaying in snapshot for instant UI feedback
        var current = WidgetBridge.readState()
        current.isPlaying.toggle()
        WidgetBridge.writeState(current)
        WidgetCenter.shared.reloadTimelines(ofKind: "MusicWidget")
        return .result()
    }
}

struct WidgetNextTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Track"
    static let description = IntentDescription("Skips to the next track")

    func perform() async throws -> some IntentResult {
        DistributedNotificationCenter.default().postNotificationName(
            WidgetBridge.nextNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "MusicWidget")
        return .result()
    }
}

struct WidgetPreviousTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Previous Track"
    static let description = IntentDescription("Plays previous track or seeks to start")

    func perform() async throws -> some IntentResult {
        DistributedNotificationCenter.default().postNotificationName(
            WidgetBridge.previousNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "MusicWidget")
        return .result()
    }
}

struct MusicEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPlaybackSnapshot
    let artwork: NSImage?
}

struct MusicTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MusicEntry {
        MusicEntry(
            date: Date(),
            snapshot: WidgetPlaybackSnapshot(title: "Music", artist: "Select a song to play", isPlaying: false),
            artwork: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> Void) {
        let state = WidgetBridge.readState()
        let art = (try? Data(contentsOf: WidgetBridge.artworkFileURL)).flatMap { NSImage(data: $0) }
        completion(MusicEntry(date: Date(), snapshot: state, artwork: art))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicEntry>) -> Void) {
        let state = WidgetBridge.readState()
        let art = (try? Data(contentsOf: WidgetBridge.artworkFileURL)).flatMap { NSImage(data: $0) }
        let entry = MusicEntry(date: Date(), snapshot: state, artwork: art)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct MusicWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: MusicEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct MediumWidgetView: View {
    let entry: MusicEntry

    var body: some View {
        HStack(spacing: 16) {
            // Artwork
            if let artwork = entry.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }

            // Song Info & Controls
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.snapshot.title.isEmpty ? "Not Playing" : entry.snapshot.title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)

                    Text(entry.snapshot.artist.isEmpty ? "Open Music to start" : entry.snapshot.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if !entry.snapshot.album.isEmpty {
                        Text(entry.snapshot.album)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Interactive Control Buttons
                HStack(spacing: 18) {
                    Button(intent: WidgetPreviousTrackIntent()) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)

                    Button(intent: WidgetTogglePlayPauseIntent()) {
                        Image(systemName: entry.snapshot.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.accentColor))
                            .shadow(color: Color.accentColor.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    Button(intent: WidgetNextTrackIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct SmallWidgetView: View {
    let entry: MusicEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let artwork = entry.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color.pink.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "music.note")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                Spacer()

                Button(intent: WidgetTogglePlayPauseIntent()) {
                    Image(systemName: entry.snapshot.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.title.isEmpty ? "Not Playing" : entry.snapshot.title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)

                Text(entry.snapshot.artist.isEmpty ? "Music" : entry.snapshot.artist)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color.clear
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
        .configurationDisplayName("Music")
        .description("Control music playback and see what's playing.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
