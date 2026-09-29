import SwiftUI

struct EmptyLibraryView: View {
    let onImportFiles: () -> Void
    let onImportURL: () -> Void
    let onPasteText: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            if let image = AppArtwork.iconImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 128, height: 128)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 8) {
                Text("Start with a book")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Drop a file here, or import EPUB, PDF, DOCX, RTF, HTML, Markdown, text, or a web article.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            HStack(spacing: 10) {
                Button(action: onImportFiles) {
                    Label("Import Files", systemImage: "doc.badge.plus")
                        .padding(.horizontal, 6)
                }
                .controlSize(.large)
                .readerGlassButton(prominent: true)
                .tint(.readerAmber)
                .keyboardShortcut("o", modifiers: [.command])

                Button(action: onImportURL) {
                    Label("Article", systemImage: "link")
                }
                .controlSize(.large)
                .readerGlassButton()

                Button(action: onPasteText) {
                    Label("Paste Text", systemImage: "doc.on.clipboard")
                }
                .controlSize(.large)
                .readerGlassButton()
            }
            .readerGlassContainer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RadialGradient(
                colors: [Color.readerAmber.opacity(0.08), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 460
            )
        }
        .navigationTitle("Rapid Reader")
    }
}
