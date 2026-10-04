import AppKit
import OrbitMorphCore

@MainActor
final class JobCoordinator {
    private let state: AppState
    init(state: AppState) { self.state = state }
    func perform(item: WheelDisplayItem, files: [URL]) {
        guard !state.isBusy else { state.message = "A conversion is already running. Please wait."; return }
        let settings = state.settings, dependencies = state.dependencies
        state.isBusy = true; state.message = "Converting \(files.count) file(s)…"
        Task {
            var scopedFolders: [URL] = []
            defer {
                scopedFolders.forEach { $0.stopAccessingSecurityScopedResource() }
                state.isBusy = false
            }
            do {
                let formats = files.compactMap { FormatID(fileURL: $0) }
                let folders = try formats.map { try state.outputFolder(for: $0.kind) }
                for folder in Set(folders.compactMap { $0 }) {
                    if folder.startAccessingSecurityScopedResource() { scopedFolders.append(folder) }
                }
                let outputDirectories = Dictionary(zip(files, folders).compactMap { input, folder in folder.map { (input, $0) } }, uniquingKeysWith: { first, _ in first })
                let outputs = try await Task.detached(priority: .userInitiated) { () -> [URL] in
                    switch item.value {
                    case .format(let target):
                        let policy = CompatibilityPolicy(registry: .init(dependencies: dependencies), disabledRoutes: settings.disabledRoutes)
                        guard policy.commonTargets(for: files).contains(target) else {
                            throw ConversionEngineError.unsupportedTarget(target)
                        }
                        return try ConversionEngine(dependencies: dependencies).convert(.init(inputs: files, target: target,
                            outputDirectories: outputDirectories, options: settings.defaults(for: target))).map(\.outputURL)
                    case .tool(let action):
                        return try ToolExecutor.perform(action, files: files, dependencies: dependencies, outputDirectories: outputDirectories)
                    }
                }.value
                state.lastOutputs = outputs
                state.message = "Converted \(outputs.count) output(s) · \(outputs.first?.deletingLastPathComponent().path ?? "")"
                if settings.soundAndHaptics {
                    NSSound(named: .init("Glass"))?.play()
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                }
                print("ORBITMORPH job=success outputs=\(outputs.map(\.path))")
            } catch {
                state.message = "Conversion failed: \(error.localizedDescription)"
                if settings.soundAndHaptics { NSSound.beep() }
                let alert = NSAlert()
                alert.messageText = "Could not convert these files"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning; alert.addButton(withTitle: "OK")
                alert.runModal()
                print("ORBITMORPH job=failed error=\(error.localizedDescription)")
            }
        }
    }
}
