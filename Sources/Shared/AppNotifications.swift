import Foundation

extension Notification.Name {
    static let openSettingsSheet = Notification.Name("OpenSettingsSheet")
    static let openSignInSheet = Notification.Name("OpenSignInSheet")
    static let openDetailItem = Notification.Name("OpenDetailItem")
    static let closeActiveDetailItem = Notification.Name("CloseActiveDetailItem")
    static let libraryArtistsChanged = Notification.Name("LibraryArtistsChanged")
    static let libraryPlaylistsChanged = Notification.Name("LibraryPlaylistsChanged")
}
