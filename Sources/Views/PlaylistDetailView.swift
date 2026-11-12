import SwiftUI

public struct PlaylistDetailView: View {
    let playlistId: String
    let initialTitle: String
    @State private var playlist: Playlist?
    @State private var isLoading = true
    private let player = AudioPlayerService.shared
    @ObservedObject var downloadManager = DownloadManager.shared

    public init(playlistId: String, initialTitle: String = "Playlist") {
        self.playlistId = playlistId
        self.initialTitle = initialTitle
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // MARK: - Playlist Header
                HStack(alignment: .bottom, spacing: 28) {
                    // Big Artwork
                    CachedAsyncImage(url: URL(string: (playlist?.thumbnailUrl ?? "").thumbnailSized(for: 440))) { phase in
                        if let img = phase.image {
                            img.resizable()
                               .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.18))
                        }
                    }
                    .frame(width: 220, height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 7)

                    // Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PLAYLIST")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        let resolvedTitle = (playlist?.title.isEmpty == false && playlist?.title != "Playlist") ? playlist!.title : initialTitle
                        Text(resolvedTitle)
                            .font(.system(size: 32, weight: .bold))
                            .lineLimit(2)

                        Text(playlist?.author ?? "YouTube Music")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.pink)

                        if let desc = playlist?.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        if let songs = playlist?.songs, !songs.isEmpty {
                            Text("\(songs.count) Songs, \(formattedTotalDuration(songs))")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer().frame(height: 6)

                        // Action Buttons
                        HStack(spacing: 12) {
                            Button {
                                if let p = playlist {
                                    player.recordPlaylistPlayed(playlist: p)
                                } else {
                                    player.recordPlaylistPlayed(id: playlistId, title: initialTitle)
                                }
                                if let songs = playlist?.songs, let first = songs.first {
                                    player.play(song: first, newQueue: songs)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text("Play")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.pink))
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let p = playlist {
                                    player.recordPlaylistPlayed(playlist: p)
                                } else {
                                    player.recordPlaylistPlayed(id: playlistId, title: initialTitle)
                                }
                                if let songs = playlist?.songs, let random = songs.randomElement() {
                                    player.isShuffle = true
                                    player.play(song: random, newQueue: songs.shuffled())
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "shuffle")
                                    Text("Shuffle")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)

                            Button {
                                if let songs = playlist?.songs {
                                    for song in songs {
                                        downloadManager.downloadSong(song)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 15))
                                    .padding(8)
                                    .background(Circle().fill(Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .help("Download Playlist")
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)

                Divider()
                    .padding(.horizontal, 32)

                // Tracklist Table
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading playlist tracks...")
                            .padding(.vertical, 40)
                        Spacer()
                    }
                } else if let songs = playlist?.songs, !songs.isEmpty {
                    TrackListView(songs: songs)
                        .padding(.horizontal, 16)
                } else {
                    Text("No tracks in this playlist.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 110) // Inset for floating pill player
        }
        .scrollIndicators(.hidden)
        .task {
            await loadPlaylist()
        }
    }

    private func loadPlaylist() async {
        isLoading = true
        if var full = try? await InnerTubeService.shared.fetchPlaylist(id: playlistId) {
            if full.title.isEmpty || full.title == "Playlist" {
                full.title = initialTitle
            }
            self.playlist = full
            player.recordPlaylistPlayed(playlist: full)
        } else {
            player.recordPlaylistPlayed(id: playlistId, title: initialTitle)
        }
        isLoading = false
    }

    private func formattedTotalDuration(_ songs: [Song]) -> String {
        let total = songs.reduce(0.0) { $0 + $1.duration }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours) Hours, \(minutes) Minutes"
        }
        return "\(minutes) Minutes"
    }
}
