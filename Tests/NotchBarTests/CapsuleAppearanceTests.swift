import XCTest
@testable import NotchBar

@MainActor
final class CapsuleAppearanceTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "capsule-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func test_defaultsKeepTheOriginalLook() {
        XCTAssertEqual(CapsuleAppearance.upcomingDefault.height, 23)
        XCTAssertEqual(CapsuleAppearance.pastDefault.height, 17)
        XCTAssertEqual(CapsuleAppearance.upcomingDefault.fill.alpha, 0.32, accuracy: 1e-9)
        XCTAssertEqual(CapsuleAppearance.pastDefault.fill.alpha, 0.62, accuracy: 1e-9)
    }

    func test_heightIsClamped() {
        var a = CapsuleAppearance.pastDefault
        a.height = 100
        XCTAssertEqual(a.clampedHeight, 30)
        a.height = 1
        XCTAssertEqual(a.clampedHeight, 13)
    }

    func test_borderFollowsFillUnlessCustom() {
        var a = CapsuleAppearance.upcomingDefault
        XCTAssertEqual(a.borderColor, a.fill.with(alpha: CapsuleAppearance.automaticBorderAlpha).color)
        a.usesCustomBorder = true
        a.border = RGBAColor(red: 0, green: 1, blue: 0)
        XCTAssertEqual(a.borderColor, a.border.color)
    }

    func test_labelFollowsFillUnlessOverridden() {
        var a = CapsuleAppearance.upcomingDefault
        XCTAssertEqual(a.labelColor, a.fill.with(alpha: 1).color)
        a.labelFollowsFill = false
        a.label = RGBAColor(red: 1, green: 0, blue: 0)
        XCTAssertEqual(a.labelColor, a.label.color)
    }

    func test_preferencesPersistAndReset() {
        let defaults = freshDefaults()
        let prefs = Preferences(defaults: defaults)
        XCTAssertEqual(prefs.pastCapsule, .pastDefault)

        prefs.pastCapsule.height = 20
        XCTAssertEqual(Preferences(defaults: defaults).pastCapsule.height, 20)

        prefs.resetCapsuleAppearance()
        XCTAssertEqual(Preferences(defaults: defaults).pastCapsule, .pastDefault)
    }
}
