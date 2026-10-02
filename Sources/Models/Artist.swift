import Foundation

public struct Artist: Identifiable, Codable, Hashable, Sendable {
    public let id: String // browseId
    public var name: String
    public var thumbnailUrl: String
    public var subscribers: String?
    public var bio: String?
    public var topSongs: [Song]
    public var albums: [Album]
    public var singles: [Album]
    public var featuredPlaylists: [Playlist]
    public var similarArtists: [Artist]

    public init(
        id: String,
        name: String,
        thumbnailUrl: String = "",
        subscribers: String? = nil,
        bio: String? = nil,
        topSongs: [Song] = [],
        albums: [Album] = [],
        singles: [Album] = [],
        featuredPlaylists: [Playlist] = [],
        similarArtists: [Artist] = []
    ) {
        self.id = id
        self.name = name
        self.thumbnailUrl = thumbnailUrl
        self.subscribers = subscribers
        self.bio = bio
        self.topSongs = topSongs
        self.albums = albums
        self.singles = singles
        self.featuredPlaylists = featuredPlaylists
        self.similarArtists = similarArtists
    }

    public func thumbnailSized(for dimension: Int) -> String {
        thumbnailUrl.thumbnailSized(for: dimension)
    }
}
