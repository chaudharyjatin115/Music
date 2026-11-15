import SwiftUI

public enum LibraryCategory: String, CaseIterable, Identifiable {
    case liked = "Liked Songs"
    case downloaded = "Downloaded"
    case songs = "Songs"
    case albums = "Albums"
    case artists = "Artists"
    case playlists = "Playlists"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .liked: return "heart.fill"
        case .downloaded: return "arrow.down.circle.fill"
        case .songs: return "music.note"
        case .albums: return "square.stack.fill"
        case .artists: return "music.mic"
        case .playlists: return "music.note.list"
        }
    }
}

public struct LibraryListView: View {
    @Binding var activeDetailItem: FeedItem?
    public let category: LibraryCategory
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var playlists: [Playlist] = []
    @State private var isLoading = true
    @State private var isShowingCreatePlaylistAlert = false
    @State private var newPlaylistTitle = ""

    @ObservedObject var downloadManager = DownloadManager.shared
    private let player = AudioPlayerService.shared
    @ObservedObject var authManager = AuthManager.shared

    public init(activeDetailItem: Binding<FeedItem?>, category: LibraryCategory = .liked) {
        self._activeDetailItem = activeDetailItem
        self.category = category
    }

    public init(activeDetailItem: Binding<FeedItem?>, initialCategory: LibraryCategory = .liked) {
        self._activeDetailItem = activeDetailItem
        self.category = initialCategory
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Loading...")
                            .padding(.vertical, 60)
                        Spacer()
                    }
                } else {
                    contentForCategory
                        .padding(.top, 24)
                }
            }
            .padding(.bottom, 110) // Inset for floating pill player
        }
        .scrollIndicators(.hidden)
        .task(id: category) {
            await loadData()
        }
        .alert("New Playlist", isPresented: $isShowingCreatePlaylistAlert) {
            TextField("Playlist Title", text: $newPlaylistTitle)
            Button("Create") {
                if !newPlaylistTitle.isEmpty {
                    playlists.append(Playlist(id: "custom_\(UUID().uuidString)", title: newPlaylistTitle))
                    newPlaylistTitle = ""
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Category Content View
    @ViewBuilder
    private var contentForCategory: some View {
        switch category {
        case .liked:
            // Hero card + tracks
            heroHeaderView(
                title: "Liked Songs",
                subtitle: "\(songs.count) Songs",
                icon: "heart.fill",
                gradient: [Color.pink, Color.red]
            )
            .padding(.horizontal, 36)

            if songs.isEmpty {
                emptyState(icon: "heart", text: authManager.isLoggedIn ? "No liked songs found" : "Sign in to view your Liked Songs")
            } else {
                TrackListView(songs: songs)
                    .padding(.horizontal, 20)
            }

        case .downloaded:
            heroHeaderView(
                title: "Downloaded",
                subtitle: "\(downloadManager.downloadedSongs.count) Songs",
                icon: "arrow.down.circle.fill",
                gradient: [Color.blue, Color.purple]
            )
            .padding(.horizontal, 36)

            if downloadManager.downloadedSongs.isEmpty {
                emptyState(icon: "arrow.down.circle", text: "No downloaded tracks for offline listening")
            } else {
                TrackListView(songs: downloadManager.downloadedSongs)
                    .padding(.horizontal, 20)
            }

        case .songs:
            VStack(alignment: .leading, spacing: 18) {
                Text("Songs")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal, 36)

                if songs.isEmpty {
                    emptyState(icon: "music.note", text: authManager.isLoggedIn ? "No tracks in library" : "Sign in to view your songs")
                } else {
                    TrackListView(songs: songs)
                        .padding(.horizontal, 20)
                }
            }

        case .albums:
            VStack(alignment: .leading, spacing: 18) {
                Text("Albums")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal, 36)

                if albums.isEmpty {
                    emptyState(icon: "square.stack", text: authManager.isLoggedIn ? "No saved albums in library" : "Sign in to view your saved albums")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 22)], spacing: 22) {
                        ForEach(albums) { album in
                            FeedItemCard(item: .album(album)) {
                                activeDetailItem = .album(album)
                            }
                        }
                    }
                    .padding(.horizontal, 36)
                }
            }

        case .artists:
            VStack(alignment: .leading, spacing: 18) {
                Text("Artists")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal, 36)

                if artists.isEmpty {
                    emptyState(icon: "music.mic", text: authManager.isLoggedIn ? "You are not following any artists yet" : "Sign in to view artists you follow")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 24)], spacing: 24) {
                        ForEach(artists) { artist in
                            Button {
                                activeDetailItem = .artist(artist)
                            } label: {
                                VStack(spacing: 10) {
                                    CachedAsyncImage(url: URL(string: artist.thumbnailSized(for: 260))) { phase in
                                        if let img = phase.image {
                                            img.resizable()
                                               .scaledToFill()
                                               .frame(width: 130, height: 130)
                                               .clipped()
                                        } else {
                                            Circle().fill(Color.secondary.opacity(0.18))
                                        }
                                    }
                                    .frame(width: 130, height: 130)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

                                    VStack(spacing: 2) {
                                        Text(artist.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .lineLimit(1)
                                            .foregroundStyle(Color.primary)

                                        if let subs = artist.subscribers, !subs.isEmpty {
                                            Text(subs)
                                                .font(.system(size: 11.5))
                                                .lineLimit(1)
                                                .foregroundStyle(Color.secondary)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 36)
                }
            }

        case .playlists:
            if playlists.isEmpty {
                emptyState(icon: "music.note.list", text: authManager.isLoggedIn ? "No playlists found" : "Sign in to sync your YouTube Music playlists")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 22)], spacing: 22) {
                    ForEach(playlists) { playlist in
                        FeedItemCard(item: .playlist(playlist)) {
                            activeDetailItem = .playlist(playlist)
                        }
                    }
                }
                .padding(.horizontal, 36)
            }
        }
    }

    private func heroHeaderView(title: String, subtitle: String, icon: String, gradient: [Color]) -> some View {
        HStack(spacing: 22) {
            ZStack {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 130, height: 130)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text("LIBRARY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)

                Text(title)
                    .font(.system(size: 30, weight: .bold))

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                if !songs.isEmpty {
                    HStack(spacing: 12) {
                        Button {
                            if let first = songs.first {
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
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.pink))
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let random = songs.randomElement() {
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
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.5))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    private func loadData() async {
        isLoading = true

        switch category {
        case .downloaded:
            self.songs = downloadManager.downloadedSongs
            isLoading = false

        case .liked, .songs:
            if authManager.isLoggedIn {
                if let liked = try? await InnerTubeService.shared.fetchLikedSongs() {
                    self.songs = liked
                } else {
                    self.songs = []
                }
            } else {
                self.songs = []
            }
            isLoading = false

        case .albums:
            if authManager.isLoggedIn {
                if let saved = try? await InnerTubeService.shared.fetchSavedAlbums() {
                    self.albums = saved
                } else {
                    self.albums = []
                }
            } else {
                self.albums = []
            }
            isLoading = false

        case .artists:
            if authManager.isLoggedIn {
                if let followed = try? await InnerTubeService.shared.fetchFollowedArtists() {
                    self.artists = followed
                } else {
                    self.artists = []
                }
            } else {
                self.artists = []
            }
            isLoading = false

        case .playlists:
            if authManager.isLoggedIn {
                if let list = try? await InnerTubeService.shared.fetchUserPlaylists() {
                    self.playlists = list
                } else {
                    self.playlists = []
                }
            } else {
                self.playlists = []
            }
            isLoading = false
        }
    }
}
