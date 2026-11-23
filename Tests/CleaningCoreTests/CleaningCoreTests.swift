import Testing
@testable import CleaningCore

@Suite struct LongPressDetectorTests {
    @Test func triggersAfterHoldDuration() {
        var d = LongPressDetector(holdDuration: 3)
        d.buttonDown(0, at: 10)
        #expect(!d.isTriggered(at: 12.9))
        #expect(d.isTriggered(at: 13))
    }

    @Test func releaseCancels() {
        var d = LongPressDetector(holdDuration: 3)
        d.buttonDown(0, at: 10)
        d.buttonUp(0, at: 11)
        #expect(!d.isTriggered(at: 20))
        #expect(d.remainingHold(at: 20) == nil)
    }

    @Test func shortTapsNeverAccumulate() {
        var d = LongPressDetector(holdDuration: 3)
        for t in stride(from: 0.0, to: 10, by: 0.5) {
            d.buttonDown(0, at: t)
            d.buttonUp(0, at: t + 0.2)
        }
        #expect(!d.isTriggered(at: 10))
    }

    @Test func holdContinuesWhileAnyButtonIsDown() {
        var d = LongPressDetector(holdDuration: 3)
        d.buttonDown(0, at: 0)
        d.buttonDown(1, at: 1)
        d.buttonUp(0, at: 2)       // button 1 still held: keep the original start
        #expect(d.isTriggered(at: 3))
    }

    @Test func strayButtonUpIsHarmless() {
        var d = LongPressDetector(holdDuration: 3)
        d.buttonUp(0, at: 0)       // e.g. a button released that was pressed before the session
        #expect(!d.isPressed)
    }

    @Test func remainingHoldCountsDown() {
        var d = LongPressDetector(holdDuration: 3)
        d.buttonDown(0, at: 0)
        #expect(d.remainingHold(at: 1) == 2)
        #expect(d.remainingHold(at: 5) == 0)
    }
}

@Suite struct RetryPolicyTests {
    @Test func backsOffAndCaps() {
        var p = RetryPolicy(baseFailureDelay: 5, maxFailureDelay: 30)
        #expect(p.recordFailure() == 5)
        #expect(p.recordFailure() == 10)
        #expect(p.recordFailure() == 20)
        #expect(p.recordFailure() == 30)
        #expect(p.recordFailure() == 30)
    }

    @Test func resetStartsOver() {
        var p = RetryPolicy()
        _ = p.recordFailure()
        _ = p.recordFailure()
        p.reset()
        #expect(p.recordFailure() == p.baseFailureDelay)
    }
}

@Suite struct SessionClockTests {
    @Test func elapsedRemainingAndExpiry() {
        let c = SessionClock(start: 100, timeout: 180)
        #expect(c.elapsed(at: 130) == 30)
        #expect(c.remaining(at: 130) == 150)
        #expect(!c.isExpired(at: 279.9))
        #expect(c.isExpired(at: 280))
        #expect(c.remaining(at: 400) == 0)
        #expect(c.elapsed(at: 50) == 0)
    }

    @Test func formatting() {
        #expect(TimeFormatting.minutesSeconds(0) == "0:00")
        #expect(TimeFormatting.minutesSeconds(75.9) == "1:15")
        #expect(TimeFormatting.minutesSeconds(180) == "3:00")
    }
}
