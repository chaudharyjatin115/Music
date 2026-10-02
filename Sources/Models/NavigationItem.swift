import Foundation

public enum NavigationItem: Hashable, Identifiable {
    case listenNow
    case browse
    case charts
    case radio
    case recentlyAdded
    case artists
    case albums
    case songs
    case downloaded
    case likedSongs
    case playlist(id: String, title: String)
    case settings

    public var id: String {
        switch self {
        case .listenNow: return "listenNow"
        case .browse: return "browse"
        case .charts, .radio: return "charts"
        case .recentlyAdded: return "recentlyAdded"
        case .artists: return "artists"
        case .albums: return "albums"
        case .songs: return "songs"
        case .downloaded: return "downloaded"
        case .likedSongs: return "likedSongs"
        case .playlist(let id, _): return "playlist_\(id)"
        case .settings: return "settings"
        }
    }

    public var title: String {
        switch self {
        case .listenNow: return "Listen Now"
        case .browse: return "Browse"
        case .charts, .radio: return "Charts"
        case .recentlyAdded: return "Recently Added"
        case .artists: return "Artists"
        case .albums: return "Albums"
        case .songs: return "Songs"
        case .downloaded: return "Downloaded"
        case .likedSongs: return "Liked Songs"
        case .playlist(_, let title): return title
        case .settings: return "Settings"
        }
    }

    public var iconName: String {
        switch self {
        case .listenNow: return "play.circle.fill"
        case .browse: return "square.grid.2x2.fill"
        case .charts, .radio: return "chart.bar.fill"
        case .recentlyAdded: return "clock"
        case .artists: return "music.mic"
        case .albums: return "square.stack"
        case .songs: return "music.note"
        case .downloaded: return "arrow.down.circle"
        case .likedSongs: return "heart.fill"
        case .playlist: return "music.note.list"
        case .settings: return "gearshape"
        }
    }
}
