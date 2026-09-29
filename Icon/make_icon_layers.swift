// Renders the layers of Icon/AppIcon.icon. Run from the repository root:
//   swift Icon/make_icon_layers.swift
// Then build the app; script/build_and_run.sh compiles the .icon with actool.
import AppKit
import CoreImage
import CoreText

let size = 1024.0
let amber = NSColor(srgbRed: 0.98, green: 0.64, blue: 0.20, alpha: 1)
let ink = NSColor(srgbRed: 0.96, green: 0.95, blue: 0.93, alpha: 1)
let assets = URL(fileURLWithPath: "Icon/AppIcon.icon/Assets", isDirectory: true)
try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

func roundedFont(_ size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
    return NSFont(descriptor: descriptor, size: size) ?? base
}

func render(_ name: String, draw: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSGraphicsContext.current!.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent(name))
}

// Word layout: the pivot letter sits on the vertical center line, as in the reader.
let font = roundedFont(540, weight: .bold)
let word = "read", pivotIndex = 1
let attributes: [NSAttributedString.Key: Any] = [.font: font]
let full = NSAttributedString(string: word, attributes: attributes)
let line = CTLineCreateWithAttributedString(full)
let pivotStart = CTLineGetOffsetForStringIndex(line, pivotIndex, nil)
let pivotEnd = CTLineGetOffsetForStringIndex(line, pivotIndex + 1, nil)
let originX = size / 2 - (pivotStart + pivotEnd) / 2
let capHeight = font.xHeight
let baselineY = size / 2 - capHeight / 2

func drawLetters(_ context: CGContext, range: Range<Int>, color: NSColor) {
    for index in range {
        let letter = NSAttributedString(string: String(Array(word)[index]), attributes: [.font: font, .foregroundColor: color])
        let x = originX + CTLineGetOffsetForStringIndex(line, index, nil)
        context.textPosition = CGPoint(x: x, y: baselineY)
        CTLineDraw(CTLineCreateWithAttributedString(letter), context)
    }
}

// Neighbor letters, fading toward the tile edges.
render("letters.png") { context in
    drawLetters(context, range: 0..<pivotIndex, color: ink)
    drawLetters(context, range: (pivotIndex + 1)..<word.count, color: ink)
    let colors = [NSColor.black.withAlphaComponent(0).cgColor, NSColor.black.cgColor,
                  NSColor.black.cgColor, NSColor.black.withAlphaComponent(0).cgColor] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.10, 0.34, 0.66, 0.90])!
    context.setBlendMode(.destinationIn)
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: 0), options: [])
}

// Horizontal motion blur: neighbors read as a word passing at speed, not as legible text.
do {
    let url = assets.appendingPathComponent("letters.png")
    let input = CIImage(contentsOf: url)!
    let blur = CIFilter(name: "CIMotionBlur", parameters: [kCIInputImageKey: input, kCIInputRadiusKey: 26, kCIInputAngleKey: 0])!
    let output = blur.outputImage!.cropped(to: input.extent)
    let context = CIContext()
    try! context.writePNGRepresentation(of: output, to: url, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
}

// Amber pivot letter.
render("pivot.png") { context in
    drawLetters(context, range: pivotIndex..<(pivotIndex + 1), color: amber)
}

// Guide marks above and below the pivot.
render("guides.png") { context in
    context.setFillColor(amber.cgColor)
    let width = 30.0, height = 104.0, gap = 44.0
    let top = CGRect(x: size / 2 - width / 2, y: baselineY + capHeight + gap, width: width, height: height)
    let bottom = CGRect(x: size / 2 - width / 2, y: baselineY - gap - height, width: width, height: height)
    for rect in [top, bottom] {
        context.addPath(CGPath(roundedRect: rect, cornerWidth: width / 2, cornerHeight: width / 2, transform: nil))
    }
    context.fillPath()
}
print("Rendered layers into \(assets.path)")
