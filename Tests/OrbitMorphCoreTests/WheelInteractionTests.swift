import XCTest
@testable import OrbitMorphCore

final class WheelInteractionTests: XCTestCase {
    func testPageNumbersMapTopToBottomInsideCircularCenter() {
        let center = WheelPoint(x: 155, y: 155)
        XCTAssertEqual(WheelPagination.pageIndex(point: .init(x: 155, y: 130), center: center, radius: 47, pageCount: 2), 0)
        XCTAssertEqual(WheelPagination.pageIndex(point: .init(x: 155, y: 180), center: center, radius: 47, pageCount: 2), 1)
        XCTAssertEqual(WheelPagination.pageIndex(point: .init(x: 155, y: 155), center: center, radius: 47, pageCount: 3), 1)
        XCTAssertNil(WheelPagination.pageIndex(point: .init(x: 190, y: 190), center: center, radius: 47, pageCount: 2))
        XCTAssertNil(WheelPagination.pageIndex(point: center, center: center, radius: 47, pageCount: 1))
    }

    func testDwellSwitchesOnceAndRequiresContinuousHover() {
        var dwell = WheelPageDwellState()
        XCTAssertNil(dwell.update(candidate: 1, currentPage: 0, now: 10))
        XCTAssertNil(dwell.update(candidate: 1, currentPage: 0, now: 10.2))
        XCTAssertEqual(dwell.update(candidate: 1, currentPage: 0, now: 10.36), 1)
        XCTAssertNil(dwell.update(candidate: 1, currentPage: 1, now: 11))
        XCTAssertNil(dwell.update(candidate: 0, currentPage: 1, now: 11.1))
        XCTAssertNil(dwell.update(candidate: nil, currentPage: 1, now: 11.3))
        XCTAssertNil(dwell.update(candidate: 0, currentPage: 1, now: 12))
        XCTAssertNil(dwell.update(candidate: 0, currentPage: 1, now: 12.2))
        XCTAssertEqual(dwell.update(candidate: 0, currentPage: 1, now: 12.36), 0)
        dwell.cancel()
        XCTAssertNil(dwell.update(candidate: 2, currentPage: 0, now: 13))
    }

    func testPlacementUsesPointerDisplayIncludingNegativeAndUpperOrigins() {
        let screens = [
            WheelScreen(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), visibleFrame: CGRect(x: 0, y: 24, width: 1920, height: 1032)),
            WheelScreen(frame: CGRect(x: -2560, y: -400, width: 2560, height: 1440), visibleFrame: CGRect(x: -2560, y: -376, width: 2560, height: 1392)),
            WheelScreen(frame: CGRect(x: 500, y: 1080, width: 1600, height: 900), visibleFrame: CGRect(x: 500, y: 1104, width: 1600, height: 852))
        ]
        let size = CGSize(width: 310, height: 310)
        let left = WheelPlacement.frame(at: .init(x: -1000, y: 500), size: size, screens: screens)
        XCTAssertEqual(left.midX, -1000)
        XCTAssertEqual(left.midY, 500)
        let upper = WheelPlacement.frame(at: .init(x: 1000, y: 1500), size: size, screens: screens)
        XCTAssertEqual(upper.midX, 1000)
        XCTAssertEqual(upper.midY, 1500)
        let edge = WheelPlacement.frame(at: .init(x: -2559, y: -399), size: size, screens: screens)
        XCTAssertEqual(edge.origin, CGPoint(x: -2560, y: -376))
    }

    func testPlacementChoosesNearestScreenInGapAndHandlesSmallVisibleArea() {
        let screen = WheelScreen(frame: CGRect(x: -500, y: -500, width: 200, height: 200), visibleFrame: CGRect(x: -500, y: -480, width: 200, height: 180))
        let frame = WheelPlacement.frame(at: .init(x: -510, y: -510), size: .init(width: 310, height: 310), screens: [screen])
        XCTAssertEqual(frame.minX, -500)
        XCTAssertEqual(frame.minY, -480)
        XCTAssertTrue(frame.minX.isFinite && frame.minY.isFinite)
    }
}
