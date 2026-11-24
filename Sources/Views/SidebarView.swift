import SwiftUI

public struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @Binding var showSignInSheet: Bool
    @Binding var showSettingsSheet: Bool

    @ObservedObject private var authManager = AuthManager.shared
    @State private var userPlaylists: [Playlist] = []
    @State private var isShowingCreatePlaylistAlert = false
    @State private var newPlaylistTitle = ""

    public init(
        selection: Binding<NavigationItem?>,
        showSignInSheet: Binding<Bool>,
        showSettingsSheet: Binding<Bool>
    ) {
        self._selection = selection
        self._showSignInSheet = showSignInSheet
        self._showSettingsSheet = showSettingsSheet
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Top Header
                VStack(alignment: .leading, spacing: 8) {
                    Menu {
                        Button("Listen Now") { selection = .listenNow }
                        Button("Explore") { selection = .browse }
                        Button("Charts") { selection = .charts }
                        Divider()
                        if authManager.isLoggedIn {
                            Button("Settings") { showSettingsSheet = true }
                        } else {
                            Button("Sign In") { showSignInSheet = true }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 12, weight: .bold))

                            Text("YouTube Music")
                                .font(.system(size: 12.5, weight: .bold))

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8.5, style: .continuous)
                                .fill(Color.ytRed)
                        )
                        .shadow(color: Color.ytRed.opacity(0.25), radius: 5, x: 0, y: 2)
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)

                // Library Section
                VStack(alignment: .leading, spacing: 3) {
                    Text("Library")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 2)

                    SidebarRow(
                        title: "Browse",
                        systemImage: "play.circle.fill",
                        isSelected: selection == .listenNow,
                        showLeftIndicator: true
                    ) {
                        selection = .listenNow
                    }

                    SidebarRow(
                        title: "Explore",
                        systemImage: "safari",
                        isSelected: selection == .browse,
                        showLeftIndicator: true
                    ) {
                        selection = .browse
                    }

                    SidebarRow(
                        title: "Charts",
                        systemImage: "chart.bar.fill",
                        isSelected: selection == .charts,
                        showLeftIndicator: true
                    ) {
                        selection = .charts
                    }
                }

                // Music Section
                VStack(alignment: .leading, spacing: 3) {
                    Text("MUSIC")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.6)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 2)

                    SidebarRow(
                        title: "Recently added",
                        systemImage: "clock",
                        isSelected: selection == .recentlyAdded,
                        showLeftIndicator: false
                    ) {
                        selection = .recentlyAdded
                    }

                    SidebarRow(
                        title: "Artists",
                        systemImage: "music.mic",
                        isSelected: selection == .artists,
                        showLeftIndicator: false
                    ) {
                        selection = .artists
                    }

                    SidebarRow(
                        title: "Albums",
                        systemImage: "square.stack",
                        isSelected: selection == .albums,
                        showLeftIndicator: false
                    ) {
                        selection = .albums
                    }

                    SidebarRow(
                        title: "Songs",
                        systemImage: "music.note",
                        isSelected: selection == .songs,
                        showLeftIndicator: false
                    ) {
                        selection = .songs
                    }

                    SidebarRow(
                        title: "Liked Songs",
                        systemImage: "heart.fill",
                        isSelected: selection == .likedSongs,
                        showLeftIndicator: false
                    ) {
                        selection = .likedSongs
                    }
                }

                // Playlists Section
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("PLAYLISTS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.6)

                        Spacer()

                        Button {
                            isShowingCreatePlaylistAlert = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("New Playlist")
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 2)

                    if userPlaylists.isEmpty {
                        Text(authManager.isLoggedIn ? "No playlists in library" : "Sign in to sync playlists")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary.opacity(0.75))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(userPlaylists) { playlist in
                            let isSelected = selection == .playlist(id: playlist.id, title: playlist.title)
                            SidebarRow(
                                title: playlist.title,
                                systemImage: "music.note.list",
                                isSelected: isSelected,
                                showLeftIndicator: false
                            ) {
                                selection = .playlist(id: playlist.id, title: playlist.title)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
        .alert("New Playlist", isPresented: $isShowingCreatePlaylistAlert) {
            TextField("Playlist Title", text: $newPlaylistTitle)
            Button("Create") {
                if !newPlaylistTitle.isEmpty {
                    userPlaylists.append(Playlist(id: "custom_\(UUID().uuidString)", title: newPlaylistTitle))
                    newPlaylistTitle = ""
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            await reloadPlaylists()
        }
        .onChange(of: authManager.isLoggedIn) { _, loggedIn in
            if loggedIn {
                Task { await reloadPlaylists() }
            } else {
                userPlaylists = []
            }
        }
    }

    private func reloadPlaylists() async {
        guard authManager.isLoggedIn else { return }
        if let playlists = try? await InnerTubeService.shared.fetchUserPlaylists() {
            self.userPlaylists = playlists
        }
    }
}

// MARK: - Sidebar Row
struct SidebarRow: View {
    let title: String
    let systemImage: String?
    let isSelected: Bool
    let showLeftIndicator: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Vertical Red Indicator Bar on Left
                if showLeftIndicator {
                    Capsule()
                        .fill(isSelected ? Color.ytRed : Color.clear)
                        .frame(width: 3.5, height: 16)
                } else {
                    Spacer().frame(width: 3.5)
                }

                if let img = systemImage {
                    Image(systemName: img)
                        .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? Color.ytRed : Color.secondary)
                        .frame(width: 18, alignment: .center)
                }

                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : (isHovered ? Color.primary : Color.primary.opacity(0.75)))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, AppSettings.shared.compactSidebar ? 3 : 5)
            .padding(.trailing, 10)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.04) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
