import AppKit
import SwiftUI
import Combine
import ServiceManagement
import OrbitMorphCore

extension Notification.Name {
    static let orbitMorphPresentationChanged = Notification.Name("OrbitMorph.presentationChanged")
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", formats = "Formats", compatibility = "Compatibility", folders = "Folders", about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .formats: return "doc"
        case .compatibility: return "square.grid.3x3"
        case .folders: return "folder"
        case .about: return "info.circle"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            NotificationCenter.default.post(name: .orbitMorphPresentationChanged, object: self)
            guard persistSettings else { return }
            do { try store.save(settings) }
            catch { message = "Could not save settings: \(error.localizedDescription)" }
        }
    }
    @Published var section: SettingsSection = .general
    @Published var message = "Ready · Files stay on this Mac"
    @Published var isBusy = false
    @Published var lastOutputs: [URL] = []
    private let store: SettingsStore
    private var persistSettings = true
    private var localeObserver: AnyCancellable?
    let dependencies: DependencyResolver
    let outputFormats: [FormatID]

    init(store: SettingsStore = .init(), dependencies: DependencyResolver = .init()) {
        self.store = store
        self.dependencies = dependencies
        // Discovery may pump the main run loop. Complete probes before any hosting view
        // is created so compatibility reads cannot re-enter SwiftUI layout.
        let registry = ConversionRegistry(dependencies: dependencies)
        let targets = FormatID.allCases.reduce(into: Set<FormatID>()) { result, source in
            result.formUnion(registry.targets(for: source))
        }
        outputFormats = FormatID.allCases.filter { targets.contains($0) }
        do { settings = try store.load() }
        catch { settings = .default; message = "Settings could not be read. Defaults are active." }
        localeObserver = NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification).receive(on: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.settings.language == .system else { return }
                self.objectWillChange.send()
                NotificationCenter.default.post(name: .orbitMorphPresentationChanged, object: self)
            }
        }
    }

    var policy: CompatibilityPolicy {
        .init(registry: .init(dependencies: dependencies), disabledRoutes: settings.disabledRoutes)
    }

    func L(_ key: String, _ arguments: CVarArg...) -> String {
        LocalizationManager.format(key, language: settings.language, arguments: arguments)
    }
    var locale: Locale { Locale(identifier: LocalizationManager.resolved(settings.language).rawValue) }
    var displayMessage: String { LocalizationManager.status(message, language: settings.language) }

    func applyPresentation(language: AppLanguage? = nil, appearance: AppAppearance? = nil) {
        persistSettings = false
        if let language { settings.language = language }
        if let appearance { settings.appearance = appearance }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            settings.launchAtLogin = enabled
            if SMAppService.mainApp.status == .requiresApproval {
                message = "Allow OrbitMorph in System Settings → Login Items."
            }
        } catch { message = "Login item: \(error.localizedDescription)" }
    }

    func chooseFolder(for category: FileKind) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.canCreateDirectories = true; panel.allowsMultipleSelection = false
        panel.prompt = L("Choose output folder")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let record = try FolderBookmarkStore.makeRecord(category: category, url: url)
            settings.outputFolders.removeAll { $0.category == category }
            settings.outputFolders.append(record)
            settings.saveBesideSource = false
        } catch { message = "Folder access: \(error.localizedDescription)" }
    }

    func outputFolder(for kind: FileKind) throws -> URL? {
        guard !settings.saveBesideSource else { return nil }
        guard let record = settings.outputFolders.first(where: { $0.category == kind })
                ?? settings.outputFolders.first(where: { $0.category == .unknown }) else { return nil }
        return try FolderBookmarkStore.resolve(record)
    }
}
