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
                        Text("OrbitMorph").font(.headline)
                        Text("Drop. Spin. Convert.").font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(.bottom, 22)
                ForEach(SettingsSection.allCases) { section in
                    Button { state.section = section } label: {
                        Label(section.rawValue, systemImage: section.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(state.section == section ? accent.opacity(0.16) : .clear,
                                        in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Label("Local & private", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
            }.padding(18).frame(width: 185).background(.ultraThinMaterial)
            Divider()
            VStack(alignment: .leading, spacing: 18) {
                Text(state.section.rawValue).font(.system(size: 25, weight: .semibold, design: .rounded))
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
                    Text(state.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }.tint(accent).frame(minWidth: 760, minHeight: 480)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Appearance") {
                Picker("Wheel style", selection: $state.settings.appearance) {
                    Text("Glass").tag(AppAppearance.glass)
                    Text("Solid").tag(AppAppearance.solid)
                }.pickerStyle(.segmented).padding(8)
            }
            GroupBox("Behavior") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Launch at login", isOn: Binding(get: { state.settings.launchAtLogin }, set: { state.setLaunchAtLogin($0) }))
                    Toggle("Sound & haptic feedback", isOn: $state.settings.soundAndHaptics)
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox("Drag shortcuts") {
                VStack(alignment: .leading, spacing: 12) {
                    modifierPicker("Convert files", selection: $state.settings.conversionModifier, other: state.settings.toolsModifier)
                    modifierPicker("File tools", selection: $state.settings.toolsModifier, other: state.settings.conversionModifier)
                    Text("Hold the shortcut while dragging a file. Sweep over a format and release to convert. Escape or releasing outside the wheel cancels.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            Text("Reduced motion follows macOS Accessibility settings.").font(.caption).foregroundStyle(.secondary)
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
            Picker("Output format", selection: $selectedFormat) {
                ForEach(state.outputFormats, id: \.self) { format in Text(format.fileExtension.uppercased()).tag(format) }
            }
            GroupBox("Default conversion options") {
                VStack(alignment: .leading, spacing: 14) {
                    if [.jpg, .webp, .heic, .avif].contains(selectedFormat) || selectedFormat.kind == .video {
                        let quality = Binding<Double>(get: { defaults.quality ?? 0.85 }, set: { v in
                            var d = defaults; d.quality = v; state.settings.formatDefaults[selectedFormat] = d
                        })
                        HStack { Text("Quality"); Spacer(); Text("\(Int(quality.wrappedValue * 100))%") }
                        Slider(value: quality, in: 0.1...1, step: 0.01)
                    }
                    if selectedFormat.kind == .audio || selectedFormat.kind == .video {
                        Picker("Audio bitrate", selection: Binding<Int>(get: { defaults.audioBitrateKbps ?? 192 }, set: { v in
                            var d = defaults; d.audioBitrateKbps = v; state.settings.formatDefaults[selectedFormat] = d
                        })) { ForEach([96, 128, 160, 192, 256, 320], id: \.self) { Text("\($0) kbps").tag($0) } }
                    }
                    if [.mp4, .m4v, .mov, .mkv].contains(selectedFormat) {
                        Picker("Video encoder preset", selection: Binding<String>(get: { defaults.videoPreset ?? "veryfast" }, set: { v in
                            var d = defaults; d.videoPreset = v; state.settings.formatDefaults[selectedFormat] = d
                        })) {
                            Text("Fast").tag("veryfast"); Text("Balanced").tag("medium"); Text("Smaller file").tag("slow")
                        }
                    }
                    if [.zip, .sevenZ].contains(selectedFormat), state.dependencies.has("7zz") {
                        Picker("Compression level", selection: Binding<Int>(get: { defaults.archiveLevel ?? 5 }, set: { v in
                            var d = defaults; d.archiveLevel = v; state.settings.formatDefaults[selectedFormat] = d
                        })) { ForEach([0, 1, 5, 9], id: \.self) { Text("Level \($0)").tag($0) } }
                    }
                    if selectedFormat.kind == .image || selectedFormat.kind == .audio || selectedFormat.kind == .video {
                        Toggle("Preserve metadata", isOn: defaultBinding(\.preserveMetadata, fallback: true))
                    }
                    if selectedFormat.kind == .document {
                        Text("Document and PDF conversions use the source content and layout supported by the selected backend.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if selectedFormat.kind == .subtitle {
                        Text("Subtitle conversion preserves cue text and timing. Styling and placement supported by only one format cannot be preserved.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Reset this format") { state.settings.formatDefaults.removeValue(forKey: selectedFormat) }
        }
    }

    private var compatibility: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Input category", selection: $category) {
                ForEach(FileKind.allCases.filter { $0 != .unknown }, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }.pickerStyle(.segmented)
            Text("✓ Enabled   ○ Disabled by you   — Unavailable\nOnly implemented routes with installed converters can be enabled.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 3, verticalSpacing: 5) {
                    GridRow {
                        Text("From / To").frame(width: 70, alignment: .leading)
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
            Toggle("Save beside the source file", isOn: $state.settings.saveBesideSource)
            Text("Folders are grouped by input type: extracted audio from a video uses Video. Folder bookmarks remember access. Without a category folder, the default folder or source location is used.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach([FileKind.unknown] + FileKind.allCases.filter { $0 != .unknown }, id: \.self) { kind in
                let record = state.settings.outputFolders.first { $0.category == kind }
                HStack(spacing: 10) {
                    Image(systemName: "folder").foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(kind == .unknown ? "Default output folder" : kind.rawValue.capitalized).font(.callout.weight(.medium))
                        Text(record?.displayPath ?? "Same as source").font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button("Choose…") { state.chooseFolder(for: kind) }
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
                    Text("OrbitMorph").font(.title2.bold())
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0") · Apple Silicon · macOS 14+")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Drop. Spin. Convert.").foregroundStyle(accent)
                }
            }
            Text("Files are processed on this Mac. No uploads, accounts or cloud conversion.").font(.callout)
            GroupBox("Converter diagnostics") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(DependencyDiagnostic.rows(resolver: state.dependencies), id: \.name) { row in
                        HStack {
                            Image(systemName: row.available ? "checkmark.circle.fill" : "minus.circle").foregroundStyle(row.available ? .green : .secondary)
                            Text(row.name).font(.system(.caption, design: .monospaced)).frame(width: 62, alignment: .leading)
                            Text(row.path ?? "Not installed").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("External converters use your locally installed tools. Credits and license information are included in the application resources.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
