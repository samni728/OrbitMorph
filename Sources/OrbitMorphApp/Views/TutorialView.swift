import SwiftUI
import OrbitMorphCore

struct TutorialView: View {
    @ObservedObject var manager: OnboardingManager
    @ObservedObject var state: AppState
    let onDismiss: () -> Void
    let onOpenFolders: () -> Void

    private let accent = Color(red: 1.0, green: 0.31, blue: 0.12)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 9) {
                    Image(systemName: "circle.hexagongrid.fill").font(.system(size: 16, weight: .semibold)).frame(width: 18, height: 18).foregroundStyle(accent)
                    Text(state.L("OrbitMorph")).font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                Spacer()
                Text(state.L("Step %d of %d", manager.currentStep.rawValue + 1, TutorialStep.allCases.count))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.bottom, 14)

            Group {
                switch manager.currentStep {
                case .conversion: conversionStep
                case .tools: toolsStep
                case .output: outputStep
                case .ready: readyStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(state.L("First-use demonstration only. Everyday conversion happens beside your Finder files.")).font(.caption2).foregroundStyle(.secondary).padding(.bottom, 10)
            Divider().opacity(0.35)
            HStack(spacing: 12) {
                if manager.currentStep != .conversion {
                    Button(state.L("Back")) { manager.back() }.buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Spacer()
                Button(state.L("Skip")) {
                    manager.skip()
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if manager.currentStep == .ready {
                    Button(state.L("Let's get started")) {
                        manager.finish()
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                } else {
                    Button(state.L("Next")) { manager.next() }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .disabled(!manager.canAdvance)
                }
            }
            .padding(.top, 12)
        }
        .environment(\.locale, state.locale)
        .padding(24)
        .frame(width: 680, height: 520)
    }

    private var conversionStep: some View {
        demoStep(title: state.L("Hold. Drag. Drop."), modifier: state.settings.conversionModifier, chooseSample: true)
    }
    private var toolsStep: some View {
        demoStep(title: state.L("There's a tool for that."), modifier: state.settings.toolsModifier, chooseSample: false)
    }
    private func demoStep(title: String, modifier: String, chooseSample: Bool) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.system(size: 24, weight: .bold, design: .rounded))
            Text(state.L("Try %@ here, then use the same gesture on files in Finder.", shortcut(modifier)))
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack {
                if chooseSample {
                    Picker("", selection: $manager.demoSample) {
                        Text("PNG").tag(FormatID.png)
                        Text("MP4").tag(FormatID.mp4)
                    }.pickerStyle(.segmented).frame(width: 130).labelsHidden()
                }
                Button(state.L("Watch demo")) { manager.requestPreview() }.buttonStyle(.bordered)
            }
            TutorialDemoRepresentable(manager: manager).frame(width: 580, height: 240)
            Text(manager.demoResult.map { state.L("Preview: %@", $0) } ?? state.L("Demo only — no files are converted here."))
                .font(.caption).foregroundStyle(manager.demoResult == nil ? Color.secondary : Color.green)
        }
    }

    private var outputStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 58, weight: .light)).foregroundStyle(accent)
            Text(state.L("Save beside your files."))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(state.L("OrbitMorph keeps the original and saves converted files beside it by default. You can choose separate output folders at any time."))
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 480)
            Button(state.L("Open Folder Settings")) { onOpenFolders() }
                .buttonStyle(.bordered)
            Label(state.L("Files stay on this Mac"), systemImage: "lock.shield")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var readyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 58, weight: .light)).foregroundStyle(accent)
            Text(state.L("Ready when you are."))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(state.L("OrbitMorph stays in the menu bar. Hold your shortcut while dragging a file in Finder to summon the wheel beside it."))
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 480)
            VStack(alignment: .leading, spacing: 10) {
                Label(state.L("Convert files · %@", shortcut(state.settings.conversionModifier)), systemImage: "arrow.triangle.2.circlepath")
                Label(state.L("File tools · %@", shortcut(state.settings.toolsModifier)), systemImage: "wand.and.stars")
            }
            .font(.system(size: 13, weight: .medium))
            .padding(16)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func shortcut(_ raw: String) -> String {
        raw.split(separator: "+").map { part in
            switch part {
            case "shift": return "⇧ Shift"
            case "option": return "⌥ Option"
            case "control": return "⌃ Control"
            case "command": return "⌘ Command"
            default: return String(part).capitalized
            }
        }.joined(separator: " + ")
    }
}
