import XCTest
@testable import OrbitMorphApp

final class WheelFeedbackTests: XCTestCase {
    @MainActor func testDistinctSegmentsPlayOneTickEach() {
        var now = 1.0
        var plays = 0
        let feedback = WheelFeedbackController(minimumInterval: 0.04, now: { now }, play: { plays += 1 })
        feedback.selectionChanged(to: 1, enabled: true)
        now += 0.05
        feedback.selectionChanged(to: 2, enabled: true)
        XCTAssertEqual(plays, 2)
    }

    @MainActor func testRepeatedUpdatesInsideSameSegmentDoNotPlayAgain() {
        var now = 1.0
        var plays = 0
        let feedback = WheelFeedbackController(minimumInterval: 0.04, now: { now }, play: { plays += 1 })
        feedback.selectionChanged(to: 3, enabled: true)
        now += 0.2
        feedback.selectionChanged(to: 3, enabled: true)
        XCTAssertEqual(plays, 1)
    }

    @MainActor func testDisabledFeedbackNeverPlays() {
        var plays = 0
        let feedback = WheelFeedbackController(minimumInterval: 0, now: { 1 }, play: { plays += 1 })
        feedback.selectionChanged(to: 1, enabled: false)
        feedback.selectionChanged(to: 2, enabled: false)
        XCTAssertEqual(plays, 0)
    }

    @MainActor func testFastBoundaryCrossingIsRateLimitedButCanPlayWhenPointerRemainsOnNewSegment() {
        var now = 1.0
        var plays = 0
        let feedback = WheelFeedbackController(minimumInterval: 0.04, now: { now }, play: { plays += 1 })
        feedback.selectionChanged(to: 1, enabled: true)
        now += 0.01
        feedback.selectionChanged(to: 2, enabled: true)
        XCTAssertEqual(plays, 1)
        now += 0.04
        feedback.selectionChanged(to: 2, enabled: true)
        XCTAssertEqual(plays, 2)
    }

    @MainActor func testLeavingWheelResetsSegmentIdentity() {
        var now = 1.0
        var plays = 0
        let feedback = WheelFeedbackController(minimumInterval: 0.04, now: { now }, play: { plays += 1 })
        feedback.selectionChanged(to: 1, enabled: true)
        feedback.selectionChanged(to: nil, enabled: true)
        now += 0.05
        feedback.selectionChanged(to: 1, enabled: true)
        XCTAssertEqual(plays, 2)
    }
}
