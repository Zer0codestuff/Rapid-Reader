import RapidReaderCore
import SwiftUI

struct NotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let notes: [ReaderNote]
    let sectionTitle: (Int) -> String
    @Binding var noteText: String
    let onAdd: () -> Void
    let onUpdate: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onJump: (ReaderNote) -> Void

    @FocusState private var composerFocused: Bool

    private var canAdd: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Notes")
                        .font(.title2.weight(.semibold))
                    Text("Each note keeps the word you were reading.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            VStack(alignment: .trailing, spacing: 10) {
                TextField("Write a note…", text: $noteText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...6)
                    .focused($composerFocused)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(composerFocused ? Color.readerAmber.opacity(0.7) : Color.primary.opacity(0.08))
                    )
                    .accessibilityLabel("New note")

                Button {
                    onAdd()
                } label: {
                    Label("Add Note", systemImage: "plus")
                }
                .readerGlassButton(prominent: true)
                .tint(.readerAmber)
                .disabled(!canAdd)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Add note (Command-Return)")
            }

            if notes.isEmpty {
                ContentUnavailableView(
                    "No notes yet",
                    systemImage: "note.text",
                    description: Text("Pause anywhere, write a thought, and jump back to that word later.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(notes) { note in
                            NoteCard(
                                note: note,
                                location: sectionTitle(note.sectionIndex),
                                onUpdate: onUpdate,
                                onDelete: onDelete,
                                onJump: onJump
                            )
                        }
                    }
                }
                .scrollIndicators(.automatic)
            }
        }
        .padding(24)
        .frame(width: 520, height: 540)
        .onAppear { composerFocused = true }
    }
}

private struct NoteCard: View {
    let note: ReaderNote
    let location: String
    let onUpdate: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onJump: (ReaderNote) -> Void

    @State private var editing = false
    @State private var draft = ""
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if editing {
                TextField("Note", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...8)
                HStack {
                    Spacer()
                    Button("Cancel") { editing = false }
                    Button("Save") {
                        onUpdate(note.id, draft)
                        editing = false
                    }
                    .readerGlassButton(prominent: true)
                    .tint(.readerAmber)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .controlSize(.small)
            } else {
                Text(note.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    Button {
                        onJump(note)
                    } label: {
                        Label("\(location), word \(note.wordIndex + 1)", systemImage: "arrow.turn.down.right")
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.readerAmberText)
                    .help("Go to this word")

                    Text(note.createdAt.readerRelativeString)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    HStack(spacing: 2) {
                        Button {
                            draft = note.text
                            editing = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .help("Edit")
                        .accessibilityLabel("Edit")

                        Button(role: .destructive) {
                            onDelete(note.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("Delete")
                        .accessibilityLabel("Delete")
                    }
                    .buttonStyle(GlassIconButtonStyle(size: 24))
                    .opacity(hovering ? 1 : 0.35)
                }
                .font(.caption)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(hovering ? 0.07 : 0.045)))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}
