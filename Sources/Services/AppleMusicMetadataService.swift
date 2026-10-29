//
//  AppleMusicMetadataService.swift
//  Music
//
//  Artwork and artist image lookup using Apple Music.
//

import Foundation

public actor AppleMusicMetadataService {
    public static let shared = AppleMusicMetadataService()

    private var artworkCache: [String: String] = [:]
    private var artistPictureCache: [String: String] = [:]
    private var negativeArtworkCache: Set<String> = []
    private var negativeArtistCache: Set<String> = []

    private init() {}

    private func fetch(url: URL) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        return try await NetworkSession.shared.data(for: req)
    }

    // MARK: - Album / Track Artwork

    /// Resolves high-resolution album/track artwork from Apple Music.
    /// Strictly verifies artist, title, and album to avoid false matches.
    /// Returns nil if not found on Apple Music, allowing caller to fall back to YT Music's original artwork.
    public func getAlbumArt(
        title: String,
        artist: String,
        album: String? = nil
    ) async -> String? {
        let cleanTitle = SaavnStreamingService.cleanTitle(title, artist: artist)
        let cleanArtist = SaavnStreamingService.cleanArtist(artist)
        let cleanAlbum = (album ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanArtist.isEmpty && cleanArtist != "Unknown Artist" && cleanArtist != "Artist" else {
            return nil
        }

        let isExplicitAlbumRequest = (!cleanAlbum.isEmpty && cleanAlbum.lowercased() == cleanTitle.lowercased()) || cleanTitle.isEmpty

        let cacheKey = "\(cleanTitle.lowercased())::\(cleanArtist.lowercased())::\(cleanAlbum.lowercased())"

        if let cached = artworkCache[cacheKey] {
            return cached
        }
        if negativeArtworkCache.contains(cacheKey) {
            return nil
        }

        // Case A: Resolving an Album's artwork (from AlbumDetailView or fetchAlbum)
        if isExplicitAlbumRequest {
            let targetAlbum = cleanAlbum.isEmpty ? cleanTitle : cleanAlbum
            if let art = await searchAlbumArtwork(albumName: targetAlbum, artistName: cleanArtist) {
                artworkCache[cacheKey] = art
                return art
            }
            negativeArtworkCache.insert(cacheKey)
            return nil
        }

        // Case B: Resolving a Track's album artwork (from AudioPlayerService)
        if let art = await searchTrackArtwork(trackTitle: cleanTitle, artistName: cleanArtist, albumName: cleanAlbum) {
            artworkCache[cacheKey] = art
            return art
        }

        negativeArtworkCache.insert(cacheKey)
        return nil
    }

    // MARK: - Album Artwork Search
    private func searchAlbumArtwork(
        albumName: String,
        artistName: String
    ) async -> String? {
        let cleanAlbum = SaavnStreamingService.cleanTitle(albumName, artist: artistName)
        guard !cleanAlbum.isEmpty && cleanAlbum != "Album" else { return nil }

        let query = "\(cleanAlbum) \(artistName)".trimmingCharacters(in: .whitespaces)
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=album&limit=10") else {
            return nil
        }

        do {
            let (data, response) = try await fetch(url: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]], !results.isEmpty else {
                return nil
            }

            let normTargetAlbum = normalize(cleanAlbum)
            let normTargetArtist = normalize(artistName)

            for item in results {
                let collectionName = item["collectionName"] as? String ?? ""
                let resArtist = item["artistName"] as? String ?? ""
                guard let rawArt = item["artworkUrl100"] as? String, !rawArt.isEmpty else { continue }

                let artistMatches = matchArtist(res: resArtist, target: normTargetArtist)
                let albumMatches = matchAlbum(res: collectionName, target: normTargetAlbum)

                if artistMatches && albumMatches {
                    return formatHighResArtwork(rawArt)
                }
            }

            return nil
        } catch {
            return nil
        }
    }

    // MARK: - Track Artwork Search
    private func searchTrackArtwork(
        trackTitle: String,
        artistName: String,
        albumName: String?
    ) async -> String? {
        let cleanTitle = SaavnStreamingService.cleanTitle(trackTitle, artist: artistName)
        guard !cleanTitle.isEmpty else { return nil }

        let query = "\(cleanTitle) \(artistName)".trimmingCharacters(in: .whitespaces)
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=10") else {
            return nil
        }

        do {
            let (data, response) = try await fetch(url: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]], !results.isEmpty else {
                return nil
            }

            let normTargetTitle = normalize(cleanTitle)
            let normTargetArtist = normalize(artistName)
            let normTargetAlbum = normalize(albumName ?? "")
            let hasAlbum = !normTargetAlbum.isEmpty && normTargetAlbum != "album" && normTargetAlbum != "unknown album"

            var fallbackMatch: String?
            for item in results {
                guard let rawArt = item["artworkUrl100"] as? String, !rawArt.isEmpty else { continue }
                let resTitle = item["trackName"] as? String ?? ""
                let resArtist = item["artistName"] as? String ?? ""
                let resAlbum = item["collectionName"] as? String ?? ""

                guard matchArtist(res: resArtist, target: normTargetArtist),
                      matchTitle(res: resTitle, target: normTargetTitle) else { continue }

                if hasAlbum && matchAlbum(res: resAlbum, target: normTargetAlbum) {
                    return formatHighResArtwork(rawArt)
                }

                if fallbackMatch == nil {
                    let normAlbum = normalize(resAlbum)
                    let isJunk = normAlbum.contains("karaoke") || normAlbum.contains("tribute") ||
                                 normAlbum.contains("ringtone") || normAlbum.contains("instrumental")
                    if !isJunk {
                        fallbackMatch = formatHighResArtwork(rawArt)
                    }
                }
            }

            return fallbackMatch
        } catch {
            return nil
        }
    }

    // MARK: - Artist Pictures

    /// Resolves official high-resolution artist photo from Apple Music.
    /// Returns nil if not found on Apple Music, so caller falls back to YT Music.
    public func getArtistPicture(artistName: String) async -> String? {
        let cleanName = SaavnStreamingService.cleanArtist(artistName)
        guard !cleanName.isEmpty else { return nil }

        let cacheKey = cleanName.lowercased()
        if let cached = artistPictureCache[cacheKey] {
            return cached
        }
        if negativeArtistCache.contains(cacheKey) {
            return nil
        }

        guard let encoded = cleanName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=musicArtist&limit=3") else {
            return nil
        }

        do {
            let (data, response) = try await fetch(url: searchUrl)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]], !results.isEmpty else {
                negativeArtistCache.insert(cacheKey)
                return nil
            }

            let normTarget = normalize(cleanName)
            var matchedArtistLink: String?

            for item in results {
                let name = normalize(item["artistName"] as? String ?? "")
                if name == normTarget || name.contains(normTarget) || normTarget.contains(name) {
                    if let link = item["artistLinkUrl"] as? String, !link.isEmpty {
                        matchedArtistLink = link
                        break
                    }
                }
            }

            if matchedArtistLink == nil, let firstLink = results.first?["artistLinkUrl"] as? String {
                matchedArtistLink = firstLink
            }

            guard let linkString = matchedArtistLink, let pageUrl = URL(string: linkString) else {
                negativeArtistCache.insert(cacheKey)
                return nil
            }

            var pageReq = URLRequest(url: pageUrl)
            pageReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            pageReq.timeoutInterval = 4

            let (htmlData, pageResp) = try await NetworkSession.shared.data(for: pageReq)
            guard let pageHttp = pageResp as? HTTPURLResponse, pageHttp.statusCode == 200,
                  let html = String(data: htmlData, encoding: .utf8) else {
                negativeArtistCache.insert(cacheKey)
                return nil
            }

            let pattern = #"<meta\s+(?:property=["']og:image["']|name=["']twitter:image["'])\s+content=["']([^"']+)["']"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                var imgUrl = String(html[range])
                if imgUrl.contains("mzstatic.com") {
                    imgUrl = imgUrl.replacingOccurrences(of: "cw.png", with: "cc.png")
                                   .replacingOccurrences(of: "cw.jpg", with: "cc.jpg")
                    artistPictureCache[cacheKey] = imgUrl
                    return imgUrl
                }
            }

            negativeArtistCache.insert(cacheKey)
            return nil
        } catch {
            negativeArtistCache.insert(cacheKey)
            return nil
        }
    }

    // MARK: - Matching Utilities

    private func matchArtist(res: String, target: String) -> Bool {
        let r = normalize(res)
        let t = normalize(target)
        if r.isEmpty || t.isEmpty { return false }
        if r == t || r.contains(t) || t.contains(r) { return true }
        return false
    }

    private func matchTitle(res: String, target: String) -> Bool {
        let r = normalize(res)
        let t = normalize(target)
        if r.isEmpty || t.isEmpty { return false }
        if r == t || r.hasPrefix(t) || t.hasPrefix(r) { return true }
        return false
    }

    private func matchAlbum(res: String, target: String) -> Bool {
        let r = normalize(res)
        let t = normalize(target)
        if r.isEmpty || t.isEmpty { return false }
        if r == t || r.contains(t) || t.contains(r) { return true }
        return false
    }

    private func formatHighResArtwork(_ urlString: String) -> String {
        urlString
            .replacingOccurrences(of: "100x100bb.jpg", with: "1000x1000bb.jpg")
            .replacingOccurrences(of: "60x60bb.jpg", with: "1000x1000bb.jpg")
            .replacingOccurrences(of: "100x100bb.png", with: "1000x1000bb.png")
            .replacingOccurrences(of: "60x60bb.png", with: "1000x1000bb.png")
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
