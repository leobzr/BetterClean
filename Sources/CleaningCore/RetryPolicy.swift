import Foundation

/// Decides how long to wait before re-arming Touch ID.
///
/// Wiping the sensor produces failed reads, and about 5 failed matches make
/// macOS demand the password at the next unlock. So each consecutive failure
/// backs off (5s, 10s, 20s, capped at 30s) instead of re-arming immediately.
public struct RetryPolicy {
    public let baseFailureDelay: TimeInterval
    public let maxFailureDelay: TimeInterval
    /// Delay after a non-failure interruption (cancel, focus loss).
    public let rearmDelay: TimeInterval
    public private(set) var consecutiveFailures = 0

    public init(baseFailureDelay: TimeInterval = 5,
                maxFailureDelay: TimeInterval = 30,
                rearmDelay: TimeInterval = 1) {
        self.baseFailureDelay = baseFailureDelay
        self.maxFailureDelay = maxFailureDelay
        self.rearmDelay = rearmDelay
    }

    /// Records a failed match and returns how long to wait before re-arming.
    public mutating func recordFailure() -> TimeInterval {
        consecutiveFailures += 1
        let delay = baseFailureDelay * pow(2, Double(consecutiveFailures - 1))
        return min(delay, maxFailureDelay)
    }

    public mutating func reset() {
        consecutiveFailures = 0
    }
}
