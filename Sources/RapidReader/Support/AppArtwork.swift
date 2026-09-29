import AppKit
import SwiftUI

enum AppArtwork {
    static var iconImage: NSImage? {
        guard let url = Bundle.main.url(forResource: "AppIconArtwork", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
}

extension Color {
    static let readerAmber = Color(red: 0.95, green: 0.62, blue: 0.22)
    static let readerInk = Color(red: 0.10, green: 0.12, blue: 0.14)
    static let readerMist = Color(red: 0.88, green: 0.90, blue: 0.91)

    /// Amber for text and thin marks: the brand amber on dark backgrounds, a deeper step on light
    /// ones, where the brand amber is below 3:1 contrast.
    static let readerAmberText = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.95, green: 0.62, blue: 0.22, alpha: 1)
            : NSColor(srgbRed: 0.76, green: 0.44, blue: 0.06, alpha: 1)
    })
}

extension Date {
    var readerRelativeString: String {
        if abs(timeIntervalSinceNow) < 60 { return String(localized: "Now") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

extension Double {
    var percentString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "0%"
    }
}

extension TimeInterval {
    var readerDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: max(0, self)) ?? "0s"
    }
}
