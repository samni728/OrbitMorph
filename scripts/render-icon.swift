import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
let cg = context.cgContext
cg.clear(CGRect(x: 0, y: 0, width: size, height: size))

let bounds = CGRect(x: 28, y: 28, width: 968, height: 968)
let background = CGPath(roundedRect: bounds, cornerWidth: 224, cornerHeight: 224, transform: nil)
cg.addPath(background)
cg.saveGState()
cg.clip()
let colors = [CGColor(red: 0.15, green: 0.22, blue: 0.29, alpha: 1),
              CGColor(red: 0.055, green: 0.085, blue: 0.13, alpha: 1)] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
cg.drawLinearGradient(gradient, start: CGPoint(x: 170, y: 970), end: CGPoint(x: 880, y: 35), options: [])
cg.restoreGState()

// Six softly separated orbit arcs surround the folded document. One active segment carries the brand's coral-orange accent.
cg.setLineWidth(38)
cg.setLineCap(.round)
let orbitColors: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (0.86, 0.91, 0.95, 0.54), (0.86, 0.91, 0.95, 0.39),
    (0.86, 0.91, 0.95, 0.47), (0.86, 0.91, 0.95, 0.33),
    (0.86, 0.91, 0.95, 0.47), (0.86, 0.91, 0.95, 0.39),
    (1.00, 0.48, 0.28, 0.98)
]
let center = CGPoint(x: 512, y: 512)
for (index, color) in orbitColors.enumerated() {
    let start = CGFloat(-90 + index * 45 + 5) * .pi / 180
    let end = start + CGFloat(34) * .pi / 180
    cg.setStrokeColor(CGColor(red: color.0, green: color.1, blue: color.2, alpha: color.3))
    cg.beginPath()
    cg.addArc(center: center, radius: 397, startAngle: start, endAngle: end, clockwise: false)
    cg.strokePath()
}

// Folded document glyph.
let page = CGMutablePath()
page.move(to: CGPoint(x: 354, y: 278))
page.addLine(to: CGPoint(x: 600, y: 278))
page.addLine(to: CGPoint(x: 704, y: 382))
page.addLine(to: CGPoint(x: 704, y: 742))
page.addQuadCurve(to: CGPoint(x: 680, y: 766), control: CGPoint(x: 704, y: 766))
page.addLine(to: CGPoint(x: 344, y: 766))
page.addQuadCurve(to: CGPoint(x: 320, y: 742), control: CGPoint(x: 320, y: 766))
page.addLine(to: CGPoint(x: 320, y: 302))
page.addQuadCurve(to: CGPoint(x: 344, y: 278), control: CGPoint(x: 320, y: 278))
page.closeSubpath()
cg.setFillColor(CGColor(red: 0.94, green: 0.97, blue: 0.99, alpha: 0.97))
cg.addPath(page)
cg.fillPath()
let fold = CGMutablePath()
fold.move(to: CGPoint(x: 600, y: 278))
fold.addLine(to: CGPoint(x: 600, y: 358))
fold.addQuadCurve(to: CGPoint(x: 624, y: 382), control: CGPoint(x: 600, y: 382))
fold.addLine(to: CGPoint(x: 704, y: 382))
fold.closeSubpath()
cg.setFillColor(CGColor(red: 0.68, green: 0.77, blue: 0.84, alpha: 0.92))
cg.addPath(fold)
cg.fillPath()
cg.setStrokeColor(CGColor(red: 0.36, green: 0.45, blue: 0.53, alpha: 0.7))
cg.setLineWidth(19)
cg.setLineCap(.round)
for y: CGFloat in [480, 554, 628] {
    cg.beginPath()
    cg.move(to: CGPoint(x: 397, y: y))
    cg.addLine(to: CGPoint(x: y == 628 ? 542 : 618, y: y))
    cg.strokePath()
}

NSGraphicsContext.restoreGraphicsState()
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: output.appendingPathComponent("icon_1024x1024.png"), options: .atomic)
