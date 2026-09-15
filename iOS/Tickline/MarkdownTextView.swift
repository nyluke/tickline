import UIKit
import TicklineKit

/// A read-only text view that draws full-width backgrounds for code blocks
/// and a side bar for block quotes before its glyphs, and keeps its content
/// centered in a comfortable reading column as the view resizes.
///
/// `UITextView` is itself a `UIScrollView` (unlike AppKit, where
/// `NSTextView` is hosted inside a separate `NSScrollView`), so sizing
/// reads from `bounds` directly instead of an enclosing scroll view, and
/// there's no `textContainerOrigin` — the container starts at the text
/// container inset.
final class MarkdownTextView: UITextView {
    private var textContainerOrigin: CGPoint {
        CGPoint(x: textContainerInset.left, y: textContainerInset.top)
    }

    override func draw(_ rect: CGRect) {
        drawCustomBlockDecorations()
        super.draw(rect)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateReadingWidth()
    }

    private func updateReadingWidth() {
        let available = bounds.width
        let horizontalPadding = max(20, (available - MarkdownTheme.readingWidth) / 2)
        if textContainer.lineFragmentPadding != horizontalPadding {
            textContainer.lineFragmentPadding = horizontalPadding
        }
    }

    private func drawCustomBlockDecorations() {
        let origin = textContainerOrigin
        let columnLeft = origin.x + textContainer.lineFragmentPadding
        let columnRight = origin.x + textContainer.size.width - textContainer.lineFragmentPadding

        let full = NSRange(location: 0, length: textStorage.length)
        textStorage.enumerateAttribute(.markdownBlockKind, in: full) { value, range, _ in
            guard let kind = value as? MarkdownBlockKind else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            rect.origin.x += origin.x
            rect.origin.y += origin.y

            switch kind {
            case .codeBlock:
                var backgroundRect = rect
                backgroundRect.origin.x = columnLeft - 8
                backgroundRect.size.width = (columnRight - columnLeft) + 16
                backgroundRect = backgroundRect.insetBy(dx: 0, dy: -4)
                let path = UIBezierPath(roundedRect: backgroundRect, cornerRadius: 8)
                MarkdownTheme.codeBackgroundColor.setFill()
                path.fill()
            case .blockQuote:
                var barRect = rect
                barRect.origin.x = rect.origin.x - 14
                barRect.size.width = 3
                MarkdownTheme.quoteBarColor.setFill()
                UIBezierPath(rect: barRect).fill()
            case .rule:
                let y = rect.midY
                let path = UIBezierPath()
                path.move(to: CGPoint(x: columnLeft, y: y))
                path.addLine(to: CGPoint(x: columnRight, y: y))
                path.lineWidth = 1
                MarkdownTheme.ruleColor.setStroke()
                path.stroke()
            }
        }
    }
}
