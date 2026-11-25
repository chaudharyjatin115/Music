import Foundation

nonisolated struct NetworkProxy: Sendable, Equatable {
    let scheme: String
    let host: String
    let port: Int

    init?(string: String) {
        let value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else { return nil }
        let port = components.port ?? (scheme == "https" ? 443 : 80)
        guard (1...65535).contains(port) else { return nil }
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    var connectionProxyDictionary: [AnyHashable: Any] {
        [
            "HTTPEnable": 1,
            "HTTPProxy": host,
            "HTTPPort": port,
            "HTTPSEnable": 1,
            "HTTPSProxy": host,
            "HTTPSPort": port,
        ]
    }
}

enum NetworkSession {
    static let proxyDefaultsKey = "settings.proxyURL"

    static func make(proxyURL: String? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.default
        let value = proxyURL ?? UserDefaults.standard.string(forKey: proxyDefaultsKey)
        if let proxy = value.flatMap(NetworkProxy.init(string:)) {
            configuration.connectionProxyDictionary = proxy.connectionProxyDictionary
        }
        configuration.urlCache = URLCache.shared
        configuration.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: configuration)
    }

    /// Single shared URLSession reusing connection and thread pools across InnerTube, Lyrics & Plugins
    static let shared: URLSession = make()
}
