import SwiftUI
import AppKit
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        VerticalScrollForwarding.install()
        MediaKeyManager.shared.start()

        DistributedNotificationCenter.default().addObserver(
            forName: WidgetBridge.toggleNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AudioPlayerService.shared.togglePlayPause()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: WidgetBridge.nextNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AudioPlayerService.shared.next()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: WidgetBridge.previousNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AudioPlayerService.shared.previous()
            }
        }

        if let icon = Bundle.main.image(forResource: "AppIcon") ?? NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns") {
            NSApplication.shared.applicationIconImage = icon
        }

        configureAllWindows()
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
            }
        }
    }
}
