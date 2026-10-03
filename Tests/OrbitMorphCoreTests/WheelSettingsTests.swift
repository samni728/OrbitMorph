import XCTest
@testable import OrbitMorphCore

final class WheelSettingsTests: XCTestCase {
    func testEightSegmentGeometryMapsTopClockwise() {
        let c = WheelPoint(x: 100, y: 100)
        XCTAssertEqual(WheelGeometry.segmentIndex(point: .init(x: 100, y: 20), center: c, innerRadius: 20, outerRadius: 100, count: 8), 0)
        XCTAssertEqual(WheelGeometry.segmentIndex(point: .init(x: 160, y: 40), center: c, innerRadius: 20, outerRadius: 100, count: 8), 1)
        XCTAssertEqual(WheelGeometry.segmentIndex(point: .init(x: 180, y: 100), center: c, innerRadius: 20, outerRadius: 100, count: 8), 2)
    }

    func testGeometryRejectsDeadZoneAndOutsideRadius() {
        let c = WheelPoint(x: 0, y: 0)
        XCTAssertNil(WheelGeometry.segmentIndex(point: .init(x: 5, y: 5), center: c, innerRadius: 20, outerRadius: 100, count: 8))
        XCTAssertNil(WheelGeometry.segmentIndex(point: .init(x: 0, y: -120), center: c, innerRadius: 20, outerRadius: 100, count: 8))
    }

    func testModifierRoutingPrefersToolsForOptionShift() {
        XCTAssertEqual(ModifierMatcher.mode(shift: true, option: false), .conversion)
        XCTAssertEqual(ModifierMatcher.mode(shift: true, option: true), .tools)
        XCTAssertNil(ModifierMatcher.mode(shift: false, option: true))
        XCTAssertNil(ModifierMatcher.mode(shift: false, option: false))
    }

    func testSettingsRoundTripPreservesOverrides() throws {
        var settings = AppSettings.default
        settings.appearance = .solid
        settings.soundAndHaptics = false
        settings.formatDefaults[.jpg] = FormatDefaults(quality: 0.82, audioBitrateKbps: nil, videoPreset: nil, preserveMetadata: false, archiveLevel: nil)
        settings.disabledRoutes.insert(.init(source: .png, target: .webp))

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(restored, settings)
    }

    func testSettingsStorePersistsAndLoads() throws {
        let suite = "OrbitMorphTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings.default
        settings.launchAtLogin = true
        try store.save(settings)
        XCTAssertEqual(try store.load(), settings)
    }
}
