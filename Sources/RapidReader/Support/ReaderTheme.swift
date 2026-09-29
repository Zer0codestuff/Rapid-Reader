import AppKit
import SwiftUI

/// Reader appearance, shared by all documents. `system` follows macOS.
enum ReaderTheme: String, CaseIterable, Identifiable {
    case system, light, dark, sepia

    static let storageKey = "readerTheme"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .sepia: "Sepia"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia: .light
        case .dark: .dark
        }
    }

    var appearance: NSAppearance? {
        colorScheme.map { NSAppearance(named: $0 == .dark ? .darkAqua : .aqua)! }
    }

    var background: Color {
        switch self {
        case .system: Color(nsColor: .textBackgroundColor)
        case .light: Color(red: 0.99, green: 0.99, blue: 0.98)
        case .dark: Color(red: 0.11, green: 0.11, blue: 0.12)
        case .sepia: Color(red: 0.96, green: 0.92, blue: 0.84)
        }
    }

    /// Body text color; `nil` keeps the standard label color.
    var ink: NSColor? {
        self == .sepia ? NSColor(red: 0.36, green: 0.27, blue: 0.20, alpha: 1) : nil
    }
}
