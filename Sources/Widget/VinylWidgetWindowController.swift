import AppKit
import SwiftUI

@MainActor
public final class VinylWidgetWindowController: NSObject, NSWindowDelegate {
    public static let shared = VinylWidgetWindowController()

    private var panel: NSPanel?

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private override init() {
        super.init()
    }

    public func toggle() {
        if isVisible {
            close()
        } else {
            show()
        }
    }

    public func show() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: false)
            return
        }

        let widgetView = VinylWidgetView()
        let hostingView = NSHostingView(rootView: widgetView)

        let initialRect = NSRect(x: 100, y: 100, width: 330, height: 388)
        let window = NSPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isFloatingPanel = true
        let alwaysOnTop = UserDefaults.standard.object(forKey: "vinylWidgetAlwaysOnTop") as? Bool ?? true
        window.level = alwaysOnTop ? .floating : .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.contentView = hostingView
        window.delegate = self
        window.setFrameAutosaveName("VinylPaperWidgetWindow")

        if window.frame.origin.x == 0 && window.frame.origin.y == 0 {
            window.center()
        }

        self.panel = window
        window.makeKeyAndOrderFront(nil)
    }

    public func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    public func setAlwaysOnTop(_ enabled: Bool) {
        panel?.level = enabled ? .floating : .normal
    }

    public func windowWillClose(_ notification: Notification) {
        self.panel = nil
    }
}
