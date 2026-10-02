import Foundation

public enum SearchTopResult: Hashable, Sendable {
    case song(Song)
    case artist(Artist)
    case album(Album)
    case playlist(Playlist)

    public var title: String {
        switch self {
        case .song(let s): return s.title
        case .artist(let a): return a.name
        case .album(let a): return a.title
        case .playlist(let p): return p.title
        }
    }

    public var subtitle: String {
        switch self {
        case .song(let s): return "Song • \(s.artist)"
        case .artist(let a): return "Artist • \(a.subscribers ?? "Artist")"
        case .album(let a): return "Album • \(a.artist)"
        case .playlist(let p): return "Playlist • \(p.author ?? "Curated")"
        }
    }

    public var thumbnailUrl: String {
        switch self {
        case .song(let s): return s.thumbnailUrl
        case .artist(let a): return a.thumbnailUrl
        case .album(let a): return a.thumbnailUrl
        case .playlist(let p): return p.thumbnailUrl
        }
    }

    public func thumbnailSized(for dimension: Int) -> String {
        thumbnailUrl.thumbnailSized(for: dimension)
    }

    public var categoryName: String {
        switch self {
        case .song: return "Song"
        case .artist: return "Artist"
        case .album: return "Album"
        case .playlist: return "Playlist"
        }
    }
}

public struct UnifiedSearchResults: Sendable {
    public var topResult: SearchTopResult?
    public var songs: [Song] = []
    public var albums: [Album] = []
    public var artists: [Artist] = []
    public var playlists: [Playlist] = []

    public init(
        topResult: SearchTopResult? = nil,
        songs: [Song] = [],
        albums: [Album] = [],
        artists: [Artist] = [],
        playlists: [Playlist] = []
    ) {
        self.topResult = topResult
        self.songs = songs
        self.albums = albums
        self.artists = artists
        self.playlists = playlists
    }

    public var isEmpty: Bool {
        topResult == nil && songs.isEmpty && albums.isEmpty && artists.isEmpty && playlists.isEmpty
    }
}
