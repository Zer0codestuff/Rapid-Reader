import RapidReaderCore
import SwiftUI

struct DocumentSearchView: View {
    let sections: [BookSection]
    @Binding var query: String
    let onSelect: (SearchMatch) -> Void

    private nonisolated static let limit = 500

    @State private var index: DocumentSearchIndex?
    @State private var matches: [SearchMatch] = []
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search in document", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit { if let first = matches.first { onSelect(first) } }

            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            List(matches) { match in
                Button { onSelect(match) } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: sectionTitle(match.sectionIndex))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        (Text(verbatim: match.before) + Text(verbatim: match.match).bold().foregroundColor(.readerAmber) + Text(verbatim: match.after))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .padding(14)
        .frame(width: 420, height: 380)
        .task {
            // The popover becomes key after it appears; focusing earlier is ignored.
            try? await Task.sleep(for: .milliseconds(50))
            fieldFocused = true
        }
        .task(id: query) {
            if index == nil {
                let sections = sections
                index = await Task.detached(priority: .userInitiated) { DocumentSearchIndex(sections: sections) }.value
            }
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let index else { return }
            let query = query
            let found = await Task.detached(priority: .userInitiated) { index.matches(for: query, limit: Self.limit) }.value
            guard !Task.isCancelled else { return }
            matches = found
        }
    }

    private var summary: String {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return String(localized: "Type to search this document.") }
        if index == nil { return String(localized: "Preparing search…") }
        switch matches.count {
        case 0: return String(localized: "No matches")
        case Self.limit...: return String(localized: "First \(Self.limit) matches")
        default: return String(localized: "\(matches.count) matches")
        }
    }

    private func sectionTitle(_ index: Int) -> String {
        sections.indices.contains(index) ? sections[index].title : ""
    }
}
