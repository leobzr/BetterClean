import Foundation

/// Decides whether and when to re-arm Touch ID.
///
/// One evaluation ("round") lets the user try several fingers before it fails,
/// and macOS locks Touch ID after about 5 failed matches until the password is
/// entered. Tested: the second failed round always hit that lockout. So after
/// `maxFailedRounds` failed rounds Touch ID stays off for the rest of the
/// session, and the trackpad hold and timer remain as exits.
public struct RetryPolicy {
    public let maxFailedRounds: Int
    /// Pause after a failed round before re-arming (only used when more than one round is allowed).
    public let failureDelay: TimeInterval
    /// Delay after a non-failure interruption (cancel, focus loss).
    public let rearmDelay: TimeInterval
    public private(set) var failedRounds = 0

    public init(maxFailedRounds: Int = 1,
                failureDelay: TimeInterval = 5,
                rearmDelay: TimeInterval = 1) {
        self.maxFailedRounds = maxFailedRounds
        self.failureDelay = failureDelay
        self.rearmDelay = rearmDelay
    }

    /// Records a failed round. Returns the delay before re-arming, or nil when
    /// Touch ID should stay off for the rest of the session.
    public mutating func recordFailure() -> TimeInterval? {
        failedRounds += 1
        return failedRounds < maxFailedRounds ? failureDelay : nil
    }

    public mutating func reset() {
        failedRounds = 0
    }
}
