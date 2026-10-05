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
            .padding(.bottom, 28)

            Group {
                switch manager.currentStep {
                case .conversion: conversionStep
                case .tools: toolsStep
                case .output: outputStep
                case .ready: readyStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(state.L("You can reopen this tutorial from Show Tutorial in the menu bar.")).font(.caption2).foregroundStyle(.secondary).padding(.bottom, 10)
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
            .padding(.top, 18)
        }
        .environment(\.locale, state.locale)
        .padding(30)
        .frame(width: 680, height: 520)
    }

    private var conversionStep: some View {
        VStack(spacing: 16) {
            Text(state.L("Hold. Drag. Drop."))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(state.L("Hold %@ while dragging the sample. Move across the wheel, then drop it on any format.", shortcut(state.settings.conversionModifier)))
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 470)
            sampleCard(url: manager.imageSampleURL, isComplete: manager.completedGestureSteps.contains(.conversion), label: state.L("Drag this PNG"))
            Text(state.L("Tutorial samples use a writable temporary copy. Your own files keep their normal output-folder rules.")).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 470)
        }
    }

    private var toolsStep: some View {
        VStack(spacing: 16) {
            Text(state.L("There's a tool for that."))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(state.L("Hold %@ while dragging the video sample to open the tools wheel.", shortcut(state.settings.toolsModifier)))
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 470)
            sampleCard(url: manager.videoSampleURL, isComplete: manager.completedGestureSteps.contains(.tools), label: state.L("Drag this video"))
            Text(state.L("Tutorial samples use a writable temporary copy. Your own files keep their normal output-folder rules.")).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 470)
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
            Text(state.L("OrbitMorph now lives in your menu bar. It stays out of the way until you drag a file or open a command yourself."))
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

    private func sampleCard(url: URL, isComplete: Bool, label: String) -> some View {
        GlassCard(appearance: state.settings.appearance) {
          VStack(spacing: 10) {
            SampleDragSourceRepresentable(url: url, accessibilityLabel: state.L("Drag sample file"))
                .frame(width: 142, height: 108)
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
            Text(url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
            Label(isComplete ? state.L("Done — nice.") : label,
                  systemImage: isComplete ? "checkmark.circle.fill" : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isComplete ? Color.green : accent)
          }
        }.frame(width: 270)
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
