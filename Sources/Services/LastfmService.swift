//
//  LastfmService.swift
//  Music
//
//  Manages Last.fm scrobbling, live "Now Playing" status, and user authorization.
//

import Foundation
import AppKit

@MainActor
public final class LastfmService: ObservableObject {
    public static let shared = LastfmService()

    @Published public var session: LastfmSession?
    @Published public var isConnected: Bool = false
    @Published public var username: String = ""
    @Published public var isWorking: Bool = false
    @Published public var awaitingAuthorization: Bool = false
    @Published public var statusMessage: String = ""
    @Published public var lastScrobbleStatus: String = ""

    @Published public var apiKey: String = ""
    @Published public var apiSecret: String = ""

    private let client = LastfmClient()
    private var pendingToken: String?
    private var currentSongId: String?
    private var hasScrobbledCurrent: Bool = false
    private var songStartTime: Int = 0

    private let apiKeyDefaultsKey = "com.music.app.lastfm_api_key"
    private let apiSecretDefaultsKey = "com.music.app.lastfm_api_secret"
    private let keychainService = "com.music.app"
    private let keychainAccount = "lastfm_api_secret"

    private init() {
        self.apiKey = UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? ""
        if let secret = Keychain.getString(service: keychainService, account: keychainAccount), !secret.isEmpty {
            self.apiSecret = secret
            UserDefaults.standard.removeObject(forKey: apiSecretDefaultsKey)
        } else if let legacySecret = UserDefaults.standard.string(forKey: apiSecretDefaultsKey), !legacySecret.isEmpty {
            self.apiSecret = legacySecret
            Keychain.setString(legacySecret, service: keychainService, account: keychainAccount)
            UserDefaults.standard.removeObject(forKey: apiSecretDefaultsKey)
        } else {
            self.apiSecret = ""
        }
        self.session = LastfmClient.loadSession()
        if let session = self.session {
            self.isConnected = true
            self.username = session.username
            self.lastScrobbleStatus = "Connected as \(session.username)"
        }
    }

    public func beginAuthorization(apiKey: String, secret: String) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let sec = secret.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty, !sec.isEmpty else {
            statusMessage = "Please provide both Last.fm API Key and Shared Secret."
            return
        }

        self.apiKey = key
        self.apiSecret = sec
        UserDefaults.standard.set(key, forKey: apiKeyDefaultsKey)
        Keychain.setString(sec, service: keychainService, account: keychainAccount)
        UserDefaults.standard.removeObject(forKey: apiSecretDefaultsKey)

        self.statusMessage = ""
        self.isWorking = true

        Task {
            defer { self.isWorking = false }
            do {
                let token = try await client.requestToken(apiKey: key, secret: sec)
                guard let url = client.authorizationURL(apiKey: key, token: token) else {
                    self.statusMessage = "Failed to construct Last.fm authorization URL."
                    return
                }
                NSWorkspace.shared.open(url)
                self.pendingToken = token
                self.awaitingAuthorization = true
                self.statusMessage = "Approve access in your browser, then click 'Finish Connecting'."
            } catch {
                self.statusMessage = "Connection failed: \(error.localizedDescription)"
            }
        }
    }

    public func completeAuthorization() {
        guard let token = pendingToken else {
            statusMessage = "No pending authentication request found."
            return
        }

        self.statusMessage = ""
        self.isWorking = true

        Task {
            defer { self.isWorking = false }
            do {
                let session = try await client.completeAuthorization(token: token)
                self.session = session
                self.isConnected = true
                self.username = session.username
                self.awaitingAuthorization = false
                self.pendingToken = nil
                self.lastScrobbleStatus = "Connected as \(session.username)"
                self.statusMessage = "Successfully connected to Last.fm as @\(session.username)!"
            } catch {
                self.statusMessage = "Authorization failed: \(error.localizedDescription)"
            }
        }
    }

    public func cancelAuthorization() {
        self.awaitingAuthorization = false
        self.pendingToken = nil
        self.statusMessage = ""
    }

    public func disconnect() {
        self.session = nil
        self.isConnected = false
        self.username = ""
        self.awaitingAuthorization = false
        self.pendingToken = nil
        self.statusMessage = "Disconnected from Last.fm"
        self.lastScrobbleStatus = ""
        Keychain.delete(service: keychainService, account: keychainAccount)
        UserDefaults.standard.removeObject(forKey: apiSecretDefaultsKey)
        Task {
            await client.disconnect()
        }
    }

    // MARK: - Playback Scrobbling Lifecycle

    public func onTrackStart(song: Song) {
        guard isConnected else { return }
        currentSongId = song.id
        hasScrobbledCurrent = false
        songStartTime = Int(Date().timeIntervalSince1970)

        let track = ScrobbleTrack(
            title: song.title,
            artist: song.artist,
            album: song.album,
            duration: song.duration,
            startedAt: songStartTime
        )

        Task {
            await client.updateNowPlaying(track)
            self.lastScrobbleStatus = "Now playing: '\(song.title)'"
        }
    }

    public func onTrackProgress(song: Song, currentTime: TimeInterval, duration: TimeInterval) {
        guard isConnected, !hasScrobbledCurrent else { return }
        guard currentSongId == song.id else { return }

        // Standard Last.fm scrobble rules: played > 30s and >= min(duration / 2, 240s)
        if lastfmScrobbleEligible(playedSeconds: currentTime, duration: duration) {
            hasScrobbledCurrent = true
            let track = ScrobbleTrack(
                title: song.title,
                artist: song.artist,
                album: song.album,
                duration: duration,
                startedAt: songStartTime > 0 ? songStartTime : Int(Date().timeIntervalSince1970)
            )

            Task {
                await client.scrobble(track)
                self.lastScrobbleStatus = "Scrobbled '\(song.title)'"
            }
        }
    }
}
