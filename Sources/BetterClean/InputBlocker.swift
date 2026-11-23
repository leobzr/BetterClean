import Cocoa
import CleaningCore

/// Swallows every keyboard, media-key, trackpad and mouse event through an
/// active CGEventTap, while watching mouse buttons for the long-press exit.
///
/// Safety: the tap expires on its own. The callback compares the current
/// time with `deadline` and lets every event through once it has passed, so
/// input comes back even if the timers or UI never run again. If the main
/// thread hangs completely, the callback can't run, macOS disables the tap
/// (tapDisabledByTimeout), and nothing re-enables it, which also restores input.
final class InputBlocker {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var deadline: TimeInterval = 0
    private(set) var longPress: LongPressDetector

    init(holdDuration: TimeInterval) {
        longPress = LongPressDetector(holdDuration: holdDuration)
    }

    var isRunning: Bool { tap != nil }

    /// Returns false if the tap could not be created (usually: no Accessibility permission).
    func start(deadline: TimeInterval) -> Bool {
        guard tap == nil else { return true }
        self.deadline = deadline
        longPress.reset()

        // All event types, including NX_SYSDEFINED (media/brightness keys)
        // and gesture types (magnify, swipe, rotate, dock swipes).
        let mask = CGEventMask.max
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        // HID level sees events earliest; fall back to session level.
        for location in [CGEventTapLocation.cghidEventTap, .cgSessionEventTap] {
            if let created = CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: inputBlockerCallback,
                userInfo: refcon
            ) {
                tap = created
                NSLog("BetterClean: event tap created at \(location == .cghidEventTap ? "HID" : "session") level")
                break
            }
        }
        guard let tap else { return false }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        longPress.reset()
    }

    /// Runs on the main thread for every event. Must stay cheap and never block.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let now = ProcessInfo.processInfo.systemUptime

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Re-enable only while the session is still within its deadline.
            if let tap, now < deadline {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Self-expiry: past the deadline, behave as if the tap weren't there.
        if now >= deadline {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            longPress.buttonDown(event.getIntegerValueField(.mouseEventButtonNumber), at: now)
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            longPress.buttonUp(event.getIntegerValueField(.mouseEventButtonNumber), at: now)
        default:
            break
        }
        return nil // swallow
    }
}

private func inputBlockerCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let blocker = Unmanaged<InputBlocker>.fromOpaque(refcon).takeUnretainedValue()
    return blocker.handle(type: type, event: event)
}
