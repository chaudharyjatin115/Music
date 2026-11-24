import Foundation

@MainActor
public final class ListenBrainzService: ObservableObject {
    public static let shared = ListenBrainzService()

    @Published public var apiToken: String = "" {
        didSet {
            if apiToken.isEmpty {
                Keychain.delete(service: keychainService, account: keychainAccount)
            } else {
                Keychain.setString(apiToken, service: keychainService, account: keychainAccount)
            }
            UserDefaults.standard.removeObject(forKey: tokenKey)
            if !apiToken.isEmpty {
                validateToken()
            } else {
                isValid = false
                username = ""
            }
        }
    }

    @Published public var isValid: Bool = false
    @Published public var username: String = ""
    @Published public var lastScrobbleStatus: String = ""

    private let keychainService = "com.music.app"
    private let keychainAccount = "listenbrainz_token"
    private let tokenKey = "com.music.app.listenbrainz_token"
    private let baseUrl = "https://api.listenbrainz.org/1"
    private let session = URLSession(configuration: .default)

    private var currentPlayingSongId: String?
    private var hasSubmittedSingleListen: Bool = false

    private init() {
        if let token = Keychain.getString(service: keychainService, account: keychainAccount), !token.isEmpty {
            self.apiToken = token
            UserDefaults.standard.removeObject(forKey: tokenKey)
        } else if let legacyToken = UserDefaults.standard.string(forKey: tokenKey), !legacyToken.isEmpty {
            self.apiToken = legacyToken
            Keychain.setString(legacyToken, service: keychainService, account: keychainAccount)
            UserDefaults.standard.removeObject(forKey: tokenKey)
        } else {
            self.apiToken = ""
        }
        if !apiToken.isEmpty {
            validateToken()
        }
    }

    public func validateToken() {
        guard !apiToken.isEmpty else {
            self.isValid = false
            self.username = ""
            return
        }

        guard let url = URL(string: "\(baseUrl)/validate-token") else { return }
        var request = URLRequest(url: url)
        request.setValue("Token \(apiToken)", forHTTPHeaderField: "Authorization")

        Task {
            do {
                let (data, _) = try await session.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let valid = json["valid"] as? Bool, valid {
                    self.isValid = true
                    self.username = json["user_name"] as? String ?? "User"
                    self.lastScrobbleStatus = "Connected as \(self.username)"
                } else {
                    self.isValid = false
                    self.lastScrobbleStatus = "Invalid Token"
                }
            } catch {
                self.isValid = false
                self.lastScrobbleStatus = "Validation Error"
            }
        }
    }

    public func onTrackStart(song: Song) {
        guard isValid, !apiToken.isEmpty else { return }
        currentPlayingSongId = song.id
        hasSubmittedSingleListen = false

        Task {
            await submitListen(song: song, listenType: "playing_now", timestamp: nil)
        }
    }

    public func onTrackProgress(song: Song, currentTime: TimeInterval, duration: TimeInterval) {
        guard isValid, !apiToken.isEmpty, !hasSubmittedSingleListen else { return }
        guard currentPlayingSongId == song.id else { return }

        // Standard scrobble rules: 50% played or 240 seconds played
        let threshold = min(duration * 0.5, 240.0)
        if duration > 10, currentTime >= threshold {
            hasSubmittedSingleListen = true
            let listenTime = Int(Date().timeIntervalSince1970)

            Task {
                await submitListen(song: song, listenType: "single", timestamp: listenTime)
            }
        }
    }

    private func submitListen(song: Song, listenType: String, timestamp: Int?) async {
        guard let url = URL(string: "\(baseUrl)/submit-listens") else { return }

        var payloadItem: [String: Any] = [
            "track_metadata": [
                "artist_name": song.artist,
                "track_name": song.title,
                "release_name": song.album.isEmpty ? song.title : song.album,
                "additional_info": [
                    "submission_client": "Music macOS",
                    "submission_client_version": "1.0.0",
                    "music_service": "youtube.com",
                    "youtube_id": song.id
                ]
            ]
        ]

        if let timestamp = timestamp {
            payloadItem["listened_at"] = timestamp
        }

        let body: [String: Any] = [
            "listen_type": listenType,
            "payload": [payloadItem]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(apiToken)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if listenType == "single" {
                    self.lastScrobbleStatus = "Scrobbled: \(song.title)"
                }
            }
        } catch {
            print("ListenBrainz submit error: \(error)")
        }
    }
}
