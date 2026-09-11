import AppKit

/// A read-only text view that draws full-width backgrounds for code blocks
/// and a side bar for block quotes before its glyphs, and keeps its content
/// centered in a comfortable reading column as the window resizes.
final class MarkdownTextView: NSTextView {
    override func draw(_ dirtyRect: NSRect) {
        drawCustomBlockDecorations()
        super.draw(dirtyRect)
    }

    override func layout() {
        super.layout()
        updateReadingWidth()
    }

    private func updateReadingWidth() {
        guard let container = textContainer, let scrollView = enclosingScrollView else { return }
        let available = scrollView.contentSize.width
        let horizontalPadding = max(28, (available - MarkdownTheme.readingWidth) / 2)
        if container.lineFragmentPadding != horizontalPadding {
            container.lineFragmentPadding = horizontalPadding
        }
    }

    private func drawCustomBlockDecorations() {
        guard let layoutManager, let textContainer, let textStorage else { return }
        let columnLeft = textContainerOrigin.x + textContainer.lineFragmentPadding
        let columnRight = textContainerOrigin.x + textContainer.size.width - textContainer.lineFragmentPadding

        let full = NSRange(location: 0, length: textStorage.length)
        textStorage.enumerateAttribute(.markdownBlockKind, in: full) { value, range, _ in
            guard let kind = value as? MarkdownBlockKind else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            rect.origin.x += textContainerOrigin.x
            rect.origin.y += textContainerOrigin.y

            switch kind {
            case .codeBlock:
                var backgroundRect = rect
                backgroundRect.origin.x = columnLeft - 8
                backgroundRect.size.width = (columnRight - columnLeft) + 16
                backgroundRect = backgroundRect.insetBy(dx: 0, dy: -4)
                let path = NSBezierPath(roundedRect: backgroundRect, xRadius: 8, yRadius: 8)
                MarkdownTheme.codeBackgroundColor.setFill()
                path.fill()
            case .blockQuote:
                var barRect = rect
                barRect.origin.x = rect.origin.x - 14
                barRect.size.width = 3
                MarkdownTheme.quoteBarColor.setFill()
                NSBezierPath(rect: barRect).fill()
            case .rule:
                let y = rect.midY
                let path = NSBezierPath()
                path.move(to: NSPoint(x: columnLeft, y: y))
                path.line(to: NSPoint(x: columnRight, y: y))
                path.lineWidth = 1
                MarkdownTheme.ruleColor.setStroke()
                path.stroke()
            }
        }
    }
}
