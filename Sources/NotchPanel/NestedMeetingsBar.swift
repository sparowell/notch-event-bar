import SwiftUI

/// Pure placement rules for what is drawn over the panel's progress bar, kept
/// apart from the views so they can be tested.
enum NestedMeetingsGeometry {
    /// A capsule never gets narrower than this, so a short meeting stays visible.
    static let minimumCapsuleWidth: CGFloat = 10
    /// A capsule starting right of this share of the bar pins its label to its
    /// right edge instead of its left.
    static let rightAnchorThreshold = 0.55
    /// Widest a label may be before its title is cut with an ellipsis.
    static let maximumLabelWidth: CGFloat = 140
    /// Smallest gap left between two neighbouring labels.
    static let labelGap: CGFloat = 4
    /// Narrowest a label may be squeezed to make room for its neighbour.
    static let minimumLabelWidth: CGFloat = 24

    enum LabelAnchor: Equatable {
        case leading, trailing
    }

    /// Horizontal extent of a capsule on a bar `barWidth` wide.
    static func capsuleFrame(
        startFraction: Double,
        widthFraction: Double,
        barWidth: CGFloat
    ) -> (x: CGFloat, width: CGFloat) {
        guard barWidth > 0 else { return (0, 0) }
        let width = min(max(CGFloat(widthFraction) * barWidth, minimumCapsuleWidth), barWidth)
        let x = min(max(CGFloat(startFraction) * barWidth, 0), barWidth - width)
        return (x, width)
    }

    static func labelAnchor(startFraction: Double) -> LabelAnchor {
        startFraction > rightAnchorThreshold ? .trailing : .leading
    }

    /// Where a label sits: flush with the capsule's left edge, or its right one,
    /// and never wider than the room left on that side inside the bar.
    static func labelFrame(
        capsuleX: CGFloat,
        capsuleWidth: CGFloat,
        anchor: LabelAnchor,
        barWidth: CGFloat
    ) -> (x: CGFloat, width: CGFloat) {
        switch anchor {
        case .leading:
            let width = min(maximumLabelWidth, max(barWidth - capsuleX, 0))
            return (capsuleX, width)
        case .trailing:
            let right = capsuleX + capsuleWidth
            let width = min(maximumLabelWidth, max(right, 0))
            return (right - width, width)
        }
    }

    /// Index of the soonest meeting that has not started; `nil` if none.
    static func nearestFutureIndex(_ meetings: [EventProgressSnapshot.NestedMeeting]) -> Int? {
        var best: Int?
        for (index, meeting) in meetings.enumerated() where !meeting.isPast {
            if let current = best {
                if meeting.secondsUntilStart < meetings[current].secondsUntilStart { best = index }
            } else {
                best = index
            }
        }
        return best
    }

    /// Whole minutes until a start, rounded up so `in 1 min` holds until it
    /// actually begins.
    static func countdownMinutes(secondsUntilStart: Int) -> Int {
        (max(secondsUntilStart, 0) + 59) / 60
    }

    /// Narrows left-anchored labels that would run into the next label to their
    /// right. Right-anchored labels keep their width; if they still collide the
    /// overlap is accepted. Frames are returned in input order.
    static func resolveOverlaps(
        _ frames: [(x: CGFloat, width: CGFloat, anchor: LabelAnchor)]
    ) -> [(x: CGFloat, width: CGFloat)] {
        var result = frames.map { (x: $0.x, width: $0.width) }
        let order = frames.indices.sorted { frames[$0].x < frames[$1].x }
        for (position, index) in order.enumerated() where frames[index].anchor == .leading {
            guard position + 1 < order.count else { continue }
            let next = result[order[position + 1]]
            let room = next.x - labelGap - result[index].x
            if room < result[index].width {
                result[index].width = max(room, minimumLabelWidth)
            }
        }
        return result
    }
}

/// Dividers and nested-meeting capsules drawn over the progress bar. Meant to
/// be an `.overlay` of the bar: it adds nothing to layout and may reach past
/// the bar's top and bottom.
struct NestedMeetingsBar: View {
    static let barHeight: CGFloat = 13
    static let capsuleHeight: CGFloat = 23
    /// A meeting that is over takes less room: it only marks a busy slot.
    static let pastCapsuleHeight: CGFloat = 17
    static let tickWidth: CGFloat = 1.5
    static let capsuleBorderWidth: CGFloat = 1.5
    /// Space between a capsule's top and the label's bottom.
    static let labelSpacing: CGFloat = 3
    static let labelBoxHeight: CGFloat = 30

    // Colours are constants so the amber can be swapped for the meeting's
    // calendar colour later without touching the drawing.
    static let amber = Color(red: 0xF0 / 255, green: 0xA2 / 255, blue: 0x3C / 255)
    static let futureFill = amber.opacity(0.32)
    static let futureBorder = amber
    static let pastFill = Color(red: 214 / 255, green: 178 / 255, blue: 128 / 255).opacity(0.62)
    static let pastBorder = Color(red: 214 / 255, green: 178 / 255, blue: 128 / 255).opacity(0.9)
    static let tickColor = Color.white.opacity(0.22)
    static let labelTitleColor = amber
    static let labelCountdownColor = Color.white.opacity(0.75)

    let tickFractions: [Double]
    let meetings: [EventProgressSnapshot.NestedMeeting]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let capsules = meetings.map {
                NestedMeetingsGeometry.capsuleFrame(
                    startFraction: $0.startFraction,
                    widthFraction: $0.widthFraction,
                    barWidth: width
                )
            }
            let anchors = meetings.map { NestedMeetingsGeometry.labelAnchor(startFraction: $0.startFraction) }
            let raw = meetings.indices.map { i in
                let frame = NestedMeetingsGeometry.labelFrame(
                    capsuleX: capsules[i].x,
                    capsuleWidth: capsules[i].width,
                    anchor: anchors[i],
                    barWidth: width
                )
                return (x: frame.x, width: frame.width, anchor: anchors[i])
            }
            let labels = NestedMeetingsGeometry.resolveOverlaps(raw)
            let nearest = NestedMeetingsGeometry.nearestFutureIndex(meetings)
            let overhang = (Self.capsuleHeight - geo.size.height) / 2

            ZStack(alignment: .topLeading) {
                ForEach(Array(tickFractions.enumerated()), id: \.offset) { _, fraction in
                    Rectangle()
                        .fill(Self.tickColor)
                        .frame(width: Self.tickWidth, height: geo.size.height)
                        .offset(x: CGFloat(fraction) * width - Self.tickWidth / 2)
                }

                ForEach(meetings.indices, id: \.self) { i in
                    let meeting = meetings[i]
                    let capsuleHeight = meeting.isPast ? Self.pastCapsuleHeight : Self.capsuleHeight

                    Capsule()
                        .fill(meeting.isPast ? Self.pastFill : Self.futureFill)
                        .overlay(
                            Capsule().strokeBorder(
                                meeting.isPast ? Self.pastBorder : Self.futureBorder,
                                lineWidth: Self.capsuleBorderWidth
                            )
                        )
                        .frame(width: capsules[i].width, height: capsuleHeight)
                        .offset(x: capsules[i].x, y: -(capsuleHeight - geo.size.height) / 2)

                    if !meeting.isPast {
                        label(for: meeting, showsCountdown: i == nearest, anchor: anchors[i])
                            .frame(
                                width: labels[i].width,
                                height: Self.labelBoxHeight,
                                alignment: anchors[i] == .leading ? .bottomLeading : .bottomTrailing
                            )
                            .offset(x: labels[i].x, y: -overhang - Self.labelSpacing - Self.labelBoxHeight)
                    }
                }
            }
            .frame(width: width, height: geo.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }

    private func label(
        for meeting: EventProgressSnapshot.NestedMeeting,
        showsCountdown: Bool,
        anchor: NestedMeetingsGeometry.LabelAnchor
    ) -> some View {
        VStack(alignment: anchor == .leading ? .leading : .trailing, spacing: 1) {
            Text(verbatim: meeting.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Self.labelTitleColor)
                .lineLimit(1)
                .truncationMode(.tail)

            if showsCountdown {
                let minutes = NestedMeetingsGeometry.countdownMinutes(secondsUntilStart: meeting.secondsUntilStart)
                Text(verbatim: Localized.string("in \(DurationLabel.short(minutes: minutes))"))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Self.labelCountdownColor)
                    .lineLimit(1)
            }
        }
    }
}
