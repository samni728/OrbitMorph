import XCTest
@testable import OrbitMorphCore

final class WheelPresentationTests: XCTestCase {
    func testPresentationLimitsVisibleSegmentsAndKeepsOrder() {
        let state = WheelPresentationState(options: [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif, .pdf])
        XCTAssertEqual(state.visibleOptions, [.jpg, .png, .webp, .heic, .tiff, .avif, .bmp, .gif])
    }

    func testSelectionAndCancelState() {
        var state = WheelPresentationState(options: [.jpg, .png, .webp])
        state.select(index: 1)
        XCTAssertEqual(state.selectedOption, .png)
        state.cancel()
        XCTAssertNil(state.selectedOption)
        XCTAssertTrue(state.isCancelled)
    }

    func testReduceMotionRemovesRotation() {
        XCTAssertEqual(WheelAnimationSpec.default.rotationDegrees, -10)
        XCTAssertGreaterThan(WheelAnimationSpec.default.duration, 0.15)
        XCTAssertEqual(WheelAnimationSpec.reduceMotion.rotationDegrees, 0)
        XCTAssertLessThan(WheelAnimationSpec.reduceMotion.duration, WheelAnimationSpec.default.duration)
    }
}
