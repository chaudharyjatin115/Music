import SwiftUI

public struct AlbumDetailView: View {
    let albumId: String
    let initialTitle: String
    let initialArtist: String
    let initialThumbnailUrl: String
    @Binding var activeDetailItem: FeedItem?
    @State private var album: Album?
    @State private var isLoading = true
    @State private var isAlbumSaved = false
    private let player = AudioPlayerService.shared
    @ObservedObject var downloadManager = DownloadManager.shared

    public init(
        albumId: String,
        initialTitle: String = "Album",
        initialArtist: String = "Artist",
        initialThumbnailUrl: String = "",
        activeDetailItem: Binding<FeedItem?> = .constant(nil)
    ) {
        self.albumId = albumId
        self.initialTitle = initialTitle
        self.initialArtist = initialArtist
        self.initialThumbnailUrl = initialThumbnailUrl
        self._activeDetailItem = activeDetailItem
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .bottom, spacing: 28) {
                    let displayThumb: String = {
                        if let t = album?.thumbnailUrl, !t.isEmpty { return t }
                        return initialThumbnailUrl
                    }()

                    CachedAsyncImage(url: URL(string: displayThumb.thumbnailSized(for: 440))) { phase in
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ALBUM")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        let resolvedTitle = (album?.title.isEmpty == false && album?.title != "Album") ? album!.title : initialTitle
                        let resolvedArtist = (album?.artist.isEmpty == false && album?.artist != "Artist") ? album!.artist : initialArtist

                        Text(resolvedTitle)
                            .font(.system(size: 32, weight: .bold))
                            .lineLimit(2)

                        Button {
                            if let artistId = album?.artistId, !artistId.isEmpty {
                                activeDetailItem = .artist(Artist(id: artistId, name: resolvedArtist, thumbnailUrl: displayThumb))
                            }
                        } label: {
                            Text(resolvedArtist)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.pink)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 8) {
                            if let year = album?.year {
                                Text(year)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                Text("•")
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 9))
                                Text("Lossless")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1)
                            )
                            .foregroundStyle(.secondary)
                        }

                        Spacer().frame(height: 6)

                        HStack(spacing: 12) {
                            Button {
                                if let songs = album?.songs, let first = songs.first {
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
                                if let songs = album?.songs, let random = songs.randomElement() {
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
                                toggleSaveAlbum()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isAlbumSaved ? "checkmark" : "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(isAlbumSaved ? "Added" : "Add to Library")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(isAlbumSaved ? Color.pink : Color.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(isAlbumSaved ? Color.pink.opacity(0.12) : Color.primary.opacity(0.08))
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(isAlbumSaved ? Color.pink.opacity(0.35) : Color.clear, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .help(isAlbumSaved ? "Remove from Library" : "Save Album to YouTube Music Account")

                            Button {
                                if let songs = album?.songs {
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
                            .help("Download Album")
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 28)

                Divider()
                    .padding(.horizontal, 32)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading album tracks...")
                            .padding(.vertical, 40)
                        Spacer()
                    }
                } else if let songs = album?.songs, !songs.isEmpty {
                    TrackListView(songs: songs, showArtwork: false, showArtist: false)
                        .padding(.horizontal, 16)

                    // Footer notes (Album release info)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(songs.count) Songs, \(formattedTotalDuration(songs))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        if let year = album?.year {
                            Text("℗ \(year) Record Label • Distributed under license")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 16)
                }
            }
            .padding(.bottom, 110) // Inset for floating pill player
        }
        .scrollIndicators(.hidden)
        .task {
            await loadAlbum()
        }
    }

    private func toggleSaveAlbum() {
        guard let alb = album else { return }
        let next = !isAlbumSaved
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isAlbumSaved = next
            album?.isSaved = next
        }
        Task {
            do {
                try await InnerTubeService.shared.toggleSaveAlbum(
                    albumId: alb.id,
                    playlistId: alb.playlistId,
                    isSaved: next
                )
            } catch {
                print("❌ Failed to toggle save album to account: \(error)")
                withAnimation {
                    isAlbumSaved = !next
                    album?.isSaved = !next
                }
            }
        }
    }

    private func loadAlbum() async {
        isLoading = true
        if var full = try? await InnerTubeService.shared.fetchAlbum(id: albumId) {
            let finalTitle = (full.title.isEmpty || full.title == "Album") ? initialTitle : full.title
            let finalArtist = (full.artist.isEmpty || full.artist == "Artist") ? initialArtist : full.artist
            var finalThumb = !full.thumbnailUrl.isEmpty ? full.thumbnailUrl : initialThumbnailUrl

            if AppSettings.shared.enableAppleMusicMetadata,
               let appleArt = await AppleMusicMetadataService.shared.getAlbumArt(title: finalTitle, artist: finalArtist, album: finalTitle) {
                finalThumb = appleArt
            }

            full.title = finalTitle
            full.artist = finalArtist
            full.thumbnailUrl = finalThumb
            full.songs = full.songs.map { s in
                var song = s
                if song.artist.isEmpty || song.artist == "Unknown Artist" || song.artist == "Artist" {
                    song.artist = finalArtist
                }
                if song.album.isEmpty || song.album == "Album" {
                    song.album = finalTitle
                }
                if song.thumbnailUrl.isEmpty || song.thumbnailUrl.contains("hqdefault.jpg") {
                    song.thumbnailUrl = !finalThumb.isEmpty ? finalThumb : "https://i.ytimg.com/vi/\(song.id)/hqdefault.jpg"
                }
                return song
            }
            self.album = full
            self.isAlbumSaved = full.isSaved
        }
        isLoading = false
    }

    private func formattedTotalDuration(_ songs: [Song]) -> String {
        let total = songs.reduce(0.0) { $0 + $1.duration }
        let minutes = Int(total) / 60
        return "\(minutes) Minutes"
    }
}
