import Foundation
import SwiftUI

enum SnapshotBuilder {
    /// Join appears this long before a meeting starts, and stays while it runs.
    static let joinLeadTime: TimeInterval = 120

    static func computeSnapshot(
        events: [CalendarEvent],
        allDayEvents: [CalendarEvent] = [],
        selectedCalendarIDs: Set<String>,
        now: Date,
        calendar: Calendar,
        locale: Locale = .current,
        dayStart: Date? = nil
    ) -> EventProgressSnapshot {
        guard !selectedCalendarIDs.isEmpty else { return .noCalendar(locale: locale) }

        let relevant = events
            .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
            .sorted { $0.startDate < $1.startDate }

        // Overlapping events: the one ending first is the one the user is
        // waiting on; the others are only counted.
        let running = relevant.filter { $0.startDate <= now && $0.endDate > now }
        let endOfToday = calendar.startOfDay(for: now.addingTimeInterval(86400))
        let upcoming = relevant.filter { $0.startDate > now }
        let allDayTitles = allDayEvents
            .filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
            .filter { $0.startDate <= now && $0.endDate > now }
            .map(\.title)
            .filter { !$0.isEmpty }

        if let current = running.min(by: { $0.endDate < $1.endDate }) {
            var snapshot = inProgressSnapshot(for: current, now: now, calendar: calendar, locale: locale)
            snapshot.concurrentEventCount = running.count - 1
            if let next = upcoming.first, next.startDate < endOfToday {
                snapshot.nextEvent = nextEvent(for: next, calendar: calendar, locale: locale)
            }
            let others = relevant.filter { $0 != current }
            snapshot.nestedMeetings = nestedMeetings(in: current, among: others, now: now, locale: locale)
            snapshot.followingEvent = followingEvent(after: current, among: others, before: endOfToday, locale: locale)
            if snapshot.joinURL == nil {
                // A meeting about to start, inside the running block or not.
                snapshot.joinURL = upcoming
                    .first { $0.startDate.timeIntervalSince(now) <= joinLeadTime }
                    .flatMap(\.joinURL)
            }
            return snapshot
        }

        guard let next = upcoming.first else {
            return .emptyToday(locale: locale, allDayTitles: allDayTitles)
        }

        // Only the states rendered as a centred message have room for it.
        let allDayMessage = EventProgressSnapshot.allDayMessage(for: allDayTitles, locale: locale)

        let secondsUntilStart = next.startDate.timeIntervalSince(now)

        if secondsUntilStart <= 5 * 60 {
            var snapshot = startingSoonSnapshot(for: next, now: now, calendar: calendar, locale: locale)
            snapshot.allDayMessage = allDayMessage
            return snapshot
        }

        if next.startDate < endOfToday {
            let lastEnd = relevant.filter { $0.endDate <= now }.map(\.endDate).max()
            // The window opens when the last event ended, or, before any event
            // today, at the user's start of day.
            var windowStart: Date?
            if let lastEnd, calendar.isDate(lastEnd, inSameDayAs: now) {
                windowStart = lastEnd
            } else if let dayStart, calendar.isDate(dayStart, inSameDayAs: now), now >= dayStart {
                windowStart = dayStart
            }
            if let windowStart {
                return breakSnapshot(from: windowStart, until: next, now: now, calendar: calendar, locale: locale)
            }
            var snapshot = upcomingTodaySnapshot(for: next, now: now, calendar: calendar, locale: locale)
            snapshot.allDayMessage = allDayMessage
            return snapshot
        }

        var snapshot = upcomingLaterSnapshot(for: next, now: now, calendar: calendar, locale: locale)
        snapshot.allDayMessage = allDayMessage
        return snapshot
    }

    /// Events that start and end within `block`, in start order. Ones that run
    /// past its end stay ordinary "next" events.
    private static func nestedMeetings(
        in block: CalendarEvent,
        among events: [CalendarEvent],
        now: Date,
        locale: Locale
    ) -> [EventProgressSnapshot.NestedMeeting] {
        let total = max(block.endDate.timeIntervalSince(block.startDate), 1)
        return events
            .filter { $0.startDate >= block.startDate && $0.endDate <= block.endDate }
            .map { event in
                EventProgressSnapshot.NestedMeeting(
                    title: event.title.nilIfEmpty ?? Localized.string("Upcoming Meeting", locale: locale),
                    startDate: event.startDate,
                    endDate: event.endDate,
                    startFraction: event.startDate.timeIntervalSince(block.startDate) / total,
                    widthFraction: event.endDate.timeIntervalSince(event.startDate) / total,
                    isPast: event.endDate <= now,
                    secondsUntilStart: max(Int(event.startDate.timeIntervalSince(now)), 0),
                    joinURL: event.joinURL
                )
            }
    }

    private static func followingEvent(
        after current: CalendarEvent,
        among events: [CalendarEvent],
        before endOfToday: Date,
        locale: Locale
    ) -> EventProgressSnapshot.FollowingEvent? {
        guard let next = events.first(where: { $0.startDate >= current.endDate }),
              next.startDate < endOfToday else { return nil }
        return EventProgressSnapshot.FollowingEvent(
            title: next.title.nilIfEmpty ?? Localized.string("Upcoming Meeting", locale: locale),
            gapSeconds: Int(next.startDate.timeIntervalSince(current.endDate))
        )
    }

    private static func durationLabel(from start: Date, to end: Date, locale: Locale) -> String {
        DurationLabel.short(minutes: Int(end.timeIntervalSince(start) / 60), locale: locale)
    }

    /// Names the day and time rather than counting down: days away, a live
    /// `DD:HH:MM:SS` was hard to read and redrew every second for nothing.
    private static func upcomingLaterSnapshot(
        for event: CalendarEvent,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> EventProgressSnapshot {
        let title = event.title.nilIfEmpty
            ?? Localized.string("Upcoming Meeting", locale: locale)
        let time = formattedTime(event.startDate, calendar: calendar, locale: locale)
        let startOfTomorrow = calendar.startOfDay(for: now.addingTimeInterval(86400))
        let when = event.startDate < calendar.startOfDay(for: startOfTomorrow.addingTimeInterval(86400))
            ? Localized.string("tomorrow \(time)", locale: locale)
            : "\(formattedWeekday(event.startDate, calendar: calendar, locale: locale)) \(time)"

        return EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: time,
            endTimeLabel: formattedTime(event.endDate, calendar: calendar, locale: locale),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: Localized.string("Upcoming", locale: locale),
            secondaryMessage: Localized.string("Next: \(title) — \(when)", locale: locale),
            tint: event.color,
            state: .upcomingLater,
            durationLabel: durationLabel(from: event.startDate, to: event.endDate, locale: locale)
        )
    }

    private static func inProgressSnapshot(
        for event: CalendarEvent,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> EventProgressSnapshot {
        let total = event.endDate.timeIntervalSince(event.startDate)
        let elapsed = now.timeIntervalSince(event.startDate)
        let progress = min(max(elapsed / max(total, 1), 0), 1)
        let elapsedSeconds = max(Int(elapsed), 0)
        let remainingSeconds = max(Int(event.endDate.timeIntervalSince(now)), 0)
        let title = event.title.nilIfEmpty
            ?? Localized.string("Current Meeting", locale: locale)

        return EventProgressSnapshot(
            title: title,
            progress: progress,
            startTimeLabel: formattedTime(event.startDate, calendar: calendar, locale: locale),
            endTimeLabel: formattedTime(event.endDate, calendar: calendar, locale: locale),
            elapsedLabel: formatDuration(seconds: elapsedSeconds),
            remainingLabel: formatDuration(seconds: remainingSeconds),
            statusLabel: Localized.string("In progress", locale: locale),
            secondaryMessage: nil,
            tint: event.color,
            state: .inProgress,
            joinURL: event.joinURL,
            remainingSeconds: remainingSeconds,
            durationLabel: durationLabel(from: event.startDate, to: event.endDate, locale: locale),
            tickFractions: ProgressTicks.fractions(durationSeconds: total)
        )
    }

    private static func startingSoonSnapshot(
        for event: CalendarEvent,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> EventProgressSnapshot {
        let title = event.title.nilIfEmpty
            ?? Localized.string("Upcoming Meeting", locale: locale)
        let minutes = max(Int(event.startDate.timeIntervalSince(now) / 60), 0)
        let message = minutes == 0
            ? Localized.string("Starts now — \(title)", locale: locale)
            : Localized.string("Starts in \(minutes)m — \(title)", locale: locale)

        return EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: formattedTime(event.startDate, calendar: calendar, locale: locale),
            endTimeLabel: formattedTime(event.endDate, calendar: calendar, locale: locale),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: Localized.string("Starts soon", locale: locale),
            secondaryMessage: message,
            tint: event.color,
            state: .startingSoon,
            joinURL: event.startDate.timeIntervalSince(now) <= joinLeadTime ? event.joinURL : nil,
            durationLabel: durationLabel(from: event.startDate, to: event.endDate, locale: locale)
        )
    }

    private static func upcomingTodaySnapshot(
        for event: CalendarEvent,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> EventProgressSnapshot {
        let title = event.title.nilIfEmpty
            ?? Localized.string("Upcoming Meeting", locale: locale)
        let interval = max(event.startDate.timeIntervalSince(now), 0)
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        let countdown = hours == 0
            ? Localized.string("\(minutes)min", locale: locale)
            : minutes == 0
                ? Localized.string("\(hours)h", locale: locale)
                : Localized.string("\(hours)h \(minutes)min", locale: locale)

        var snapshot = EventProgressSnapshot(
            title: title,
            progress: 0,
            startTimeLabel: formattedTime(event.startDate, calendar: calendar, locale: locale),
            endTimeLabel: formattedTime(event.endDate, calendar: calendar, locale: locale),
            elapsedLabel: "",
            remainingLabel: "",
            statusLabel: Localized.string("Upcoming today", locale: locale),
            secondaryMessage: Localized.string("Next: \(title) in \(countdown)", locale: locale),
            tint: event.color,
            state: .upcomingToday,
            durationLabel: durationLabel(from: event.startDate, to: event.endDate, locale: locale)
        )
        snapshot.nextEvent = nextEvent(for: event, calendar: calendar, locale: locale)
        return snapshot
    }

    /// Shaped like an event in progress — the gap is what the user is waiting
    /// out — but tinted neutral so it never reads as a real one.
    private static func breakSnapshot(
        from start: Date,
        until next: CalendarEvent,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> EventProgressSnapshot {
        let total = next.startDate.timeIntervalSince(start)
        let elapsed = now.timeIntervalSince(start)
        let remainingSeconds = max(Int(next.startDate.timeIntervalSince(now)), 0)
        let label = Localized.string("Break", locale: locale)

        var snapshot = EventProgressSnapshot(
            title: label,
            progress: min(max(elapsed / max(total, 1), 0), 1),
            startTimeLabel: formattedTime(start, calendar: calendar, locale: locale),
            endTimeLabel: formattedTime(next.startDate, calendar: calendar, locale: locale),
            elapsedLabel: formatDuration(seconds: max(Int(elapsed), 0)),
            remainingLabel: formatDuration(seconds: remainingSeconds),
            statusLabel: label,
            secondaryMessage: nil,
            tint: Color.gray,
            state: .onBreak,
            remainingSeconds: remainingSeconds,
            durationLabel: durationLabel(from: start, to: next.startDate, locale: locale)
        )
        snapshot.nextEvent = nextEvent(for: next, calendar: calendar, locale: locale)
        return snapshot
    }

    private static func nextEvent(
        for event: CalendarEvent,
        calendar: Calendar,
        locale: Locale
    ) -> EventProgressSnapshot.NextEvent {
        EventProgressSnapshot.NextEvent(
            title: event.title.nilIfEmpty ?? Localized.string("Upcoming Meeting", locale: locale),
            startTimeLabel: formattedTime(event.startDate, calendar: calendar, locale: locale),
            startDate: event.startDate,
            joinURL: event.joinURL
        )
    }

    private static func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = seconds % 60

        // No `00:` in front when the hours are zero: `39:38`, not `00:39:38`.
        return hours == 0
            ? String(format: "%02d:%02d", minutes, seconds)
            : String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private static func formattedTime(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .omitted,
                time: .shortened,
                locale: locale,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
        )
    }

    private static func formattedWeekday(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated)
        )
    }
}

struct CalendarEvent: Equatable {
    /// EventKit's event identifier. Every instance of a recurring event shares
    /// it, so anything keying off an occurrence must pair it with `startDate`.
    let identifier: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarIdentifier: String
    let color: Color
    var joinURL: URL?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
