import AppKit
import SwiftUI
import RapidReaderCore

@main
struct RapidReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Rapid Reader", id: "library") {
            ContentView(library: appDelegate.library)
                .frame(minWidth: 740, minHeight: 560)
                .modifier(WindowOpenerRegistration(delegate: appDelegate))
        }
        .windowStyle(.titleBar)
        .commands {
            SidebarCommands()
            ImportCommands()
        }

        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let library = LibraryStore()
    /// Reopens the library window after it was closed. Set by the window's content.
    var openLibraryWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showLibraryWindow() }
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        showLibraryWindow()
        Task { @MainActor in
            library.setDefaultPreferences(ReadingDefaults.preferences())
            await library.importFiles(urls.filter(\.isFileURL))
        }
    }

    @objc func readInRapidReader(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string) ?? pasteboard.string(forType: .URL), !text.isEmpty else {
            error.pointee = "No readable text or URL was provided."
            return
        }
        library.setDefaultPreferences(ReadingDefaults.preferences())
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), ["https", "http"].contains(url.scheme ?? ""), url.host != nil {
            Task { await library.importArticle(from: url) }
        } else {
            library.importClipboardText(text)
        }
        showLibraryWindow()
    }

    private func showLibraryWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && $0.isVisible }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            openLibraryWindow?()
        }
    }
}

private struct WindowOpenerRegistration: ViewModifier {
    let delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            let openWindow = openWindow
            delegate.openLibraryWindow = { openWindow(id: "library") }
        }
    }
}
