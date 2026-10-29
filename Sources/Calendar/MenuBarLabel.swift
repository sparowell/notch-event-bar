import Foundation

/// Compact countdown rendered next to the menu-bar icon. Deliberately answers a
/// single question — "how long until this is over?" — so it stays a few glyphs
/// wide and never competes with the notch panel for detail.
enum MenuBarLabel {
    static func text(
        for snapshot: EventProgressSnapshot,
        enabled: Bool,
        locale: Locale = .current,
        now: Date = Date()
    ) -> String? {
        guard enabled else { return nil }

        switch snapshot.state {
        case .inProgress:
            let remaining = text(remainingSeconds: snapshot.remainingSeconds, locale: locale)
            guard let next = nextLabel(snapshot.nextEvent, now: now, locale: locale) else { return remaining }
            guard let remaining else { return next }
            return Localized.string("\(remaining) · \(next)", locale: locale)
        case .onBreak, .upcomingToday:
            return nextLabel(snapshot.nextEvent, now: now, locale: locale)
        default:
            return text(remainingSeconds: snapshot.remainingSeconds, locale: locale)
        }
    }

    static let maximumTitleLength = 20

    /// Trimmed, cut on grapheme boundaries so emoji are never split.
    static func truncatedTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maximumTitleLength else { return trimmed }
        return String(trimmed.prefix(maximumTitleLength)) + "…"
    }

    private static func nextLabel(_ next: EventProgressSnapshot.NextEvent?, now: Date, locale: Locale) -> String? {
        guard let next,
              let delta = text(remainingSeconds: Int(next.startDate.timeIntervalSince(now)), locale: locale)
        else { return nil }
        let title = truncatedTitle(next.title)
        return Localized.string("→ \(title) in \(delta)", locale: locale)
    }

    static func text(remainingSeconds: Int?, locale: Locale = .current) -> String? {
        guard let remainingSeconds, remainingSeconds > 0 else { return nil }

        // Round up: a countdown that reads "0 min" while the event is still
        // running is wrong, and the last minute should tick away as "1 min".
        let totalMinutes = (remainingSeconds + 59) / 60
        return DurationLabel.short(minutes: totalMinutes, locale: locale)
    }
}
