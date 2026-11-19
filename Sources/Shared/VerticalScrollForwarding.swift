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
    var isForwarding: Bool?
    var beganEvent: NSEvent?
}

nonisolated(unsafe) private var scrollStateKey: UInt8 = 0

extension NSScrollView {
    private var scrollState: ScrollForwardState {
        if let state = objc_getAssociatedObject(self, &scrollStateKey) as? ScrollForwardState {
            return state
        }
        let state = ScrollForwardState()
        objc_setAssociatedObject(self, &scrollStateKey, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }

    var canScrollVertically: Bool {
        guard let document = documentView else { return false }
        return document.frame.height > contentView.bounds.height + 1
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
        if canScrollVertically {
            forwarded_scrollWheel(with: event)
            return
        }

        guard let outer = enclosingVerticalScrollView else {
            forwarded_scrollWheel(with: event)
            return
        }

        if !event.hasPreciseScrollingDeltas {
            if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) {
                outer.scrollWheel(with: event)
                return
            }
            forwarded_scrollWheel(with: event)
            return
        }

        let state = scrollState
        let isEnded = event.phase.contains(.ended) || event.phase.contains(.cancelled)
        let isMomentumEnded = event.momentumPhase.contains(.ended)

        if let forwarding = state.isForwarding {
            if forwarding {
                outer.scrollWheel(with: event)
            } else {
                forwarded_scrollWheel(with: event)
            }

            if isMomentumEnded || (isEnded && event.momentumPhase.isEmpty) {
                state.isForwarding = nil
                state.beganEvent = nil
            }
            return
        }

        if event.phase.contains(.began) && event.scrollingDeltaX == 0 && event.scrollingDeltaY == 0 {
            state.beganEvent = event
            return
        }

        if isEnded {
            if let began = state.beganEvent {
                state.beganEvent = nil
                forwarded_scrollWheel(with: began)
            }
            forwarded_scrollWheel(with: event)
            state.isForwarding = nil
            return
        }

        let deltaY = abs(event.scrollingDeltaY)
        let deltaX = abs(event.scrollingDeltaX)

        if deltaY > 0 || deltaX > 0 {
            let shouldForward = deltaY > deltaX
            state.isForwarding = shouldForward

            if let began = state.beganEvent {
                state.beganEvent = nil
                if shouldForward {
                    outer.scrollWheel(with: began)
                } else {
                    forwarded_scrollWheel(with: began)
                }
            }

            if shouldForward {
                outer.scrollWheel(with: event)
            } else {
                forwarded_scrollWheel(with: event)
            }

            if isMomentumEnded || (isEnded && event.momentumPhase.isEmpty) {
                state.isForwarding = nil
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
