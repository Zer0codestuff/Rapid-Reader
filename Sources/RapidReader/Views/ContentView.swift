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
                onDelete: { offsets in library.deleteItems(at: offsets, from: visibleItems) },
                onToggleFavorite: library.toggleFavorite
            )
        } detail: {
            if let item = library.selectedItem {
                ReaderView(item: item, library: library)
                    .id(item.id)
            } else {
                EmptyLibraryView(
                    onImportFiles: { showingFileImporter = true },
                    onPasteText: importClipboard
                )
            }
        }
        .navigationTitle("Rapid Reader")
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
        }
        .onChange(of: library.lastFailures) { _, failures in
            showingFailureAlert = !failures.isEmpty
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingStatistics = true
                } label: {
                    Label("Statistics", systemImage: "chart.bar.xaxis")
                }
                .help("Reading statistics")

                Button {
                    showingFileImporter = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import files")

                Button {
                    showingURLImporter = true
                } label: {
                    Label("Article", systemImage: "link")
                }
                .help("Import article URL")
            }
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
