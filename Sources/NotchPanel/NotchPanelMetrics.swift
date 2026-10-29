import CoreGraphics

/// Geometry shared by the notch panel's content and the settings orb drawn on
/// top of it.
///
/// The orb lives in a `.overlay(alignment: .topTrailing)`, so it paints over
/// whatever the content puts in that corner — the event's time range, on the
/// in-progress layout. Nothing in SwiftUI reserves that space automatically:
/// the content has to inset itself by `contentTrailingClearance`. Deriving that
/// inset from the orb's own size here is what keeps the two from drifting apart
/// the next time either is retuned.
enum NotchPanelMetrics {
    /// Diameter of the settings orb's circular background.
    static let orbDiameter: CGFloat = 26
    /// Point size of the gear glyph inside the orb.
    static let orbIconSize: CGFloat = 12
    static let orbTopPadding: CGFloat = 18
    static let orbTrailingPadding: CGFloat = 20

    /// Horizontal inset applied to the panel's content.
    static let contentHorizontalPadding: CGFloat = 28

    /// Breathing room kept between the orb and any content drawn beside it.
    static let orbClearanceGap: CGFloat = 8

    /// Extra trailing inset a content row sharing the orb's line must add on top
    /// of `contentHorizontalPadding` to stay clear of it.
    static let contentTrailingClearance: CGFloat =
        orbTrailingPadding + orbDiameter + orbClearanceGap - contentHorizontalPadding

    /// Gap actually left between the content's trailing edge and the orb's
    /// leading edge. Independent of the panel width: both are measured from the
    /// trailing edge, so it cancels out.
    static var effectiveOrbClearance: CGFloat {
        (contentHorizontalPadding + contentTrailingClearance) - (orbTrailingPadding + orbDiameter)
    }
}

/// Vertical layout of the open panel. Heights depend only on the snapshot's
/// *state* (is there an upcoming nested meeting, a third field, a Join row),
/// never on text length or the second-by-second countdown, so the panel does
/// not jump on the 30 s refresh.
enum PanelLayout {
    static let titleRowHeight: CGFloat = 27
    /// Gap under the title row when a nested meeting's caption rides above the bar.
    static let captionGap: CGFloat = 46
    static let plainGap: CGFloat = 18
    static let barHeight: CGFloat = 13
    static let barToMetricsGap: CGFloat = 12
    static let singleRowMetricsHeight: CGFloat = 17
    static let twoRowMetricsHeight: CGFloat = 32
    static let joinRowHeight: CGFloat = 38
    static let bottomPadding: CGFloat = 22
    /// Width of the third bottom field, right of Remaining.
    static let thirdFieldWidth: CGFloat = 150
    /// Content area (below the top inset) of the centred-message states.
    static let secondaryContentHeight: CGFloat = 50
    static let secondaryAllDayExtra: CGFloat = 20

    static func isRunningState(_ snapshot: EventProgressSnapshot) -> Bool {
        snapshot.state == .inProgress || snapshot.state == .onBreak
    }

    static func hasUpcomingNestedMeeting(_ snapshot: EventProgressSnapshot) -> Bool {
        snapshot.nestedMeetings.contains { !$0.isPast }
    }

    static func hasJoinRow(_ snapshot: EventProgressSnapshot) -> Bool {
        (isRunningState(snapshot) || snapshot.state == .startingSoon) && snapshot.joinURL != nil
    }

    /// What the third bottom field says, or `nil` to hide it.
    enum ThirdField: Equatable {
        /// `1h → Title`: gap to the event following a meeting.
        case gap(minutes: Int, title: String)
        /// `→ Title`: a block (or break) is running, no time shown.
        case arrow(title: String)
    }

    static func thirdField(for snapshot: EventProgressSnapshot) -> ThirdField? {
        switch snapshot.state {
        case .inProgress:
            guard let following = snapshot.followingEvent else { return nil }
            if !snapshot.nestedMeetings.isEmpty {
                return .arrow(title: following.title)
            }
            return .gap(minutes: following.gapSeconds / 60, title: following.title)
        case .onBreak:
            return snapshot.nextEvent.map { .arrow(title: $0.title) }
        default:
            return nil
        }
    }

    static func metricsHeight(for snapshot: EventProgressSnapshot) -> CGFloat {
        thirdField(for: snapshot) == nil ? singleRowMetricsHeight : twoRowMetricsHeight
    }

    static func height(for snapshot: EventProgressSnapshot, topInset: CGFloat) -> CGFloat {
        guard isRunningState(snapshot) else {
            let extra = snapshot.allDayMessage == nil ? 0 : secondaryAllDayExtra
            let join = hasJoinRow(snapshot) ? joinRowHeight : 0
            return topInset + secondaryContentHeight + extra + join + bottomPadding
        }
        let gap = hasUpcomingNestedMeeting(snapshot) ? captionGap : plainGap
        let join = hasJoinRow(snapshot) ? joinRowHeight : 0
        return topInset + titleRowHeight + gap + barHeight + barToMetricsGap
            + metricsHeight(for: snapshot) + join + bottomPadding
    }
}
