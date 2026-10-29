import SwiftUI
import XCTest
@testable import NotchBar

final class MenuBarLabelTests: XCTestCase {
    private let english = Locale(identifier: "en")

    private static func inProgressSnapshot(remainingSeconds: Int) -> EventProgressSnapshot {
        EventProgressSnapshot(
            title: "Standup",
            progress: 0.5,
            startTimeLabel: "10:00",
            endTimeLabel: "10:30",
            elapsedLabel: "00:15:00",
            remainingLabel: "00:15:00",
            statusLabel: "In progress",
            secondaryMessage: nil,
            tint: .blue,
            state: .inProgress,
            remainingSeconds: remainingSeconds
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 06:13 UTC on the reference day, so both events fall on the same day.
    func test_text_countsDownABreak() {
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let snapshot = SnapshotBuilder.computeSnapshot(
            events: [
                CalendarEvent(identifier: "a", title: "A", startDate: now.addingTimeInterval(-3600),
                              endDate: now.addingTimeInterval(-600), calendarIdentifier: "c", color: .blue),
                CalendarEvent(identifier: "b", title: "B", startDate: now.addingTimeInterval(12 * 60),
                              endDate: now.addingTimeInterval(3600), calendarIdentifier: "c", color: .blue),
            ],
            selectedCalendarIDs: ["c"],
            now: now,
            calendar: utcCalendar,
            locale: english
        )

        XCTAssertEqual(snapshot.state, .onBreak)
        XCTAssertEqual(MenuBarLabel.text(for: snapshot, enabled: true, locale: english, now: now), "→ B in 12 min")
    }

    // MARK: - Nothing to count down

    func test_text_isNil_whenNoRemainingSeconds() {
        XCTAssertNil(MenuBarLabel.text(remainingSeconds: nil, locale: english))
    }

    func test_text_isNil_whenRemainingIsZeroOrNegative() {
        XCTAssertNil(MenuBarLabel.text(remainingSeconds: 0, locale: english))
        XCTAssertNil(MenuBarLabel.text(remainingSeconds: -30, locale: english))
    }

    // MARK: - Under an hour: minutes, rounded up

    func test_text_roundsPartialMinuteUp_soItNeverReadsZero() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 1, locale: english), "1 min")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 59, locale: english), "1 min")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 60, locale: english), "1 min")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 61, locale: english), "2 min")
    }

    func test_text_showsMinutes_underOneHour() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 23 * 60, locale: english), "23 min")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 59 * 60, locale: english), "59 min")
    }

    // MARK: - One hour and over: padded hours notation

    func test_text_switchesToHoursNotation_atOneHour() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 3600, locale: english), "1h")
    }

    func test_text_rollsUpToTheNextHour_whenMinutesRoundTo60() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 3599, locale: english), "1h")
    }

    func test_text_padsMinutesToTwoDigits() {
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 3660, locale: english), "1h01")
        XCTAssertEqual(MenuBarLabel.text(remainingSeconds: 2 * 3600 + 45 * 60, locale: english), "2h45")
    }

    // MARK: - Derivation from a snapshot

    func test_textForSnapshot_isNil_whenTheToggleIsOff() {
        let snapshot = Self.inProgressSnapshot(remainingSeconds: 900)

        XCTAssertNil(MenuBarLabel.text(for: snapshot, enabled: false, locale: english))
    }

    func test_textForSnapshot_countsDownTheRunningEvent() {
        let snapshot = Self.inProgressSnapshot(remainingSeconds: 900)

        XCTAssertEqual(MenuBarLabel.text(for: snapshot, enabled: true, locale: english), "15 min")
    }

    func test_textForSnapshot_isNil_whenNothingIsRunning() {
        XCTAssertNil(MenuBarLabel.text(for: .emptyToday(), enabled: true, locale: english))
        XCTAssertNil(MenuBarLabel.text(for: .accessRevoked(), enabled: true, locale: english))
    }

    // MARK: - French typography

    func test_text_usesFrenchSpacing_forHours() {
        let value = MenuBarLabel.text(remainingSeconds: 3660, locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "1 h 01")
    }

    func test_text_isIdenticalInFrench_forMinutes() {
        let value = MenuBarLabel.text(remainingSeconds: 23 * 60, locale: Locale(identifier: "fr"))
        XCTAssertEqual(value, "23 min")
    }

    // MARK: - Next-event label

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func snapshot(
        _ state: EventProgressSnapshot.State,
        remaining: Int? = nil,
        next: (String, TimeInterval)? = nil
    ) -> EventProgressSnapshot {
        var s = EventProgressSnapshot(
            title: "X", progress: 0, startTimeLabel: "", endTimeLabel: "", elapsedLabel: "",
            remainingLabel: "", statusLabel: "", secondaryMessage: nil, tint: .blue,
            state: state, remainingSeconds: remaining
        )
        if let next {
            s.nextEvent = .init(title: next.0, startTimeLabel: "", startDate: now.addingTimeInterval(next.1))
        }
        return s
    }

    private func label(_ s: EventProgressSnapshot, locale: Locale? = nil) -> String? {
        MenuBarLabel.text(for: s, enabled: true, locale: locale ?? english, now: now)
    }

    func test_inProgress_withNext() {
        XCTAssertEqual(label(snapshot(.inProgress, remaining: 23 * 60, next: ("Standup", 35 * 60))),
                       "23 min · → Standup in 35 min")
    }

    func test_inProgress_withoutNext() {
        XCTAssertEqual(label(snapshot(.inProgress, remaining: 23 * 60)), "23 min")
    }

    func test_onBreak() {
        XCTAssertEqual(label(snapshot(.onBreak, remaining: 600, next: ("Standup", 600))), "→ Standup in 10 min")
    }

    func test_upcomingToday() {
        XCTAssertEqual(label(snapshot(.upcomingToday, next: ("Review", 3 * 3600 + 5 * 60))), "→ Review in 3h05")
    }

    func test_deltaOverOneHour() {
        XCTAssertEqual(label(snapshot(.inProgress, remaining: 3900, next: ("A", 7200))), "1h05 · → A in 2h")
    }

    func test_upcomingToday_withoutNext_isNil() {
        XCTAssertNil(label(snapshot(.upcomingToday)))
    }

    func test_disabled_isNil() {
        let s = snapshot(.upcomingToday, next: ("A", 600))
        XCTAssertNil(MenuBarLabel.text(for: s, enabled: false, locale: english, now: now))
    }

    func test_otherStates_unchanged() {
        XCTAssertNil(label(snapshot(.upcomingLater, next: ("A", 600))))
        XCTAssertNil(label(snapshot(.startingSoon, next: ("A", 600))))
    }

    func test_truncation() {
        let exact = String(repeating: "a", count: 20)
        XCTAssertEqual(MenuBarLabel.truncatedTitle(exact), exact)
        XCTAssertEqual(MenuBarLabel.truncatedTitle(exact + "b"), exact + "…")
        XCTAssertEqual(MenuBarLabel.truncatedTitle("  hi  "), "hi")
        let emoji = String(repeating: "👨‍👩‍👧", count: 21)
        XCTAssertEqual(MenuBarLabel.truncatedTitle(emoji), String(repeating: "👨‍👩‍👧", count: 20) + "…")
    }

    func test_french() {
        XCTAssertEqual(label(snapshot(.inProgress, remaining: 23 * 60, next: ("Standup", 35 * 60)),
                             locale: Locale(identifier: "fr")),
                       "23 min · → Standup dans 35 min")
    }

    func test_builderExposesNextEvent_forUpcomingToday() {
        let s = SnapshotBuilder.computeSnapshot(
            events: [CalendarEvent(identifier: "b", title: "B", startDate: now.addingTimeInterval(3 * 3600),
                                   endDate: now.addingTimeInterval(4 * 3600), calendarIdentifier: "c", color: .blue)],
            selectedCalendarIDs: ["c"], now: now, calendar: utcCalendar, locale: english)
        XCTAssertEqual(s.state, .upcomingToday)
        XCTAssertEqual(s.nextEvent?.title, "B")
        XCTAssertEqual(label(s), "→ B in 3h")
    }
}

@MainActor
final class TitleWordLimitTests: XCTestCase {
    func test_keepsFirstWordsAndAddsEllipsis() {
        XCTAssertEqual(MenuBarLabel.truncatedTitle("Weekly sync with design team", wordLimit: 3), "Weekly sync with…")
    }

    func test_shortTitleIsUntouched() {
        XCTAssertEqual(MenuBarLabel.truncatedTitle("Standup  now", wordLimit: 3), "Standup  now")
    }

    func test_noLimit_keepsAllWords() {
        XCTAssertEqual(MenuBarLabel.truncatedTitle("a b c d e"), "a b c d e")
    }

    func test_characterCapStillApplies() {
        let result = MenuBarLabel.truncatedTitle("Internationalization Documentation review", wordLimit: 2)
        XCTAssertLessThanOrEqual(result.count, MenuBarLabel.maximumTitleLength + 1)
    }

    func test_limitIsClamped() {
        XCTAssertEqual(Preferences.clampedWordLimit(0), 1)
        XCTAssertEqual(Preferences.clampedWordLimit(99), 10)
    }
}
