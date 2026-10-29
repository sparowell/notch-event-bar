import AppKit
import SwiftUI

struct NotchPanelView: View {
    @ObservedObject var progressModel: EventProgressModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onSettingsTapped: () -> Void

    var body: some View {
        let isExpanded = progressModel.isHoverVisible
        let snapshot = progressModel.snapshot
        let openHeight = ScreenHelper.panelHeight(for: snapshot)
        let motion = PanelMotionStyle(reduceMotion: reduceMotion)

        ZStack(alignment: .top) {
            // Invisible at rest: on a notched Mac the physical notch already shows
            // through, and with nothing drawn there is no overlay layer for the
            // interactive Space-switch gesture to slide along with the desktop.
            // The surface fades/grows in only while the panel is open.
            NotchSurface(isExpanded: isExpanded)
                .frame(
                    width: isExpanded ? ScreenHelper.panelWidth : ScreenHelper.collapsedWidth(),
                    height: isExpanded ? openHeight : ScreenHelper.closedHeight()
                )
                .opacity(isExpanded ? 1 : 0)

            NotchContentView(progressModel: progressModel, shimmerEnabled: motion.shimmerEnabled)
                .frame(width: ScreenHelper.panelWidth, height: openHeight)
                .opacity(isExpanded ? 1 : 0)
                .blur(radius: isExpanded ? 0 : motion.collapsedBlur)
                .scaleEffect(isExpanded ? 1 : motion.collapsedScale, anchor: .top)
                .offset(y: isExpanded ? 0 : motion.collapsedOffsetY)
                .animation(motion.contentAnimation(isExpanded: isExpanded), value: isExpanded)
        }
        .overlay(alignment: .top) {
            // Sits just below the closed notch, the only place a line reads as
            // belonging to it rather than floating on the desktop.
            if !isExpanded, let progress = progressModel.restingProgress {
                RestingProgressLineView(progress: progress, tint: progressModel.snapshot.tint)
                    .frame(width: ScreenHelper.collapsedWidth())
                    .offset(y: ScreenHelper.closedHeight())
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            SettingsOrbButton(action: onSettingsTapped)
                .padding(.top, NotchPanelMetrics.orbTopPadding)
                .padding(.trailing, NotchPanelMetrics.orbTrailingPadding)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : motion.accessoryCollapsedScale, anchor: .topTrailing)
                .allowsHitTesting(isExpanded)
                .animation(motion.contentAnimation(isExpanded: isExpanded), value: isExpanded)
        }
        .overlay(alignment: .bottom) {
            // The content above ignores clicks, so the button lives out here and is
            // placed into the row the content reserves for it.
            if PanelLayout.hasJoinRow(snapshot), let joinURL = snapshot.joinURL {
                JoinButton(tint: snapshot.tint) {
                    NSWorkspace.shared.open(joinURL)
                }
                .padding(.bottom, PanelLayout.bottomPadding)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : motion.accessoryCollapsedScale, anchor: .bottom)
                .allowsHitTesting(isExpanded)
                .animation(motion.contentAnimation(isExpanded: isExpanded), value: isExpanded)
            }
        }
        .frame(width: ScreenHelper.panelWidth, height: openHeight, alignment: .top)
        .compositingGroup()
        .animation(motion.containerAnimation, value: isExpanded)
    }
}

struct NotchContentView: View {
    @ObservedObject var progressModel: EventProgressModel
    let shimmerEnabled: Bool

    var body: some View {
        let snapshot = progressModel.snapshot
        let height = ScreenHelper.panelHeight(for: snapshot)

        Group {
            switch snapshot.state {
            case .inProgress, .onBreak:
                InProgressContent(
                    snapshot: snapshot,
                    isAnimating: progressModel.isHoverVisible && shimmerEnabled,
                    usesEmojiLabels: progressModel.usesEmojiLabels,
                    upcomingCapsule: progressModel.upcomingCapsule,
                    pastCapsule: progressModel.pastCapsule
                )
            case .startingSoon, .upcomingToday, .upcomingLater, .emptyToday, .noCalendar, .accessRevoked:
                SecondaryContent(
                    message: snapshot.secondaryMessage ?? "",
                    allDayMessage: snapshot.allDayMessage
                )
            }
        }
        .padding(.horizontal, NotchPanelMetrics.contentHorizontalPadding)
        .padding(.top, ScreenHelper.contentTopInset())
        .padding(.bottom, PanelLayout.bottomPadding)
        // The running states reserve their own Join row; the message states
        // (starting soon) get it as extra room at the bottom.
        .padding(.bottom, !PanelLayout.isRunningState(snapshot) && PanelLayout.hasJoinRow(snapshot) ? PanelLayout.joinRowHeight : 0)
        .frame(width: ScreenHelper.panelWidth, height: height)
        .allowsHitTesting(false)
    }
}

private struct InProgressContent: View {
    let snapshot: EventProgressSnapshot
    let isAnimating: Bool
    let usesEmojiLabels: Bool
    let upcomingCapsule: CapsuleAppearance
    let pastCapsule: CapsuleAppearance

    var body: some View {
        let gap = PanelLayout.hasUpcomingNestedMeeting(snapshot) ? PanelLayout.captionGap : PanelLayout.plainGap

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(snapshot.title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.white)

                if snapshot.concurrentEventCount > 0 {
                    Text(verbatim: "+\(snapshot.concurrentEventCount)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .fixedSize()
                }

                Spacer(minLength: 0)

                TimeRangeView(
                    start: snapshot.startTimeLabel,
                    end: snapshot.endTimeLabel,
                    duration: snapshot.durationLabel
                )
            }
            .frame(height: PanelLayout.titleRowHeight, alignment: .top)
            .padding(.trailing, NotchPanelMetrics.contentTrailingClearance)

            AnimatedProgressBar(progress: snapshot.progress, tint: snapshot.tint, isAnimating: isAnimating)
                .frame(maxWidth: .infinity)
                .frame(height: PanelLayout.barHeight)
                .overlay {
                    NestedMeetingsBar(
                        tickFractions: snapshot.tickFractions,
                        meetings: snapshot.nestedMeetings,
                        upcoming: upcomingCapsule,
                        past: pastCapsule
                    )
                }
                .padding(.top, gap)

            HStack(alignment: .top, spacing: 16) {
                MetricLabel(titleKey: "Elapsed", emoji: "⏱", usesEmoji: usesEmojiLabels, value: snapshot.elapsedLabel)
                    .fixedSize()

                MetricLabel(titleKey: "Remaining", emoji: "⏳", usesEmoji: usesEmojiLabels, value: snapshot.remainingLabel)
                    .fixedSize()

                Spacer(minLength: 0)

                if let third = PanelLayout.thirdField(for: snapshot) {
                    ThirdField(field: third)
                }
            }
            .frame(height: PanelLayout.metricsHeight(for: snapshot), alignment: .top)
            .padding(.top, PanelLayout.barToMetricsGap)

            if PanelLayout.hasJoinRow(snapshot) {
                // Room for the Join button, which the panel draws on top.
                Color.clear.frame(height: PanelLayout.joinRowHeight)
            }
        }
    }
}

/// `1h → Title` or `→ Title`, right-aligned beside Remaining, two rows at most.
/// An arrow rather than a word, because the row already carries two labelled metrics.
private struct ThirdField: View {
    let field: PanelLayout.ThirdField

    var body: some View {
        let dim = Color.white.opacity(0.42)
        let main = Color.white.opacity(0.78)
        let text: Text = {
            switch field {
            case let .gap(minutes, title):
                return Text(DurationLabel.short(minutes: minutes)).foregroundColor(main)
                    + Text(verbatim: " → ").foregroundColor(dim)
                    + Text(verbatim: title).foregroundColor(main)
            case let .upNext(title):
                return Text("Up next", bundle: Localized.resources).foregroundColor(main)
                    + Text(verbatim: " → ").foregroundColor(dim)
                    + Text(verbatim: title).foregroundColor(main)
            case let .arrow(title):
                return Text(verbatim: "→ ").foregroundColor(dim)
                    + Text(verbatim: title).foregroundColor(main)
            }
        }()

        text
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .lineLimit(2)
            .multilineTextAlignment(.trailing)
            .frame(width: PanelLayout.thirdFieldWidth, alignment: .trailing)
            .accessibilityLabel(Text("Then:", bundle: Localized.resources))
    }
}

private struct SecondaryContent: View {
    let message: String
    var allDayMessage: String?

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            Text(message)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.trailing, 46)

            if let allDayMessage {
                Text(allDayMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .padding(.trailing, 46)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
