import Cocoa
import ApplicationServices
import Carbon
import IOKit
import IOKit.pwr_mgt
import IOKit.hidsystem

enum Permissions {
    /// Active event taps need Accessibility. With `prompt`, macOS shows its
    /// "grant access" dialog when the permission is missing.
    static func accessibilityGranted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
}

enum SecureInput {
    /// When another app leaves Secure Event Input on, keyboard events skip
    /// event taps, so the keyboard can't be blocked.
    static var isEnabled: Bool { IsSecureEventInputEnabled() }
}

/// Keeps the display awake while cleaning (no events reach apps, and a
/// session can be idle for minutes).
final class DisplaySleepAssertion {
    private var assertionID: IOPMAssertionID = 0
    private var held = false

    func acquire() {
        guard !held else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "BetterClean cleaning mode" as CFString,
            &assertionID)
        held = (result == kIOReturnSuccess)
    }

    func release() {
        guard held else { return }
        IOPMAssertionRelease(assertionID)
        held = false
    }
}

/// Caps Lock can toggle below the event tap while the keyboard is wiped.
/// Record it at the start and put it back at the end.
enum CapsLock {
    static var isOn: Bool {
        CGEventSource.flagsState(.hidSystemState).contains(.maskAlphaShift)
    }

    static func set(_ on: Bool) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var connect: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else {
            return
        }
        defer { IOServiceClose(connect) }
        IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), on)
    }
}
