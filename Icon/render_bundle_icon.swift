// Draws the icon macOS shows for a bundle, so compiled Icon Composer icons can be exported as PNGs.
import AppKit
// usage: icon-render <bundle> <out.png> <pixels> [dark]
let args = CommandLine.arguments
let px = Int(args[3])!
if args.count > 4 { NSApplication.shared.appearance = NSAppearance(named: .darkAqua) }
let icon = NSWorkspace.shared.icon(forFile: args[1])
icon.size = NSSize(width: px, height: px)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let appearance = args.count > 4 ? NSAppearance(named: .darkAqua)! : NSAppearance(named: .aqua)!
appearance.performAsCurrentDrawingAppearance {
    icon.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
