import SwiftUI
import AppKit
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notificationObservers: [any NSObjectProtocol] = []
    private var lastProcessedCommandId: String = ""
    private var launchTimestamp: TimeInterval = Date().timeIntervalSince1970

    private func processPendingWidgetCommand(fallbackAction: String? = nil) {
        if let cmd = WidgetBridge.readLatestCommand(),
           cmd.timestamp >= launchTimestamp,
           cmd.id != lastProcessedCommandId {
            lastProcessedCommandId = cmd.id
            Self.executeWidgetAction(cmd.action)
            return
        }
        if let action = fallbackAction {
            Self.executeWidgetAction(action)
        }
    }

    private static func executeWidgetAction(_ action: String) {
        switch action {
        case "toggle":
            AudioPlayerService.shared.togglePlayPause()
        case "next":
            AudioPlayerService.shared.next()
        case "previous":
            AudioPlayerService.shared.previous()
        default:
            break
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchTimestamp = Date().timeIntervalSince1970
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        VerticalScrollForwarding.install()
        MediaKeyManager.shared.start()

        let darwinCenter = CFNotificationCenterGetDarwinNotifyCenter()
        for name in [WidgetBridge.toggleDarwinNotification, WidgetBridge.nextDarwinNotification, WidgetBridge.previousDarwinNotification] {
            CFNotificationCenterAddObserver(
                darwinCenter,
                Unmanaged.passUnretained(self).toOpaque(),
                { _, observer, name, _, _ in
                    guard let observer, let raw = name?.rawValue as? String else { return }
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                    let fallback: String? = {
                        switch raw {
                        case WidgetBridge.toggleDarwinNotification: return "toggle"
                        case WidgetBridge.nextDarwinNotification: return "next"
                        case WidgetBridge.previousDarwinNotification: return "previous"
                        default: return nil
                        }
                    }()
                    Task { @MainActor in
                        delegate.processPendingWidgetCommand(fallbackAction: fallback)
                    }
                },
                name as CFString,
                nil,
                .deliverImmediately
            )
        }

        let toggleObs = DistributedNotificationCenter.default().addObserver(
            forName: WidgetBridge.toggleNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingWidgetCommand(fallbackAction: "toggle")
            }
        }
        notificationObservers.append(toggleObs)

        let nextObs = DistributedNotificationCenter.default().addObserver(
            forName: WidgetBridge.nextNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingWidgetCommand(fallbackAction: "next")
            }
        }
        notificationObservers.append(nextObs)

        let prevObs = DistributedNotificationCenter.default().addObserver(
            forName: WidgetBridge.previousNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingWidgetCommand(fallbackAction: "previous")
            }
        }
        notificationObservers.append(prevObs)

        // Fallback poll for sandboxed widget IPC if notifications are dropped.
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingWidgetCommand()
            }
        }

        if let icon = Bundle.main.image(forResource: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns") {
            NSApplication.shared.applicationIconImage = icon
        }

        configureAllWindows()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Self.handleWidgetURL(url)
        }
    }

    static func handleWidgetURL(_ url: URL) {
        guard url.scheme == "music-widget" else { return }
        let host = url.host ?? ""
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let action = !host.isEmpty ? host : path
        Task { @MainActor in
            executeWidgetAction(action)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        for obs in notificationObservers {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
        notificationObservers.removeAll()
    }

    func configureAllWindows() {
        let theme = AppSettings.shared.theme
        for window in NSApplication.shared.windows {
            // Target the main application window
            guard window.styleMask.contains(.titled),
                  !(window is NSPanel),
                  window.frame.origin.x > -1000,
                  window.className != "NSStatusBarWindow" else {
                continue
            }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.toolbar?.showsBaselineSeparator = false
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.isOpaque = false
            window.backgroundColor = .clear

            switch theme {
            case .system:
                window.appearance = nil
            case .dark:
                window.appearance = NSAppearance(named: .darkAqua)
            case .light:
                window.appearance = NSAppearance(named: .aqua)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            configureAllWindows()
        }
        return true
    }
}

@main
struct MusicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var player = AudioPlayerService.shared

    private static var memoryPressureSource: DispatchSourceMemoryPressure?

    @MainActor
    private static func purgeTransientMemory() {
        URLCache.shared.memoryCapacity = 0
        ImageMemoryCache.shared.clear()
        malloc_zone_pressure_relief(nil, 0)
    }

    @MainActor
    private static func restoreActiveMemory() {
        URLCache.shared.memoryCapacity = 4 * 1024 * 1024
    }

    init() {
        URLCache.shared = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024)
        Self.setupMemoryManagement()
    }

    private static func setupMemoryManagement() {
        let center = NotificationCenter.default
        let backgroundEvents: [NSNotification.Name] = [
            NSApplication.didHideNotification,
            NSWindow.didMiniaturizeNotification
        ]
        for name in backgroundEvents {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { purgeTransientMemory() }
            }
        }

        center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                let hasVisible = NSApplication.shared.windows.contains {
                    $0.isVisible && !$0.isMiniaturized && $0.occlusionState.contains(.visible) && !($0 is NSPanel) && $0.className != "NSStatusBarWindow"
                }
                if !hasVisible { purgeTransientMemory() }
            }
        }

        let foregroundEvents: [NSNotification.Name] = [
            NSApplication.didUnhideNotification,
            NSApplication.didBecomeActiveNotification,
            NSWindow.didDeminiaturizeNotification
        ]
        for name in foregroundEvents {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { restoreActiveMemory() }
            }
        }

        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        source.setEventHandler {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { purgeTransientMemory() }
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    var body: some Scene {
        WindowGroup("Music") {
            MainView()
                .frame(minWidth: 800, idealWidth: 1200, maxWidth: .infinity, minHeight: 580, idealHeight: 800, maxHeight: .infinity)
                .onOpenURL { url in
                    AppDelegate.handleWidgetURL(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .openSettingsSheet, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            // Media Controls in macOS Menu Bar
            CommandMenu("Controls") {
                Button(player.isPlaying ? "Pause" : "Play") {
                    player.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Next") {
                    player.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command])

                Button("Previous") {
                    player.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command])

                Divider()

                Button("Shuffle") {
                    player.isShuffle.toggle()
                }

                Button("Repeat") {
                    switch player.repeatMode {
                    case .off: player.repeatMode = .all
                    case .all: player.repeatMode = .one
                    case .one: player.repeatMode = .off
                    }
                }
            }

            CommandMenu("View") {
                Picker("Appearance", selection: Binding(
                    get: { AppSettings.shared.theme },
                    set: { AppSettings.shared.theme = $0 }
                )) {
                    Label("System", systemImage: "laptopcomputer").tag(AppTheme.system)
                    Label("Dark", systemImage: "moon.fill").tag(AppTheme.dark)
                    Label("Light", systemImage: "sun.max.fill").tag(AppTheme.light)
                }

                Divider()

                Button("Toggle Dark Mode") {
                    AppSettings.shared.theme = (AppSettings.shared.theme == .dark) ? .light : .dark
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Divider()

                Button("Vinyl Paper Widget") {
                    VinylWidgetWindowController.shared.toggle()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
    }
}
