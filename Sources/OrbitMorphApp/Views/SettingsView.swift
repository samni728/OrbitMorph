import SwiftUI
import AppKit
import OrbitMorphCore

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var selectedFormat: FormatID = .jpg
    @State private var category: FileKind = .image
    private let accent = Color(red: 1, green: 0.31, blue: 0.12)

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "circle.hexagongrid.fill").font(.title).foregroundStyle(accent)
                    VStack(alignment: .leading) {
                        Text(state.L("OrbitMorph")).font(.headline)
                        Text(state.L("Drop. Spin. Convert.")).font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(.bottom, 22)
                ForEach(SettingsSection.allCases) { section in
                    Button { state.section = section } label: {
                        Label(state.L(section.rawValue), systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(state.section == section ? accent.opacity(0.16) : .clear,
                                        in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Label(state.L("Local & private"), systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
            }.padding(18).frame(width: 185).background(.ultraThinMaterial)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                Text(state.L(state.section.rawValue)).font(.system(size: 25, weight: .semibold, design: .rounded))
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch state.section {
                        case .general: general
                        case .formats: formats
                        case .compatibility: compatibility
                        case .folders: folders
                        case .about: about
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(2)
                }
                Divider()
                HStack {
                    if state.isBusy { ProgressView().controlSize(.small) }
                    Text(state.displayMessage).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.015))
        }.environment(\.locale, state.locale).tint(accent).frame(minWidth: 760, minHeight: 480)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard(state.L("Language"), appearance: state.settings.appearance) {
                Picker(state.L("Language"), selection: $state.settings.language) {
                    Text(state.L("System Default")).tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.en)
                    Text("简体中文").tag(AppLanguage.zhHans)
                }.pickerStyle(.segmented)
            }
            GlassCard(state.L("Appearance"), appearance: state.settings.appearance) {
                Picker(state.L("Wheel style"), selection: $state.settings.appearance) {
                    Text(state.L("Glass")).tag(AppAppearance.glass)
                    Text(state.L("Solid")).tag(AppAppearance.solid)
                }.pickerStyle(.segmented).padding(8)
            }
            GlassCard(state.L("Behavior"), appearance: state.settings.appearance) {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(state.L("Launch at login"), isOn: Binding(get: { state.settings.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                    Toggle(state.L("Sound & haptic feedback"), isOn: $state.settings.soundAndHaptics)
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            GlassCard(state.L("Drag shortcuts"), appearance: state.settings.appearance) {
                VStack(alignment: .leading, spacing: 12) {
                    modifierPicker(state.L("Convert files"), selection: $state.settings.conversionModifier, other: state.settings.toolsModifier)
                    modifierPicker(state.L("File tools"), selection: $state.settings.toolsModifier, other: state.settings.conversionModifier)
                    Text(state.L("Hold the shortcut while dragging a file. Sweep over a format and release to convert. Escape or releasing outside the wheel cancels."))
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            Text(state.L("Reduced motion follows macOS Accessibility settings.")).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func modifierPicker(_ title: String, selection: Binding<String>, other: String) -> some View {
        Picker(title, selection: selection) {
            ForEach(ModifierMatcher.choices.filter { $0 != other }, id: \.self) { key in
                Text(key.replacingOccurrences(of: "+", with: " + ").capitalized).tag(key)
            }
        }
    }

    private var defaults: FormatDefaults { state.settings.defaults(for: selectedFormat) }
    private func defaultBinding<T>(_ key: WritableKeyPath<FormatDefaults, T>, fallback: T) -> Binding<T> {
        Binding(get: { defaults[keyPath: key] }, set: { value in
            var values = defaults; values[keyPath: key] = value
            state.settings.formatDefaults[selectedFormat] = values
        })
    }
    private var formats: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(state.L("Output format"), selection: $selectedFormat) {
                ForEach(state.outputFormats, id: \.self) { format in Text(format.fileExtension.uppercased()).tag(format) }
            }
            GlassCard(state.L("Default conversion options"), appearance: state.settings.appearance) {
                VStack(alignment: .leading, spacing: 14) {
                    if [.jpg, .webp, .heic, .avif].contains(selectedFormat) || selectedFormat.kind == .video {
                        let quality = Binding<Double>(get: { defaults.quality ?? 0.85 }, set: { v in
                            var d = defaults; d.quality = v; state.settings.formatDefaults[selectedFormat] = d
                        })
                        HStack { Text(state.L("Quality")); Spacer(); Text(state.L("\(Int(quality.wrappedValue * 100))%")) }
                        Slider(value: quality, in: 0.1...1, step: 0.01)
                    }
                    if (selectedFormat.kind == .audio && ![.wav, .flac, .aiff, .caf].contains(selectedFormat)) || selectedFormat.kind == .video {
                        Picker(state.L("Audio bitrate"), selection: Binding<Int>(get: { defaults.audioBitrateKbps ?? 192 }, set: { v in
                            var d = defaults; d.audioBitrateKbps = v; state.settings.formatDefaults[selectedFormat] = d
                        })) { ForEach([96, 128, 160, 192, 256, 320], id: \.self) { Text(state.L("\($0) kbps")).tag($0) } }
                    }
                    if [.mp4, .m4v, .mov, .mkv, .ts, .threeGP].contains(selectedFormat) {
                        Picker(state.L("Video encoder preset"), selection: Binding<String>(get: { defaults.videoPreset ?? "veryfast" }, set: { v in
                            var d = defaults; d.videoPreset = v; state.settings.formatDefaults[selectedFormat] = d
                        })) {
                            Text(state.L("Fast")).tag("veryfast"); Text(state.L("Balanced")).tag("medium"); Text(state.L("Smaller file")).tag("slow")
                        }
                    }
                    if [.zip, .sevenZ].contains(selectedFormat), state.dependencies.has("7zz") {
                        Picker(state.L("Compression level"), selection: Binding<Int>(get: { defaults.archiveLevel ?? 5 }, set: { v in
                            var d = defaults; d.archiveLevel = v; state.settings.formatDefaults[selectedFormat] = d
                        })) { ForEach([0, 1, 5, 9], id: \.self) { Text(state.L("Level %d", $0)).tag($0) } }
                    }
                    if selectedFormat.kind == .image || selectedFormat.kind == .audio || selectedFormat.kind == .video {
                        Toggle(state.L("Preserve metadata"), isOn: defaultBinding(\.preserveMetadata, fallback: true))
                    }
                    if selectedFormat.kind == .document {
                        Text(state.L("Document and PDF conversions use the source content and layout supported by the selected backend."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if selectedFormat.kind == .subtitle {
                        Text(state.L("Subtitle conversion preserves cue text and timing. Styling and placement supported by only one format cannot be preserved."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if selectedFormat.kind == .spreadsheet || selectedFormat.kind == .presentation {
                        Text(state.L("Office conversion uses LibreOffice. Complex formulas, charts, fonts, macros and slide animations may change."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if selectedFormat.kind == .ebook {
                        Text(state.L("Calibre reflows DRM-free books. Layout, styles and metadata follow the destination format."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(state.L("Reset this format")) { state.settings.formatDefaults.removeValue(forKey: selectedFormat) }
        }
    }

    private var compatibility: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(state.L("Input category"), selection: $category) {
                ForEach(FileKind.allCases.filter { $0 != .unknown }, id: \.self) { Text(state.L($0.rawValue)).tag($0) }
            }.pickerStyle(.menu)
            Text(state.L("✓ Enabled   ○ Disabled by you   — Unavailable\nOnly implemented routes with installed converters can be enabled."))
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 3, verticalSpacing: 5) {
                    GridRow {
                        Text(state.L("From / To")).frame(width: 70, alignment: .leading)
                        ForEach(FormatID.allCases, id: \.self) { target in
                            Text(target.fileExtension.uppercased()).font(.system(size: 9, weight: .semibold)).frame(width: 39)
                        }
                    }
                    Divider()
                    ForEach(FormatID.allCases.filter { $0.kind == category }, id: \.self) { source in
                        GridRow {
                            Text(source.fileExtension.uppercased()).font(.caption.weight(.medium)).frame(width: 70, alignment: .leading)
                            ForEach(FormatID.allCases, id: \.self) { target in
                                let supported = state.policy.isSupported(source: source, target: target)
                                let enabled = state.policy.isEnabled(source: source, target: target)
                                Button {
                                    let route = DisabledRoute(source: source, target: target)
                                    if enabled { state.settings.disabledRoutes.insert(route) }
                                    else { state.settings.disabledRoutes.remove(route) }
                                } label: {
                                    Text(supported ? (enabled ? "✓" : "○") : "—").frame(width: 39, height: 28)
                                        .background(enabled ? accent.opacity(0.13) : Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 5))
                                }.buttonStyle(.plain).disabled(!supported)
                                    .help("\(source.rawValue.uppercased()) → \(target.rawValue.uppercased())")
                            }
                        }
                    }
                }
            }
        }
    }

    private var folders: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(state.L("Save beside the source file"), isOn: $state.settings.saveBesideSource)
            Text(state.L("Folders are grouped by input type: extracted audio from a video uses Video. Folder bookmarks remember access. Without a category folder, the default folder or source location is used."))
                .font(.caption).foregroundStyle(.secondary)
            ForEach([FileKind.unknown] + FileKind.allCases.filter { $0 != .unknown }, id: \.self) { kind in
                let record = state.settings.outputFolders.first { $0.category == kind }
                HStack(spacing: 10) {
                    Image(systemName: "folder").foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.L(kind == .unknown ? "Default output folder" : kind.rawValue)).font(.callout.weight(.medium))
                        Text(record?.displayPath ?? state.L("Same as source")).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button(state.L("Choose…")) { state.chooseFolder(for: kind) }
                    if record != nil {
                        Button { state.settings.outputFolders.removeAll { $0.category == kind } } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain)
                    }
                }.padding(10).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.L("OrbitMorph")).font(.title2.bold())
                    Text(state.L("Version %@ · Apple Silicon · macOS 14+", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(state.L("Drop. Spin. Convert.")).foregroundStyle(accent)
                }
            }
            Text(state.L("Files are processed on this Mac. No uploads, accounts or cloud conversion.")).font(.callout)
            GlassCard(state.L("Converter diagnostics"), appearance: state.settings.appearance) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(DependencyDiagnostic.rows(resolver: state.dependencies), id: \.name) { row in
                        HStack {
                            Image(systemName: row.available ? "checkmark.circle.fill" : "minus.circle").foregroundStyle(row.available ? .green : .secondary)
                            Text(row.name).font(.system(.caption, design: .monospaced)).frame(width: 96, alignment: .leading)
                            Text(row.path ?? state.L("Not installed")).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(state.L("External converters use your locally installed tools. Credits and license information are included in the application resources."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
