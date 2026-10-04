import Foundation

public struct WheelPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public enum WheelGeometry {
    public static func segmentIndex(
        point: WheelPoint,
        center: WheelPoint,
        innerRadius: Double,
        outerRadius: Double,
        count: Int
    ) -> Int? {
        guard count > 0 else { return nil }
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = hypot(dx, dy)
        guard radius >= innerRadius, radius <= outerRadius else { return nil }

        // 0° is top and indices advance clockwise.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let step = 2 * Double.pi / Double(count)
        let shifted = angle + step / 2
        return Int(floor(shifted / step)) % count
    }
}

public enum DragMode: String, Codable, Sendable {
    case conversion, tools
}

public enum ModifierMatcher {
    public static let choices = ["shift", "option", "control", "command", "option+shift", "control+shift", "command+shift"]

    public static func mode(shift: Bool, option: Bool, control: Bool, command: Bool, settings: AppSettings) -> DragMode? {
        let active = Set([(shift, "shift"), (option, "option"), (control, "control"), (command, "command")].filter(\.0).map(\.1))
        func matches(_ value: String) -> Bool {
            let required = Set(value.split(separator: "+").map(String.init))
            return !required.isEmpty && active == required
        }
        if matches(settings.toolsModifier) { return .tools }
        if matches(settings.conversionModifier) { return .conversion }
        return nil
    }

    public static func mode(shift: Bool, option: Bool) -> DragMode? {
        guard shift else { return nil }
        return option ? .tools : .conversion
    }
}
