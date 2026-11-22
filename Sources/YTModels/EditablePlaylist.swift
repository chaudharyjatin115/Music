//
//  Playlist.swift
//  YT Music
//
//  View-facing model for a playlist the signed-in user can edit, used to
//  populate the "Add to Playlist" picker and the lightweight playlist manager.
//

import Foundation

public struct EditablePlaylist: Identifiable, Sendable, Equatable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var thumbnailURL: URL?

    public init(id: String, title: String, subtitle: String = "", thumbnailURL: URL? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
    }
}

extension String {
    /// System playlists (`LM`, `SE`) carry playlist-shaped data but reject edits.
    var isSystemPlaylistId: Bool { self == "LM" || self == "SE" }
}
