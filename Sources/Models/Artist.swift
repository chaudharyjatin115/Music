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
    public var isFollowed: Bool
    public var channelId: String?
    public var subscribeParams: String?
    public var unsubscribeParams: String?

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
        similarArtists: [Artist] = [],
        isFollowed: Bool = false,
        channelId: String? = nil,
        subscribeParams: String? = nil,
        unsubscribeParams: String? = nil
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
        self.isFollowed = isFollowed
        self.channelId = channelId
        self.subscribeParams = subscribeParams
        self.unsubscribeParams = unsubscribeParams
    }

    enum CodingKeys: String, CodingKey {
        case id, name, thumbnailUrl, subscribers, bio, topSongs, albums, singles, featuredPlaylists, similarArtists
        case isFollowed, channelId, subscribeParams, unsubscribeParams
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl) ?? ""
        subscribers = try container.decodeIfPresent(String.self, forKey: .subscribers)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        topSongs = try container.decodeIfPresent([Song].self, forKey: .topSongs) ?? []
        albums = try container.decodeIfPresent([Album].self, forKey: .albums) ?? []
        singles = try container.decodeIfPresent([Album].self, forKey: .singles) ?? []
        featuredPlaylists = try container.decodeIfPresent([Playlist].self, forKey: .featuredPlaylists) ?? []
        similarArtists = try container.decodeIfPresent([Artist].self, forKey: .similarArtists) ?? []
        isFollowed = try container.decodeIfPresent(Bool.self, forKey: .isFollowed) ?? false
        channelId = try container.decodeIfPresent(String.self, forKey: .channelId)
        subscribeParams = try container.decodeIfPresent(String.self, forKey: .subscribeParams)
        unsubscribeParams = try container.decodeIfPresent(String.self, forKey: .unsubscribeParams)
    }

    public func thumbnailSized(for dimension: Int) -> String {
        thumbnailUrl.thumbnailSized(for: dimension)
    }
}
