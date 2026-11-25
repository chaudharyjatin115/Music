import Foundation

public struct EclipseAddonManifest: Codable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let description: String?
    public let types: [String]?
}

public struct EclipseAddon: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var version: String
    public var description: String
    public var baseUrl: String
    public var isEnabled: Bool

    public init(
        id: String,
        name: String,
        version: String = "1.0.0",
        description: String = "",
        baseUrl: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.baseUrl = baseUrl
        self.isEnabled = isEnabled
    }
}

@MainActor
public final class EclipseAddonService: ObservableObject {
    public static let shared = EclipseAddonService()

    @Published public var addons: [EclipseAddon] = []

    private let storageKey = "com.music.app.eclipse_addons"

    private init() {
        loadAddons()
    }

    public func loadAddons() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([EclipseAddon].self, from: data) {
            self.addons = saved
        }
    }

    public func saveAddons() {
        if let data = try? JSONEncoder().encode(addons) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func isLocalHost(_ host: String) -> Bool {
        let lower = host.lowercased()
        return lower == "localhost"
            || lower == "127.0.0.1"
            || lower == "::1"
            || lower == "[::1]"
            || lower.hasSuffix(".local")
            || lower.hasPrefix("192.168.")
            || lower.hasPrefix("10.")
    }

    private static func isAllowedAddonURL(_ url: URL, allowHTTPForLocalOnly: Bool = true) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              let host = url.host, !host.isEmpty else { return false }
        if scheme == "https" { return true }
        if scheme == "http" {
            return !allowHTTPForLocalOnly || isLocalHost(host)
        }
        return false
    }

    private static func sanitizeIdentifier(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = raw.unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(cleaned))
    }

    /// Connect and install an Eclipse addon from its base URL (HTTPS required for non-local hosts)
    public func addAddon(urlString: String) async throws -> EclipseAddon {
        var cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleanUrl.hasSuffix("/") {
            cleanUrl = String(cleanUrl.dropLast())
        }
        if !cleanUrl.contains("://") {
            let hostCandidate = cleanUrl.split(separator: "/").first?.split(separator: ":").first.map(String.init) ?? ""
            cleanUrl = (Self.isLocalHost(hostCandidate) ? "http://" : "https://") + cleanUrl
        }

        guard let baseURL = URL(string: cleanUrl),
              Self.isAllowedAddonURL(baseURL),
              let manifestUrl = URL(string: "\(cleanUrl)/manifest.json") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: manifestUrl)
        request.timeoutInterval = 8
        let (data, response) = try await NetworkSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let manifest = try JSONDecoder().decode(EclipseAddonManifest.self, from: data)
        let safeId = Self.sanitizeIdentifier(manifest.id)
        guard !safeId.isEmpty else {
            throw URLError(.badServerResponse)
        }

        let addon = EclipseAddon(
            id: safeId,
            name: manifest.name,
            version: manifest.version,
            description: manifest.description ?? "Self-hosted music source",
            baseUrl: cleanUrl,
            isEnabled: true
        )

        // Remove existing duplicate if present
        addons.removeAll { $0.id == addon.id || $0.baseUrl == cleanUrl }
        addons.append(addon)
        saveAddons()
        return addon
    }

    public func removeAddon(id: String) {
        addons.removeAll { $0.id == id }
        saveAddons()
    }

    public func toggleAddon(id: String) {
        if let index = addons.firstIndex(where: { $0.id == id }) {
            addons[index].isEnabled.toggle()
            saveAddons()
        }
    }

    /// Search across all enabled self-hosted Eclipse addons
    public func search(query: String) async -> [Song] {
        let enabled = addons.filter { $0.isEnabled }
        guard !enabled.isEmpty else { return [] }

        var results: [Song] = []

        for addon in enabled {
            guard var components = URLComponents(string: addon.baseUrl) else { continue }
            components.path = (components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path) + "/search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
            guard let searchUrl = components.url, Self.isAllowedAddonURL(searchUrl) else { continue }
            var req = URLRequest(url: searchUrl)
            req.timeoutInterval = 6

            guard let (data, resp) = try? await NetworkSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let items = (json["results"] as? [[String: Any]]) ?? (json["tracks"] as? [[String: Any]]) ?? []
            for item in items {
                let rawTrackId = (item["id"] as? String) ?? (item["trackId"] as? String) ?? UUID().uuidString
                let trackId = rawTrackId.replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "..", with: "_")
                let title = (item["title"] as? String) ?? "Untitled Track"
                let artist = (item["artist"] as? String) ?? addon.name
                let album = item["album"] as? String
                let duration = (item["duration"] as? Double) ?? 180.0
                let rawThumb = (item["thumbnail"] as? String) ?? (item["cover"] as? String) ?? ""
                let thumb: String = {
                    guard let thumbURL = URL(string: rawThumb),
                          Self.isAllowedAddonURL(thumbURL, allowHTTPForLocalOnly: true) else { return "" }
                    return thumbURL.absoluteString
                }()

                let song = Song(
                    id: "eclipse:\(addon.id):\(trackId)",
                    title: title,
                    artist: "\(artist) [\(addon.name)]",
                    album: album ?? "",
                    duration: duration,
                    thumbnailUrl: thumb
                )
                results.append(song)
            }
        }
        return results
    }

    /// Resolve playable direct audio stream URL from an Eclipse addon
    public func resolveStreamUrl(songId: String) async -> String? {
        // Expected format: eclipse:<addonId>:<trackId>
        let components = songId.components(separatedBy: ":")
        guard components.count >= 3, components[0] == "eclipse" else { return nil }

        let addonId = components[1]
        let trackId = components.dropFirst(2).joined(separator: ":")
        guard !trackId.isEmpty, !trackId.contains(".."), !trackId.contains("/") else { return nil }

        guard let addon = addons.first(where: { $0.id == addonId }), addon.isEnabled else { return nil }
        guard let encodedTrackId = trackId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let streamEndpoint = URL(string: "\(addon.baseUrl)/stream/\(encodedTrackId)"),
              Self.isAllowedAddonURL(streamEndpoint) else { return nil }
        var req = URLRequest(url: streamEndpoint)
        req.timeoutInterval = 6

        // If the endpoint directly streams audio (HTTP 200 or 302 redirect), return the URL directly
        if let (data, resp) = try? await NetworkSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse {
            if let mime = http.mimeType, mime.starts(with: "audio/") || mime.contains("octet-stream") {
                return streamEndpoint.absoluteString
            }
            // Or if JSON is returned: { "url": "https://..." }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let streamUrl = json["url"] as? String,
               let parsed = URL(string: streamUrl),
               Self.isAllowedAddonURL(parsed) {
                return parsed.absoluteString
            }
        }

        return streamEndpoint.absoluteString
    }
}
