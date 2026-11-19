import AppKit

@MainActor
final class MediaKeyManager {
    static let shared = MediaKeyManager()
    private var eventMonitor: Any?
    private var lastEventTime: TimeInterval = 0

    private init() {}

    func start() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self = self, event.subtype.rawValue == 8 else { return event }
            let data1 = event.data1
            let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
            let keyFlags = (data1 & 0x0000FFFF)
            let keyState = ((keyFlags & 0xFF00) >> 8) == 0xA // 0xA is KeyDown

            guard keyState else { return nil }

            let now = ProcessInfo.processInfo.systemUptime
            guard now - self.lastEventTime > 0.35 else { return nil }
            self.lastEventTime = now

            switch keyCode {
            case 16: // NX_KEYTYPE_PLAY (Play/Pause)
                AudioPlayerService.shared.togglePlayPause()
                return nil
            case 17, 19: // NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST (Next Track)
                AudioPlayerService.shared.next()
                return nil
            case 18, 20: // NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND (Previous Track)
                AudioPlayerService.shared.previous()
                return nil
            default:
                return event
            }
        }
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
