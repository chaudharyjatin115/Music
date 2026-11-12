import SwiftUI
import WebKit

public struct WebSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @State private var isLoading = true
    @State private var selectedTab: Int = 0
    @State private var manualCookiesInput = ""
    @State private var manualNameInput = ""
    @State private var manualError: String? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .foregroundStyle(.pink)
                        .font(.title2)
                    Text("Sign in to YouTube Music")
                        .font(.headline)
                }

                Spacer()

                Picker("", selection: $selectedTab) {
                    Text("Web Sign In").tag(0)
                    Text("Paste Cookies / Token").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Spacer()

                if isLoading && selectedTab == 0 {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 8)
                }

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Material.bar)

            Divider()

            if selectedTab == 0 {
                // WebKit Sign In
                WKWebViewContainer(isLoading: $isLoading) { cookies, name, avatar in
                    authManager.saveCookies(cookies)
                    if let name = name, let avatar = avatar {
                        authManager.updateUserInfo(name: name, avatarUrl: avatar)
                    }
                    dismiss()
                }
            } else {
                // Manual Cookie Import
                VStack(alignment: .leading, spacing: 16) {
                    Text("Manual Browser Cookie Import")
                        .font(.title3.bold())

                    Text("If Google blocks embedded authentication on your device, you can log in via your system browser (Safari or Chrome) and paste the session cookies below:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            if let url = URL(string: "https://music.youtube.com") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("1. Open YouTube Music in Browser", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cookie Header or SAPISID / SID string:")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        TextEditor(text: $manualCookiesInput)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 180)
                            .padding(4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Display Name (optional):")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        TextField("e.g. My Account", text: $manualNameInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    if let error = manualError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Spacer()

                    HStack {
                        Spacer()
                        Button("Apply & Sign In") {
                            applyManualCookies()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.pink)
                        .disabled(manualCookiesInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(24)
            }
        }
        .frame(minWidth: 540, idealWidth: 620, minHeight: 650, idealHeight: 700)
    }

    private func applyManualCookies() {
        let text = manualCookiesInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        var dict: [String: String] = [:]

        if text.contains(";") || text.contains("=") {
            let pairs = text.components(separatedBy: ";")
            for pair in pairs {
                let parts = pair.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count == 2 {
                    dict[parts[0]] = parts[1]
                }
            }
        } else {
            // Assume direct SAPISID
            dict["SAPISID"] = text
            dict["__Secure-3PAPISID"] = text
        }

        if dict["SAPISID"] != nil || dict["__Secure-3PAPISID"] != nil || dict["SID"] != nil {
            authManager.saveCookies(dict)
            let name = manualNameInput.isEmpty ? "Google Account" : manualNameInput
            authManager.updateUserInfo(name: name, avatarUrl: "")
            dismiss()
        } else {
            manualError = "Could not find a valid SAPISID or SID cookie. Please make sure to copy the full cookie header from music.youtube.com."
        }
    }
}

struct WKWebViewContainer: NSViewRepresentable {
    @Binding var isLoading: Bool
    var onLoginSuccess: ([String: String], String?, String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // Use official Safari macOS User-Agent (verified to pass Google security checks)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

        if let loginUrl = URL(string: "https://accounts.google.com/ServiceLogin?continue=https%3A%2F%2Fmusic.youtube.com") {
            let request = URLRequest(url: loginUrl)
            webView.load(request)
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.stopLoading()
        nsView.navigationDelegate = nil
        nsView.loadHTMLString("", baseURL: nil)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WKWebViewContainer

        init(_ parent: WKWebViewContainer) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }

            guard let url = webView.url else { return }

            if url.host?.contains("music.youtube.com") == true {
                // Read cookies from store
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                    guard let self = self else { return }

                    var cookieDict: [String: String] = [:]
                    for cookie in cookies {
                        cookieDict[cookie.name] = cookie.value
                    }

                    // Check if authenticated
                    if cookieDict["SAPISID"] != nil || cookieDict["__Secure-3PAPISID"] != nil || cookieDict["SID"] != nil {
                        // Extract avatar and user name if available
                        let js = """
                        (() => {
                            const img = document.querySelector('button#avatar-btn img') || document.querySelector('#right-content yt-img-shadow img');
                            return {
                                avatar: img ? img.src : null,
                                name: document.title.replace(' - YouTube Music', '')
                            };
                        })()
                        """

                        webView.evaluateJavaScript(js) { result, _ in
                            var name: String? = nil
                            var avatar: String? = nil
                            if let dict = result as? [String: Any] {
                                avatar = dict["avatar"] as? String
                                name = dict["name"] as? String
                            }

                            DispatchQueue.main.async {
                                self.parent.onLoginSuccess(cookieDict, name, avatar)
                            }
                        }
                    }
                }
            }
        }
    }
}
