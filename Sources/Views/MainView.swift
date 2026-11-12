import SwiftUI
import AppKit

extension NSScrollView {
    open override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.autohidesScrollers = true
        self.scrollerStyle = .overlay
    }
}

// MARK: - Window Configuration
struct WindowConfigurator: NSViewRepresentable {
    var showNowPlaying: Bool = false
    var theme: AppTheme = .system

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window = window, window.frame.origin.x > -1000 else { return }
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.toolbar?.showsBaselineSeparator = false
        window.isMovableByWindowBackground = true

        // Behind-window vibrancy requires isOpaque = false and clear background
        window.isOpaque = false
        window.backgroundColor = .clear

        if showNowPlaying {
            window.appearance = NSAppearance(named: .darkAqua)
        } else {
            switch theme {
            case .system:
                window.appearance = nil
            case .dark:
                window.appearance = NSAppearance(named: .darkAqua)
            case .light:
                window.appearance = NSAppearance(named: .aqua)
            }
        }

        // Standard window traffic lights (close, miniaturize, zoom) must ALWAYS be visible & enabled
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.closeButton)?.superview?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false

        // Hide any sidebar toggle accessories in titlebar when in Now Playing
        for vc in window.titlebarAccessoryViewControllers {
            vc.isHidden = showNowPlaying
        }

        if let toolbar = window.toolbar {
            for item in toolbar.items {
                if item.itemIdentifier.rawValue.contains("sidebar") || item.itemIdentifier.rawValue.contains("ToggleSidebar") {
                    item.view?.isHidden = showNowPlaying
                }
            }
        }
    }
}

public struct MainView: View {
    @State private var settings = AppSettings.shared
    @State private var selection: NavigationItem? = .listenNow
    @State private var searchQuery: String = ""
    @State private var showSignInSheet = false
    @State private var showSettingsSheet = false
    @State private var showNowPlaying = CommandLine.arguments.contains("--test-now-playing")
    @State private var activeDetailItem: FeedItem? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    @ObservedObject var authManager = AuthManager.shared

    public init() {
        if CommandLine.arguments.contains("--test-now-playing") {
            _showNowPlaying = State(initialValue: true)
        }
    }

    public var body: some View {
        ZStack {
            if showNowPlaying {
                // Dedicated Full Now Playing Screen
                NowPlayingView(isPresented: $showNowPlaying)
                    .ignoresSafeArea(.all)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(
                        selection: $selection,
                        showSignInSheet: $showSignInSheet,
                        showSettingsSheet: $showSettingsSheet
                    )
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
                } detail: {
                    ZStack(alignment: .bottom) {
                        VStack(spacing: 0) {
                            // MARK: - Top Header: [< >]  [🔍 Search]  [Profile]
                            HStack(spacing: 16) {
                                // Chevrons < >
                                HStack(spacing: 6) {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            if activeDetailItem != nil {
                                                activeDetailItem = nil
                                            } else if !searchQuery.isEmpty {
                                                searchQuery = ""
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(activeDetailItem != nil || !searchQuery.isEmpty ? Color.primary : Color.secondary.opacity(0.4))
                                            .frame(width: 26, height: 26)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(activeDetailItem == nil && searchQuery.isEmpty)

                                    Button {
                                        // Forward placeholder
                                    } label: {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(Color.secondary.opacity(0.4))
                                            .frame(width: 26, height: 26)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(true)
                                }

                                // Search Pill Field
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.secondary)

                                    TextField("Search", text: $searchQuery)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(Color.primary)

                                    if !searchQuery.isEmpty {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.15)) {
                                                searchQuery = ""
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(width: 260)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.ytSearchBackground)
                                )

                                Spacer()

                                // User Profile
                                Button {
                                    if authManager.isLoggedIn {
                                        showSettingsSheet = true
                                    } else {
                                        showSignInSheet = true
                                    }
                                } label: {
                                    if authManager.isLoggedIn {
                                        HStack(spacing: 10) {
                                            let resolvedName = !authManager.userDisplayName.isEmpty && authManager.userDisplayName != "YouTube Music" && authManager.userDisplayName != "YouTube Music User" ? authManager.userDisplayName : "My Account"
                                            Text(resolvedName)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(Color.primary)

                                            if !authManager.userAvatarUrl.isEmpty {
                                                CachedAsyncImage(url: URL(string: authManager.userAvatarUrl.thumbnailSized(for: 64))) { phase in
                                                    if let img = phase.image {
                                                        img.resizable().aspectRatio(contentMode: .fill)
                                                    } else {
                                                        Circle().fill(Color.ytRed.opacity(0.2))
                                                    }
                                                }
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                                .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                                            } else {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundStyle(Color.ytRed)
                                            }
                                        }
                                    } else {
                                        HStack(spacing: 6) {
                                            Image(systemName: "person.crop.circle.badge.plus")
                                                .font(.system(size: 13))
                                            Text("Sign In")
                                                .font(.system(size: 12.5, weight: .semibold))
                                        }
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.ytRed)
                                        )
                                    }
                                }
                                .buttonStyle(.plain)
                                .help(authManager.isLoggedIn ? "Account Settings" : "Sign In to YouTube Music")
                            }
                            .padding(.horizontal, 28)
                            .padding(.top, 14)
                            .padding(.bottom, 10)
                            .background(Color.ytHeaderBackground)

                            Divider()
                                .opacity(0.4)

                            // MARK: - Main Scrollable Content Area
                            Group {
                                if let detailItem = activeDetailItem {
                                    DetailView(item: detailItem, activeDetailItem: $activeDetailItem)
                                } else if !searchQuery.isEmpty {
                                    SearchView(query: $searchQuery, activeDetailItem: $activeDetailItem)
                                } else {
                                    switch selection {
                                    case .listenNow, .none:
                                        FeedView(title: "Listen Now", activeDetailItem: $activeDetailItem)
                                    case .browse:
                                        FeedView(title: "Browse", activeDetailItem: $activeDetailItem)
                                    case .charts, .radio:
                                        FeedView(title: "Charts", activeDetailItem: $activeDetailItem)
                                    case .recentlyAdded:
                                        LibraryListView(activeDetailItem: $activeDetailItem, category: .songs)
                                            .id("lib_recent")
                                    case .artists:
                                        LibraryListView(activeDetailItem: $activeDetailItem, category: .artists)
                                            .id("lib_artists")
                                    case .albums:
                                        LibraryListView(activeDetailItem: $activeDetailItem, category: .albums)
                                            .id("lib_albums")
                                    case .songs:
                                        LibraryListView(activeDetailItem: $activeDetailItem, category: .songs)
                                            .id("lib_songs")
                                    case .likedSongs:
                                        LibraryListView(activeDetailItem: $activeDetailItem, category: .liked)
                                            .id("lib_liked")
                                    case .downloaded:
                                        LibraryListView(activeDetailItem: $activeDetailItem, category: .downloaded)
                                            .id("lib_downloaded")
                                    case .playlist(let id, let title):
                                        PlaylistDetailView(playlistId: id, initialTitle: title)
                                            .onAppear {
                                                AudioPlayerService.shared.recordPlaylistPlayed(id: id, title: title)
                                            }
                                    case .settings:
                                        SettingsView(showSignInSheet: $showSignInSheet)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.ytBackground.ignoresSafeArea())

                        // MARK: - Floating Player Bar
                        PlayerBarView(showNowPlaying: $showNowPlaying)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.ytBackground)
                }
                .background(Color.clear)
            }
        }
        .background(WindowConfigurator(showNowPlaying: showNowPlaying, theme: settings.theme))
        .preferredColorScheme(showNowPlaying ? .dark : (settings.theme == .dark ? .dark : (settings.theme == .light ? .light : nil)))
        .sheet(isPresented: $showSignInSheet) {
            WebSignInView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(showSignInSheet: $showSignInSheet)
                .frame(minWidth: 740, idealWidth: 800, minHeight: 500, idealHeight: 560)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenSettingsSheet"))) { _ in
            showSettingsSheet = true
        }
        .onChange(of: selection) { _, _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                searchQuery = ""
                activeDetailItem = nil
            }
        }
    }
}
