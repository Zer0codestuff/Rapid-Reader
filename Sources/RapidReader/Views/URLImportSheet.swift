import SwiftUI

struct URLImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var submitted = false
    @FocusState private var isFocused: Bool
    let onImport: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Article URL")
                .font(.title3.weight(.semibold))

            TextField("https://example.com/article", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 420)
                .focused($isFocused)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Import") {
                    importURL()
                }
                .buttonStyle(.borderedProminent)
                .disabled(parsedURL == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
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
