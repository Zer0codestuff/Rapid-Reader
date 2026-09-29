import AppKit
import RapidReaderCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var library: LibraryStore
    @State private var searchText = ""
    @State private var showingFileImporter = false
    @State private var showingURLImporter = false
    @State private var showingFailureAlert = false
    @State private var showingStatistics = false
    @State private var isDropTargeted = false
    @AppStorage(ReaderTheme.storageKey) private var theme: ReaderTheme = .system

    private var visibleItems: [RapidReaderCore.LibraryItem] {
        let sorted = library.items.sortedForLibrary
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return sorted
        }
        return sorted.filter { item in
            item.title.localizedCaseInsensitiveContains(searchText)
                || item.author?.localizedCaseInsensitiveContains(searchText) == true
                || item.sourceName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            LibrarySidebarView(
                items: visibleItems,
                selectedID: $library.selectedID,
                searchText: $searchText,
                onImportFiles: { showingFileImporter = true },
                onImportURL: { showingURLImporter = true },
                onPasteText: importClipboard,
                onShowStatistics: { showingStatistics = true },
                onDelete: { id in
                    if let index = visibleItems.firstIndex(where: { $0.id == id }) {
                        library.deleteItems(at: IndexSet(integer: index), from: visibleItems)
                    }
                },
                onToggleFavorite: library.toggleFavorite
            )
        } detail: {
            if let item = library.selectedItem {
                ReaderView(item: item, library: library)
                    .id(item.id)
            } else {
                EmptyLibraryView(
                    onImportFiles: { showingFileImporter = true },
                    onImportURL: { showingURLImporter = true },
                    onPasteText: importClipboard
                )
            }
        }
        .overlay {
            if isDropTargeted {
                DropHint()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isDropTargeted)
        // The whole window follows an explicit reader theme, so the chrome matches the page.
        .preferredColorScheme(theme.colorScheme)
        .focusedSceneValue(\.importActions, ImportActions(
            files: { showingFileImporter = true },
            article: { showingURLImporter = true },
            clipboard: importClipboard
        ))
        .dropDestination(for: URL.self) { urls, _ in
            guard !urls.isEmpty else { return false }
            Task { @MainActor in
                syncDefaultPreferences()
                let files = urls.filter(\.isFileURL)
                if !files.isEmpty { await library.importFiles(files) }
                for url in urls where !url.isFileURL { await library.importArticle(from: url) }
            }
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .onChange(of: library.lastFailures) { _, failures in
            showingFailureAlert = !failures.isEmpty
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: DocumentImportService.supportedFileTypes,
            allowsMultipleSelection: true
        ) { result in
            Task { @MainActor in
                switch result {
                case .success(let urls):
                    syncDefaultPreferences()
                    await library.importFiles(urls)
                    showingFailureAlert = !library.lastFailures.isEmpty
                case .failure(let error):
                    library.recordFailure(sourceName: "Import", message: error.localizedDescription)
                    showingFailureAlert = true
                }
            }
        }
        .sheet(isPresented: $showingStatistics) {
            StatisticsView(statistics: library.statistics)
        }
        .sheet(isPresented: $showingURLImporter) {
            URLImportSheet { url in
                showingURLImporter = false
                Task { @MainActor in
                    syncDefaultPreferences()
                    await library.importArticle(from: url)
                    showingFailureAlert = !library.lastFailures.isEmpty
                }
            }
        }
        .onAppear {
            showingFailureAlert = !library.lastFailures.isEmpty
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            library.flushPendingChanges()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            library.flushPendingChanges()
        }
        .alert("Import issue", isPresented: $showingFailureAlert) {
            Button("OK") {
                library.clearFailures()
            }
        } message: {
            Text(library.lastFailures.map { "\($0.sourceName): \($0.message)" }.joined(separator: "\n"))
        }
    }

    private func importClipboard() {
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        syncDefaultPreferences()
        library.importClipboardText(text)
        showingFailureAlert = !library.lastFailures.isEmpty
    }

    private func syncDefaultPreferences() {
        library.setDefaultPreferences(ReadingDefaults.preferences())
    }
}

private struct DropHint: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.readerAmber, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(10)
            Label("Drop to add to your library", systemImage: "arrow.down.doc")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .readerGlass(in: Capsule())
        }
        .allowsHitTesting(false)
    }
}
