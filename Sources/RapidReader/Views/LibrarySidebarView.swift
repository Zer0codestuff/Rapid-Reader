import RapidReaderCore
import SwiftUI

struct LibrarySidebarView: View {
    let items: [RapidReaderCore.LibraryItem]
    @Binding var selectedID: UUID?
    @Binding var searchText: String
    let onImportFiles: () -> Void
    let onImportURL: () -> Void
    let onPasteText: () -> Void
    let onDelete: (IndexSet) -> Void
    let onToggleFavorite: (UUID) -> Void

    @State private var pendingDeletion: UUID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                Section("Library") {
                    ForEach(items) { item in
                        LibraryRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                Button(item.isFavorite ? LocalizedStringKey("Unfavorite") : LocalizedStringKey("Favorite")) {
                                    onToggleFavorite(item.id)
                                }
                                Button("Delete", role: .destructive) { pendingDeletion = item.id }
                            }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first, items.indices.contains(index) { pendingDeletion = items[index].id }
                    }
                }
            }
            .onDeleteCommand { pendingDeletion = selectedID }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search")

            Divider()

            HStack(spacing: 8) {
                Button(action: onImportFiles) {
                    Label("Files", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Import EPUB, PDF, DOCX, RTF, HTML, Markdown, or text")

                Menu {
                    Button("Article URL", systemImage: "link", action: onImportURL)
                    Button("Clipboard", systemImage: "doc.on.clipboard", action: onPasteText)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.button)
                .controlSize(.small)
                .help("More import options")
            }
            .padding(10)
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        .alert("Delete document?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let id = pendingDeletion, let index = items.firstIndex(where: { $0.id == id }) {
                    onDelete(IndexSet(integer: index))
                }
                pendingDeletion = nil
            }
        } message: {
            Text("This removes the document, reading progress, and notes from this library. The original file is kept.")
        }
    }
}

private struct LibraryRow: View {
    let item: RapidReaderCore.LibraryItem

    var body: some View {
        HStack(spacing: 10) {
            BookCoverThumbnail(
                imageData: item.coverImageData,
                width: 34,
                height: 46,
                fallbackSystemImage: iconName
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .lineLimit(1)

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.readerAmber)
                    }
                }

                HStack(spacing: 6) {
                    Text(item.format.displayName)
                    Text(item.fractionComplete.percentString)
                    if let date = item.lastReadAt {
                        Text(date.readerRelativeString)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch item.format {
        case .epub: "books.vertical"
        case .pdf: "doc.richtext"
        case .docx, .rtf: "doc.text"
        case .html, .webArticle: "safari"
        case .markdown, .plainText, .unknown: "text.alignleft"
        }
    }
}
