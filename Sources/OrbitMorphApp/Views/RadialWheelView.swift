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
        var p = Path()
        p.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }
}

@MainActor
final class WheelViewModel: ObservableObject {
    @Published var selectedIndex: Int?
    @Published var items: [WheelDisplayItem]
    let mode: DragMode
    var onSelect: ((WheelDisplayItem) -> Void)?
    var onCancel: (() -> Void)?

    init(items: [WheelDisplayItem], mode: DragMode) {
        self.items = Array(items.prefix(8)); self.mode = mode
    }

    var selected: WheelDisplayItem? {
        guard let selectedIndex, items.indices.contains(selectedIndex) else { return nil }
        return items[selectedIndex]
    }
}

struct RadialWheelView: View {
    @ObservedObject var model: WheelViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    private let accent = Color(red: 1.0, green: 0.31, blue: 0.12)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Circle().fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(.white.opacity(0.36), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 20, y: 10)
                ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                    let step = 360.0 / Double(max(model.items.count, 1))
                    let start = -90.0 - step / 2 + Double(index) * step
                    let end = start + step
                    RingSegmentShape(startAngle: .degrees(start), endAngle: .degrees(end), innerRatio: 0.42)
                        .fill(model.selectedIndex == index ? accent.opacity(0.94) : Color.primary.opacity(0.045))
                        .overlay(RingSegmentShape(startAngle: .degrees(start), endAngle: .degrees(end), innerRatio: 0.42).stroke(Color.primary.opacity(0.18), lineWidth: 1))
                        .scaleEffect(model.selectedIndex == index ? 1.035 : 1)
                        .contentShape(RingSegmentShape(startAngle: .degrees(start), endAngle: .degrees(end), innerRatio: 0.42))
                        .onHover { inside in
                            withAnimation(.spring(response: 0.20, dampingFraction: 0.78)) {
                                model.selectedIndex = inside ? index : (model.selectedIndex == index ? nil : model.selectedIndex)
                            }
                        }
                        .onTapGesture { model.onSelect?(item) }
                    let a = (Double(index) * step - 90) * Double.pi / 180
                    let r = size * 0.355
                    VStack(spacing: 2) {
                        if case .tool = item.value { Image(systemName: item.symbol).font(.system(size: 11, weight: .semibold)) }
                        Text(item.label).font(.system(size: item.label.count > 5 ? 8 : 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(model.selectedIndex == index ? .white : .primary.opacity(0.82))
                    .position(x: center.x + CGFloat(cos(a)) * r, y: center.y + CGFloat(sin(a)) * r)
                    .allowsHitTesting(false)
                }
                Circle().fill(.thinMaterial).frame(width: size * 0.34, height: size * 0.34)
                    .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                VStack(spacing: 5) {
                    Image(systemName: model.selected?.symbol ?? (model.mode == .conversion ? "arrow.triangle.2.circlepath" : "wand.and.stars"))
                        .font(.system(size: 20, weight: .medium)).foregroundStyle(accent)
                    Text(model.selected?.label ?? (model.mode == .conversion ? "CONVERT" : "TOOLS"))
                        .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.primary.opacity(0.85))
                }
            }
            .frame(width: size, height: size).position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .padding(16)
        .scaleEffect(appeared ? 1 : (reduceMotion ? 0.96 : 0.90))
        .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -10))
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(reduceMotion ? .easeOut(duration: 0.10) : .spring(response: 0.20, dampingFraction: 0.72)) { appeared = true } }
    }
}
