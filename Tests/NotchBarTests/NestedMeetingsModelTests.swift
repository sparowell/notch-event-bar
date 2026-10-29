import XCTest
import SwiftUI
@testable import NotchBar

final class NestedMeetingsModelTests: XCTestCase {
    private let calendarID = "cal"
    private let english = Locale(identifier: "en_GB")
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    // 12:00 UTC, so the rest of the day fits a 4 h block plus a follower.
    private lazy var now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 12))!

    private func event(
        _ title: String, start: TimeInterval, minutes: Double, join: String? = nil
    ) -> CalendarEvent {
        CalendarEvent(
            identifier: "\(title)-\(start)",
            title: title,
            startDate: now.addingTimeInterval(start),
            endDate: now.addingTimeInterval(start + minutes * 60),
            calendarIdentifier: calendarID,
            color: .blue,
            joinURL: join.flatMap(URL.init(string:))
        )
    }

    private func snapshot(_ events: [CalendarEvent]) -> EventProgressSnapshot {
        SnapshotBuilder.computeSnapshot(
            events: events, selectedCalendarIDs: [calendarID],
            now: now, calendar: calendar, locale: english
        )
    }

    // MARK: - Ticks

    func test_ticks_byDuration() {
        XCTAssertEqual(ProgressTicks.fractions(durationSeconds: 45 * 60), [])
        XCTAssertEqual(ProgressTicks.fractions(durationSeconds: 60 * 60), [0.5])
        XCTAssertEqual(ProgressTicks.fractions(durationSeconds: 90 * 60), [1.0 / 3, 2.0 / 3])
        XCTAssertEqual(ProgressTicks.fractions(durationSeconds: 120 * 60), [0.25, 0.5, 0.75])
        XCTAssertEqual(ProgressTicks.fractions(durationSeconds: 8 * 3600), [0.25, 0.5, 0.75])
    }

    // MARK: - Duration label

    func test_durationLabel_dropsZeroMinutes() {
        XCTAssertEqual(DurationLabel.short(minutes: 45, locale: english), "45 min")
        XCTAssertEqual(DurationLabel.short(minutes: 60, locale: english), "1h")
        XCTAssertEqual(DurationLabel.short(minutes: 90, locale: english), "1h30")
        XCTAssertEqual(DurationLabel.short(minutes: 240, locale: english), "4h")
    }

    func test_snapshot_carriesDurationAndTicks() {
        let s = snapshot([event("Block", start: -600, minutes: 90)])
        XCTAssertEqual(s.durationLabel, "1h30")
        XCTAssertEqual(s.tickFractions.count, 2)
    }

    // MARK: - Nested meetings

    func test_nested_listsOnlyMeetingsInsideTheBlock() {
        let block = event("Block", start: -3600, minutes: 240)
        let inside = event("Sync", start: 1800, minutes: 30)
        let past = event("Done", start: -1800, minutes: 15)
        let overrun = event("Overrun", start: 3 * 3600 - 600, minutes: 30)
        let s = snapshot([block, inside, past, overrun])

        XCTAssertEqual(s.title, "Block")
        XCTAssertEqual(s.nestedMeetings.map(\.title), ["Done", "Sync"])
        XCTAssertEqual(s.nestedMeetings.map(\.isPast), [true, false])
    }

    func test_nested_geometryIsFractionsOfTheBlock() {
        // Block 11:00–15:00, meeting 12:30–13:00.
        let s = snapshot([event("Block", start: -3600, minutes: 240), event("Sync", start: 1800, minutes: 30)])
        let sync = s.nestedMeetings[0]
        XCTAssertEqual(sync.startFraction, 1.5 / 4, accuracy: 1e-9)
        XCTAssertEqual(sync.widthFraction, 0.5 / 4, accuracy: 1e-9)
        XCTAssertEqual(sync.secondsUntilStart, 1800)
    }

    // MARK: - Following event

    func test_following_isFirstEventStartingAfterTheCurrentEnds_withGap() {
        let s = snapshot([
            event("Meeting", start: -600, minutes: 60),
            event("Gym", start: 50 * 60 + 3600, minutes: 60),
        ])
        XCTAssertEqual(s.followingEvent, .init(title: "Gym", gapSeconds: 3600))
    }

    func test_following_nilWhenNothingAfter() {
        XCTAssertNil(snapshot([event("Meeting", start: -600, minutes: 60)]).followingEvent)
    }

    // MARK: - Join

    func test_join_appearsTwoMinutesBeforeANestedMeeting() {
        let block = event("Block", start: -3600, minutes: 240)
        let nested = { (offset: TimeInterval) in
            self.event("Call", start: offset, minutes: 30, join: "https://meet.google.com/abc-defg-hij")
        }
        XCTAssertNil(snapshot([block, nested(180)]).joinURL)
        XCTAssertNotNil(snapshot([block, nested(120)]).joinURL)
    }

    func test_join_startingSoonOnlyInsideTwoMinutes() {
        let link = "https://zoom.us/j/1"
        XCTAssertNil(snapshot([event("Call", start: 4 * 60, minutes: 30, join: link)]).joinURL)
        XCTAssertNotNil(snapshot([event("Call", start: 90, minutes: 30, join: link)]).joinURL)
    }

    func test_nextEvent_carriesJoinURL() {
        let s = snapshot([
            event("Now", start: -600, minutes: 60),
            event("Call", start: 2 * 3600, minutes: 30, join: "https://zoom.us/j/1"),
        ])
        XCTAssertEqual(s.nextEvent?.joinURL, URL(string: "https://zoom.us/j/1"))
    }
}
