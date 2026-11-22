import SwiftUI

public struct DetailView: View {
    let item: FeedItem
    @Binding var activeDetailItem: FeedItem?

    public init(item: FeedItem, activeDetailItem: Binding<FeedItem?> = .constant(nil)) {
        self.item = item
        self._activeDetailItem = activeDetailItem
    }

    public var body: some View {
        Group {
            switch item {
            case .artist(let artist):
                ArtistDetailView(
                    artistId: artist.id,
                    initialName: artist.name,
                    initialThumbnailUrl: artist.thumbnailUrl,
                    initialIsFollowed: artist.isFollowed,
                    initialChannelId: artist.channelId,
                    activeDetailItem: $activeDetailItem
                )
            case .album(let album):
                AlbumDetailView(albumId: album.id, initialTitle: album.title, initialArtist: album.artist, initialThumbnailUrl: album.thumbnailUrl, activeDetailItem: $activeDetailItem)
            case .playlist(let playlist):
                PlaylistDetailView(playlistId: playlist.id, initialTitle: playlist.title)
            case .song(let song):
                PlaylistDetailView(playlistId: song.id, initialTitle: song.title)
            }
        }
    }
}
