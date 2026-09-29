import RapidReaderCore
import SwiftUI

struct NotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    let notes: [ReaderNote]
    @Binding var noteText: String
    let onAdd: () -> Void
    let onUpdate: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onJump: (ReaderNote) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Notes").font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            TextEditor(text: $noteText)
                .frame(height: 80)
                .accessibilityLabel("New note")
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.22)))
            HStack {
                Spacer()
                Button("Add Note", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            List(notes) { note in
                NoteRow(note: note, onUpdate: onUpdate, onDelete: onDelete, onJump: onJump)
            }
            .frame(height: 240)
        }
        .padding(24)
        .frame(width: 500)
    }
}

private struct NoteRow: View {
    let note: ReaderNote
    let onUpdate: (UUID, String) -> Void
    let onDelete: (UUID) -> Void
    let onJump: (ReaderNote) -> Void
    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if editing {
                TextField("Note", text: $draft, axis: .vertical)
                HStack {
                    Button("Save") { onUpdate(note.id, draft); editing = false }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel") { editing = false }
                }
            } else {
                Text(note.text).textSelection(.enabled)
                HStack {
                    Button("Section \(note.sectionIndex + 1), word \(note.wordIndex + 1)") { onJump(note) }
                        .buttonStyle(.link)
                    Spacer()
                    Button("Edit") { draft = note.text; editing = true }
                    Button("Delete", role: .destructive) { onDelete(note.id) }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
