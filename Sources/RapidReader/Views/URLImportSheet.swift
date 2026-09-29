import SwiftUI

struct URLImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var submitted = false
    @FocusState private var isFocused: Bool
    let onImport: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Import an Article")
                    .font(.title2.weight(.semibold))
                Text("Paste a web address. Only the article text is kept.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextField("https://example.com/article", text: $urlText)
                .textFieldStyle(.plain)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isFocused ? Color.readerAmber.opacity(0.7) : Color.primary.opacity(0.08))
                )
                .focused($isFocused)
                .onSubmit(importURL)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Import") {
                    importURL()
                }
                .readerGlassButton(prominent: true)
                .tint(.readerAmber)
                .disabled(parsedURL == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { isFocused = true }
    }

    private var parsedURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            return nil
        }
        return url
    }

    private func importURL() {
        guard !submitted, let parsedURL else { return }
        submitted = true
        onImport(parsedURL)
    }
}
