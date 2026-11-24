import Cocoa
import CleaningCore

struct SessionConfig {
    var timeout: TimeInterval
    var holdDuration: TimeInterval
    /// Prototype switch: use the system Touch ID dialog instead of the
    /// embedded LAAuthenticationView, to compare how each behaves.
    var useSystemPrompt: Bool

    /// Product decision (2026-11-23): 20 s is also the release default. The
    /// timer is a last-resort fallback; users who want longer pick it in the
    /// launcher window.
    static let defaultTimeout: TimeInterval = 20
    static let timeoutKey = "timeoutSeconds"

    /// The timer is chosen in the launcher window and saved here. Always
    /// clamped to TimeoutOptions.range, whatever is stored.
    static func load() -> SessionConfig {
        let defaults = UserDefaults.standard
        let storedTimeout = defaults.object(forKey: timeoutKey) as? Double ?? defaultTimeout
        return SessionConfig(
            timeout: TimeoutOptions.clamp(storedTimeout),
            holdDuration: defaults.object(forKey: "holdSeconds") as? Double ?? 3,
            useSystemPrompt: defaults.bool(forKey: "useSystemPrompt")
        )
    }

    static func saveTimeout(_ seconds: TimeInterval) {
        UserDefaults.standard.set(TimeoutOptions.clamp(seconds), forKey: timeoutKey)
    }
}

enum StartError: LocalizedError {
    case accessibilityMissing
    case secureInputEnabled
    case tapFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityMissing:
            return "BetterClean needs Accessibility access to block the keyboard and trackpad. Enable it in System Settings › Privacy & Security › Accessibility, then try again."
        case .secureInputEnabled:
            return "Another app has Secure Keyboard Entry turned on, so the keyboard can't be blocked. Close password fields or the app holding it (often a terminal or password manager) and try again."
        case .tapFailed:
            return "Couldn't create the input blocker. Check the Accessibility permission (remove and re-add BetterClean if you just rebuilt it)."
        }
    }
}

enum EndReason: String {
    case touchID = "Touch ID"
    case longPress = "trackpad hold"
    case timeout = "timer"
    case systemSleep = "system sleep"
    case displaySleep = "display sleep (power button pressed?)"
    case screenLocked = "screen locked"
    case sessionInactive = "user session switched"
}

/// Ties the pieces together for one cleaning session.
///
/// Ending is idempotent and restores input first, before any UI work.
final class CleaningSession {
    var onEnded: ((EndReason) -> Void)?
    private(set) var isActive = false

    private let config: SessionConfig
    private let blocker: InputBlocker
    private let overlay = OverlayController()
    private let unlocker = BiometricUnlocker()
    private let displayAwake = DisplaySleepAssertion()
    private var clock: SessionClock?
    private var capsLockWasOn = false
    private var cursorHidden = false
    private var ticker: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var otherObservers: [(NotificationCenter, NSObjectProtocol)] = []

    init(config: SessionConfig) {
        self.config = config
        self.blocker = InputBlocker(holdDuration: config.holdDuration)
    }

    func start() throws {
        guard !isActive else { return }
        guard Permissions.accessibilityGranted(prompt: true) else { throw StartError.accessibilityMissing }
        guard !SecureInput.isEnabled else { throw StartError.secureInputEnabled }

        let now = ProcessInfo.processInfo.systemUptime
        let clock = SessionClock(start: now, timeout: config.timeout)
        guard blocker.start(deadline: clock.deadline) else { throw StartError.tapFailed }

        self.clock = clock
        isActive = true
        capsLockWasOn = CapsLock.isOn

        NSApp.activate(ignoringOtherApps: true)
        overlay.show()
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching,
                                     .disableForceQuit, .disableSessionTermination,
                                     .disableHideApplication, .disableAppleMenu]
        CGDisplayHideCursor(CGMainDisplayID())
        cursorHidden = true
        displayAwake.acquire()

        startTouchID()
        observeSystem()

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
        tick()
        logEvent("session started (timeout \(Int(config.timeout))s, hold \(config.holdDuration)s, systemPrompt \(config.useSystemPrompt))")
    }

    func end(_ reason: EndReason) {
        guard isActive else { return }
        isActive = false

        blocker.stop() // input back first
        ticker?.invalidate()
        ticker = nil
        unlocker.stop()

        NSApp.presentationOptions = []
        if cursorHidden {
            CGDisplayShowCursor(CGMainDisplayID())
            cursorHidden = false
        }
        overlay.close()
        displayAwake.release()
        if CapsLock.isOn != capsLockWasOn { CapsLock.set(capsLockWasOn) }
        removeObservers()

        logEvent("session ended by \(reason.rawValue)")
        onEnded?(reason)
    }

    // MARK: - Private

    private func startTouchID() {
        switch BiometricUnlocker.availability() {
        case .available:
            unlocker.onContextReady = { [weak self] context in
                guard let self else { return }
                self.overlay.installAuthView(for: self.config.useSystemPrompt ? nil : context)
            }
            unlocker.onStatus = { [weak self] in self?.overlay.setMessage($0) }
            unlocker.onSuccess = { [weak self] in self?.end(.touchID) }
            unlocker.start()
        case .unavailable(let reason):
            overlay.setMessage("\(reason) Hold the trackpad or wait for the timer.")
        }
    }

    private func tick() {
        guard isActive, let clock else { return }
        let now = ProcessInfo.processInfo.systemUptime

        if blocker.longPress.isTriggered(at: now) { end(.longPress); return }
        if clock.isExpired(at: now) { end(.timeout); return }

        let hold = blocker.longPress.remainingHold(at: now)
        overlay.update(
            elapsed: TimeFormatting.minutesSeconds(clock.elapsed(at: now)),
            autoUnlockIn: TimeFormatting.minutesSeconds(clock.remaining(at: now).rounded(.up)),
            holdRemaining: hold.map { String(format: "%.1fs", $0) }
        )
    }

    private func observeSystem() {
        let ws = NSWorkspace.shared.notificationCenter
        let endOn: [(Notification.Name, EndReason)] = [
            (NSWorkspace.willSleepNotification, .systemSleep),
            (NSWorkspace.screensDidSleepNotification, .displaySleep),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive),
        ]
        for (name, reason) in endOn {
            workspaceObservers.append(ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.end(reason)
            })
        }

        let distributed = DistributedNotificationCenter.default()
        let locked = distributed.addObserver(forName: Notification.Name("com.apple.screenIsLocked"),
                                             object: nil, queue: .main) { [weak self] _ in
            self?.end(.screenLocked)
        }
        otherObservers.append((distributed, locked))

        let screens = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            self?.overlay.rebuild()
        }
        otherObservers.append((NotificationCenter.default, screens))
    }

    private func removeObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { ws.removeObserver($0) }
        workspaceObservers.removeAll()
        otherObservers.forEach { center, token in center.removeObserver(token) }
        otherObservers.removeAll()
    }
}
