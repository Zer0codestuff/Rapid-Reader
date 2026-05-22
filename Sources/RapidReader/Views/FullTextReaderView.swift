import AppKit
import RapidReaderCore
import SwiftUI

struct FullTextReaderView: NSViewRepresentable {
    let sections: [BookSection]
    let currentSectionIndex: Int
    let currentWordIndex: Int
    let onSelectWord: (Int, Int) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        let textView = ClickableDocumentTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 24)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ClickableDocumentTextView else { return }

        let document = TextDocumentBuilder.makeDocument(
            sections: sections,
            currentSectionIndex: currentSectionIndex,
            currentWordIndex: currentWordIndex
        )

        textView.onSelectWord = onSelectWord
        textView.wordRanges = document.wordRanges
        textView.textStorage?.setAttributedString(document.attributedText)

        if let selectedRange = document.selectedRange {
            textView.scrollRangeToVisible(selectedRange)
        }
    }
}

private struct TextWordRange {
    var range: NSRange
    var sectionIndex: Int
    var wordIndex: Int
}

private struct BuiltTextDocument {
    var attributedText: NSAttributedString
    var wordRanges: [TextWordRange]
    var selectedRange: NSRange?
}

private enum TextDocumentBuilder {
    static func makeDocument(
        sections: [BookSection],
        currentSectionIndex: Int,
        currentWordIndex: Int
    ) -> BuiltTextDocument {
        let output = NSMutableAttributedString()
        var wordRanges: [TextWordRange] = []
        var selectedRange: NSRange?

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 4
        bodyStyle.paragraphSpacing = 12

        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacing = 10

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: bodyStyle
        ]
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: headingStyle
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .backgroundColor: NSColor.systemOrange.withAlphaComponent(0.26),
            .foregroundColor: NSColor.labelColor
        ]

        for (sectionIndex, section) in sections.enumerated() {
            if sectionIndex > 0 {
                output.append(NSAttributedString(string: "\n\n"))
            }

            output.append(NSAttributedString(string: "\(section.title)\n", attributes: headingAttributes))

            let sectionText = TextProcessor.normalizedText(section.text)
            let bodyStart = output.length
            output.append(NSAttributedString(string: sectionText, attributes: bodyAttributes))

            let ranges = wordRangesIn(sectionText)
            let highlightedWordIndex = highlightedIndex(
                for: section,
                sectionIndex: sectionIndex,
                currentSectionIndex: currentSectionIndex,
                currentWordIndex: currentWordIndex
            )

            for (wordIndex, range) in ranges.enumerated() {
                let absoluteRange = NSRange(location: bodyStart + range.location, length: range.length)
                wordRanges.append(
                    TextWordRange(
                        range: absoluteRange,
                        sectionIndex: sectionIndex,
                        wordIndex: wordIndex
                    )
                )

                if wordIndex == highlightedWordIndex, sectionIndex == currentSectionIndex {
                    output.addAttributes(selectedAttributes, range: absoluteRange)
                    selectedRange = absoluteRange
                }
            }
        }

        return BuiltTextDocument(
            attributedText: output,
            wordRanges: wordRanges,
            selectedRange: selectedRange
        )
    }

    private static func wordRangesIn(_ text: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: #"\S+"#) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).map(\.range)
    }

    private static func highlightedIndex(
        for section: BookSection,
        sectionIndex: Int,
        currentSectionIndex: Int,
        currentWordIndex: Int
    ) -> Int? {
        guard sectionIndex == currentSectionIndex else { return nil }
        let maxIndex = max(TextProcessor.tokenize(section.text).count - 1, 0)
        return min(max(currentWordIndex, 0), maxIndex)
    }
}

private final class ClickableDocumentTextView: NSTextView {
    var wordRanges: [TextWordRange] = []
    var onSelectWord: ((Int, Int) -> Void)?

    override func mouseDown(with event: NSEvent) {
        defer {
            super.mouseDown(with: event)
        }

        guard
            let layoutManager,
            let textContainer
        else {
            return
        }

        var location = convert(event.locationInWindow, from: nil)
        location.x -= textContainerOrigin.x
        location.y -= textContainerOrigin.y

        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )

        guard let match = wordRanges.first(where: { NSLocationInRange(characterIndex, $0.range) }) else {
            return
        }

        DispatchQueue.main.async { [onSelectWord] in
            onSelectWord?(match.sectionIndex, match.wordIndex)
        }
    }
}
