import Foundation

public struct Playlist: Identifiable, Codable, Hashable, Sendable {
    public let id: String // browseId or playlistId (VL...)
    public var title: String
    public var description: String?
    public var author: String?
    public var thumbnailUrl: String
    public var songCount: Int
    public var songs: [Song]

    public init(
        id: String,
        title: String,
        description: String? = nil,
        author: String? = nil,
        thumbnailUrl: String = "",
        songCount: Int = 0,
        songs: [Song] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.author = author
        self.thumbnailUrl = thumbnailUrl
        self.songCount = songCount
        self.songs = songs
    }

    public var highResThumbnailUrl: String {
        thumbnailSized(for: 600)
    }

    public func thumbnailSized(for dimension: Int) -> String {
        thumbnailUrl.thumbnailSized(for: dimension)
    }
}
