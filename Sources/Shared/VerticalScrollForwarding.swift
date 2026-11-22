import AppKit
import ObjectiveC

@MainActor
enum VerticalScrollForwarding {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        NSScrollView.installSmoothScrollForwarding()
    }
}

private final class ScrollForwardState {
    enum Direction {
        case vertical
        case horizontal
    }
    var direction: Direction?
}

nonisolated(unsafe) private var scrollStateKey: UInt8 = 0

extension NSScrollView {
    private var scrollForwardState: ScrollForwardState {
        if let state = objc_getAssociatedObject(self, &scrollStateKey) as? ScrollForwardState {
            return state
        }
        let state = ScrollForwardState()
        objc_setAssociatedObject(self, &scrollStateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }

    var canScrollVertically: Bool {
        guard let document = documentView else { return false }
        return document.frame.height > contentView.bounds.height + 2
    }

    private var enclosingVerticalScrollView: NSScrollView? {
        var current = superview
        while let candidate = current {
            if let scrollView = candidate as? NSScrollView, scrollView.canScrollVertically {
                return scrollView
            }
            current = candidate.superview
        }
        return nil
    }

    @objc private func forwarded_scrollWheel(with event: NSEvent) {
        // Vertical-capable scroll views handle their own scrolling natively
        if canScrollVertically {
            forwarded_scrollWheel(with: event)
            return
        }

        // Horizontal-only scroll views: route vertical events to the enclosing vertical scroll view
        guard let outer = enclosingVerticalScrollView else {
            forwarded_scrollWheel(with: event)
            return
        }

        // Traditional mouse wheel without gesture phases
        if event.phase.isEmpty && event.momentumPhase.isEmpty {
            if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                outer.scrollWheel(with: event)
            } else {
                forwarded_scrollWheel(with: event)
            }
            return
        }

        let state = scrollForwardState

        if event.phase.contains(.began) {
            state.direction = nil
        }

        let isEnded = event.phase.contains(.ended) || event.phase.contains(.cancelled)
        let isMomentumEnded = event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled)

        // If gesture direction was already locked, route consistently to avoid hitching
        if let dir = state.direction {
            if dir == .vertical {
                outer.scrollWheel(with: event)
            } else {
                forwarded_scrollWheel(with: event)
            }
            if isMomentumEnded || (isEnded && event.momentumPhase.isEmpty) {
                state.direction = nil
            }
            return
        }

        let dy = abs(event.scrollingDeltaY)
        let dx = abs(event.scrollingDeltaX)

        if dy > 0 || dx > 0 {
            let dir: ScrollForwardState.Direction = (dy > dx) ? .vertical : .horizontal
            state.direction = dir
            if dir == .vertical {
                outer.scrollWheel(with: event)
            } else {
                forwarded_scrollWheel(with: event)
            }
            if isMomentumEnded || (isEnded && event.momentumPhase.isEmpty) {
                state.direction = nil
            }
            return
        }

        forwarded_scrollWheel(with: event)
    }

    static func installSmoothScrollForwarding() {
        let origSel = #selector(scrollWheel(with:))
        let swizSel = #selector(forwarded_scrollWheel(with:))
        guard let origMethod = class_getInstanceMethod(NSScrollView.self, origSel),
              let swizMethod = class_getInstanceMethod(NSScrollView.self, swizSel) else {
            return
        }
        method_exchangeImplementations(origMethod, swizMethod)
    }
}
