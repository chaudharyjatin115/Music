import SwiftUI

public struct TrackListView: View {
    let songs: [Song]
    let showArtwork: Bool
    let showArtist: Bool
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var hoveredSongId: String?

    public init(songs: [Song], showArtwork: Bool = true, showArtist: Bool = true) {
        self.songs = songs
        self.showArtwork = showArtwork
        self.showArtist = showArtist
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 12) {
                Text("#")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .center)

                Text("Title")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showArtist {
                    Text("Artist")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 140, alignment: .leading)
                }

                Text("Time")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .trailing)

                Spacer().frame(width: 60)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Song Rows
            LazyVStack(spacing: 2) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    let isPlayingThis = player.currentSong?.id == song.id
                    let isHovered = hoveredSongId == song.id

                    HStack(spacing: 12) {
                        // Play button or track number
                        ZStack {
                            if isPlayingThis && player.isPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.pink)
                            } else if isHovered {
                                Button {
                                    if isPlayingThis {
                                        player.togglePlayPause()
                                    } else {
                                        player.play(song: song, newQueue: songs)
                                    }
                                } label: {
                                    Image(systemName: isPlayingThis && player.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.primary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 28, alignment: .center)

                        // Artwork thumbnail & Title
                        HStack(spacing: 10) {
                            if showArtwork {
                                let thumb = !song.thumbnailUrl.isEmpty ? song.thumbnailUrl : (song.id.starts(with: "eclipse:") ? "" : "https://i.ytimg.com/vi/\(song.id)/hqdefault.jpg")
                                if !thumb.isEmpty {
                                    CachedAsyncImage(url: URL(string: thumb.thumbnailSized(for: 100))) { phase in
                                        if let img = phase.image {
                                            img.resizable()
                                               .scaledToFill()
                                               .frame(width: 32, height: 32)
                                               .clipped()
                                        } else {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.secondary.opacity(0.2))
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }

                            Text(song.title)
                                .font(.system(size: 13, weight: isPlayingThis ? .semibold : .medium))
                                .foregroundStyle(isPlayingThis ? Color.pink : Color.primary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Artist Column (if enabled)
                        if showArtist {
                            let displayArtist = (!song.artist.isEmpty && song.artist != "Unknown Artist") ? song.artist : (song.album.isEmpty ? "" : song.album)
                            Text(displayArtist)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 140, alignment: .leading)
                                .lineLimit(1)
                        }

                        // Duration
                        Text(song.formattedDuration)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .trailing)

                        // Actions: Like, Download, Context Menu
                        HStack(spacing: 8) {
                            // Like Button
                            Button {
                                Task {
                                    try? await InnerTubeService.shared.toggleLike(videoId: song.id, isLiked: !song.isLiked)
                                }
                            } label: {
                                Image(systemName: song.isLiked ? "heart.fill" : "heart")
                                    .font(.system(size: 11))
                                    .foregroundStyle(song.isLiked ? Color.pink : Color.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)

                            // Download Button
                            if downloadManager.isDownloaded(songId: song.id) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.pink)
                                    .help("Downloaded")
                            } else if downloadManager.isDownloading(songId: song.id) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 14, height: 14)
                            } else {
                                Button {
                                    downloadManager.downloadSong(song)
                                } label: {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.secondary.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help("Download for offline listening")
                            }
                        }
                        .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isHovered ? Color.primary.opacity(0.04) : (isPlayingThis ? Color.pink.opacity(0.06) : Color.clear))
                    )
                    .onHover { hovering in
                        hoveredSongId = hovering ? song.id : nil
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: AppSettings.shared.playClickCount) {
                        player.play(song: song, newQueue: songs)
                    }
                    .contextMenu {
                        Button("Play") { player.play(song: song, newQueue: songs) }
                        Button("Play Next") { player.queue.insert(song, at: 0) }
                        Button("Add to Queue") { player.queue.append(song) }
                        Divider()
                        if downloadManager.isDownloaded(songId: song.id) {
                            Button("Remove Download") { downloadManager.deleteDownload(songId: song.id) }
                        } else {
                            Button("Download") { downloadManager.downloadSong(song) }
                        }
                        Button("Like on YouTube Music") {
                            Task { try? await InnerTubeService.shared.toggleLike(videoId: song.id, isLiked: true) }
                        }
                    }
                }
            }
        }
    }
}
