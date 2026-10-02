import Foundation

public struct Song: Identifiable, Codable, Hashable, Sendable {
    public let id: String // YouTube videoId
    public var title: String
    public var artist: String
    public var artistId: String?
    public var album: String
    public var albumId: String?
    public var duration: TimeInterval
    public var thumbnailUrl: String
    public var streamUrl: String?
    public var isLiked: Bool
    public var isDownloaded: Bool
    public var localFilePath: String?

    public init(
        id: String,
        title: String,
        artist: String,
        artistId: String? = nil,
        album: String = "",
        albumId: String? = nil,
        duration: TimeInterval = 0,
        thumbnailUrl: String = "",
        streamUrl: String? = nil,
        isLiked: Bool = false,
        isDownloaded: Bool = false,
        localFilePath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artistId = artistId
        self.album = album
        self.albumId = albumId
        self.duration = duration
        self.thumbnailUrl = thumbnailUrl
        self.streamUrl = streamUrl
        self.isLiked = isLiked
        self.isDownloaded = isDownloaded
        self.localFilePath = localFilePath
    }

    public var formattedDuration: String {
        duration.formattedPlaybackTime
    }

    init(track: Track) {
        let vid = track.videoId ?? ""
        let art = !track.artists.isEmpty ? track.artists.map(\.name).joined(separator: ", ") : track.subtitle
        let alb = track.albumLink?.name ?? ""
        let dur = InnerTubeService.parseDurationString(track.duration ?? "0:00")
        let thumb = track.thumbnailURL?.absoluteString ?? (!vid.isEmpty ? "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg" : "")

        self.init(
            id: vid,
            title: track.title,
            artist: art,
            artistId: track.artists.first?.browseId,
            album: alb,
            albumId: track.albumLink?.browseId,
            duration: dur,
            thumbnailUrl: thumb,
            isLiked: track.likeStatus == .liked
        )
    }

    public var highResThumbnailUrl: String {
        thumbnailSized(for: 600)
    }

    public func thumbnailSized(for dimension: Int) -> String {
        thumbnailUrl.thumbnailSized(for: dimension)
    }
}

extension TimeInterval {
    public var formattedPlaybackTime: String {
        guard isFinite && !isNaN && self >= 0 else { return "0:00" }
        let total = Int(self)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
