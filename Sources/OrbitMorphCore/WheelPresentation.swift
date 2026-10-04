import Foundation

public struct WheelPresentationState: Equatable, Sendable {
    public let visibleOptions: [FormatID]
    public private(set) var selectedIndex: Int?
    public private(set) var isCancelled: Bool

    public init(options: [FormatID]) {
        self.visibleOptions = Array(options.prefix(8))
        self.selectedIndex = nil
        self.isCancelled = false
    }

    public var selectedOption: FormatID? {
        guard let selectedIndex, visibleOptions.indices.contains(selectedIndex) else { return nil }
        return visibleOptions[selectedIndex]
    }

    public mutating func select(index: Int?) {
        if let index, visibleOptions.indices.contains(index) {
            selectedIndex = index
            isCancelled = false
        } else {
            selectedIndex = nil
        }
    }

    public mutating func cancel() {
        selectedIndex = nil
        isCancelled = true
    }
}

public struct WheelAnimationSpec: Equatable, Sendable {
    public let duration: Double
    public let initialScale: Double
    public let rotationDegrees: Double

    public static let `default` = WheelAnimationSpec(duration: 0.20, initialScale: 0.90, rotationDegrees: -10)
    public static let reduceMotion = WheelAnimationSpec(duration: 0.10, initialScale: 0.96, rotationDegrees: 0)
}
