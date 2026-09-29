import RapidReaderCore
import SwiftUI

struct LibrarySidebarView: View {
    let items: [RapidReaderCore.LibraryItem]
    @Binding var selectedID: UUID?
    @Binding var searchText: String
    let onImportFiles: () -> Void
    let onImportURL: () -> Void
    let onPasteText: () -> Void
    let onShowStatistics: () -> Void
    let onDelete: (UUID) -> Void
    let onToggleFavorite: (UUID) -> Void

    @State private var pendingDeletion: UUID?

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Started but unfinished documents, most recent first.
    private var inProgress: [RapidReaderCore.LibraryItem] {
        items.filter { $0.lastReadAt != nil && $0.fractionComplete > 0 && $0.fractionComplete < 0.999 }
    }

    private var others: [RapidReaderCore.LibraryItem] {
        let ids = Set(inProgress.map(\.id))
        return items.filter { !ids.contains($0.id) }
    }

    var body: some View {
        List(selection: $selectedID) {
            if isSearching {
                Section("Results") { rows(items) }
            } else {
                if !inProgress.isEmpty {
                    Section("Continue Reading") { rows(inProgress) }
                }
                if !others.isEmpty {
                    Section("Library") { rows(others) }
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if isSearching && items.isEmpty {
                Text("No documents match “\(searchText)”.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .onDeleteCommand { pendingDeletion = selectedID }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search library")
        .navigationSplitViewColumnWidth(min: 230, ideal: 280)
        .toolbar {
            ToolbarItemGroup {
                Button(action: onShowStatistics) {
                    Label("Statistics", systemImage: "chart.bar.xaxis")
                }
                .help("Reading statistics")

                Menu {
                    Button("Import Files…", systemImage: "doc.badge.plus", action: onImportFiles)
                    Button("Import Article…", systemImage: "link", action: onImportURL)
                    Button("Paste Text", systemImage: "doc.on.clipboard", action: onPasteText)
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .menuIndicator(.hidden)
                .help("Add documents")
            }
        }
        .alert("Delete document?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let id = pendingDeletion { onDelete(id) }
                pendingDeletion = nil
            }
        } message: {
            Text("This removes the document, reading progress, and notes from this library. The original file is kept.")
        }
    }

    private func rows(_ items: [RapidReaderCore.LibraryItem]) -> some View {
        ForEach(items) { item in
            LibraryRow(item: item)
                .tag(item.id)
                .contextMenu {
                    Button(item.isFavorite ? "Unfavorite" : "Favorite") {
                        onToggleFavorite(item.id)
                    }
                    Divider()
                    Button("Delete…", role: .destructive) { pendingDeletion = item.id }
                }
        }
    }
}

private struct LibraryRow: View {
    let item: RapidReaderCore.LibraryItem

    var body: some View {
        HStack(spacing: 11) {
            BookCoverThumbnail(
                imageData: item.coverImageData,
                width: 34,
                height: 46,
                fallbackSystemImage: item.format.symbolName
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.readerAmber)
                            .accessibilityLabel("Favorite")
                    }
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressBar(fraction: item.fractionComplete)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(item.fractionComplete.percentString) read")
    }

    private var subtitle: String {
        var parts = [item.author ?? item.format.displayName]
        if let date = item.lastReadAt { parts.append(date.readerRelativeString) }
        return parts.joined(separator: " · ")
    }
}

private struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(Color.readerAmber)
                    .frame(width: fraction > 0 ? max(3, proxy.size.width * fraction) : 0)
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }
}

extension ReadingFormat {
    var symbolName: String {
        switch self {
        case .epub: "books.vertical"
        case .pdf: "doc.richtext"
        case .docx, .rtf: "doc.text"
        case .html, .webArticle: "safari"
        case .markdown, .plainText, .unknown: "text.alignleft"
        }
    }
}
