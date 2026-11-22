import Foundation

public struct FeedSection: Identifiable, Sendable {
    public var id: String { title }
    public let title: String
    public let subtitle: String?
    public let items: [FeedItem]

    public init(title: String, subtitle: String? = nil, items: [FeedItem]) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
    }
}

public enum FeedItem: Identifiable, Sendable {
    case song(Song)
    case album(Album)
    case playlist(Playlist)
    case artist(Artist)

    public var id: String {
        switch self {
        case .song(let s): return "song_\(s.id)"
        case .album(let a): return "album_\(a.id)"
        case .playlist(let p): return "playlist_\(p.id)"
        case .artist(let ar): return "artist_\(ar.id)"
        }
    }

    public var title: String {
        switch self {
        case .song(let s): return s.title
        case .album(let a): return a.title
        case .playlist(let p): return p.title
        case .artist(let ar): return ar.name
        }
    }

    public var subtitle: String {
        switch self {
        case .song(let s): return s.artist
        case .album(let a): return a.artist
        case .playlist(let p): return p.author ?? "Playlist"
        case .artist(let ar): return ar.subscribers ?? "Artist"
        }
    }

    public var thumbnailUrl: String {
        switch self {
        case .song(let s): return s.thumbnailUrl
        case .album(let a): return a.thumbnailUrl
        case .playlist(let p): return p.thumbnailUrl
        case .artist(let ar): return ar.thumbnailUrl
        }
    }

    public func thumbnailSized(for dimension: Int) -> String {
        thumbnailUrl.thumbnailSized(for: dimension)
    }
}

public actor InnerTubeService {
    public static let shared = InnerTubeService()

    private let client = InnerTubeClient.shared

    private init() {}

    // MARK: - Home Feed
    public func fetchHomeFeed() async throws -> [FeedSection] {
        let feed = try await client.homeFeed()
        var sections: [FeedSection] = []

        for shelf in feed.shelves {
            let feedItems = shelf.items.compactMap { makeFeedItem(from: $0) }
            if !feedItems.isEmpty {
                sections.append(FeedSection(title: shelf.title, subtitle: nil, items: feedItems))
            }
        }

        if sections.isEmpty {
            // Fallback to explore if home is empty
            return try await fetchExplore()
        }

        return sections
    }

    public func fetchArtistsOnRepeat(existingSections: [FeedSection] = []) async throws -> (title: String, artists: [Artist])? {
        for section in existingSections {
            let lower = section.title.lowercased()
            if lower.contains("repeat") && lower.contains("artist") {
                let artists = section.items.compactMap { item -> Artist? in
                    if case .artist(let a) = item { return a }
                    return nil
                }
                if !artists.isEmpty {
                    return (title: section.title, artists: artists)
                }
            }
        }

        guard await CredentialStore.shared.isSignedIn else { return nil }

        var channelId = await MainActor.run { AuthManager.shared.userChannelId }
        if channelId.isEmpty {
            if let info = try? await client.accountInfo(), let cid = info.channelId, !cid.isEmpty {
                channelId = cid
                await MainActor.run {
                    AuthManager.shared.userChannelId = cid
                    UserDefaults.standard.set(cid, forKey: "com.music.app.userChannelId")
                }
            }
        }

        guard !channelId.isEmpty else { return nil }

        let channelFeed = try await client.userChannel(channelId: channelId)
        for shelf in channelFeed.shelves {
            let lower = shelf.title.lowercased()
            if lower.contains("repeat") && lower.contains("artist") {
                let artists: [Artist] = shelf.items.compactMap { item in
                    if let feedItem = makeFeedItem(from: item), case .artist(let a) = feedItem {
                        return a
                    }
                    if !item.title.isEmpty {
                        return Artist(
                            id: item.browseId ?? UUID().uuidString,
                            name: item.title,
                            thumbnailUrl: item.thumbnailURL?.absoluteString ?? "",
                            subscribers: item.subtitle.isEmpty ? nil : item.subtitle,
                            bio: nil,
                            topSongs: [],
                            albums: []
                        )
                    }
                    return nil
                }

                if !artists.isEmpty {
                    return (title: shelf.title, artists: artists)
                }
            }
        }

        return nil
    }

    // MARK: - Explore
    public func fetchExplore() async throws -> [FeedSection] {
        let shelves = try await client.explore()
        var sections: [FeedSection] = []

        for shelf in shelves {
            let feedItems = shelf.items.compactMap { makeFeedItem(from: $0) }
            if !feedItems.isEmpty {
                sections.append(FeedSection(title: shelf.title, subtitle: nil, items: feedItems))
            }
        }
        return sections
    }

    // MARK: - Charts
    public func fetchCharts() async throws -> [FeedSection] {
        // Fetch charts via browse endpoint FEmusic_charts
        let destination = EntityDestination(
            browseId: "FEmusic_charts",
            kind: .unknown,
            title: "Charts",
            subtitle: "",
            thumbnailURL: nil
        )
        if let page = try? await client.entity(destination), !page.shelves.isEmpty {
            var sections: [FeedSection] = []
            if !page.tracks.isEmpty {
                let songItems = page.tracks.map { FeedItem.song(Song(track: $0)) }
                sections.append(FeedSection(title: "Top Chart Songs", subtitle: nil, items: songItems))
            }
            for shelf in page.shelves {
                let items = shelf.items.compactMap { makeFeedItem(from: $0) }
                if !items.isEmpty {
                    sections.append(FeedSection(title: shelf.title, subtitle: nil, items: items))
                }
            }
            if !sections.isEmpty {
                return sections
            }
        }

        // Fallback to explore
        return try await fetchExplore()
    }

    // MARK: - Search
    public func searchUnified(query: String) async throws -> UnifiedSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UnifiedSearchResults() }

        var results = UnifiedSearchResults()

        let shelves = try await client.search(trimmed, filter: .all)

        for shelf in shelves {
            for item in shelf.items {
                let thumb = item.thumbnailURL?.absoluteString ?? ""
                switch item.kind {
                case .song, .video:
                    let song = Song(
                        id: item.videoId ?? item.browseId ?? "",
                        title: item.title,
                        artist: item.subtitle,
                        album: item.albumLink?.name ?? "",
                        duration: 0,
                        thumbnailUrl: thumb
                    )
                    if !song.id.isEmpty && !results.songs.contains(where: { $0.id == song.id }) {
                        results.songs.append(song)
                    }
                case .album:
                    let album = Album(
                        id: item.browseId ?? item.playlistId ?? "",
                        title: item.title,
                        artist: item.subtitle,
                        year: "",
                        thumbnailUrl: thumb,
                        songs: []
                    )
                    if !album.id.isEmpty && !results.albums.contains(where: { $0.id == album.id }) {
                        results.albums.append(album)
                    }
                case .artist, .profile:
                    let artist = Artist(
                        id: item.browseId ?? "",
                        name: item.title,
                        thumbnailUrl: thumb,
                        subscribers: item.subtitle,
                        bio: nil,
                        topSongs: [],
                        albums: []
                    )
                    if !artist.id.isEmpty && !results.artists.contains(where: { $0.id == artist.id }) {
                        results.artists.append(artist)
                    }
                case .playlist:
                    let playlist = Playlist(
                        id: item.playlistId ?? item.browseId ?? "",
                        title: item.title,
                        description: item.subtitle,
                        author: item.subtitle,
                        thumbnailUrl: thumb,
                        songCount: 0,
                        songs: []
                    )
                    if !playlist.id.isEmpty && !results.playlists.contains(where: { $0.id == playlist.id }) {
                        results.playlists.append(playlist)
                    }
                default:
                    break
                }
            }
        }

        // Set topResult if available
        if let firstShelf = shelves.first, let firstItem = firstShelf.items.first {
            let thumb = firstItem.thumbnailURL?.absoluteString ?? ""
            switch firstItem.kind {
            case .artist, .profile:
                let artist = Artist(id: firstItem.browseId ?? "", name: firstItem.title, thumbnailUrl: thumb, subscribers: firstItem.subtitle, bio: nil, topSongs: [], albums: [])
                results.topResult = .artist(artist)
            case .album:
                let album = Album(id: firstItem.browseId ?? "", title: firstItem.title, artist: firstItem.subtitle, year: "", thumbnailUrl: thumb, songs: [])
                results.topResult = .album(album)
            case .playlist:
                let pl = Playlist(id: firstItem.playlistId ?? firstItem.browseId ?? "", title: firstItem.title, description: firstItem.subtitle, author: firstItem.subtitle, thumbnailUrl: thumb, songCount: 0, songs: [])
                results.topResult = .playlist(pl)
            default:
                if let song = results.songs.first {
                    results.topResult = .song(song)
                }
            }
        } else if let song = results.songs.first {
            results.topResult = .song(song)
        }

        return results
    }

    public func search(query: String) async throws -> [Song] {
        let unified = try await searchUnified(query: query)
        return unified.songs
    }

    // MARK: - Album Details
    public func fetchAlbum(id: String) async throws -> Album {
        let cleanId = id.hasPrefix("MPRE") ? id : (id.starts(with: "VL") ? id : "MPREb_\(id)")
        let destination = EntityDestination(
            browseId: cleanId,
            kind: .album,
            title: "",
            subtitle: "",
            thumbnailURL: nil
        )

        let page = try await client.entity(destination)
        let title = page.header.title.isEmpty ? "Album" : page.header.title
        let artist = page.header.subtitle.isEmpty ? "Artist" : page.header.subtitle
        var thumb = page.header.thumbnailURL?.absoluteString ?? ""
        if await AppSettings.shared.enableAppleMusicMetadata,
           let appleArt = await AppleMusicMetadataService.shared.getAlbumArt(title: title, artist: artist, album: title) {
            thumb = appleArt
        }

        var songs: [Song] = []
        for track in page.tracks {
            var song = Song(track: track)
            if song.artist.isEmpty { song.artist = artist }
            if song.album.isEmpty { song.album = title }
            if song.thumbnailUrl.isEmpty || song.thumbnailUrl.contains("hqdefault") {
                song.thumbnailUrl = !thumb.isEmpty ? thumb : song.thumbnailUrl
            }
            songs.append(song)
        }

        return Album(
            id: id,
            title: title,
            artist: artist,
            year: page.header.description,
            thumbnailUrl: thumb,
            songs: songs,
            isSaved: page.header.isSaved ?? false,
            playlistId: page.shufflePlaylistId
        )
    }

    public func toggleSaveAlbum(albumId: String, playlistId: String?, isSaved: Bool) async throws {
        let targetId: String
        if let pid = playlistId, !pid.isEmpty {
            targetId = pid
        } else if albumId.starts(with: "MPREb_") {
            targetId = String(albumId.dropFirst(6))
        } else {
            targetId = albumId
        }
        try await client.setPlaylistSaved(playlistId: targetId, saved: isSaved)
    }

    // MARK: - Playlist Details
    public func fetchPlaylist(id: String) async throws -> Playlist {
        let cleanId = id.hasPrefix("VL") ? id : "VL\(id)"
        let destination = EntityDestination(
            browseId: cleanId,
            kind: .playlist,
            title: "",
            subtitle: "",
            thumbnailURL: nil
        )

        let page = try await client.entity(destination)
        let title = page.header.title.isEmpty ? "Playlist" : page.header.title
        let author = page.header.subtitle.isEmpty ? "YouTube Music" : page.header.subtitle
        let thumb = page.header.thumbnailURL?.absoluteString ?? ""

        var songs: [Song] = []
        for track in page.tracks {
            var song = Song(track: track)
            if song.thumbnailUrl.isEmpty || song.thumbnailUrl.contains("hqdefault") {
                song.thumbnailUrl = !thumb.isEmpty ? thumb : song.thumbnailUrl
            }
            songs.append(song)
        }

        return Playlist(
            id: id,
            title: title,
            description: page.header.description.isEmpty ? nil : page.header.description,
            author: author,
            thumbnailUrl: thumb,
            songCount: songs.count,
            songs: songs
        )
    }

    // MARK: - Artist Details
    public func fetchArtist(id: String) async throws -> Artist {
        let destination = EntityDestination(
            browseId: id,
            kind: .artist,
            title: "",
            subtitle: "",
            thumbnailURL: nil
        )

        let page = try await client.entity(destination)
        let name = page.header.title.isEmpty ? "Artist" : page.header.title
        let subscribers = page.header.subtitle
        var thumb = page.header.thumbnailURL?.absoluteString ?? ""
        if await AppSettings.shared.enableAppleMusicMetadata,
           let applePic = await AppleMusicMetadataService.shared.getArtistPicture(artistName: name) {
            thumb = applePic
        }

        let topSongs = page.tracks.map { Song(track: $0) }

        var albums: [Album] = []
        for shelf in page.shelves {
            for item in shelf.items where item.kind == .album {
                albums.append(Album(
                    id: item.browseId ?? "",
                    title: item.title,
                    artist: name,
                    year: item.subtitle,
                    thumbnailUrl: item.thumbnailURL?.absoluteString ?? thumb,
                    songs: []
                ))
            }
        }

        return Artist(
            id: id,
            name: name,
            thumbnailUrl: thumb,
            subscribers: subscribers,
            bio: page.header.description.isEmpty ? nil : page.header.description,
            topSongs: topSongs,
            albums: albums
        )
    }

    // MARK: - Library & User Data
    public func fetchLikedSongs() async throws -> [Song] {
        let destination = EntityDestination(
            browseId: "VLLM",
            kind: .playlist,
            title: "Liked Music",
            subtitle: "",
            thumbnailURL: nil
        )
        let page = try await client.entity(destination)
        return page.tracks.map { Song(track: $0) }
    }

    public func fetchUserPlaylists() async throws -> [Playlist] {
        let libraryPage = try await client.library(browseId: "FEmusic_liked_playlists")
        var playlists: [Playlist] = []

        for shelf in libraryPage.shelves {
            for item in shelf.items {
                playlists.append(Playlist(
                    id: item.playlistId ?? item.browseId ?? "",
                    title: item.title,
                    description: item.subtitle,
                    author: item.subtitle,
                    thumbnailUrl: item.thumbnailURL?.absoluteString ?? "",
                    songCount: 0,
                    songs: []
                ))
            }
        }

        if playlists.isEmpty {
            // Check landing library
            let landing = try await client.library()
            for shelf in landing.shelves where shelf.title.localizedCaseInsensitiveContains("playlist") {
                for item in shelf.items {
                    playlists.append(Playlist(
                        id: item.playlistId ?? item.browseId ?? "",
                        title: item.title,
                        description: item.subtitle,
                        author: item.subtitle,
                        thumbnailUrl: item.thumbnailURL?.absoluteString ?? "",
                        songCount: 0,
                        songs: []
                    ))
                }
            }
        }

        return playlists
    }

    public func fetchSavedAlbums() async throws -> [Album] {
        var albums: [Album] = []

        func processPage(_ page: LibraryPage) {
            for shelf in page.shelves {
                for item in shelf.items {
                    guard let bid = item.browseId, !bid.isEmpty else { continue }
                    var artistName = item.artists.map(\.name).joined(separator: ", ")
                    var year = ""
                    if artistName.isEmpty {
                        let parts = item.subtitle.components(separatedBy: " • ").filter {
                            let l = $0.lowercased()
                            return l != "album" && l != "ep" && l != "single"
                        }
                        if let first = parts.first {
                            artistName = first
                        }
                        if parts.count > 1, let last = parts.last, last.allSatisfy({ $0.isNumber }) && last.count == 4 {
                            year = last
                        }
                    } else {
                        let parts = item.subtitle.components(separatedBy: " • ")
                        if let last = parts.last, last.allSatisfy({ $0.isNumber }) && last.count == 4 {
                            year = last
                        }
                    }

                    albums.append(Album(
                        id: bid,
                        title: item.title,
                        artist: artistName.isEmpty ? item.subtitle : artistName,
                        year: year,
                        thumbnailUrl: item.thumbnailURL?.absoluteString ?? "",
                        songs: [],
                        isSaved: true
                    ))
                }
            }
        }

        // Primary: liked/saved albums endpoint
        if let libraryPage = try? await client.library(browseId: "FEmusic_liked_albums") {
            processPage(libraryPage)

            // Follow continuations (up to 5 pages)
            var cur = libraryPage
            var pageCount = 1
            while let token = cur.continuation, pageCount < 5 {
                do {
                    cur = try await client.libraryContinuation(token)
                    processPage(cur)
                    pageCount += 1
                } catch {
                    break
                }
            }
        }

        // Fallback: check library landing if needed
        if albums.isEmpty {
            if let landing = try? await client.library() {
                for shelf in landing.shelves where shelf.title.localizedCaseInsensitiveContains("album") {
                    for item in shelf.items {
                        guard let bid = item.browseId, !bid.isEmpty else { continue }
                        albums.append(Album(
                            id: bid,
                            title: item.title,
                            artist: item.subtitle,
                            year: "",
                            thumbnailUrl: item.thumbnailURL?.absoluteString ?? "",
                            songs: [],
                            isSaved: true
                        ))
                    }
                }
            }
        }

        var seen = Set<String>()
        return albums.filter { seen.insert($0.id).inserted }
    }

    public func fetchFollowedArtists() async throws -> [Artist] {
        var artists: [Artist] = []

        func extractArtists(from page: LibraryPage) {
            for shelf in page.shelves {
                for item in shelf.items {
                    guard let bid = item.browseId, !bid.isEmpty else { continue }
                    artists.append(Artist(
                        id: bid,
                        name: item.title,
                        thumbnailUrl: item.thumbnailURL?.absoluteString ?? "",
                        subscribers: item.subtitle.isEmpty ? nil : item.subtitle,
                        bio: nil,
                        topSongs: [],
                        albums: []
                    ))
                }
            }
        }

        // Primary: followed/subscribed artists endpoint
        if let libraryPage = try? await client.library(browseId: "FEmusic_library_corpus_artists") {
            extractArtists(from: libraryPage)

            var cur = libraryPage
            var pageCount = 1
            while let token = cur.continuation, pageCount < 5 {
                do {
                    cur = try await client.libraryContinuation(token)
                    extractArtists(from: cur)
                    pageCount += 1
                } catch {
                    break
                }
            }
        }

        // Secondary fallback: artists from library tracks
        if artists.isEmpty {
            if let libraryPage = try? await client.library(browseId: "FEmusic_library_corpus_track_artists") {
                extractArtists(from: libraryPage)

                var cur = libraryPage
                var pageCount = 1
                while let token = cur.continuation, pageCount < 5 {
                    do {
                        cur = try await client.libraryContinuation(token)
                        extractArtists(from: cur)
                        pageCount += 1
                    } catch {
                        break
                    }
                }
            }
        }

        // Fallback: check library landing if still empty
        if artists.isEmpty {
            if let landing = try? await client.library() {
                for shelf in landing.shelves where shelf.title.localizedCaseInsensitiveContains("artist") {
                    for item in shelf.items {
                        guard let bid = item.browseId, !bid.isEmpty else { continue }
                        artists.append(Artist(
                            id: bid,
                            name: item.title,
                            thumbnailUrl: item.thumbnailURL?.absoluteString ?? "",
                            subscribers: item.subtitle.isEmpty ? nil : item.subtitle,
                            bio: nil,
                            topSongs: [],
                            albums: []
                        ))
                    }
                }
            }
        }

        var seen = Set<String>()
        return artists.filter { seen.insert($0.id).inserted }
    }

    // MARK: - User Listening History
    public func fetchListeningHistory() async throws -> [Song] {
        let historySections = try await client.history()
        let allTracks = historySections.flatMap { $0.tracks }
        return allTracks.map { Song(track: $0) }
    }

    // MARK: - Radio Queue Continuation
    public func fetchRadioQueue(videoId: String) async -> [Song] {
        guard let page = try? await client.radio(for: videoId) else {
            return []
        }
        return page.tracks.map { Song(track: $0) }
    }

    // MARK: - Likes
    public func toggleLike(videoId: String, isLiked: Bool) async throws {
        try await client.setLikeStatus(videoId: videoId, status: isLiked ? .liked : .indifferent)
    }

    // MARK: - Stream URL Resolver (Used by DownloadManager)
    public func resolveAudioStreamUrl(videoId: String, song: Song? = nil) async throws -> String {
        if let song = song,
           let playback = await AudioPlayerService.shared.resolvePlaybackStream(for: song) {
            return playback.url.absoluteString
        }
        let stream = try await StreamResolver.shared.audioStream(videoId: videoId)
        return stream.url.absoluteString
    }

    // MARK: - Lyrics
    public func fetchLyrics(videoId: String) async -> [LyricLine] {
        let query = LyricsQuery(videoId: videoId, title: "", artist: "")
        guard let lyrics = try? await client.lyrics(for: query) else {
            return []
        }
        return lyrics.lines
    }

    // MARK: - Helpers
    private func makeFeedItem(from item: ShelfItem) -> FeedItem? {
        let thumb = item.thumbnailURL?.absoluteString ?? ""
        switch item.kind {
        case .song, .video:
            let song = Song(
                id: item.videoId ?? item.browseId ?? UUID().uuidString,
                title: item.title,
                artist: item.subtitle,
                album: item.albumLink?.name ?? "",
                duration: 0,
                thumbnailUrl: thumb
            )
            return .song(song)
        case .album:
            let album = Album(
                id: item.browseId ?? item.playlistId ?? UUID().uuidString,
                title: item.title,
                artist: item.subtitle,
                year: "",
                thumbnailUrl: thumb,
                songs: []
            )
            return .album(album)
        case .playlist:
            let playlist = Playlist(
                id: item.playlistId ?? item.browseId ?? UUID().uuidString,
                title: item.title,
                description: item.subtitle,
                author: item.subtitle,
                thumbnailUrl: thumb,
                songCount: 0,
                songs: []
            )
            return .playlist(playlist)
        case .artist, .profile:
            let artist = Artist(
                id: item.browseId ?? UUID().uuidString,
                name: item.title,
                thumbnailUrl: thumb,
                subscribers: item.subtitle,
                bio: nil,
                topSongs: [],
                albums: []
            )
            return .artist(artist)
        default:
            return nil
        }
    }

    public static func parseDurationString(_ str: String) -> TimeInterval {
        let parts = str.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return 0
    }
}
