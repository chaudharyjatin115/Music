import SwiftUI

public struct FeedView: View {
    let title: String
    @State private var sections: [FeedSection] = []
    @State private var historySongs: [Song] = []
    @State private var savedAlbums: [Album] = []
    @State private var likedSongs: [Song] = []
    @State private var followedArtists: [Artist] = []
    @State private var repeatArtists: [Artist] = []
    @State private var repeatSectionTitle: String = "Artists on repeat"
    @State private var displayAlbums: [Album] = []
    @State private var displaySongs: [Song] = []
    @State private var displayArtists: [Artist] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var authManager = AuthManager.shared
    @Binding var activeDetailItem: FeedItem?

    @State private var albumScrollIndex: Int = 0

    public init(title: String, activeDetailItem: Binding<FeedItem?>) {
        self.title = title
        self._activeDetailItem = activeDetailItem
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if title == "Listen Now" {
                    renderHome()
                } else {
                    renderCategorizedFeed()
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ytBackground)
        .task {
            await loadFeed()
        }
        .onChange(of: authManager.isLoggedIn) { _, loggedIn in
            Task { await loadFeed() }
        }
    }

    @ViewBuilder
    private func renderHome() -> some View {
        let displayAlbums = self.displayAlbums
        let displaySongs = self.displaySongs
        let displayArtists = !repeatArtists.isEmpty ? repeatArtists : self.displayArtists

        // Albums Carousel
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Albums")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.primary)
                }

                Spacer()

                if displayAlbums.count > 4 {
                    // < > Pagination Arrows
                    HStack(spacing: 6) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if albumScrollIndex > 0 {
                                    albumScrollIndex -= 1
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(albumScrollIndex > 0 ? Color.primary : Color.secondary.opacity(0.4))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(albumScrollIndex == 0)

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if albumScrollIndex < max(0, displayAlbums.count - 4) {
                                    albumScrollIndex += 1
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(albumScrollIndex < max(0, displayAlbums.count - 4) ? Color.primary : Color.secondary.opacity(0.4))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isLoading && displayAlbums.isEmpty {
                HStack(spacing: 18) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                            .frame(width: 156, height: 190)
                    }
                }
                .padding(.vertical, 4)
            } else if displayAlbums.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(authManager.isLoggedIn ? "No recently streamed albums in your account" : "Sign in to see your recently streamed albums")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 18) {
                            ForEach(Array(displayAlbums.enumerated()), id: \.element.id) { index, album in
                                MockupAlbumCard(album: album) {
                                    activeDetailItem = .album(album)
                                } onPlay: {
                                    playAlbum(album)
                                }
                                .id(index)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: albumScrollIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(newIndex, anchor: .leading)
                        }
                    }
                }
            }
        }

        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recently added")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.primary)

                if isLoading && displaySongs.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(0..<5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.04))
                                .frame(height: 48)
                        }
                    }
                } else if displaySongs.isEmpty {
                    Text(authManager.isLoggedIn ? "No recently added tracks" : "Sign in to see your recent tracks")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    HStack(spacing: 12) {
                        Text("Title")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.secondary.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 48) // Space matching thumbnail width

                        Text("Artist")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.secondary.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Time")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.secondary.opacity(0.8))
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)

                    LazyVStack(spacing: 4) {
                        ForEach(displaySongs) { song in
                            let isPlayingThis = (player.currentSong?.id == song.id)
                            MockupSongRow(
                                song: song,
                                isPlaying: isPlayingThis && player.isPlaying,
                                isActiveSelected: isPlayingThis
                            ) {
                                if isPlayingThis {
                                    player.togglePlayPause()
                                } else {
                                    player.play(song: song, newQueue: displaySongs)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                Text(repeatSectionTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.primary)

                if isLoading && displayArtists.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(0..<6, id: \.self) { _ in
                            VStack(spacing: 8) {
                                Circle()
                                    .fill(Color.primary.opacity(0.04))
                                    .frame(width: 76, height: 76)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.04))
                                    .frame(width: 50, height: 10)
                            }
                        }
                    }
                } else if displayArtists.isEmpty {
                    Text(authManager.isLoggedIn ? "Play music to see your artists on repeat" : "Sign in to view your artists on repeat")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 20)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(displayArtists.prefix(6)) { artist in
                            MockupArtistCircle(artist: artist) {
                                activeDetailItem = .artist(artist)
                            }
                        }
                    }
                }
            }
            .frame(width: 290)
        }
        .padding(.top, 10)

        let additionalShelves = sections.filter { s in
            let lower = s.title.lowercased()
            return !lower.contains("album") && !lower.contains("recent") && !lower.contains("popular") && !(lower.contains("artist") && lower.contains("repeat"))
        }

        if !additionalShelves.isEmpty {
            LazyVStack(alignment: .leading, spacing: 22) {
                Divider()
                    .padding(.vertical, 8)

                ForEach(additionalShelves) { shelf in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(shelf.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.primary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(shelf.items) { item in
                                    FeedItemCard(item: item) {
                                        handleItemTap(item, inSection: shelf)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderCategorizedFeed() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primary)
        }
        .padding(.bottom, 8)

        if isLoading && sections.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.large)
                Spacer()
            }
            .padding(.vertical, 60)
        } else {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.primary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(section.items) { item in
                                FeedItemCard(item: item) {
                                    handleItemTap(item, inSection: section)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func updateDisplayCollections() {
        var albums: [Album] = []
        var seenAlbums = Set<String>()
        for song in historySongs {
            if let albId = song.albumId, !albId.isEmpty, !seenAlbums.contains(albId) {
                seenAlbums.insert(albId)
                albums.append(Album(
                    id: albId,
                    title: !song.album.isEmpty ? song.album : "Album",
                    artist: song.artist,
                    artistId: song.artistId,
                    thumbnailUrl: song.thumbnailUrl
                ))
            }
        }
        for section in sections {
            let lower = section.title.lowercased()
            if lower.contains("listen again") || lower.contains("recent") || lower.contains("again") {
                for item in section.items {
                    if case .album(let a) = item, !seenAlbums.contains(a.id), !a.id.isEmpty {
                        seenAlbums.insert(a.id)
                        albums.append(a)
                    }
                }
            }
        }
        if albums.count < 8 {
            for a in savedAlbums where !seenAlbums.contains(a.id) && !a.id.isEmpty {
                seenAlbums.insert(a.id)
                albums.append(a)
            }
        }
        if albums.count < 8 {
            for section in sections {
                for item in section.items {
                    if case .album(let a) = item, !seenAlbums.contains(a.id), !a.id.isEmpty {
                        seenAlbums.insert(a.id)
                        albums.append(a)
                    }
                }
            }
        }
        self.displayAlbums = albums

        var songs: [Song] = []
        var seenSongs = Set<String>()
        for s in historySongs where !seenSongs.contains(s.id) && !s.id.isEmpty {
            seenSongs.insert(s.id)
            songs.append(s)
            if songs.count >= 8 { break }
        }
        if songs.count < 8 {
            for section in sections {
                let lower = section.title.lowercased()
                if lower.contains("quick") || lower.contains("listen again") || lower.contains("recent") || lower.contains("library") {
                    for item in section.items {
                        if case .song(let s) = item, !seenSongs.contains(s.id), !s.id.isEmpty {
                            seenSongs.insert(s.id)
                            songs.append(s)
                            if songs.count >= 8 { break }
                        }
                    }
                }
                if songs.count >= 8 { break }
            }
        }
        if songs.count < 8 {
            for s in likedSongs where !seenSongs.contains(s.id) && !s.id.isEmpty {
                seenSongs.insert(s.id)
                songs.append(s)
                if songs.count >= 8 { break }
            }
        }
        self.displaySongs = songs

        var playCounts: [String: Int] = [:]
        var artistDetails: [String: (name: String, artistId: String?, thumb: String)] = [:]
        for song in historySongs {
            let key = song.artistId ?? song.artist
            guard !key.isEmpty else { continue }
            playCounts[key, default: 0] += 1
            if artistDetails[key] == nil {
                artistDetails[key] = (name: song.artist, artistId: song.artistId, thumb: song.thumbnailUrl)
            }
        }
        var artists: [Artist] = []
        var seenArtists = Set<String>()
        for key in playCounts.sorted(by: { $0.value > $1.value }).map(\.key) {
            if let detail = artistDetails[key], !seenArtists.contains(detail.name) {
                seenArtists.insert(detail.name)
                artists.append(Artist(id: detail.artistId ?? key, name: detail.name, thumbnailUrl: detail.thumb))
                if artists.count >= 6 { break }
            }
        }
        if artists.count < 6 {
            for section in sections {
                let lower = section.title.lowercased()
                if lower.contains("listen again") || lower.contains("recent") || lower.contains("artist") {
                    for item in section.items {
                        if case .artist(let a) = item, !seenArtists.contains(a.name), !a.name.isEmpty {
                            seenArtists.insert(a.name)
                            artists.append(a)
                            if artists.count >= 6 { break }
                        }
                    }
                }
                if artists.count >= 6 { break }
            }
        }
        if artists.count < 6 {
            for a in followedArtists where !seenArtists.contains(a.name) && !a.name.isEmpty {
                seenArtists.insert(a.name)
                artists.append(a)
                if artists.count >= 6 { break }
            }
        }
        self.displayArtists = artists
    }

    private func loadFeed() async {
        isLoading = true
        errorMessage = nil

        do {
            if title == "Browse" {
                self.sections = try await InnerTubeService.shared.fetchExplore()
            } else if title == "Charts" || title == "Radio" {
                self.sections = try await InnerTubeService.shared.fetchCharts()
            } else {
                let homeSections = try await InnerTubeService.shared.fetchHomeFeed()
                self.sections = homeSections

                if authManager.isLoggedIn {
                    async let historyTask = try? InnerTubeService.shared.fetchListeningHistory()
                    async let albumsTask = try? InnerTubeService.shared.fetchSavedAlbums()
                    async let likedSongsTask = try? InnerTubeService.shared.fetchLikedSongs()
                    async let artistsTask = try? InnerTubeService.shared.fetchFollowedArtists()
                    async let repeatTask = try? InnerTubeService.shared.fetchArtistsOnRepeat(existingSections: homeSections)

                    let (loadedHistory, loadedAlbums, loadedSongs, loadedArtists, loadedRepeat) = await (historyTask, albumsTask, likedSongsTask, artistsTask, repeatTask)
                    if let h = loadedHistory { self.historySongs = h }
                    if let a = loadedAlbums { self.savedAlbums = a }
                    if let s = loadedSongs { self.likedSongs = s }
                    if let ar = loadedArtists { self.followedArtists = ar }
                    if let rep = loadedRepeat {
                        self.repeatSectionTitle = rep.title
                        self.repeatArtists = rep.artists
                    }
                }
                updateDisplayCollections()
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Unable to load feed."
        }
    }

    private func handleItemTap(_ item: FeedItem, inSection section: FeedSection?) {
        switch item {
        case .song(let song):
            var queue: [Song] = []
            if let section = section {
                for itm in section.items {
                    if case .song(let s) = itm, s.id != song.id {
                        queue.append(s)
                    }
                }
            }
            player.play(song: song, newQueue: queue.isEmpty ? nil : queue)
        case .album, .playlist, .artist:
            activeDetailItem = item
        }
    }

    private func playAlbum(_ album: Album) {
        Task {
            if let a = try? await InnerTubeService.shared.fetchAlbum(id: album.id), let first = a.songs.first {
                player.play(song: first, newQueue: a.songs)
            }
        }
    }
}

struct MockupAlbumCard: View {
    let album: Album
    let onSelect: () -> Void
    let onPlay: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .center) {
                    CachedAsyncImage(url: URL(string: album.thumbnailSized(for: 320))) { img in
                        img.resizable()
                           .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(colors: [Color.gray.opacity(0.15), Color.gray.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .frame(width: 156, height: 156)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(isHovered ? 0.16 : 0.08), radius: isHovered ? 8 : 4, x: 0, y: 3)

                    if isHovered {
                        Circle()
                            .fill(Color.ytRed)
                            .frame(width: 42, height: 42)
                            .shadow(color: Color.ytRed.opacity(0.4), radius: 6, x: 0, y: 2)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1.5)
                            )
                            .onTapGesture {
                                onPlay()
                            }
                    }
                }
                .frame(width: 156, height: 156)

                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    Text(album.artist)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                .frame(width: 156, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MockupSongRow: View {
    let song: Song
    let isPlaying: Bool
    let isActiveSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Thumbnail with Red Pause Button Overlay if Active
                ZStack {
                    CachedAsyncImage(url: URL(string: song.thumbnailSized(for: 100)), targetDimension: 80) { img in
                        img.resizable()
                           .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.18))
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    if isPlaying || isActiveSelected {
                        Circle()
                            .fill(Color.ytRed)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                    } else if isHovered {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            )
                    }
                }
                .frame(width: 36, height: 36)

                // Song Title
                Text(song.title)
                    .font(.system(size: 13, weight: (isActiveSelected || isPlaying) ? .bold : .medium))
                    .foregroundStyle((isActiveSelected || isPlaying) ? Color.ytRed : Color.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Artist Name
                Text(song.artist)
                    .font(.system(size: 13, weight: (isActiveSelected || isPlaying) ? .medium : .regular))
                    .foregroundStyle((isActiveSelected || isPlaying) ? Color.ytRed : Color.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Duration Time
                Text(song.duration > 0 ? song.formattedDuration : "")
                    .font(.system(size: 12.5, weight: (isActiveSelected || isPlaying) ? .semibold : .regular))
                    .foregroundStyle((isActiveSelected || isPlaying) ? Color.ytRed : Color.secondary)
                    .frame(width: 50, alignment: .trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill((isActiveSelected || isPlaying) ? Color.ytLightPink : (isHovered ? Color.ytRowHover : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct MockupArtistCircle: View {
    let artist: Artist
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                CachedAsyncImage(url: URL(string: artist.thumbnailSized(for: 180))) { img in
                    img.resizable()
                       .scaledToFill()
                       .frame(width: 76, height: 76)
                       .clipped()
                } placeholder: {
                    Circle()
                        .fill(LinearGradient(colors: [Color.pink.opacity(0.35), Color.purple.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .frame(width: 76, height: 76)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(isHovered ? 0.16 : 0.08), radius: isHovered ? 6 : 3, x: 0, y: 2)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)

                VStack(spacing: 2) {
                    Text(artist.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .frame(width: 80)

                    if let subtitle = artist.subscribers, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                            .frame(width: 80)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

public struct FeedItemCard: View {
    public let item: FeedItem
    public let onSelect: () -> Void
    public var onPlay: (() -> Void)? = nil
    @State private var isHovered = false

    public init(item: FeedItem, onSelect: @escaping () -> Void, onPlay: (() -> Void)? = nil) {
        self.item = item
        self.onSelect = onSelect
        self.onPlay = onPlay
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                CachedAsyncImage(url: URL(string: item.thumbnailSized(for: 320))) { img in
                    img.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.18))
                }
                .frame(width: 156, height: 156)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(isHovered ? 0.14 : 0.06), radius: isHovered ? 6 : 3, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    Text(item.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                .frame(width: 156, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
