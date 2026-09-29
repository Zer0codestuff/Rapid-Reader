import AppKit
import SwiftUI

/// Reader shortcuts apply only in this window, outside text fields and sheets.
struct ReaderKeyboardHandler: NSViewRepresentable {
    let onPlayPause: () -> Void
    let onBack: () -> Void
    let onForward: () -> Void

    final class Coordinator {
        var monitor: Any?
        var handler: ReaderKeyboardHandler
        init(_ handler: ReaderKeyboardHandler) { self.handler = handler }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let coordinator = context.coordinator
        coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak view, weak coordinator] event in
            guard let window = view?.window, event.window === window,
                  window.isKeyWindow, window.attachedSheet == nil,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  let coordinator else { return event }
            if let responder = window.firstResponder,
               responder is NSTextView || responder is NSControl { return event }
            switch event.keyCode {
            case 49: coordinator.handler.onPlayPause()
            case 123: coordinator.handler.onBack()
            case 124: coordinator.handler.onForward()
            default: return event
            }
            return nil
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.handler = self
    }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor { NSEvent.removeMonitor(monitor) }
        coordinator.monitor = nil
    }
}
