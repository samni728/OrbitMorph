import Foundation

public enum AppAppearance: String, Codable, CaseIterable, Sendable {
    case glass, solid
}

public struct FormatDefaults: Codable, Equatable, Sendable {
    public var quality: Double?
    public var audioBitrateKbps: Int?
    public var videoPreset: String?
    public var preserveMetadata: Bool
    public var archiveLevel: Int?

    public init(
        quality: Double? = nil,
        audioBitrateKbps: Int? = nil,
        videoPreset: String? = nil,
        preserveMetadata: Bool = true,
        archiveLevel: Int? = nil
    ) {
        self.quality = quality
        self.audioBitrateKbps = audioBitrateKbps
        self.videoPreset = videoPreset
        self.preserveMetadata = preserveMetadata
        self.archiveLevel = archiveLevel
    }
}

public struct DisabledRoute: Codable, Hashable, Sendable {
    public let source: FormatID
    public let target: FormatID
    public init(source: FormatID, target: FormatID) { self.source = source; self.target = target }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var appearance: AppAppearance
    public var launchAtLogin: Bool
    public var soundAndHaptics: Bool
    public var conversionModifier: String
    public var toolsModifier: String
    public var formatDefaults: [FormatID: FormatDefaults]
    public var disabledRoutes: Set<DisabledRoute>
    public var saveBesideSource: Bool
    public var outputFolders: [FolderRecord] = []

    public func defaults(for format: FormatID) -> FormatDefaults {
        var value = formatDefaults[format] ?? .init()
        if value.quality == nil {
            switch format {
            case .jpg: value.quality = 0.92
            case .webp: value.quality = 0.88
            case .heic, .avif: value.quality = 0.85
            default: break
            }
        }
        return value
    }

    public static let `default` = AppSettings(
        appearance: .glass,
        launchAtLogin: false,
        soundAndHaptics: true,
        conversionModifier: "shift",
        toolsModifier: "option+shift",
        formatDefaults: [:],
        disabledRoutes: [],
        saveBesideSource: true
    )
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case appearance, launchAtLogin, soundAndHaptics, conversionModifier, toolsModifier
        case formatDefaults, disabledRoutes, saveBesideSource, outputFolders
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self = .default
        appearance = try c.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? appearance
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
        soundAndHaptics = try c.decodeIfPresent(Bool.self, forKey: .soundAndHaptics) ?? soundAndHaptics
        conversionModifier = try c.decodeIfPresent(String.self, forKey: .conversionModifier) ?? conversionModifier
        toolsModifier = try c.decodeIfPresent(String.self, forKey: .toolsModifier) ?? toolsModifier
        formatDefaults = try c.decodeIfPresent([FormatID: FormatDefaults].self, forKey: .formatDefaults) ?? formatDefaults
        disabledRoutes = try c.decodeIfPresent(Set<DisabledRoute>.self, forKey: .disabledRoutes) ?? disabledRoutes
        saveBesideSource = try c.decodeIfPresent(Bool.self, forKey: .saveBesideSource) ?? saveBesideSource
        outputFolders = try c.decodeIfPresent([FolderRecord].self, forKey: .outputFolders) ?? []
    }
}

public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "OrbitMorph.AppSettings.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func save(_ settings: AppSettings) throws {
        defaults.set(try JSONEncoder().encode(settings), forKey: key)
    }

    public func load() throws -> AppSettings {
        guard let data = defaults.data(forKey: key) else { return .default }
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }
}
