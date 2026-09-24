#if canImport(AppKit)
import AppKit

/// A text table that sizes its columns the way a browser's automatic table
/// layout does, recomputed whenever the available width changes.
///
/// Left to itself, `NSTextTable` scales every column's preferred width by
/// the same factor when the table doesn't fit, ignoring minimum widths, so
/// a column next to a much longer one gets squeezed until its words break
/// between letters. Instead, each column here keeps the width of its widest
/// unbreakable run, and the rest of the space goes to columns in proportion
/// to how much more they'd need to fit their content on one line.
final class MarkdownTextTable: NSTextTable {
    /// Horizontal padding inside each cell, on each side.
    static let cellPadding: CGFloat = 10

    private var minimumColumnWidths: [CGFloat] = []
    private var maximumColumnWidths: [CGFloat] = []
    private var fittedWidth: CGFloat?

    /// Records the narrowest and widest each column's content can be laid
    /// out, from the rendered cells in row-major order.
    func measureColumns(of rows: [[NSAttributedString]]) {
        minimumColumnWidths = (0..<numberOfColumns).map { column in
            ceil(rows.map { Self.widestUnbreakableRun(in: $0[column]) }.max() ?? 0) + 1
        }
        maximumColumnWidths = (0..<numberOfColumns).map { column in
            ceil(rows.map { $0[column].size().width }.max() ?? 0) + 1
        }
    }

    override func rect(
        for block: NSTextTableBlock,
        layoutAt startingPoint: NSPoint,
        in rect: NSRect,
        textContainer: NSTextContainer,
        characterRange charRange: NSRange
    ) -> NSRect {
        if rect.width != fittedWidth, let storage = textContainer.layoutManager?.textStorage {
            fittedWidth = rect.width
            fitColumns(to: rect.width, in: storage, at: charRange.location)
        }
        return super.rect(
            for: block,
            layoutAt: startingPoint,
            in: rect,
            textContainer: textContainer,
            characterRange: charRange
        )
    }

    /// Sets every cell's width for a table laid out in `width` points.
    private func fitColumns(to width: CGFloat, in storage: NSTextStorage, at location: Int) {
        guard minimumColumnWidths.count == numberOfColumns else { return }
        let available = width - 2 * Self.cellPadding * CGFloat(numberOfColumns)
        let minimumTotal = minimumColumnWidths.reduce(0, +)
        let maximumTotal = maximumColumnWidths.reduce(0, +)

        let widths: [CGFloat]
        if maximumTotal <= available {
            widths = maximumColumnWidths
        } else if minimumTotal >= available {
            // Something has to break between letters. Narrowing only the
            // widest columns breaks long runs like file paths and keeps
            // short words whole.
            widths = Self.capping(minimumColumnWidths, toTotal: available)
        } else {
            let share = (available - minimumTotal) / (maximumTotal - minimumTotal)
            widths = zip(minimumColumnWidths, maximumColumnWidths).map { minimum, maximum in
                (minimum + (maximum - minimum) * share).rounded(.down)
            }
        }

        let tableRange = storage.range(of: self, at: location)
        storage.enumerateAttribute(.paragraphStyle, in: tableRange) { value, _, _ in
            guard let cell = (value as? NSParagraphStyle)?.textBlocks.last as? NSTextTableBlock,
                  cell.table === self else { return }
            cell.setValue(widths[cell.startingColumn], type: .absoluteValueType, for: .width)
        }
    }

    /// Lowers the largest of `widths` to a common cap so they sum to at
    /// most `total`.
    private static func capping(_ widths: [CGFloat], toTotal total: CGFloat) -> [CGFloat] {
        var remaining = total
        var uncapped = widths.count
        var cap = CGFloat.greatestFiniteMagnitude
        for width in widths.sorted() {
            let share = remaining / CGFloat(uncapped)
            if width > share {
                cap = max(share.rounded(.down), 1)
                break
            }
            remaining -= width
            uncapped -= 1
        }
        return widths.map { min($0, cap) }
    }

    /// The width of the widest run in `content` that the text system can't
    /// break across lines.
    private static func widestUnbreakableRun(in content: NSAttributedString) -> CGFloat {
        let text = content.string as NSString
        let tokenizer = CFStringTokenizerCreate(
            nil, text, CFRange(location: 0, length: text.length),
            kCFStringTokenizerUnitLineBreak, nil
        )
        var widest: CGFloat = 0
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            var run = NSRange(location: range.location, length: range.length)
            // Spaces at the end of a run hang past the end of the line.
            while run.length > 0,
                  let scalar = UnicodeScalar(text.character(at: run.location + run.length - 1)),
                  CharacterSet.whitespacesAndNewlines.contains(scalar) {
                run.length -= 1
            }
            widest = max(widest, content.attributedSubstring(from: run).size().width)
        }
        return widest
    }
}
#endif
