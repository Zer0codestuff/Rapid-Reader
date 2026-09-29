import AppKit
import RapidReaderCore
import SwiftUI

struct FullTextReaderView: NSViewRepresentable {
    let sections: [BookSection]
    let currentSectionIndex: Int
    let currentWordIndex: Int
    let textColor: NSColor
    let appearance: NSAppearance?
    var bottomInset: CGFloat = 0
    let onSelectWord: (Int, Int) -> Void

    final class Coordinator {
        var sections: [BookSection] = []
        var textColor: NSColor?
        var selectedRange: NSRange?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.automaticallyAdjustsContentInsets = false

        let textView = ClickableDocumentTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 36)
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

        let coordinator = context.coordinator
        textView.onSelectWord = onSelectWord
        scrollView.appearance = appearance
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        if coordinator.sections != sections || coordinator.textColor != textColor {
            let document = TextDocumentBuilder.makeDocument(sections: sections, textColor: textColor)
            textView.wordRanges = document.wordRanges
            textView.textStorage?.setAttributedString(document.attributedText)
            coordinator.sections = sections
            coordinator.textColor = textColor
            coordinator.selectedRange = nil
        }
        let sectionRanges = textView.wordRanges.filter { $0.sectionIndex == currentSectionIndex }
        let index = min(max(currentWordIndex, 0), max(sectionRanges.count - 1, 0))
        let selectedRange = sectionRanges.indices.contains(index) ? sectionRanges[index].range : nil
        guard selectedRange != coordinator.selectedRange else { return }
        if let old = coordinator.selectedRange {
            textView.textStorage?.removeAttribute(.backgroundColor, range: old)
        }
        coordinator.selectedRange = selectedRange
        if let selectedRange {
            textView.textStorage?.addAttribute(.backgroundColor, value: NSColor(srgbRed: 0.95, green: 0.62, blue: 0.22, alpha: 0.30), range: selectedRange)
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
}

private enum TextDocumentBuilder {
    static func makeDocument(
        sections: [BookSection],
        textColor: NSColor
    ) -> BuiltTextDocument {
        let output = NSMutableAttributedString()
        var wordRanges: [TextWordRange] = []
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineHeightMultiple = 1.12
        bodyStyle.paragraphSpacing = 12

        let headingStyle = NSMutableParagraphStyle()
        headingStyle.paragraphSpacing = 14
        headingStyle.paragraphSpacingBefore = 18

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: readingFont(size: 18, weight: .regular),
            .foregroundColor: textColor,
            .paragraphStyle: bodyStyle
        ]
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: readingFont(size: 26, weight: .semibold),
            .foregroundColor: textColor,
            .paragraphStyle: headingStyle
        ]
        for (sectionIndex, section) in sections.enumerated() {
            if sectionIndex > 0 {
                output.append(NSAttributedString(string: "\n\n"))
            }

            output.append(NSAttributedString(string: "\(section.title)\n", attributes: headingAttributes))

            let tokenized = TextProcessor.tokenizedText(section.text)
            let sectionText = tokenized.text
            let bodyStart = output.length
            output.append(NSAttributedString(string: sectionText, attributes: bodyAttributes))

            let ranges = tokenized.tokens.map(\.range)

            for (wordIndex, range) in ranges.enumerated() {
                let absoluteRange = NSRange(location: bodyStart + range.location, length: range.length)
                wordRanges.append(
                    TextWordRange(
                        range: absoluteRange,
                        sectionIndex: sectionIndex,
                        wordIndex: wordIndex
                    )
                )


            }
        }

        return BuiltTextDocument(
            attributedText: output,
            wordRanges: wordRanges
        )
    }


}

private func readingFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard let serif = base.fontDescriptor.withDesign(.serif) else { return base }
    return NSFont(descriptor: serif, size: size) ?? base
}

private final class ClickableDocumentTextView: NSTextView {
    var wordRanges: [TextWordRange] = []
    var onSelectWord: ((Int, Int) -> Void)?

    /// Keeps lines at a comfortable reading length by centering a column in wide windows.
    private let columnWidth: CGFloat = 680

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let horizontal = max(28, (newSize.width - columnWidth) / 2)
        if abs(textContainerInset.width - horizontal) > 0.5 {
            textContainerInset = NSSize(width: horizontal, height: textContainerInset.height)
        }
    }

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
