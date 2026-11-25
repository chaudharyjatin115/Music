//
//  MusicLinks.swift
//  YT Music
//
//  Builds canonical music.youtube.com URLs for sharing / opening in a browser.
//

import Foundation

enum MusicLinks {
    private static let base = "https://music.youtube.com"

    static func url(videoId: String?, playlistId: String?, browseId: String?) -> URL? {
        var components = URLComponents(string: base)
        if let videoId {
            components?.path = "/watch"
            var items = [URLQueryItem(name: "v", value: videoId)]
            if let playlistId { items.append(URLQueryItem(name: "list", value: playlistId)) }
            components?.queryItems = items
            return components?.url
        }
        if let playlistId {
            components?.path = "/playlist"
            components?.queryItems = [URLQueryItem(name: "list", value: playlistId)]
            return components?.url
        }
        if let browseId {
            // Playlist browse ids are "VL<playlistId>"; map them to a playlist link.
            if browseId.hasPrefix("VL") {
                components?.path = "/playlist"
                components?.queryItems = [URLQueryItem(name: "list", value: String(browseId.dropFirst(2)))]
                return components?.url
            }
            if browseId.hasPrefix("UC") {
                components?.path = "/channel/\(browseId)"
                return components?.url
            }
            components?.path = "/browse/\(browseId)"
            return components?.url
        }
        return nil
    }

    enum Target: Equatable {
        case handle(String)
        case entity(EntityLink)
        case watch(videoId: String, playlistId: String?)
    }

    static func target(for url: URL) -> Target? {
        guard let host = url.host?.lowercased(),
              host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let first = parts.first else { return nil }
        let id = parts.dropFirst().first
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        func query(_ name: String) -> String? { items?.first { $0.name == name }?.value }
        if first.hasPrefix("@") { return .handle(first) }
        switch (first, id) {
        case ("channel", let id?):
            return .entity(EntityLink(name: "", browseId: id, kind: .artist))
        case ("browse", let id?):
            let kind: ShelfItem.Kind = id.hasPrefix("MPRE") ? .album
                : id.hasPrefix("UC") ? .artist
                : id.hasPrefix("MPSP") ? .podcast : .unknown
            return .entity(EntityLink(name: "", browseId: id, kind: kind))
        case ("watch", _):
            guard let videoId = query("v") else { return nil }
            return .watch(videoId: videoId, playlistId: query("list"))
        case ("playlist", _):
            guard let list = query("list") else { return nil }
            return .entity(EntityLink(name: "", browseId: "VL" + list, kind: .playlist))
        default:
            return nil
        }
    }
}
