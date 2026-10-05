import SwiftUI
import OrbitMorphCore

struct WheelDisplayItem: Identifiable, Hashable {
    enum Value: Hashable { case format(FormatID), tool(ToolActionID) }
    let value: Value
    var id: String {
        switch value { case .format(let f): return "format-\(f.rawValue)"; case .tool(let t): return "tool-\(t.rawValue)" }
    }
    var label: String {
        switch value { case .format(let f): return f.fileExtension.uppercased(); case .tool(let t): return t.label.uppercased() }
    }
    var symbol: String {
        switch value {
        case .format: return "arrow.triangle.2.circlepath"
        case .tool(let t):
            switch t {
            case .compress: return "archivebox"
            case .resizeImage: return "arrow.up.left.and.arrow.down.right"
            case .rotate: return "rotate.right"
            case .stripMetadata: return "sparkles"
            case .extractAudio: return "waveform"
            case .makeGIF: return "photo.stack"
            case .pdfMerge: return "doc.on.doc"
            case .archive: return "doc.zipper"
            case .unarchive: return "shippingbox.and.arrow.backward"
            }
        }
    }
}

struct RingSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRatio: CGFloat
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let corner = min(10.0, (outer - inner) * 0.16)
        let outerInset = corner / outer
        let innerInset = corner / inner
        let start = startAngle.radians, end = endAngle.radians
        func point(_ radius: CGFloat, _ angle: Double) -> CGPoint {
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        var p = Path()
        p.move(to: point(outer, start + outerInset))
        p.addArc(center: center, radius: outer, startAngle: .radians(start + outerInset), endAngle: .radians(end - outerInset), clockwise: false)
        p.addQuadCurve(to: point(outer - corner, end), control: point(outer, end))
        p.addLine(to: point(inner + corner, end))
        p.addQuadCurve(to: point(inner, end - innerInset), control: point(inner, end))
        p.addArc(center: center, radius: inner, startAngle: .radians(end - innerInset), endAngle: .radians(start + innerInset), clockwise: true)
        p.addQuadCurve(to: point(inner + corner, start), control: point(inner, start))
        p.addLine(to: point(outer - corner, start))
        p.addQuadCurve(to: point(outer, start + outerInset), control: point(outer, start))
        p.closeSubpath()
        return p
    }
}

@MainActor
final class WheelViewModel: ObservableObject {
    @Published var selectedIndex: Int?
    @Published var items: [WheelDisplayItem]
    @Published var page = 0 {
        didSet { if page != oldValue { selectedIndex = nil } }
    }
    let mode: DragMode
    @Published var appearance: AppAppearance
    @Published var language: AppLanguage
    var onSelect: ((WheelDisplayItem) -> Void)?
    var onCancel: (() -> Void)?

    init(items: [WheelDisplayItem], mode: DragMode, appearance: AppAppearance = .glass, language: AppLanguage = .system) {
        self.items = items; self.mode = mode; self.appearance = appearance; self.language = language
    }

    func label(for item: WheelDisplayItem) -> String {
        switch item.value {
        case .format: return item.label
        case .tool(let action): return LocalizationManager.text(action.label, language: language).uppercased()
        }
    }
    func L(_ key: String, _ arguments: CVarArg...) -> String { LocalizationManager.format(key, language: language, arguments: arguments) }

    var pageCount: Int { max(1, (items.count + 7) / 8) }
    var visibleItems: [WheelDisplayItem] { Array(items.dropFirst(page * 8).prefix(8)) }
    func nextPage() { page = (page + 1) % pageCount; selectedIndex = nil }

    var selected: WheelDisplayItem? {
        guard let selectedIndex, visibleItems.indices.contains(selectedIndex) else { return nil }
        return visibleItems[selectedIndex]
    }
}

struct RadialWheelView: View {
    @ObservedObject var model: WheelViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private let accent = Color(red: 1.0, green: 0.31, blue: 0.12)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let glass = GlassPolicy.usesMaterial(appearance: model.appearance, reduceTransparency: reduceTransparency, increaseContrast: contrast == .increased)
            ZStack {
                Circle().fill(glass ? AnyShapeStyle(Color.primary.opacity(0.08)) : AnyShapeStyle(Color(nsColor: .windowBackgroundColor)))
                    .overlay(Circle().stroke(.white.opacity(0.36), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
                ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { index, item in
                    let step = 360.0 / Double(max(model.visibleItems.count, 1))
                    let start = -90.0 - step / 2 + Double(index) * step + 1.5
                    let end = start + step - 3
                    RingSegmentShape(startAngle: .degrees(start), endAngle: .degrees(end), innerRatio: 0.42)
                        .fill(model.selectedIndex == index ? accent.opacity(0.94) : Color(nsColor: .controlBackgroundColor).opacity(glass ? 0.28 : 0.98))
                        .overlay(RingSegmentShape(startAngle: .degrees(start), endAngle: .degrees(end), innerRatio: 0.42).stroke(.white.opacity(0.45), lineWidth: 1))
                        .scaleEffect(model.selectedIndex == index ? 1.025 : 1)
                        .contentShape(RingSegmentShape(startAngle: .degrees(start), endAngle: .degrees(end), innerRatio: 0.42))
                        .onHover { inside in
                            withAnimation(reduceMotion ? .easeOut(duration: 0.10) : .spring(response: 0.20, dampingFraction: 0.78)) {
                                model.selectedIndex = inside ? index : (model.selectedIndex == index ? nil : model.selectedIndex)
                            }
                        }
                        .onTapGesture { model.onSelect?(item) }
                    let a = (Double(index) * step - 90) * Double.pi / 180
                    let r = size * 0.355
                    VStack(spacing: 2) {
                        if case .tool = item.value { Image(systemName: item.symbol).font(.system(size: 11, weight: .semibold)) }
                        Text(model.label(for: item)).font(.system(size: model.label(for: item).count > 5 ? 8 : 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(model.selectedIndex == index ? .white : .primary.opacity(0.82))
                    .position(x: center.x + CGFloat(cos(a)) * r, y: center.y + CGFloat(sin(a)) * r)
                    .allowsHitTesting(false)
                }
                Circle().fill(Color(nsColor: .controlBackgroundColor).opacity(glass ? 0.26 : 1)).frame(width: size * 0.34, height: size * 0.34)
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                if model.pageCount > 1 {
                    VStack(spacing: 0) {
                        ForEach(0..<model.pageCount, id: \.self) { page in
                            Button { model.page = page } label: {
                                Text("\(page + 1)")
                                    .font(.system(size: 14, weight: model.page == page ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(model.page == page ? accent : Color.primary.opacity(0.65))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(model.page == page ? accent.opacity(0.14) : .clear)
                                    .contentShape(Rectangle())
                                    .overlay(alignment: .bottom) {
                                        if page < model.pageCount - 1 { Divider().opacity(0.3).allowsHitTesting(false) }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(model.L("More · %d/%d", page + 1, model.pageCount))
                            .accessibilityAddTraits(model.page == page ? .isSelected : [])
                        }
                    }
                    .frame(width: size * 0.34, height: size * 0.34)
                    .clipShape(Circle())
                    .contentShape(Circle())
                } else {
                    VStack(spacing: 5) {
                        if model.mode == .tools {
                            Image(systemName: model.selected?.symbol ?? "wand.and.stars").font(.system(size: 16, weight: .medium)).foregroundStyle(accent)
                        }
                        Text(model.selected.map { model.label(for: $0) } ?? model.L(model.items.isEmpty ? "NO FORMATS" : (model.mode == .conversion ? "CONVERT" : "TOOLS")))
                            .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.85))
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.70), in: Capsule())
                    }
                    .allowsHitTesting(false)
                }

            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: model.page)
            .frame(width: size, height: size).position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .padding(16)
    }
}
