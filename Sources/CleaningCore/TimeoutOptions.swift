import Foundation

/// The auto-unlock timer the user can choose.
///
/// Bounded on both ends: the timer is the last-resort exit, so it must never
/// be so long that someone is stuck if Touch ID and the trackpad hold fail.
public enum TimeoutOptions {
    public static let presets: [TimeInterval] = [20, 60, 180, 300]
    public static let range: ClosedRange<TimeInterval> = 10...900 // 10 s to 15 min

    public static func clamp(_ seconds: TimeInterval) -> TimeInterval {
        min(max(seconds, range.lowerBound), range.upperBound)
    }

    /// Values the custom-time stepper moves between: 10 s steps up to a
    /// minute, 30 s steps up to 5 min, 1 min steps up to 15 min.
    public static let stepperValues: [TimeInterval] =
        Array(stride(from: 10.0, through: 60, by: 10))
        + Array(stride(from: 90.0, through: 300, by: 30))
        + Array(stride(from: 360.0, through: 900, by: 60))

    /// Next stepper value above `seconds` (snaps off-grid values onto the grid).
    public static func increment(_ seconds: TimeInterval) -> TimeInterval {
        stepperValues.first { $0 > seconds } ?? range.upperBound
    }

    /// Previous stepper value below `seconds`.
    public static func decrement(_ seconds: TimeInterval) -> TimeInterval {
        stepperValues.last { $0 < seconds } ?? range.lowerBound
    }
}

extension TimeFormatting {
    /// 20 -> "20 s", 60 -> "1 min", 90 -> "1 min 30 s"
    public static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60, rest = total % 60
        switch (minutes, rest) {
        case (0, _): return "\(rest) s"
        case (_, 0): return "\(minutes) min"
        default: return "\(minutes) min \(rest) s"
        }
    }
}
