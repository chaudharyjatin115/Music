import Foundation

public struct Album: Identifiable, Codable, Hashable, Sendable {
    public let id: String // browseId
    public var title: String
    public var artist: String
    public var artistId: String?
    public var year: String?
    public var thumbnailUrl: String
    public var trackCount: Int
    public var songs: [Song]
    public var isSaved: Bool
    public var playlistId: String?

    public init(
        id: String,
        title: String,
        artist: String,
        artistId: String? = nil,
        year: String? = nil,
        thumbnailUrl: String = "",
        trackCount: Int = 0,
        songs: [Song] = [],
        isSaved: Bool = false,
        playlistId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistId = artistId
        self.year = year
        self.thumbnailUrl = thumbnailUrl
        self.trackCount = trackCount
        self.songs = songs
        self.isSaved = isSaved
        self.playlistId = playlistId
    }

    public var highResThumbnailUrl: String {
        thumbnailSized(for: 600)
    }

    public func thumbnailSized(for dimension: Int) -> String {
        thumbnailUrl.thumbnailSized(for: dimension)
    }
}
