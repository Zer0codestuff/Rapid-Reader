import SwiftUI

struct URLImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    let onImport: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Article URL")
                .font(.title3.weight(.semibold))

            TextField("https://example.com/article", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 420)
                .onSubmit(importURL)

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
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(24)
    }

    private var parsedURL: URL? {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
            return nil
        }
        return url
    }

    private func importURL() {
        guard let parsedURL else { return }
        onImport(parsedURL)
    }
}
