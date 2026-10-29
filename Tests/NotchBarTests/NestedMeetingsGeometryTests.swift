import XCTest
@testable import NotchBar

final class NestedMeetingsGeometryTests: XCTestCase {
    private typealias G = NestedMeetingsGeometry

    private func meeting(
        start: Double = 0.2,
        width: Double = 0.1,
        past: Bool = false,
        seconds: Int = 600
    ) -> EventProgressSnapshot.NestedMeeting {
        EventProgressSnapshot.NestedMeeting(
            title: "M",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 60),
            startFraction: start,
            widthFraction: width,
            isPast: past,
            secondsUntilStart: seconds
        )
    }

    func test_capsuleFrame_scalesFractionsToBarWidth() {
        let frame = G.capsuleFrame(startFraction: 0.25, widthFraction: 0.5, barWidth: 400)
        XCTAssertEqual(frame.x, 100)
        XCTAssertEqual(frame.width, 200)
    }

    func test_capsuleFrame_keepsTinyMeetingVisibleAndInsideBar() {
        let tiny = G.capsuleFrame(startFraction: 0.5, widthFraction: 0.001, barWidth: 400)
        XCTAssertEqual(tiny.width, G.minimumCapsuleWidth)
        let atEnd = G.capsuleFrame(startFraction: 1.0, widthFraction: 0.001, barWidth: 400)
        XCTAssertEqual(atEnd.x + atEnd.width, 400)
    }

    func test_capsuleFrame_zeroBar() {
        let frame = G.capsuleFrame(startFraction: 0.5, widthFraction: 0.5, barWidth: 0)
        XCTAssertEqual(frame.width, 0)
    }

    func test_labelAnchor_flipsPast55Percent() {
        XCTAssertEqual(G.labelAnchor(startFraction: 0.2), .leading)
        XCTAssertEqual(G.labelAnchor(startFraction: 0.55), .leading)
        XCTAssertEqual(G.labelAnchor(startFraction: 0.56), .trailing)
    }

    func test_labelFrame_leadingStartsAtCapsuleEdge() {
        let frame = G.labelFrame(capsuleX: 50, capsuleWidth: 40, anchor: .leading, barWidth: 400)
        XCTAssertEqual(frame.x, 50)
        XCTAssertEqual(frame.width, G.maximumLabelWidth)
    }

    func test_labelFrame_leadingNeverLeavesBar() {
        let frame = G.labelFrame(capsuleX: 350, capsuleWidth: 40, anchor: .leading, barWidth: 400)
        XCTAssertEqual(frame.width, 50)
    }

    func test_labelFrame_trailingEndsAtCapsuleRightEdge() {
        let frame = G.labelFrame(capsuleX: 300, capsuleWidth: 60, anchor: .trailing, barWidth: 400)
        XCTAssertEqual(frame.x + frame.width, 360)
        XCTAssertEqual(frame.width, G.maximumLabelWidth)
    }

    func test_labelFrame_trailingNeverLeavesBar() {
        let frame = G.labelFrame(capsuleX: 0, capsuleWidth: 60, anchor: .trailing, barWidth: 400)
        XCTAssertEqual(frame.x, 0)
        XCTAssertEqual(frame.width, 60)
    }

    func test_nearestFutureIndex_picksSoonestUnstarted() {
        let meetings = [
            meeting(past: true, seconds: 0),
            meeting(seconds: 900),
            meeting(seconds: 300),
        ]
        XCTAssertEqual(G.nearestFutureIndex(meetings), 2)
    }

    func test_nearestFutureIndex_nilWhenAllPastOrEmpty() {
        XCTAssertNil(G.nearestFutureIndex([]))
        XCTAssertNil(G.nearestFutureIndex([meeting(past: true, seconds: 0)]))
    }

    func test_countdownMinutes_roundsUp() {
        XCTAssertEqual(G.countdownMinutes(secondsUntilStart: 1), 1)
        XCTAssertEqual(G.countdownMinutes(secondsUntilStart: 60), 1)
        XCTAssertEqual(G.countdownMinutes(secondsUntilStart: 61), 2)
        XCTAssertEqual(G.countdownMinutes(secondsUntilStart: 360), 6)
        XCTAssertEqual(G.countdownMinutes(secondsUntilStart: 0), 0)
    }

    func test_resolveOverlaps_narrowsLeftLabelToNeighbour() {
        let result = G.resolveOverlaps([
            (x: 10, width: 140, anchor: .leading),
            (x: 90, width: 140, anchor: .leading),
        ])
        XCTAssertEqual(result[0].width, 90 - G.labelGap - 10)
        XCTAssertEqual(result[1].width, 140)
    }

    func test_resolveOverlaps_keepsOrderAndRespectsMinimum() {
        let result = G.resolveOverlaps([
            (x: 200, width: 100, anchor: .leading),
            (x: 205, width: 100, anchor: .leading),
        ])
        XCTAssertEqual(result[0].x, 200)
        XCTAssertEqual(result[0].width, G.minimumLabelWidth)
    }

    func test_resolveOverlaps_leavesDistantLabelsAlone() {
        let result = G.resolveOverlaps([
            (x: 0, width: 100, anchor: .leading),
            (x: 300, width: 100, anchor: .trailing),
        ])
        XCTAssertEqual(result[0].width, 100)
        XCTAssertEqual(result[1].width, 100)
    }

    func test_countdownLabel_usesSharedFormat() {
        XCTAssertEqual(Localized.string("in \(DurationLabel.short(minutes: 6))", locale: Locale(identifier: "en")), "in 6 min")
        XCTAssertEqual(Localized.string("in \(DurationLabel.short(minutes: 60))", locale: Locale(identifier: "fr")), "dans 1h")
    }
}
