import Foundation

/// Detects the emergency exit: a trackpad/mouse button held down continuously
/// for `holdDuration` seconds.
///
/// Fed from the event tap (button down/up) and polled by a timer, because no
/// events arrive while a button is simply being held.
public struct LongPressDetector {
    public let holdDuration: TimeInterval
    private var heldButtons: Set<Int64> = []
    private var pressStart: TimeInterval?

    public init(holdDuration: TimeInterval) {
        self.holdDuration = holdDuration
    }

    public mutating func buttonDown(_ button: Int64, at time: TimeInterval) {
        if heldButtons.isEmpty { pressStart = time }
        heldButtons.insert(button)
    }

    public mutating func buttonUp(_ button: Int64, at time: TimeInterval) {
        heldButtons.remove(button)
        if heldButtons.isEmpty { pressStart = nil }
    }

    public mutating func reset() {
        heldButtons.removeAll()
        pressStart = nil
    }

    public var isPressed: Bool { pressStart != nil }

    public func isTriggered(at now: TimeInterval) -> Bool {
        guard let pressStart else { return false }
        return now - pressStart >= holdDuration
    }

    /// Seconds still to hold before the exit fires, or nil when nothing is held.
    public func remainingHold(at now: TimeInterval) -> TimeInterval? {
        guard let pressStart else { return nil }
        return max(0, holdDuration - (now - pressStart))
    }
}
