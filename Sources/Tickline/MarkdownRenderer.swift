import AppKit
import Markdown

/// Walks a parsed Markdown tree and builds a styled `NSAttributedString`.
///
/// Architecture note: leaf/standalone block producers (paragraph, heading,
/// code block, thematic break, the table fallback) each terminate
/// themselves with a trailing "\n" that carries their own paragraph style.
/// Pure containers (document, block quote, lists, list items) just
/// concatenate their already-self-terminated children. This keeps every
/// block responsible for its own vertical rhythm.
struct MarkdownRenderer: MarkupVisitor {
    private let baseURL: URL?
    private var listDepth = 0
    private var quoteDepth = 0

    init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    mutating func render(source: String) -> NSAttributedString {
        let document = Markdown.Document(parsing: source)
        return visit(document)
    }

    // MARK: - Containers

    mutating func defaultVisit(_ markup: Markup) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    mutating func visitDocument(_ document: Markdown.Document) -> NSMutableAttributedString {
        defaultVisit(document)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSMutableAttributedString {
        quoteDepth += 1
        let inner = NSMutableAttributedString()
        for child in blockQuote.children {
            inner.append(visit(child))
        }
        quoteDepth -= 1

        let indent: CGFloat = 20 * CGFloat(quoteDepth + 1)
        let full = NSRange(location: 0, length: inner.length)
        inner.enumerateAttribute(.paragraphStyle, in: full) { value, range, _ in
            let base = (value as? NSParagraphStyle) ?? NSParagraphStyle()
            guard let mutable = base.mutableCopy() as? NSMutableParagraphStyle else { return }
            mutable.headIndent += indent
            mutable.firstLineHeadIndent += indent
            mutable.tailIndent = mutable.tailIndent == 0 ? 0 : mutable.tailIndent
            inner.addAttribute(.paragraphStyle, value: mutable, range: range)
        }
        inner.addAttribute(.markdownBlockKind, value: MarkdownBlockKind.blockQuote, range: full)
        return inner
    }

    // MARK: - Lists

    mutating func visitUnorderedList(_ list: UnorderedList) -> NSMutableAttributedString {
        listDepth += 1
        defer { listDepth -= 1 }
        let bullets = ["•", "◦", "▪︎"]
        let bullet = bullets[(listDepth - 1) % bullets.count]

        let result = NSMutableAttributedString()
        for child in list.children {
            guard let item = child as? ListItem else { continue }
            let marker = markerText(for: item, defaultMarker: bullet)
            result.append(renderListItem(item, marker: marker))
        }
        return result
    }

    mutating func visitOrderedList(_ list: OrderedList) -> NSMutableAttributedString {
        listDepth += 1
        defer { listDepth -= 1 }

        let result = NSMutableAttributedString()
        var number = Int(list.startIndex)
        for child in list.children {
            guard let item = child as? ListItem else { continue }
            let marker = markerText(for: item, defaultMarker: "\(number).")
            result.append(renderListItem(item, marker: marker))
            number += 1
        }
        return result
    }

    private func markerText(for item: ListItem, defaultMarker: String) -> String {
        switch item.checkbox {
        case .checked: return "☑"
        case .unchecked: return "☐"
        case nil: return defaultMarker
        }
    }

    private mutating func renderListItem(_ item: ListItem, marker: String) -> NSMutableAttributedString {
        let indentUnit: CGFloat = 24
        let headIndent = indentUnit * CGFloat(listDepth)
        let firstLineIndent = headIndent - indentUnit + 8

        let result = NSMutableAttributedString()
        var isFirstBlock = true
        for child in item.children {
            if let paragraph = child as? Paragraph {
                let inline = NSMutableAttributedString()
                if isFirstBlock {
                    inline.append(NSAttributedString(string: marker + "\t", attributes: [
                        .font: MarkdownTheme.bodyFont,
                        .foregroundColor: MarkdownTheme.secondaryTextColor
                    ]))
                }
                for grandchild in paragraph.children {
                    inline.append(visit(grandchild))
                }
                inline.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.bodyFont]))
                applyMultiLineParagraphStyle(to: inline) { isLast in
                    let style = NSMutableParagraphStyle()
                    style.lineHeightMultiple = MarkdownTheme.lineHeightMultiple
                    style.headIndent = headIndent
                    style.firstLineHeadIndent = isFirstBlock ? firstLineIndent : headIndent
                    style.tabStops = [NSTextTab(textAlignment: .left, location: headIndent)]
                    style.defaultTabInterval = headIndent
                    style.paragraphSpacing = isLast ? 6 : 0
                    return style
                }
                result.append(inline)
                isFirstBlock = false
            } else {
                // Nested list, code block, etc. — it renders (and indents)
                // itself when visited.
                result.append(visit(child))
            }
        }
        return result
    }

    // MARK: - Leaf blocks

    mutating func visitParagraph(_ paragraph: Paragraph) -> NSMutableAttributedString {
        let inline = NSMutableAttributedString()
        for child in paragraph.children {
            inline.append(visit(child))
        }
        inline.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.bodyFont]))
        applyMultiLineParagraphStyle(to: inline) { isLast in
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = MarkdownTheme.lineHeightMultiple
            style.paragraphSpacing = isLast ? MarkdownTheme.paragraphSpacing : 0
            return style
        }
        return inline
    }

    mutating func visitHeading(_ heading: Heading) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in heading.children {
            content.append(visit(child))
        }
        let full = NSRange(location: 0, length: content.length)
        content.addAttribute(.font, value: MarkdownTheme.headingFont(level: heading.level), range: full)
        content.addAttribute(.foregroundColor, value: MarkdownTheme.textColor, range: full)
        content.append(NSAttributedString(string: "\n"))

        let spacing = MarkdownTheme.headingSpacing(level: heading.level)
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.15
        style.paragraphSpacing = spacing.after
        content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
        return content
    }

    func visitCodeBlock(_ codeBlock: CodeBlock) -> NSMutableAttributedString {
        var code = codeBlock.code
        if code.hasSuffix("\n") { code.removeLast() }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: MarkdownTheme.codeFont,
            .foregroundColor: MarkdownTheme.textColor,
            .markdownBlockKind: MarkdownBlockKind.codeBlock
        ]
        let result = NSMutableAttributedString(string: code, attributes: attrs)
        result.append(NSAttributedString(string: "\n", attributes: attrs))
        applyMultiLineParagraphStyle(to: result) { isLast in
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = 1.3
            style.headIndent = 14
            style.firstLineHeadIndent = 14
            style.tailIndent = -14
            style.paragraphSpacing = isLast ? MarkdownTheme.paragraphSpacing : 0
            return style
        }
        return result
    }

    func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: "\u{200B}\n", attributes: [
            .font: NSFont.systemFont(ofSize: 2),
            .markdownBlockKind: MarkdownBlockKind.rule
        ])
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = MarkdownTheme.paragraphSpacing
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }

    func visitHTMLBlock(_ html: HTMLBlock) -> NSMutableAttributedString {
        NSMutableAttributedString()
    }

    // MARK: - Tables (plain monospace fallback — good enough for a reader)

    func visitTable(_ table: Markdown.Table) -> NSMutableAttributedString {
        var rows: [[String]] = []
        for child in table.children {
            if let head = child as? Markdown.Table.Head {
                rows.append(head.children.compactMap { ($0 as? Markdown.Table.Cell).map(plainText) })
            } else if let body = child as? Markdown.Table.Body {
                for rowChild in body.children {
                    if let row = rowChild as? Markdown.Table.Row {
                        rows.append(row.children.compactMap { ($0 as? Markdown.Table.Cell).map(plainText) })
                    }
                }
            }
        }
        guard !rows.isEmpty else { return NSMutableAttributedString() }

        let columnCount = rows.map(\.count).max() ?? 0
        var widths = [Int](repeating: 3, count: columnCount)
        for row in rows {
            for (index, cell) in row.enumerated() {
                widths[index] = max(widths[index], cell.count)
            }
        }
        func padded(_ row: [String]) -> String {
            (0..<columnCount).map { index in
                let cell = index < row.count ? row[index] : ""
                return cell.padding(toLength: widths[index], withPad: " ", startingAt: 0)
            }.joined(separator: "  │  ")
        }

        var lines: [String] = [padded(rows[0])]
        lines.append(widths.map { String(repeating: "─", count: $0) }.joined(separator: "──┼──"))
        for row in rows.dropFirst() {
            lines.append(padded(row))
        }

        let text = lines.joined(separator: "\n") + "\n"
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: MarkdownTheme.codeFont,
            .foregroundColor: MarkdownTheme.textColor,
            .markdownBlockKind: MarkdownBlockKind.codeBlock
        ])
        applyMultiLineParagraphStyle(to: result) { isLast in
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = 1.3
            style.headIndent = 14
            style.firstLineHeadIndent = 14
            style.tailIndent = -14
            style.paragraphSpacing = isLast ? MarkdownTheme.paragraphSpacing : 0
            return style
        }
        return result
    }

    // MARK: - Inline

    func visitText(_ text: Markdown.Text) -> NSMutableAttributedString {
        NSMutableAttributedString(string: text.string, attributes: [
            .font: MarkdownTheme.bodyFont,
            .foregroundColor: MarkdownTheme.textColor
        ])
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in emphasis.children { content.append(visit(child)) }
        restyleFonts(in: content) { NSFontManager.shared.convert($0, toHaveTrait: .italicFontMask) }
        return content
    }

    mutating func visitStrong(_ strong: Strong) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in strong.children { content.append(visit(child)) }
        restyleFonts(in: content) { NSFontManager.shared.convert($0, toHaveTrait: .boldFontMask) }
        return content
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in strikethrough.children { content.append(visit(child)) }
        content.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 0, length: content.length)
        )
        return content
    }

    func visitInlineCode(_ inlineCode: InlineCode) -> NSMutableAttributedString {
        NSMutableAttributedString(string: inlineCode.code, attributes: [
            .font: MarkdownTheme.codeFont,
            .foregroundColor: MarkdownTheme.textColor,
            .backgroundColor: MarkdownTheme.codeBackgroundColor
        ])
    }

    mutating func visitLink(_ link: Markdown.Link) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in link.children { content.append(visit(child)) }
        if let destination = link.destination, let url = resolveURL(destination) {
            let full = NSRange(location: 0, length: content.length)
            content.addAttribute(.link, value: url, range: full)
            content.addAttribute(.foregroundColor, value: MarkdownTheme.linkColor, range: full)
            content.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: full)
            content.addAttribute(.cursor, value: NSCursor.pointingHand, range: full)
        }
        return content
    }

    func visitImage(_ image: Markdown.Image) -> NSMutableAttributedString {
        guard let source = image.source, let url = resolveURL(source) else {
            return NSMutableAttributedString()
        }
        guard url.isFileURL, let nsImage = NSImage(contentsOf: url) else {
            // Remote images are intentionally out of scope for a fast,
            // dependency-free reader — show a small clickable link instead.
            let altText = plainText(image)
            let label = altText.isEmpty ? url.absoluteString : altText
            let content = NSMutableAttributedString(string: "🖼 \(label)", attributes: [
                .font: MarkdownTheme.bodyFont,
                .foregroundColor: MarkdownTheme.linkColor,
                .link: url
            ])
            return content
        }
        let attachment = ScaledImageAttachment()
        attachment.image = nsImage
        return NSMutableAttributedString(attachment: attachment)
    }

    func visitLineBreak(_ lineBreak: LineBreak) -> NSMutableAttributedString {
        NSMutableAttributedString(string: "\n", attributes: [.font: MarkdownTheme.bodyFont])
    }

    func visitSoftBreak(_ softBreak: SoftBreak) -> NSMutableAttributedString {
        NSMutableAttributedString(string: " ", attributes: [.font: MarkdownTheme.bodyFont])
    }

    func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSMutableAttributedString {
        NSMutableAttributedString()
    }

    // MARK: - Helpers

    private func restyleFonts(in content: NSMutableAttributedString, transform: (NSFont) -> NSFont) {
        let full = NSRange(location: 0, length: content.length)
        content.enumerateAttribute(.font, in: full) { value, range, _ in
            let base = (value as? NSFont) ?? MarkdownTheme.bodyFont
            content.addAttribute(.font, value: transform(base), range: range)
        }
    }

    /// Applies a distinct paragraph style to every "\n"-delimited line in
    /// `attrString`, so per-line vertical spacing (e.g. only the last line
    /// of a paragraph gets space after it) doesn't leak onto internal hard
    /// breaks.
    private func applyMultiLineParagraphStyle(
        to attrString: NSMutableAttributedString,
        makeStyle: (_ isLast: Bool) -> NSParagraphStyle
    ) {
        let nsString = attrString.string as NSString
        var lineStart = 0
        while true {
            let searchRange = NSRange(location: lineStart, length: nsString.length - lineStart)
            let newlineRange = nsString.range(of: "\n", range: searchRange)
            if newlineRange.location == NSNotFound {
                let lineRange = NSRange(location: lineStart, length: nsString.length - lineStart)
                if lineRange.length > 0 {
                    attrString.addAttribute(.paragraphStyle, value: makeStyle(true), range: lineRange)
                }
                break
            }
            let lineRange = NSRange(location: lineStart, length: newlineRange.location + 1 - lineStart)
            let isLastLine = newlineRange.location + 1 == nsString.length
            attrString.addAttribute(.paragraphStyle, value: makeStyle(isLastLine), range: lineRange)
            lineStart = newlineRange.location + 1
        }
    }

    private func resolveURL(_ raw: String) -> URL? {
        if let url = URL(string: raw), url.scheme != nil {
            return url
        }
        guard let base = baseURL else {
            return URL(string: raw)
        }
        return URL(fileURLWithPath: raw, relativeTo: base.deletingLastPathComponent()).standardizedFileURL
    }
}

private func plainText(_ markup: any Markup) -> String {
    if let text = markup as? Markdown.Text { return text.string }
    if markup is SoftBreak { return " " }
    if markup is LineBreak { return " " }
    return markup.children.map { plainText($0) }.joined()
}
