import SwiftUI
import AppKit

extension NSAppearance {
    public var isDark: Bool {
        if bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return true
        }
        return name.rawValue.lowercased().contains("dark")
    }
}

extension Color {
    public static let ytRed = Color(red: 0.95, green: 0.15, blue: 0.25)

    public static let ytBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.isDark
            ? NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
            : NSColor.white
    }))

    public static let ytHeaderBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.isDark
            ? NSColor(red: 0.125, green: 0.125, blue: 0.145, alpha: 1.0)
            : NSColor.white
    }))

    public static let ytSidebarBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.isDark
            ? NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0)
            : NSColor(red: 0.965, green: 0.968, blue: 0.973, alpha: 1.0)
    }))

    public static let ytSearchBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.isDark
            ? NSColor(red: 0.18, green: 0.18, blue: 0.21, alpha: 1.0)
            : NSColor(red: 0.94, green: 0.945, blue: 0.955, alpha: 1.0)
    }))

    public static let ytLightPink = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.isDark
            ? NSColor(red: 0.95, green: 0.15, blue: 0.25, alpha: 0.20)
            : NSColor(red: 0.99, green: 0.93, blue: 0.94, alpha: 1.0)
    }))

    public static let ytCardBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.isDark
            ? NSColor(white: 0.16, alpha: 1.0)
            : NSColor(white: 0.96, alpha: 1.0)
    }))

    public static let ytRowHover = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.isDark
            ? NSColor(white: 1.0, alpha: 0.06)
            : NSColor(white: 0.0, alpha: 0.04)
    }))
}

// MARK: - Visual Effect Blur
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .sidebar,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .followsWindowActiveState
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
