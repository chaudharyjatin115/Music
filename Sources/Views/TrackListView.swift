import SwiftUI

public struct TrackListView: View {
    let songs: [Song]
    let showArtwork: Bool
    let showArtist: Bool
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var hoveredSongId: String?
    @State private var userPlaylists: [Playlist] = []
    @State private var showNewPlaylistAlert = false
    @State private var targetSongForPlaylist: Song? = nil
    @State private var newPlaylistTitle: String = ""

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
                                    CachedAsyncImage(url: URL(string: thumb.thumbnailSized(for: 100)), targetDimension: 80) { phase in
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
                        Button("Start Radio") { player.startRadio(for: song) }

                        Divider()

                        Menu("Add to Playlist") {
                            Button {
                                targetSongForPlaylist = song
                                showNewPlaylistAlert = true
                            } label: {
                                Label("New Playlist...", systemImage: "plus")
                            }

                            if !userPlaylists.isEmpty {
                                Divider()
                                ForEach(userPlaylists) { pl in
                                    Button(pl.title) {
                                        Task {
                                            try? await InnerTubeService.shared.addToPlaylist(playlistId: pl.id, videoId: song.id)
                                        }
                                    }
                                }
                            }
                        }

                        Divider()

                        if !song.artist.isEmpty {
                            Button("Go to Artist") {
                                let artistId = song.artistId ?? ""
                                NotificationCenter.default.post(
                                    name: .openDetailItem,
                                    object: FeedItem.artist(Artist(id: artistId, name: song.artist))
                                )
                            }
                        }

                        if !song.album.isEmpty {
                            Button("Go to Album") {
                                let albumId = song.albumId ?? ""
                                NotificationCenter.default.post(
                                    name: .openDetailItem,
                                    object: FeedItem.album(Album(id: albumId, title: song.album, artist: song.artist))
                                )
                            }
                        }

                        Button("Copy Song Link") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("https://music.youtube.com/watch?v=\(song.id)", forType: .string)
                        }

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
        .task {
            if userPlaylists.isEmpty && AuthManager.shared.isLoggedIn {
                if let list = try? await InnerTubeService.shared.fetchUserPlaylists() {
                    self.userPlaylists = list
                }
            }
        }
        .alert("New Playlist", isPresented: $showNewPlaylistAlert) {
            TextField("Playlist Title", text: $newPlaylistTitle)
            Button("Create") {
                let title = newPlaylistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return }
                let songId = targetSongForPlaylist?.id
                Task {
                    if let plId = try? await InnerTubeService.shared.createPlaylist(title: title, videoIds: songId.map { [$0] } ?? []) {
                        let newPl = Playlist(id: plId, title: title, songCount: songId != nil ? 1 : 0)
                        await MainActor.run {
                            self.userPlaylists.insert(newPl, at: 0)
                            self.newPlaylistTitle = ""
                            self.targetSongForPlaylist = nil
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                targetSongForPlaylist = nil
                newPlaylistTitle = ""
            }
        }
    }
}
