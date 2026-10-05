import Foundation

/// Coordinates use a top-down Y axis, matching the wheel's rendered page rows.
public enum WheelPagination {
    public static func pageIndex(point: WheelPoint, center: WheelPoint, radius: Double, pageCount: Int) -> Int? {
        guard pageCount > 1, radius > 0, radius.isFinite,
              point.x.isFinite, point.y.isFinite else { return nil }
        let dx = point.x - center.x, dy = point.y - center.y
        guard hypot(dx, dy) <= radius else { return nil }
        let row = Int(floor((dy + radius) / (2 * radius) * Double(pageCount)))
        return min(max(row, 0), pageCount - 1)
    }
}

/// A continuous hover switches once. Moving away or cancellation resets the dwell.
public struct WheelPageDwellState: Sendable {
    public let delay: Double
    private var candidate: Int?
    private var enteredAt: Double?
    private var fired = false

    public init(delay: Double = 0.35) { self.delay = max(0, delay) }

    public mutating func update(candidate: Int?, currentPage: Int, now: Double) -> Int? {
        guard let candidate, candidate >= 0, candidate != currentPage, now.isFinite else {
            cancel(); return nil
        }
        if candidate != self.candidate {
            self.candidate = candidate; enteredAt = now; fired = false
        }
        guard !fired, let enteredAt, now - enteredAt >= delay else { return nil }
        fired = true
        return candidate
    }

    public mutating func cancel() { candidate = nil; enteredAt = nil; fired = false }
}

public struct WheelScreen: Sendable {
    public let frame: CGRect
    public let visibleFrame: CGRect
    public init(frame: CGRect, visibleFrame: CGRect) { self.frame = frame; self.visibleFrame = visibleFrame }
}

public enum WheelPlacement {
    /// Screen frames and pointer use AppKit's global bottom-up coordinates.
    /// Choose by full frame (including the menu bar), then clamp to visible space.
    public static func frame(at point: WheelPoint, size: CGSize, screens: [WheelScreen]) -> CGRect {
        let pointer = CGPoint(x: point.x, y: point.y)
        let fallback = CGRect(x: 0, y: 0, width: 1200, height: 800)
        func distance(to rect: CGRect) -> Double {
            let dx = max(rect.minX - pointer.x, 0, pointer.x - rect.maxX)
            let dy = max(rect.minY - pointer.y, 0, pointer.y - rect.maxY)
            return hypot(dx, dy)
        }
        let screen = screens.first { $0.frame.contains(pointer) }
            ?? screens.min { distance(to: $0.frame) < distance(to: $1.frame) }
        let visible = screen?.visibleFrame ?? fallback
        let x = min(max(pointer.x - size.width / 2, visible.minX), max(visible.minX, visible.maxX - size.width))
        let y = min(max(pointer.y - size.height / 2, visible.minY), max(visible.minY, visible.maxY - size.height))
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
