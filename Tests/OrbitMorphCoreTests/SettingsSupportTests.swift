import XCTest
@testable import OrbitMorphCore

final class SettingsSupportTests: XCTestCase {
    func testCompatibilityPolicyCannotEnableUnsupportedRoute() {
        let deps = DependencyResolver(overrides: ["ffmpeg": nil, "magick": "/opt/homebrew/bin/magick"])
        let policy = CompatibilityPolicy(registry: ConversionRegistry(dependencies: deps), disabledRoutes: [])
        XCTAssertFalse(policy.isSupported(source: .mov, target: .mp4))
        XCTAssertFalse(policy.isEnabled(source: .mov, target: .mp4))
        XCTAssertTrue(policy.isSupported(source: .png, target: .jpg))
        XCTAssertTrue(policy.isEnabled(source: .png, target: .jpg))
    }

    func testDisabledSupportedRouteBecomesDisabled() {
        let deps = DependencyResolver(overrides: ["magick": "/opt/homebrew/bin/magick"])
        let disabled: Set<DisabledRoute> = [.init(source: .png, target: .webp)]
        let policy = CompatibilityPolicy(registry: ConversionRegistry(dependencies: deps), disabledRoutes: disabled)
        XCTAssertTrue(policy.isSupported(source: .png, target: .webp))
        XCTAssertFalse(policy.isEnabled(source: .png, target: .webp))
    }

    func testFolderRecordRoundTrips() throws {
        let record = FolderRecord(category: .image, displayPath: "/Users/test/Exports", bookmarkData: Data([1,2,3]))
        let data = try JSONEncoder().encode(record)
        XCTAssertEqual(try JSONDecoder().decode(FolderRecord.self, from: data), record)
    }

    func testDependencyDiagnosticsIncludesUnavailableCommands() {
        let resolver = DependencyResolver(overrides: ["ffmpeg": "/opt/homebrew/bin/ffmpeg", "magick": nil])
        let rows = DependencyDiagnostic.rows(resolver: resolver)
        XCTAssertEqual(rows.first(where: { $0.name == "ffmpeg" })?.available, true)
        XCTAssertEqual(rows.first(where: { $0.name == "magick" })?.available, false)
    }
}
