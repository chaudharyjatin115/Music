import SwiftUI

public struct ArtistDetailView: View {
    let artistId: String
    let initialName: String
    let initialThumbnailUrl: String
    @Binding var activeDetailItem: FeedItem?

    @State private var artist: Artist?
    @State private var isLoading = true
    @State private var isBioExpanded = false

    private let player = AudioPlayerService.shared

    public init(
        artistId: String,
        initialName: String = "Artist",
        initialThumbnailUrl: String = "",
        activeDetailItem: Binding<FeedItem?> = .constant(nil)
    ) {
        self.artistId = artistId
        self.initialName = initialName
        self.initialThumbnailUrl = initialThumbnailUrl
        self._activeDetailItem = activeDetailItem
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                heroHeaderView

                Divider()
                    .padding(.horizontal, 32)

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading artist...")
                            .padding(.vertical, 40)
                        Spacer()
                    }
                } else {
                    if let songs = artist?.topSongs, !songs.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Top Songs")
                                    .font(.system(size: 22, weight: .bold))
                                Spacer()
                            }
                            .padding(.horizontal, 32)

                            TrackListView(songs: songs)
                                .padding(.horizontal, 16)
                        }
                    }

                    if let albums = artist?.albums, !albums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Albums")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal, 32)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 20) {
                                    ForEach(albums) { album in
                                        albumCard(album)
                                    }
                                }
                                .padding(.horizontal, 32)
                            }
                        }
                    }

                    if let singles = artist?.singles, !singles.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Singles & EPs")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal, 32)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 20) {
                                    ForEach(singles) { single in
                                        albumCard(single)
                                    }
                                }
                                .padding(.horizontal, 32)
                            }
                        }
                    }

                    if let playlists = artist?.featuredPlaylists, !playlists.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Featured On")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal, 32)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 20) {
                                    ForEach(playlists) { playlist in
                                        playlistCard(playlist)
                                    }
                                }
                                .padding(.horizontal, 32)
                            }
                        }
                    }

                    if let similar = artist?.similarArtists, !similar.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Fans Also Like")
                                .font(.system(size: 22, weight: .bold))
                                .padding(.horizontal, 32)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 20) {
                                    ForEach(similar) { sim in
                                        similarArtistCard(sim)
                                    }
                                }
                                .padding(.horizontal, 32)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }

                    if let bio = artist?.bio, !bio.isEmpty {
                        aboutSection(bio)
                    }
                }
            }
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .task {
            await loadArtist()
        }
    }

    // MARK: - Hero Header
    private var heroHeaderView: some View {
        let displayThumb = (artist?.thumbnailUrl.isEmpty == false) ? artist!.thumbnailUrl : initialThumbnailUrl

        return HStack(alignment: .center, spacing: 28) {
            CachedAsyncImage(url: URL(string: displayThumb.thumbnailSized(for: 360))) { phase in
                if let img = phase.image {
                    img.resizable()
                       .scaledToFill()
                       .frame(width: 170, height: 170)
                       .clipped()
                } else if phase.error != nil {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 170, height: 170)
                        .overlay {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary.opacity(0.35))
                        }
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 170, height: 170)
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                        }
                }
            }
            .frame(width: 170, height: 170)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    let resolvedName = (artist?.name.isEmpty == false && artist?.name != "Artist") ? artist!.name : initialName
                    Text(resolvedName)
                        .font(.system(size: 34, weight: .bold))

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.pink)
                        .help("Verified Artist")
                }

                if let subs = artist?.subscribers, !subs.isEmpty {
                    Text(subs)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        if let songs = artist?.topSongs, let first = songs.first {
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
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.pink))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let songs = artist?.topSongs, let random = songs.randomElement() {
                            player.isShuffle = true
                            player.play(song: random, newQueue: songs.shuffled())
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                            Text("Shuffle")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let songs = artist?.topSongs, let first = songs.first {
                            player.play(song: first, newQueue: songs)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text("Radio")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
    }

    private func albumCard(_ album: Album) -> some View {
        Button {
            activeDetailItem = .album(album)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                CachedAsyncImage(url: URL(string: album.thumbnailSized(for: 320))) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(Image(systemName: "square.stack").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let year = album.year {
                        Text(year)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playlist Card
    private func playlistCard(_ playlist: Playlist) -> some View {
        Button {
            activeDetailItem = .playlist(playlist)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                CachedAsyncImage(url: URL(string: playlist.thumbnailSized(for: 320))) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(Image(systemName: "music.note.list").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("Playlist")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Similar Artist Card
    private func similarArtistCard(_ sim: Artist) -> some View {
        Button {
            activeDetailItem = .artist(sim)
        } label: {
            VStack(spacing: 8) {
                CachedAsyncImage(url: URL(string: sim.thumbnailSized(for: 220))) { phase in
                    if let img = phase.image {
                        img.resizable()
                           .scaledToFill()
                           .frame(width: 120, height: 120)
                           .clipped()
                    } else {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                VStack(spacing: 2) {
                    Text(sim.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(sim.subscribers ?? "Artist")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 120)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - About Section
    private func aboutSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About \(artist?.name ?? initialName)")
                .font(.system(size: 22, weight: .bold))

            Text(bio)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(isBioExpanded ? nil : 3)

            Button(isBioExpanded ? "Show Less" : "Read More") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isBioExpanded.toggle()
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.pink)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
    }

    private func loadArtist() async {
        isLoading = true
        if var full = try? await InnerTubeService.shared.fetchArtist(id: artistId) {
            if full.name.isEmpty || full.name == "Artist" {
                full.name = initialName
            }
            if let applePic = await AppleMusicMetadataService.shared.getArtistPicture(artistName: full.name) {
                full.thumbnailUrl = applePic
            }
            self.artist = full
        }
        isLoading = false
    }
}
