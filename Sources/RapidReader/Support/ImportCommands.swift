import SwiftUI

struct ImportActions {
    var files: () -> Void
    var article: () -> Void
    var clipboard: () -> Void
}

private struct ImportActionsKey: FocusedValueKey { typealias Value = ImportActions }

extension FocusedValues {
    var importActions: ImportActions? {
        get { self[ImportActionsKey.self] }
        set { self[ImportActionsKey.self] = newValue }
    }
}

struct ImportCommands: Commands {
    @FocusedValue(\.importActions) private var actions
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Import Files…") { actions?.files() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(actions == nil)
            Button("Import Article…") { actions?.article() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Button("Import Clipboard") { actions?.clipboard() }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }
    }
}
