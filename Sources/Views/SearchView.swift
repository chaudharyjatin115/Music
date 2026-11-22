import SwiftUI

public struct GenreCategory: Identifiable {
    public var id: String { title }
    public let title: String
    public let gradientColors: [Color]
    public let iconName: String
}

public struct SearchView: View {
    @Binding var query: String
    @Binding var activeDetailItem: FeedItem?

    @State private var searchResults = UnifiedSearchResults()
    public enum SearchCategoryTab: String, CaseIterable, Identifiable {
        case all = "All"
        case songs = "Songs"
        case albums = "Albums"
        case artists = "Artists"
        case playlists = "Playlists"
        public var id: String { rawValue }
    }

    @State private var isSearching = false
    @State private var selectedTab: SearchCategoryTab = .all
    @State private var showAllSongs = false
    @State private var showAllAlbums = false
    @State private var showAllArtists = false
    @State private var showAllPlaylists = false

    private let player = AudioPlayerService.shared

    private let categories: [GenreCategory] = [
        GenreCategory(title: "Pop", gradientColors: [.pink, .purple], iconName: "sparkles"),
        GenreCategory(title: "Hip-Hop", gradientColors: [.orange, .red], iconName: "flame.fill"),
        GenreCategory(title: "Dance / Electronic", gradientColors: [.cyan, .blue], iconName: "bolt.fill"),
        GenreCategory(title: "Rock", gradientColors: [Color(red: 0.7, green: 0.1, blue: 0.1), .black], iconName: "guitars.fill"),
        GenreCategory(title: "R&B / Soul", gradientColors: [.purple, .indigo], iconName: "heart.fill"),
        GenreCategory(title: "Alternative", gradientColors: [.teal, .mint], iconName: "leaf.fill"),
        GenreCategory(title: "Chill", gradientColors: [.mint, .teal], iconName: "cup.and.saucer.fill"),
        GenreCategory(title: "Workout", gradientColors: [.yellow, .orange], iconName: "figure.run"),
        GenreCategory(title: "Focus", gradientColors: [.blue, .indigo], iconName: "brain.head.profile"),
        GenreCategory(title: "K-Pop", gradientColors: [.pink, .red], iconName: "star.fill"),
        GenreCategory(title: "Country", gradientColors: [.brown, .orange], iconName: "sunset.fill"),
        GenreCategory(title: "Classical", gradientColors: [.indigo, .black], iconName: "music.quarternote.3")
    ]

    public init(query: Binding<String>, activeDetailItem: Binding<FeedItem?> = .constant(nil)) {
        self._query = query
        self._activeDetailItem = activeDetailItem
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                // Header
                Text(query.isEmpty ? "Search" : "Results for \"\(query)\"")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 32)
                    .padding(.top, 24)

                if query.isEmpty {
                    categoriesGrid
                } else if isSearching {
                    loadingView
                } else if searchResults.isEmpty {
                    emptyView
                } else {
                    // Category Filter Chips
                    categoryChipsBar

                    if selectedTab == .all {
                        // MARK: - 1. Top Matching Hero Result
                        if let top = searchResults.topResult {
                            topResultSection(top)
                        }

                        // MARK: - 2. Songs Section
                        if !searchResults.songs.isEmpty {
                            songsSection
                        }

                        // MARK: - 3. Albums Section
                        if !searchResults.albums.isEmpty {
                            albumsSection
                        }

                        // MARK: - 4. Artists Section
                        if !searchResults.artists.isEmpty {
                            artistsSection
                        }

                        // MARK: - 5. Playlists Section
                        if !searchResults.playlists.isEmpty {
                            playlistsSection
                        }
                    } else if selectedTab == .songs {
                        allSongsView
                    } else if selectedTab == .albums {
                        allAlbumsView
                    } else if selectedTab == .artists {
                        allArtistsView
                    } else if selectedTab == .playlists {
                        allPlaylistsView
                    }
                }
            }
            .padding(.bottom, 120) // Inset for floating mini player
        }
        .scrollIndicators(.hidden)
        .task(id: query) {
            await performSearch(query: query)
        }
    }

    // MARK: - Category Chips Bar
    private var categoryChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SearchCategoryTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.pink : Color(nsColor: .controlBackgroundColor).opacity(0.65))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.12), lineWidth: 0.75)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Dedicated All Views
    private var allSongsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Songs (\(searchResults.songs.count))")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 32)

            TrackListView(songs: searchResults.songs)
                .padding(.horizontal, 16)
        }
    }

    private var allAlbumsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Albums (\(searchResults.albums.count))")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 32)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)],
                spacing: 20
            ) {
                ForEach(searchResults.albums) { album in
                    albumCard(album)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private var allArtistsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Artists (\(searchResults.artists.count))")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 32)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 20)],
                spacing: 20
            ) {
                ForEach(searchResults.artists) { artist in
                    artistCard(artist)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private var allPlaylistsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Playlists (\(searchResults.playlists.count))")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 32)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)],
                spacing: 20
            ) {
                ForEach(searchResults.playlists) { playlist in
                    playlistCard(playlist)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Top Result Section
    private func topResultSection(_ top: SearchTopResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP RESULT")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .padding(.horizontal, 32)

            HStack(spacing: 20) {
                // Large Artwork
                CachedAsyncImage(url: URL(string: top.thumbnailSized(for: 200))) { phase in
                    if let img = phase.image {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(Image(systemName: "music.note").font(.system(size: 28)).foregroundStyle(.secondary))
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: top.categoryName == "Artist" ? 48 : 12, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(top.categoryName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.pink)
                        .tracking(0.5)

                    Text(top.title)
                        .font(.system(size: 20, weight: .bold))
                        .lineLimit(1)

                    Text(top.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Action button (Play or Open)
                Button {
                    handleTopResultClick(top)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: top.categoryName == "Artist" ? "person.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(top.categoryName == "Artist" ? "View Artist" : (top.categoryName == "Album" ? "View Album" : "Play"))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.pink))
                    .shadow(color: Color.pink.opacity(0.35), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
                    )
            )
            .padding(.horizontal, 32)
        }
    }

    private func handleTopResultClick(_ top: SearchTopResult) {
        switch top {
        case .song(let song):
            player.play(song: song, newQueue: searchResults.songs)
        case .album(let album):
            activeDetailItem = .album(album)
        case .artist(let artist):
            activeDetailItem = .artist(artist)
        case .playlist(let playlist):
            activeDetailItem = .playlist(playlist)
        }
    }

    // MARK: - Songs Section
    private var songsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Songs")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if searchResults.songs.count > 5 {
                    Button("See All (\(searchResults.songs.count))") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = .songs
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pink)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)

            let displayedSongs = Array(searchResults.songs.prefix(5))
            TrackListView(songs: displayedSongs)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Albums Section
    private var albumsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Albums")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if searchResults.albums.count > 5 {
                    Button("See All (\(searchResults.albums.count))") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = .albums
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pink)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(searchResults.albums) { album in
                        albumCard(album)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
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

                    Text(album.artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let year = album.year {
                        Text(year)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Artists Section
    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Artists")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if searchResults.artists.count > 5 {
                    Button("See All (\(searchResults.artists.count))") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = .artists
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pink)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(searchResults.artists) { artist in
                        artistCard(artist)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private func artistCard(_ artist: Artist) -> some View {
        Button {
            activeDetailItem = .artist(artist)
        } label: {
            VStack(spacing: 8) {
                CachedAsyncImage(url: URL(string: artist.thumbnailSized(for: 240))) { phase in
                    if let img = phase.image {
                        img.resizable()
                           .scaledToFill()
                           .frame(width: 120, height: 120)
                           .clipped()
                    } else {
                        Circle()
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

                VStack(spacing: 2) {
                    Text(artist.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("Artist")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 120)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Playlists Section
    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Playlists")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                if searchResults.playlists.count > 5 {
                    Button("See All (\(searchResults.playlists.count))") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = .playlists
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pink)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(searchResults.playlists) { playlist in
                        playlistCard(playlist)
                    }
                }
                .padding(.horizontal, 32)
            }
        }
    }

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

                    Text(playlist.author ?? "Curated Playlist")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 160, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Categories Grid
    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browse Categories")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 32)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 18)],
                spacing: 18
            ) {
                ForEach(categories) { category in
                    Button {
                        query = category.title
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(
                                colors: category.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                            HStack {
                                Text(category.title)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 2)

                                Spacer()

                                Image(systemName: category.iconName)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(16)
                        }
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: category.gradientColors.first?.opacity(0.3) ?? .clear, radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Searching songs, albums, artists, playlists...")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 80)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
            Text("No results found for \"\(query)\"")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = UnifiedSearchResults()
            return
        }
        isSearching = true
        async let ytResults = InnerTubeService.shared.searchUnified(query: trimmed)
        async let addonTracks = EclipseAddonService.shared.search(query: trimmed)

        var finalResults = (try? await ytResults) ?? UnifiedSearchResults()
        let addonSongs = await addonTracks
        if !addonSongs.isEmpty {
            finalResults.songs.insert(contentsOf: addonSongs, at: 0)
        }
        self.searchResults = finalResults
        self.isSearching = false
    }
}
