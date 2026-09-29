import AppKit
import SwiftUI
import RapidReaderCore

@main
struct RapidReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Rapid Reader") {
            ContentView(library: appDelegate.library)
                .frame(minWidth: 740, minHeight: 560)
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func application(_ application: NSApplication, open urls: [URL]) {
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
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }

}
