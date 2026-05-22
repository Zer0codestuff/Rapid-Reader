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
}

extension Date {
    var readerRelativeString: String {
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
