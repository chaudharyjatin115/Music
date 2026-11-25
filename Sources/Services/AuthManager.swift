import Foundation
import CryptoKit
import WebKit

@MainActor
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    @Published public var isLoggedIn: Bool = false
    @Published public var userDisplayName: String = "Guest"
    @Published public var userEmail: String = ""
    @Published public var userAvatarUrl: String = ""
    @Published public var userChannelId: String = ""
    @Published public var cookies: [String: String] = [:]

    private let cookiesKey = "com.music.app.cookies"
    private let userDisplayNameKey = "com.music.app.userDisplayName"
    private let userEmailKey = "com.music.app.userEmail"
    private let userAvatarUrlKey = "com.music.app.userAvatarUrl"
    private let userChannelIdKey = "com.music.app.userChannelId"

    private init() {
        loadStoredSession()
        Task {
            await syncCredentialStore()
            await fetchUserProfile()
        }
    }

    public func loadStoredSession() {
        self.userDisplayName = UserDefaults.standard.string(forKey: userDisplayNameKey) ?? "YouTube Music User"
        self.userEmail = UserDefaults.standard.string(forKey: userEmailKey) ?? ""
        self.userAvatarUrl = UserDefaults.standard.string(forKey: userAvatarUrlKey) ?? ""
        self.userChannelId = UserDefaults.standard.string(forKey: userChannelIdKey) ?? ""

        let service = "moe.tenshii.YT-Music"
        let account = "youtube-credentials"

        if let data = Keychain.get(service: service, account: account),
           let stored = try? JSONDecoder().decode(Credentials.self, from: data),
           stored.isUsable {
            self.cookies = stored.cookies
            self.isLoggedIn = true
            UserDefaults.standard.removeObject(forKey: cookiesKey)
            return
        }

        if let data = UserDefaults.standard.data(forKey: cookiesKey),
           let savedCookies = try? JSONDecoder().decode([String: String].self, from: data),
           !savedCookies.isEmpty {
            self.cookies = savedCookies
            self.isLoggedIn = savedCookies["SAPISID"] != nil || savedCookies["__Secure-3PAPISID"] != nil || savedCookies["SID"] != nil
            UserDefaults.standard.removeObject(forKey: cookiesKey)
            let creds = Credentials(cookies: savedCookies)
            if let enc = try? JSONEncoder().encode(creds) {
                Keychain.set(enc, service: service, account: account)
            }
        } else {
            self.isLoggedIn = false
            self.cookies = [:]
            self.userChannelId = ""
        }
    }

    private func syncCredentialStore() async {
        if !cookies.isEmpty {
            let creds = Credentials(cookies: cookies)
            await CredentialStore.shared.update(creds)
        } else if let creds = await CredentialStore.shared.credentials, creds.isUsable {
            self.cookies = creds.cookies
            self.isLoggedIn = true
        }
        UserDefaults.standard.removeObject(forKey: cookiesKey)
    }

    public func saveCookies(_ newCookies: [String: String]) {
        let sanitized = Credentials.sanitizeCookies(newCookies)
        self.cookies = sanitized
        UserDefaults.standard.removeObject(forKey: cookiesKey)
        self.isLoggedIn = sanitized["SAPISID"] != nil || sanitized["__Secure-3PAPISID"] != nil || sanitized["SID"] != nil

        Task {
            let creds = Credentials(cookies: sanitized)
            await CredentialStore.shared.update(creds)
            await fetchUserProfile()
        }
    }

    public func updateUserInfo(name: String, email: String = "", avatarUrl: String) {
        self.userDisplayName = name
        self.userEmail = email
        self.userAvatarUrl = avatarUrl
        UserDefaults.standard.set(name, forKey: userDisplayNameKey)
        UserDefaults.standard.set(email, forKey: userEmailKey)
        UserDefaults.standard.set(avatarUrl, forKey: userAvatarUrlKey)
    }

    public func signOut() {
        self.cookies = [:]
        self.isLoggedIn = false
        self.userDisplayName = "Guest"
        self.userEmail = ""
        self.userAvatarUrl = ""
        self.userChannelId = ""
        UserDefaults.standard.removeObject(forKey: cookiesKey)
        UserDefaults.standard.removeObject(forKey: userDisplayNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userAvatarUrlKey)
        UserDefaults.standard.removeObject(forKey: userChannelIdKey)

        Task {
            await CredentialStore.shared.clear()
            let store = WKWebsiteDataStore.default()
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            let records = await store.dataRecords(ofTypes: types)
            await store.removeData(ofTypes: types, for: records)
        }
    }

    public func fetchUserProfile() async {
        guard isLoggedIn else { return }

        if let info = try? await InnerTubeClient.shared.accountInfo() {
            self.userDisplayName = info.name
            self.userAvatarUrl = info.avatarURL?.absoluteString ?? ""
            if let cid = info.channelId, !cid.isEmpty {
                self.userChannelId = cid
                UserDefaults.standard.set(cid, forKey: userChannelIdKey)
            }
            UserDefaults.standard.set(self.userDisplayName, forKey: userDisplayNameKey)
            UserDefaults.standard.set(self.userAvatarUrl, forKey: userAvatarUrlKey)
            return
        }

        let cookieStr = cookieHeaderString
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/account/account_menu") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(cookieStr, forHTTPHeaderField: "Cookie")
        if let authHeader = generateSapisidHash() {
            req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        req.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        req.setValue("21", forHTTPHeaderField: "X-YouTube-Client-Name")
        req.setValue("1.20240101.01.00", forHTTPHeaderField: "X-YouTube-Client-Version")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20240101.01.00",
                    "hl": "en",
                    "gl": "US"
                ]
            ]
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        req.httpBody = httpBody

        do {
            let (data, _) = try await NetworkSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let actions = json["actions"] as? [[String: Any]] {
                for act in actions {
                    if let openPopup = act["openPopupAction"] as? [String: Any],
                       let popup = openPopup["popup"] as? [String: Any],
                       let menu = popup["multiPageMenuRenderer"] as? [String: Any],
                       let header = menu["header"] as? [String: Any],
                       let accHeader = header["activeAccountHeaderRenderer"] as? [String: Any] {

                        var name = "User"
                        var avatar = ""

                        if let accName = accHeader["accountName"] as? [String: Any],
                           let runs = accName["runs"] as? [[String: Any]],
                           let first = runs.first,
                           let txt = first["text"] as? String {
                            name = txt
                        }

                        if let accPhoto = accHeader["accountPhoto"] as? [String: Any],
                           let thumbs = accPhoto["thumbnails"] as? [[String: Any]],
                           let last = thumbs.last,
                           let url = last["url"] as? String {
                            avatar = url
                        }

                        self.userDisplayName = name
                        self.userAvatarUrl = avatar
                        UserDefaults.standard.set(name, forKey: self.userDisplayNameKey)
                        UserDefaults.standard.set(avatar, forKey: self.userAvatarUrlKey)
                        break
                    }
                }
            }
        } catch {
            print("Failed to fetch account profile: \(error)")
        }
    }

    public var cookieHeaderString: String {
        return cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    public func generateSapisidHash(origin: String = "https://music.youtube.com") -> String? {
        guard let sapisid = cookies["SAPISID"] ?? cookies["__Secure-3PAPISID"] else { return nil }
        let now = Date()
        return Credentials.sapisidHash(sapisid: sapisid, origin: origin, now: now)
    }
}
