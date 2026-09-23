import AppKit

// A vector-drawn companion to the website's calendar/checkmark symbol.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}
func drawIcon(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setShouldAntialias(true)

    // The glass layers are drawn at each output resolution, keeping the small
    // Finder/Dock icons crisp. No downloaded bitmap or machine-local asset.
    let background = rounded(NSRect(x: 64, y: 64, width: 896, height: 896), 202)
    NSGraphicsContext.saveGraphicsState()
    let baseShadow = NSShadow(); baseShadow.shadowColor = color(0.02, 0.30, 0.20, 0.22)
    baseShadow.shadowBlurRadius = 24; baseShadow.shadowOffset = NSSize(width: 0, height: -12); baseShadow.set()
    color(0.12, 0.58, 0.40).setFill(); background.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(0.04, 0.40, 0.28), color(0.12, 0.65, 0.43), color(0.43, 0.82, 0.66)])!.draw(in: background, angle: 65)

    NSGraphicsContext.saveGraphicsState(); background.addClip()
    // Curved translucent colour behind the calendar refracts through its face.
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: -80, y: 215))
    wave.curve(to: NSPoint(x: 1090, y: 700), controlPoint1: NSPoint(x: 700, y: -150), controlPoint2: NSPoint(x: 310, y: 1000))
    wave.line(to: NSPoint(x: 1090, y: -80)); wave.line(to: NSPoint(x: -80, y: -80)); wave.close()
    NSGradient(colors: [color(0.00, 0.36, 0.25), color(0.04, 0.65, 0.37), color(0.30, 0.84, 0.50)])!.draw(in: wave, angle: 80)
    color(0.73, 0.96, 0.78, 0.36).setStroke(); wave.lineWidth = 4; wave.stroke()
    NSGraphicsContext.restoreGraphicsState()
    color(0.87, 1, 0.94, 0.40).setStroke(); background.lineWidth = 3; background.stroke()
    let baseInner = rounded(NSRect(x: 72, y: 72, width: 880, height: 880), 195)
    color(0.79, 1, 0.87, 0.18).setStroke(); baseInner.lineWidth = 3; baseInner.stroke()

    let paper = rounded(NSRect(x: 238, y: 224, width: 548, height: 566), 92)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = color(0.0, 0.25, 0.16, 0.24)
    shadow.shadowBlurRadius = 40; shadow.shadowOffset = NSSize(width: 0, height: -22); shadow.set()
    color(0.72, 0.96, 0.85, 0.20).setFill(); paper.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(0.77, 0.95, 0.86, 0.38), color(0.83, 0.97, 0.89, 0.18), color(0.91, 0.98, 0.94, 0.48)])!.draw(in: paper, angle: 85)

    // Rounded reflective rim and a softer inner edge give the glass thickness.
    color(0.87, 1, 0.95, 0.62).setStroke(); paper.lineWidth = 5; paper.stroke()
    let inner = rounded(NSRect(x: 247, y: 233, width: 530, height: 548), 85)
    color(0.86, 0.98, 0.93, 0.24).setStroke(); inner.lineWidth = 3; inner.stroke()
    NSGraphicsContext.saveGraphicsState(); paper.addClip()
    let shine = NSBezierPath()
    shine.move(to: NSPoint(x: 238, y: 510))
    shine.curve(to: NSPoint(x: 810, y: 790), controlPoint1: NSPoint(x: 420, y: 820), controlPoint2: NSPoint(x: 620, y: 550))
    shine.line(to: NSPoint(x: 810, y: 850)); shine.line(to: NSPoint(x: 210, y: 850)); shine.close()
    NSGradient(colors: [color(1, 1, 1, 0), color(0.87, 1, 0.94, 0.18)])!.draw(in: shine, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    let divider = NSBezierPath(); divider.move(to: NSPoint(x: 281, y: 651)); divider.line(to: NSPoint(x: 743, y: 651))
    divider.lineWidth = 3; divider.lineCapStyle = .round
    color(0.05, 0.42, 0.28, 0.13).setStroke(); divider.stroke()
    var dividerLight = AffineTransform(); dividerLight.translate(x: 0, y: -3); divider.transform(using: dividerLight)
    color(0.90, 1, 0.93, 0.40).setStroke(); divider.stroke()

    for x: CGFloat in [383, 641] {
        let ring = rounded(NSRect(x: x - 20, y: 725, width: 40, height: 103), 20)
        NSGraphicsContext.saveGraphicsState()
        let ringShadow = NSShadow(); ringShadow.shadowColor = color(0.01, 0.33, 0.23, 0.20)
        ringShadow.shadowBlurRadius = 6; ringShadow.shadowOffset = NSSize(width: 0, height: -4); ringShadow.set()
        color(0.67, 0.91, 0.79).setFill(); ring.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [color(0.10, 0.40, 0.28), color(0.56, 0.85, 0.67), color(0.81, 0.95, 0.84)])!.draw(in: ring, angle: 25)
        color(0.83, 0.97, 0.89, 0.55).setStroke(); ring.lineWidth = 2; ring.stroke()
    }

    let check = NSBezierPath(); check.move(to: NSPoint(x: 367, y: 469))
    check.line(to: NSPoint(x: 475, y: 361)); check.line(to: NSPoint(x: 662, y: 556))
    check.lineWidth = 53; check.lineCapStyle = .round; check.lineJoinStyle = .round
    NSGraphicsContext.saveGraphicsState()
    let checkShadow = NSShadow(); checkShadow.shadowColor = color(0.01, 0.32, 0.16, 0.22)
    checkShadow.shadowBlurRadius = 9; checkShadow.shadowOffset = NSSize(width: 0, height: -6); checkShadow.set()
    color(0.01, 0.34, 0.20).setStroke(); check.stroke()
    NSGraphicsContext.restoreGraphicsState()
    check.lineWidth = 43; color(0.02, 0.47, 0.27).setStroke(); check.stroke()
    let highlight = NSBezierPath(); highlight.move(to: NSPoint(x: 367, y: 483))
    highlight.line(to: NSPoint(x: 475, y: 375)); highlight.line(to: NSPoint(x: 656, y: 564))
    highlight.lineWidth = 3; highlight.lineCapStyle = .round; highlight.lineJoinStyle = .round
    color(0.54, 0.90, 0.68, 0.48).setStroke(); highlight.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try drawIcon(pixels: size).write(to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try drawIcon(pixels: size * 2).write(to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}

// Modern ICNS representations carry PNG data; include standard and Retina sizes.
func bigEndian(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
var chunks = Data()
for (type, pixels) in [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128),
                       ("ic08", 256), ("ic09", 512), ("ic10", 1024),
                       ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)] {
    let png = drawIcon(pixels: pixels)
    chunks.append(Data(type.utf8)); chunks.append(bigEndian(png.count + 8)); chunks.append(png)
}
var icon = Data("icns".utf8); icon.append(bigEndian(chunks.count + 8)); icon.append(chunks)
try icon.write(to: output.deletingLastPathComponent().appendingPathComponent("AppIcon.icns"))
