import SwiftUI

struct EmptyLibraryView: View {
    let onImportFiles: () -> Void
    let onPasteText: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            if let image = AppArtwork.iconImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 160)
                    .accessibilityHidden(true)
            }

            Text("Rapid Reader")
                .font(.system(size: 36, weight: .semibold, design: .rounded))

            HStack(spacing: 10) {
                Button(action: onImportFiles) {
                    Label("Import Files", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("o", modifiers: [.command])

                Button(action: onPasteText) {
                    Label("Paste Text", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.readerMist.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
