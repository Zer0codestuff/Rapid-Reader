import AppKit
import SwiftUI

@main
struct RapidReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Rapid Reader") {
            ContentView()
                .frame(minWidth: 1060, minHeight: 720)
        }
        .windowStyle(.titleBar)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
