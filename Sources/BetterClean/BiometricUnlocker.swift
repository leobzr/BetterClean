import Foundation
import LocalAuthentication
import CleaningCore

/// Keeps a biometrics-only Touch ID prompt armed for the whole session.
///
/// Each attempt uses a fresh LAContext. `onContextReady` is called before
/// evaluation starts so the overlay can embed an LAAuthenticationView bound
/// to that context (the prompt then shows inside our window rather than as a
/// system dialog that might sit behind the overlay).
final class BiometricUnlocker {
    enum Availability {
        case available
        case unavailable(String)
    }

    /// Called with the new context before each round, and with nil when Touch ID pauses.
    var onContextReady: ((LAContext?) -> Void)?
    var onSuccess: (() -> Void)?
    var onStatus: ((String) -> Void)?

    private var context: LAContext?
    private var retry = RetryPolicy()
    private var pendingRearm: DispatchWorkItem?
    private var active = false

    static func availability() -> Availability {
        let probe = LAContext()
        var error: NSError?
        if probe.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .available
        }
        return .unavailable(describe(error))
    }

    func start() {
        active = true
        retry.reset()
        arm()
    }

    func stop() {
        active = false
        pendingRearm?.cancel()
        pendingRearm = nil
        context?.invalidate() // dismisses any prompt still showing
        context = nil
    }

    private func arm() {
        guard active else { return }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = ""                    // no "Use Password…" (keyboard is blocked)
        ctx.touchIDAuthenticationAllowableReuseDuration = 0 // a recent unlock must not count
        context = ctx
        onContextReady?(ctx)
        onStatus?("Touch ID ready")

        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: "exit cleaning mode") { [weak self] success, error in
            DispatchQueue.main.async {
                self?.handleResult(of: ctx, success: success, error: error)
            }
        }
    }

    private func handleResult(of ctx: LAContext, success: Bool, error: Error?) {
        guard active, ctx === context else { return } // stale or stopped

        if success {
            retry.reset()
            onSuccess?()
            return
        }

        let code = (error as? LAError)?.code
        logEvent("Touch ID attempt ended: \(String(describing: code)) \(error?.localizedDescription ?? "")")

        switch code {
        case .biometryLockout:
            onStatus?("Touch ID is locked after too many attempts. Hold the trackpad or wait for the timer.")
        case .biometryNotAvailable, .biometryNotEnrolled:
            onStatus?("Touch ID unavailable. Hold the trackpad or wait for the timer.")
        case .authenticationFailed:
            if let delay = retry.recordFailure() {
                onStatus?("Fingerprint not recognized. Touch ID ready again in \(Int(delay))s.")
                scheduleRearm(after: delay)
            } else {
                // Another round would likely lock Touch ID until the password is entered.
                context = nil
                onContextReady?(nil)
                onStatus?("Fingerprint not recognized. Touch ID is paused so macOS doesn't lock it. Hold the trackpad or wait for the timer.")
            }
        default:
            // userCancel, systemCancel (focus loss), appCancel, notInteractive, …
            scheduleRearm(after: retry.rearmDelay)
        }
    }

    private func scheduleRearm(after delay: TimeInterval) {
        pendingRearm?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.arm() }
        pendingRearm = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private static func describe(_ error: NSError?) -> String {
        guard let error else { return "Touch ID unavailable." }
        switch LAError.Code(rawValue: error.code) {
        case .biometryNotAvailable:
            return "Touch ID isn't available (no sensor, or the lid is closed)."
        case .biometryNotEnrolled:
            return "No fingerprints are enrolled."
        case .biometryLockout:
            return "Touch ID is locked. Unlock with your password first."
        default:
            return error.localizedDescription
        }
    }
}
