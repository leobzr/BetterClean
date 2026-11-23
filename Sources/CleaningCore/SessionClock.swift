import Foundation

/// Elapsed / remaining time for one cleaning session, in system uptime seconds.
public struct SessionClock {
    public let start: TimeInterval
    public let timeout: TimeInterval

    public init(start: TimeInterval, timeout: TimeInterval) {
        self.start = start
        self.timeout = timeout
    }

    public var deadline: TimeInterval { start + timeout }

    public func elapsed(at now: TimeInterval) -> TimeInterval {
        max(0, now - start)
    }

    public func remaining(at now: TimeInterval) -> TimeInterval {
        max(0, timeout - elapsed(at: now))
    }

    public func isExpired(at now: TimeInterval) -> Bool {
        now >= deadline
    }
}

public enum TimeFormatting {
    /// 75.4 -> "1:15"
    public static func minutesSeconds(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
