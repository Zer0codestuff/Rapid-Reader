import AppKit
import SwiftUI

struct BookCoverThumbnail: View {
    let imageData: Data?
    var width: CGFloat = 38
    var height: CGFloat = 52
    var fallbackSystemImage = "book.closed"

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.readerInk.opacity(0.78),
                            Color.readerInk.opacity(0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: min(width, height) * 0.42, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(image == nil ? 0 : 0.16), radius: 5, y: 2)
        .accessibilityHidden(true)
    }

    private var image: NSImage? {
        guard let imageData else { return nil }
        return NSImage(data: imageData)
    }
}
