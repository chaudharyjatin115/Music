//
//  SaavnStreamingService.swift
//  Music
//
//  Provides high-quality (up to 320kbps AAC) audio streaming from JioSaavn.
//

import Foundation
import CommonCrypto

public struct SaavnStream: Sendable {
    public let url: URL
    public let bitrate: Int
    public let qualityTitle: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double?
    public let artworkURL: String?

    public init(
        url: URL,
        bitrate: Int = 320_000,
        qualityTitle: String = "Saavn 320kbps AAC (HQ)",
        title: String,
        artist: String,
        album: String = "",
        duration: Double? = nil,
        artworkURL: String? = nil
    ) {
        self.url = url
        self.bitrate = bitrate
        self.qualityTitle = qualityTitle
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
    }
}

private extension Dictionary {
    mutating func setBounded(_ value: Value, for key: Key, limit: Int = 60) {
        if count >= limit { removeAll(keepingCapacity: true) }
        self[key] = value
    }
}

private extension Set {
    mutating func insertBounded(_ member: Element, limit: Int = 60) {
        if count >= limit { removeAll(keepingCapacity: true) }
        insert(member)
    }
}

public actor SaavnStreamingService {
    public static let shared = SaavnStreamingService()

    private var streamCache: [String: SaavnStream] = [:]
    private var negativeCache: Set<String> = []

    private let desKey = "38346591"

    private init() {}

    private func fetch(url: URL, timeout: TimeInterval = 6) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        req.timeoutInterval = timeout
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        return try await NetworkSession.shared.data(for: req)
    }

    /// Attempts to find and resolve a 320kbps audio stream from JioSaavn for the given track.
    /// Returns nil if the song is not found or cannot be resolved, allowing fallback to YT Music.
    public func resolveStream(
        title: String,
        artist: String,
        duration: Double? = nil
    ) async -> SaavnStream? {
        let cleanTitle = Self.cleanTitle(title, artist: artist)
        let cleanArtist = Self.cleanArtist(artist)
        let cacheKey = "\(cleanTitle.lowercased())::\(cleanArtist.lowercased())"

        if let cached = streamCache[cacheKey] {
            return cached
        }
        if negativeCache.contains(cacheKey) {
            return nil
        }

        // Search Saavn API
        let query = "\(cleanTitle) \(cleanArtist)".trimmingCharacters(in: .whitespaces)
        guard let songs = await searchSaavnSongs(query: query), !songs.isEmpty else {
            // Try searching just clean title if combined search yields nothing
            if let fallbackSongs = await searchSaavnSongs(query: cleanTitle), !fallbackSongs.isEmpty {
                if let match = matchBestSong(songs: fallbackSongs, targetTitle: cleanTitle, targetArtist: cleanArtist, targetDuration: duration) {
                    if let stream = await resolveStreamFromCandidate(match) {
                        streamCache.setBounded(stream, for: cacheKey)
                        return stream
                    }
                }
            }
            negativeCache.insertBounded(cacheKey)
            return nil
        }

        guard let bestMatch = matchBestSong(songs: songs, targetTitle: cleanTitle, targetArtist: cleanArtist, targetDuration: duration) else {
            negativeCache.insertBounded(cacheKey)
            return nil
        }

        if let stream = await resolveStreamFromCandidate(bestMatch) {
            streamCache.setBounded(stream, for: cacheKey)
            return stream
        }

        negativeCache.insertBounded(cacheKey)
        return nil
    }

    // MARK: - API & Decryption

    private struct SaavnCandidate {
        let id: String
        let title: String
        let artist: String
        let album: String
        let duration: Double?
        let encryptedMediaUrl: String
        let image: String?
    }

    private func searchSaavnSongs(query: String) async -> [SaavnCandidate]? {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.jiosaavn.com/api.php?__call=search.getResults&q=\(encoded)&_format=json&_marker=0&api_version=4&ctx=web6dot0&n=6&p=1") else {
            return nil
        }

        do {
            let (data, response) = try await fetch(url: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                return nil
            }

            var candidates: [SaavnCandidate] = []
            for item in results {
                guard let id = item["id"] as? String,
                      let rawTitle = item["title"] as? String else { continue }

                let decodedTitle = Self.decodeHTMLEntities(rawTitle)
                let moreInfo = item["more_info"] as? [String: Any] ?? [:]
                guard let enc = moreInfo["encrypted_media_url"] as? String, !enc.isEmpty else {
                    continue
                }

                // Parse artist
                var artistName = ""
                if let artistMap = moreInfo["artistMap"] as? [String: Any],
                   let primaryArtists = artistMap["primary_artists"] as? [[String: Any]],
                   let first = primaryArtists.first,
                   let name = first["name"] as? String {
                    artistName = name
                } else if let music = moreInfo["music"] as? String, !music.isEmpty {
                    artistName = music
                } else if let sub = item["subtitle"] as? String {
                    artistName = sub.components(separatedBy: " - ").first ?? sub
                }

                let album = moreInfo["album"] as? String ?? ""
                let durationSec: Double? = {
                    if let dStr = moreInfo["duration"] as? String, let d = Double(dStr) { return d }
                    if let dNum = moreInfo["duration"] as? Double { return dNum }
                    return nil
                }()
                let img = item["image"] as? String

                candidates.append(SaavnCandidate(
                    id: id,
                    title: decodedTitle,
                    artist: Self.decodeHTMLEntities(artistName),
                    album: Self.decodeHTMLEntities(album),
                    duration: durationSec,
                    encryptedMediaUrl: enc,
                    image: img
                ))
            }

            return candidates
        } catch {
            return nil
        }
    }

    private func resolveStreamFromCandidate(_ candidate: SaavnCandidate) async -> SaavnStream? {
        guard let decryptedUrlString = decryptDES(base64: candidate.encryptedMediaUrl, key: desKey) else {
            return nil
        }

        // Saavn typically serves 96kbps, 160kbps, and 320kbps MP4/AAC streams
        // Attempt to upgrade to 320kbps
        let u320 = decryptedUrlString
            .replacingOccurrences(of: "_96.mp4", with: "_320.mp4")
            .replacingOccurrences(of: "_160.mp4", with: "_320.mp4")
            .replacingOccurrences(of: "_48.mp4", with: "_320.mp4")

        var chosenUrlString = u320
        var bitrate = 320_000
        var qualityTitle = "Saavn 320kbps AAC (HQ)"

        // Quick verification of the 320kbps URL
        if let checkURL = URL(string: u320) {
            var headReq = URLRequest(url: checkURL)
            headReq.httpMethod = "HEAD"
            headReq.timeoutInterval = 2.5
            if let (_, resp) = try? await NetworkSession.shared.data(for: headReq),
               let http = resp as? HTTPURLResponse, http.statusCode == 200 {
                chosenUrlString = u320
                bitrate = 320_000
            } else {
                // If 320 is not available, try 160kbps or the base decrypted URL
                let u160 = decryptedUrlString
                    .replacingOccurrences(of: "_96.mp4", with: "_160.mp4")
                    .replacingOccurrences(of: "_48.mp4", with: "_160.mp4")
                chosenUrlString = u160
                bitrate = 160_000
                qualityTitle = "Saavn 160kbps AAC"
            }
        }

        guard let finalURL = URL(string: chosenUrlString) else { return nil }

        // Upgrade image URL to high quality 500x500
        let artUrl = candidate.image?
            .replacingOccurrences(of: "150x150.jpg", with: "500x500.jpg")
            .replacingOccurrences(of: "50x50.jpg", with: "500x500.jpg")

        return SaavnStream(
            url: finalURL,
            bitrate: bitrate,
            qualityTitle: qualityTitle,
            title: candidate.title,
            artist: candidate.artist,
            album: candidate.album,
            duration: candidate.duration,
            artworkURL: artUrl
        )
    }

    // MARK: - Matching Logic

    private func matchBestSong(
        songs: [SaavnCandidate],
        targetTitle: String,
        targetArtist: String,
        targetDuration: Double?
    ) -> SaavnCandidate? {
        let normTargetTitle = Self.normalizeText(targetTitle)
        let normTargetArtist = Self.normalizeText(targetArtist)

        var bestScore = -1
        var bestCandidate: SaavnCandidate?

        for song in songs {
            let normSongTitle = Self.normalizeText(song.title)
            let normSongArtist = Self.normalizeText(song.artist)

            var score = 0

            // 1. Title Matching
            if normSongTitle == normTargetTitle {
                score += 50
            } else if normSongTitle.contains(normTargetTitle) || normTargetTitle.contains(normSongTitle) {
                score += 35
            } else {
                // Word overlap
                let tWords = Set(normTargetTitle.split(separator: " ").filter { $0.count > 2 })
                let sWords = Set(normSongTitle.split(separator: " ").filter { $0.count > 2 })
                let common = tWords.intersection(sWords)
                if !common.isEmpty {
                    score += 20 * common.count
                }
            }

            // 2. Artist Matching
            if !normTargetArtist.isEmpty {
                if normSongArtist == normTargetArtist {
                    score += 40
                } else if normSongArtist.contains(normTargetArtist) || normTargetArtist.contains(normSongArtist) {
                    score += 30
                } else {
                    let aWords = Set(normTargetArtist.split(separator: " ").filter { $0.count > 2 })
                    let saWords = Set(normSongArtist.split(separator: " ").filter { $0.count > 2 })
                    let common = aWords.intersection(saWords)
                    if !common.isEmpty {
                        score += 20
                    }
                }
            } else {
                // No target artist provided, rely on title
                score += 15
            }

            // 3. Duration Proximity Check (if available)
            if let td = targetDuration, td > 0, let sd = song.duration, sd > 0 {
                let diff = abs(td - sd)
                if diff <= 6 {
                    score += 15
                } else if diff <= 15 {
                    score += 8
                } else if diff > 60 {
                    score -= 25 // likely different version / remix / intro
                }
            }

            if score > bestScore {
                bestScore = score
                bestCandidate = song
            }
        }

        // Require minimum confidence score to avoid false positives
        if bestScore >= 40 {
            return bestCandidate
        }

        return nil
    }

    // MARK: - Cryptography (DES-ECB PKCS7)

    private func decryptDES(base64: String, key: String) -> String? {
        guard let data = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines)),
              let keyData = key.data(using: .utf8) else {
            return nil
        }

        var decryptedData = Data(count: data.count + kCCBlockSizeDES)
        var numBytesDecrypted: size_t = 0

        let cryptStatus = decryptedData.withUnsafeMutableBytes { decryptedBytes in
            data.withUnsafeBytes { dataBytes in
                keyData.withUnsafeBytes { keyBytes in
                    CCCrypt(
                        CCOperation(kCCDecrypt),
                        CCAlgorithm(kCCAlgorithmDES),
                        CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                        keyBytes.baseAddress,
                        kCCKeySizeDES,
                        nil,
                        dataBytes.baseAddress,
                        data.count,
                        decryptedBytes.baseAddress,
                        decryptedBytes.count,
                        &numBytesDecrypted
                    )
                }
            }
        }

        guard cryptStatus == kCCSuccess else { return nil }
        decryptedData.count = numBytesDecrypted
        return String(data: decryptedData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Cleaners & Helpers

    private static let cleanTitleRegexes: [NSRegularExpression] = [
        #"\s*[\(\[](official\s*)?(music\s*)?(video|audio|lyric\s*video|visualizer|hd|4k|remastered[^\)\]]*)[\)\]]"#,
        #"\s*[\(\[](feat|ft)\.?\s+[^\)\]]+[\)\]]"#,
        #"\s*[\(\[]live[^\)\]]*[\)\]]"#,
        #"\s*[\(\[]full\s+song[\)\]]"#
    ].compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }

    public static func cleanTitle(_ title: String, artist: String? = nil) -> String {
        var cleaned = title

        for regex in cleanTitleRegexes {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }

        // If title is "Artist - Song Title", extract just the song title
        if cleaned.contains(" - ") {
            let parts = cleaned.components(separatedBy: " - ")
            if parts.count >= 2 {
                let left = parts[0].trimmingCharacters(in: .whitespaces)
                let right = parts[1].trimmingCharacters(in: .whitespaces)
                if let a = artist, !a.isEmpty,
                   left.localizedCaseInsensitiveContains(a) || a.localizedCaseInsensitiveContains(left) {
                    cleaned = right
                }
            }
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func cleanArtist(_ artist: String) -> String {
        var cleaned = artist
        let junk = [" - Topic", "VEVO", " Official", " Official Channel"]
        for j in junk {
            cleaned = cleaned.replacingOccurrences(of: j, with: "", options: .caseInsensitive)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeText(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
