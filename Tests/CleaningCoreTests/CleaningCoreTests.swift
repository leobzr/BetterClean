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
    @Test func defaultStopsAfterOneFailedRound() {
        // Two failed rounds locked Touch ID in testing, so the default allows one.
        var p = RetryPolicy()
        #expect(p.recordFailure() == nil)
    }

    @Test func allowsConfiguredRoundsThenStops() {
        var p = RetryPolicy(maxFailedRounds: 3, failureDelay: 5)
        #expect(p.recordFailure() == 5)
        #expect(p.recordFailure() == 5)
        #expect(p.recordFailure() == nil)
    }

    @Test func resetStartsOver() {
        var p = RetryPolicy(maxFailedRounds: 2, failureDelay: 5)
        _ = p.recordFailure()
        p.reset()
        #expect(p.recordFailure() == 5)
    }
}

@Suite struct TimeoutOptionsTests {
    @Test func clampsToSafeRange() {
        #expect(TimeoutOptions.clamp(0) == 10)
        #expect(TimeoutOptions.clamp(-5) == 10)
        #expect(TimeoutOptions.clamp(20) == 20)
        #expect(TimeoutOptions.clamp(86_400) == 900)
    }

    @Test func presetsAreWithinRange() {
        for preset in TimeoutOptions.presets {
            #expect(TimeoutOptions.range.contains(preset))
        }
    }

    @Test func stepsUpThroughBands() {
        #expect(TimeoutOptions.increment(20) == 30)
        #expect(TimeoutOptions.increment(50) == 60)
        #expect(TimeoutOptions.increment(60) == 90)
        #expect(TimeoutOptions.increment(300) == 360)
        #expect(TimeoutOptions.increment(900) == 900)
    }

    @Test func stepsDownThroughBands() {
        #expect(TimeoutOptions.decrement(60) == 50)
        #expect(TimeoutOptions.decrement(90) == 60)
        #expect(TimeoutOptions.decrement(300) == 270)
        #expect(TimeoutOptions.decrement(360) == 300)
        #expect(TimeoutOptions.decrement(10) == 10)
    }

    @Test func upAndDownReturnToTheSameValue() {
        for start in TimeoutOptions.stepperValues.dropLast() {
            #expect(TimeoutOptions.decrement(TimeoutOptions.increment(start)) == start, "from \(start)")
        }
    }

    @Test func offGridValuesSnapOntoTheGrid() {
        #expect(TimeoutOptions.increment(290) == 300)
        #expect(TimeoutOptions.decrement(290) == 270)
        #expect(TimeoutOptions.increment(15) == 20)
    }

    @Test func stepperValuesStayInRange() {
        #expect(TimeoutOptions.stepperValues.first == TimeoutOptions.range.lowerBound)
        #expect(TimeoutOptions.stepperValues.last == TimeoutOptions.range.upperBound)
    }

    @Test func durationFormatting() {
        #expect(TimeFormatting.duration(20) == "20 s")
        #expect(TimeFormatting.duration(60) == "1 min")
        #expect(TimeFormatting.duration(90) == "1 min 30 s")
        #expect(TimeFormatting.duration(900) == "15 min")
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
