import XCTest
import SwiftUI
@testable import NotchBar

final class PanelLayoutTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let inset: CGFloat = 46

    private func snapshot(
        state: EventProgressSnapshot.State = .inProgress,
        nested: [EventProgressSnapshot.NestedMeeting] = [],
        following: EventProgressSnapshot.FollowingEvent? = nil,
        join: Bool = false,
        nextEvent: EventProgressSnapshot.NextEvent? = nil,
        allDay: String? = nil
    ) -> EventProgressSnapshot {
        var s = EventProgressSnapshot(
            title: "T", progress: 0.5, startTimeLabel: "18:00", endTimeLabel: "18:30",
            elapsedLabel: "10:00", remainingLabel: "20:00", statusLabel: "", secondaryMessage: nil,
            tint: .blue, state: state
        )
        s.joinURL = join ? URL(string: "https://meet.example.com/x") : nil
        s.nestedMeetings = nested
        s.followingEvent = following
        s.nextEvent = nextEvent
        s.allDayMessage = allDay
        return s
    }

    private func meeting(past: Bool) -> EventProgressSnapshot.NestedMeeting {
        .init(title: "M", startDate: now, endDate: now.addingTimeInterval(1800),
              startFraction: 0.2, widthFraction: 0.2, isPast: past, secondsUntilStart: past ? 0 : 600)
    }

    private let follower = EventProgressSnapshot.FollowingEvent(title: "Gym", gapSeconds: 3600)

    func test_contentTopInset_belowTheCutOut() {
        XCTAssertEqual(ScreenHelper.contentTopInset(safeAreaTop: 38), 46)
        XCTAssertEqual(ScreenHelper.contentTopInset(safeAreaTop: 0), 28)
    }

    func test_height_minimal_noThirdField() {
        // 46 + 27 + 18 + 13 + 12 + 17 + 22
        XCTAssertEqual(PanelLayout.height(for: snapshot(), topInset: inset), 155)
    }

    func test_height_withThirdField() {
        XCTAssertEqual(PanelLayout.height(for: snapshot(following: follower), topInset: inset), 170)
    }

    func test_height_maximum() {
        let s = snapshot(nested: [meeting(past: false)], following: follower, join: true)
        XCTAssertEqual(PanelLayout.height(for: s, topInset: inset), 236)
    }

    func test_captionGap_onlyForUpcomingNestedMeeting() {
        let upcoming = snapshot(nested: [meeting(past: false)])
        let past = snapshot(nested: [meeting(past: true)])
        XCTAssertEqual(
            PanelLayout.height(for: upcoming, topInset: inset) - PanelLayout.height(for: past, topInset: inset), 28
        )
    }

    func test_joinRow_addsItsHeight() {
        let with = PanelLayout.height(for: snapshot(join: true), topInset: inset)
        let without = PanelLayout.height(for: snapshot(), topInset: inset)
        XCTAssertEqual(with - without, 38)
    }

    func test_height_ignoresCountdownText() {
        var a = snapshot(following: follower)
        var b = a
        a.nestedMeetings = [meeting(past: false)]
        var later = meeting(past: false)
        later = .init(title: "M", startDate: now, endDate: now.addingTimeInterval(1800),
                      startFraction: 0.2, widthFraction: 0.2, isPast: false, secondsUntilStart: 90)
        b.nestedMeetings = [later]
        XCTAssertEqual(PanelLayout.height(for: a, topInset: inset), PanelLayout.height(for: b, topInset: inset))
    }

    func test_thirdField_gapAfterMeeting() {
        XCTAssertEqual(PanelLayout.thirdField(for: snapshot(following: follower)), .gap(minutes: 60, title: "Gym"))
    }

    func test_thirdField_arrowDuringBlock() {
        let s = snapshot(nested: [meeting(past: true)], following: follower)
        XCTAssertEqual(PanelLayout.thirdField(for: s), .arrow(title: "Gym"))
    }

    func test_thirdField_hiddenWithoutFollowingEvent() {
        XCTAssertNil(PanelLayout.thirdField(for: snapshot()))
    }

    func test_secondaryStates_useCompactHeight() {
        let s = snapshot(state: .emptyToday)
        XCTAssertEqual(PanelLayout.height(for: s, topInset: inset), 118)
        XCTAssertEqual(PanelLayout.height(for: snapshot(state: .upcomingToday, allDay: "x"), topInset: inset), 138)
    }
}

final class PanelLayoutJoinTests: XCTestCase {
    private func startingSoon(join: Bool) -> EventProgressSnapshot {
        EventProgressSnapshot(
            title: "T", progress: 0, startTimeLabel: "", endTimeLabel: "", elapsedLabel: "",
            remainingLabel: "", statusLabel: "", secondaryMessage: "Starts in 1m",
            tint: .blue, state: .startingSoon,
            joinURL: join ? URL(string: "https://zoom.us/j/1") : nil
        )
    }

    func test_startingSoon_withLink_getsAJoinRow() {
        XCTAssertTrue(PanelLayout.hasJoinRow(startingSoon(join: true)))
        XCTAssertEqual(
            PanelLayout.height(for: startingSoon(join: true), topInset: 46)
                - PanelLayout.height(for: startingSoon(join: false), topInset: 46),
            PanelLayout.joinRowHeight
        )
    }
}
