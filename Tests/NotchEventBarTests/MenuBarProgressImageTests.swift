import SwiftUI
import XCTest
@testable import NotchEventBar

final class MenuBarProgressImageTests: XCTestCase {
    private func snapshot(state: EventProgressSnapshot.State, progress: Double, tint: Color = .orange) -> EventProgressSnapshot {
        EventProgressSnapshot(
            title: "Maths", progress: progress, startTimeLabel: "10:00", endTimeLabel: "11:00",
            elapsedLabel: "", remainingLabel: "", statusLabel: "", secondaryMessage: nil,
            tint: tint, state: state
        )
    }

    func test_fill_inProgressAndBreak_returnProgressAndTint() {
        let running = MenuBarProgressImage.fill(for: snapshot(state: .inProgress, progress: 0.4), enabled: true)
        XCTAssertEqual(running?.progress, 0.4)
        XCTAssertEqual(running?.tint, .orange)
        let onBreak = MenuBarProgressImage.fill(for: snapshot(state: .onBreak, progress: 0.7, tint: .gray), enabled: true)
        XCTAssertEqual(onBreak?.progress, 0.7)
        XCTAssertEqual(onBreak?.tint, .gray)
    }

    func test_fill_otherStates_returnNil() {
        let others: [EventProgressSnapshot.State] = [.startingSoon, .upcomingToday, .upcomingLater, .emptyToday, .noCalendar, .accessRevoked]
        for state in others {
            XCTAssertNil(MenuBarProgressImage.fill(for: snapshot(state: state, progress: 0.5), enabled: true), "\(state)")
        }
    }

    func test_fill_disabled_returnsNil() {
        XCTAssertNil(MenuBarProgressImage.fill(for: snapshot(state: .inProgress, progress: 0.5), enabled: false))
    }

    func test_fill_clampsProgress() {
        XCTAssertEqual(MenuBarProgressImage.fill(for: snapshot(state: .inProgress, progress: -0.2), enabled: true)?.progress, 0)
        XCTAssertEqual(MenuBarProgressImage.fill(for: snapshot(state: .inProgress, progress: 1.7), enabled: true)?.progress, 1)
    }

    func test_filledWidth_quantisesToWholeSteps() {
        XCTAssertEqual(MenuBarProgressImage.filledWidth(for: 0), 0)
        XCTAssertEqual(MenuBarProgressImage.filledWidth(for: 0.5), 14)
        XCTAssertEqual(MenuBarProgressImage.filledWidth(for: 1), 28)
        XCTAssertEqual(MenuBarProgressImage.filledWidth(for: 0.5), MenuBarProgressImage.filledWidth(for: 0.505))
        XCTAssertEqual(MenuBarProgressImage.filledWidth(for: -1), 0)
        XCTAssertEqual(MenuBarProgressImage.filledWidth(for: 3), 28)
    }

    func test_image_hasBarSizeAndIsNotTemplate() {
        let image = MenuBarProgressImage.image(filledWidth: 10, tint: .orange)
        XCTAssertEqual(image.size, MenuBarProgressImage.size)
        XCTAssertFalse(image.isTemplate)
    }
}
