#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import Markdown

/// Walks a parsed Markdown tree and builds a styled `NSAttributedString`.
///
/// Architecture note: leaf/standalone block producers (paragraph, heading,
/// code block, thematic break, the table fallback) each terminate
/// themselves with a trailing "\n" that carries their own paragraph style.
/// Pure containers (document, block quote, lists, list items) just
/// concatenate their already-self-terminated children. This keeps every
/// block responsible for its own vertical rhythm.
public struct MarkdownRenderer: MarkupVisitor {
    private let baseURL: URL?
    private var listDepth = 0
    private var quoteDepth = 0
    /// Containers enclosing the block being visited, outermost first.
    private var containers: [MarkdownBlockContext.Container] = []
    private var nextBlockID = 0

    public init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    public mutating func render(source: String) -> NSAttributedString {
        let document = Markdown.Document(parsing: source)
        return visit(document)
    }

    // MARK: - Containers

    public mutating func defaultVisit(_ markup: Markup) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for child in markup.children {
            result.append(visit(child))
        }
        return result
    }

    public mutating func visitDocument(_ document: Markdown.Document) -> NSMutableAttributedString {
        defaultVisit(document)
    }

    public mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSMutableAttributedString {
        quoteDepth += 1
        pushContainer(.blockQuote)
        let inner = NSMutableAttributedString()
        for child in blockQuote.children {
            inner.append(visit(child))
        }
        containers.removeLast()
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

    public mutating func visitUnorderedList(_ list: UnorderedList) -> NSMutableAttributedString {
        listDepth += 1
        pushContainer(.list(ordered: false))
        defer {
            containers.removeLast()
            listDepth -= 1
        }
        let bullets = ["•", "◦", "▪︎"]
        let bullet = bullets[(listDepth - 1) % bullets.count]

        let result = NSMutableAttributedString()
        var number = 1
        for child in list.children {
            guard let item = child as? ListItem else { continue }
            let marker = markerText(for: item, defaultMarker: bullet)
            result.append(renderListItem(item, marker: marker, number: number))
            number += 1
        }
        addSpacingAfterList(to: result)
        return result
    }

    public mutating func visitOrderedList(_ list: OrderedList) -> NSMutableAttributedString {
        listDepth += 1
        pushContainer(.list(ordered: true))
        defer {
            containers.removeLast()
            listDepth -= 1
        }

        let result = NSMutableAttributedString()
        var number = Int(list.startIndex)
        for child in list.children {
            guard let item = child as? ListItem else { continue }
            let marker = markerText(for: item, defaultMarker: "\(number).")
            result.append(renderListItem(item, marker: marker, number: number))
            number += 1
        }
        addSpacingAfterList(to: result)
        return result
    }

    private func markerText(for item: ListItem, defaultMarker: String) -> String {
        switch item.checkbox {
        case .checked: return "☑"
        case .unchecked: return "☐"
        case nil: return defaultMarker
        }
    }

    private mutating func renderListItem(_ item: ListItem, marker: String, number: Int) -> NSMutableAttributedString {
        let isTask = item.checkbox != nil
        pushContainer(.listItem(number: number, isTask: isTask))
        defer { containers.removeLast() }

        let indent = MarkdownTheme.listIndent
        let headIndent = indent * CGFloat(listDepth)
        #if canImport(AppKit)
        // Right-align the marker just left of the text, as browsers do, so
        // "9." and "10." end at the same place.
        let markerPrefix = "\t"
        let firstLineIndent = headIndent - indent
        let tabStops = [
            NSTextTab(textAlignment: .right, location: headIndent - 6),
            NSTextTab(textAlignment: .left, location: headIndent)
        ]
        #elseif canImport(UIKit)
        let markerPrefix = ""
        let firstLineIndent = headIndent - indent + 8
        let tabStops = [NSTextTab(textAlignment: .left, location: headIndent)]
        #endif

        let result = NSMutableAttributedString()
        var isFirstBlock = true
        let children = Array(item.children)
        for (index, child) in children.enumerated() {
            if let paragraph = child as? Paragraph {
                // A paragraph followed by another paragraph or a code block
                // in the same item gets paragraph spacing; one followed by a
                // nested list, or ending the item, doesn't.
                let next = index + 1 < children.count ? children[index + 1] : nil
                let spacingAfter = next == nil || next is ListItemContainer
                    ? MarkdownTheme.listItemSpacing
                    : MarkdownTheme.listParagraphSpacing
                let inline = NSMutableAttributedString()
                if isFirstBlock {
                    var markerAttributes: [NSAttributedString.Key: Any] = [
                        .font: MarkdownTheme.bodyFont,
                        .foregroundColor: MarkdownTheme.secondaryTextColor
                    ]
                    if !isTask {
                        markerAttributes[.markdownListMarker] = true
                    }
                    inline.append(NSAttributedString(string: markerPrefix + marker + "\t", attributes: markerAttributes))
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
                    style.tabStops = tabStops
                    style.defaultTabInterval = headIndent
                    style.paragraphSpacing = isLast ? spacingAfter : 0
                    return style
                }
                tag(inline, as: .paragraph)
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

    public mutating func visitParagraph(_ paragraph: Paragraph) -> NSMutableAttributedString {
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
        tag(inline, as: .paragraph)
        return inline
    }

    public mutating func visitHeading(_ heading: Heading) -> NSMutableAttributedString {
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
        style.lineHeightMultiple = MarkdownTheme.headingLineHeightMultiple
        style.paragraphSpacingBefore = spacing.before
        style.paragraphSpacing = spacing.after
        #if canImport(AppKit)
        if MarkdownTheme.headingHasRule(level: heading.level) {
            // A text block draws the rule across the full column, 0.3em
            // below the text as in VS Code. Its margins take over the
            // paragraph spacing so the rule sits between them.
            let block = NSTextBlock()
            block.setValue(100, type: .percentageValueType, for: .width)
            let fontSize = MarkdownTheme.headingFont(level: heading.level).pointSize
            block.setWidth(0.3 * fontSize, type: .absoluteValueType, for: .padding, edge: .maxY)
            block.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
            block.setBorderColor(MarkdownTheme.ruleColor, for: .maxY)
            block.setWidth(spacing.before, type: .absoluteValueType, for: .margin, edge: .minY)
            block.setWidth(spacing.after, type: .absoluteValueType, for: .margin, edge: .maxY)
            style.textBlocks = [block]
            style.paragraphSpacingBefore = 0
            style.paragraphSpacing = 0
        }
        #endif
        content.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: content.length))
        tag(content, as: .heading(level: heading.level))
        return content
    }

    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> NSMutableAttributedString {
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
        tag(result, as: .codeBlock)
        return result
    }

    public mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: "\u{200B}\n", attributes: [
            .font: PlatformFont.systemFont(ofSize: 2),
            .markdownBlockKind: MarkdownBlockKind.rule
        ])
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = MarkdownTheme.paragraphSpacing
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        tag(result, as: .rule)
        return result
    }

    public func visitHTMLBlock(_ html: HTMLBlock) -> NSMutableAttributedString {
        NSMutableAttributedString()
    }

    // MARK: - Tables

    public mutating func visitTable(_ table: Markdown.Table) -> NSMutableAttributedString {
        var cells: [[Markdown.Table.Cell]] = []
        for child in table.children {
            if let head = child as? Markdown.Table.Head {
                cells.append(head.children.compactMap { $0 as? Markdown.Table.Cell })
            } else if let body = child as? Markdown.Table.Body {
                for rowChild in body.children {
                    if let row = rowChild as? Markdown.Table.Row {
                        cells.append(row.children.compactMap { $0 as? Markdown.Table.Cell })
                    }
                }
            }
        }
        let rows = cells.map { $0.map(plainText) }
        guard !rows.isEmpty else { return NSMutableAttributedString() }

        #if canImport(AppKit)
        let result = renderTextTable(cells, alignments: table.columnAlignments)
        #elseif canImport(UIKit)
        let result = renderGridTable(rows)
        #endif
        tag(result, as: .table(rows: rows))
        return result
    }

    #if canImport(AppKit)
    /// Lays a table out as an AppKit text table, styled like VS Code's
    /// preview: each column as wide as its content (shrinking and wrapping
    /// proportionally when the window is narrower), a bold header with a
    /// heavy rule under it, and a light rule between body rows.
    private mutating func renderTextTable(
        _ cells: [[Markdown.Table.Cell]],
        alignments: [Markdown.Table.ColumnAlignment?]
    ) -> NSMutableAttributedString {
        let columnCount = cells.map(\.count).max() ?? 0

        // Render every cell first so each column can be sized to its content.
        var contents: [[NSMutableAttributedString]] = []
        for (rowIndex, row) in cells.enumerated() {
            var rowContents: [NSMutableAttributedString] = []
            for column in 0..<columnCount {
                let content = NSMutableAttributedString()
                if column < row.count {
                    for child in row[column].children {
                        content.append(visit(child))
                    }
                }
                if rowIndex == 0 {
                    restyleFonts(in: content, transform: platformBoldFont(from:))
                }
                rowContents.append(content)
            }
            contents.append(rowContents)
        }
        let columnWidths = (0..<columnCount).map { column in
            ceil(contents.map { $0[column].size().width }.max() ?? 0) + 1
        }

        let textTable = NSTextTable()
        textTable.numberOfColumns = columnCount
        textTable.collapsesBorders = true

        let result = NSMutableAttributedString()
        for (rowIndex, rowContents) in contents.enumerated() {
            for (column, content) in rowContents.enumerated() {
                let block = NSTextTableBlock(
                    table: textTable,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: column,
                    columnSpan: 1
                )
                // Without a width on the table itself, the automatic layout
                // treats these as preferred column widths.
                block.setValue(columnWidths[column], type: .absoluteValueType, for: .width)
                block.setWidth(5, type: .absoluteValueType, for: .padding, edge: .minY)
                block.setWidth(5, type: .absoluteValueType, for: .padding, edge: .maxY)
                block.setWidth(10, type: .absoluteValueType, for: .padding, edge: .minX)
                block.setWidth(10, type: .absoluteValueType, for: .padding, edge: .maxX)
                if rowIndex == 0 {
                    block.setWidth(1, type: .absoluteValueType, for: .border, edge: .maxY)
                    block.setBorderColor(MarkdownTheme.tableHeaderRuleColor, for: .maxY)
                } else if rowIndex > 1 {
                    block.setWidth(1, type: .absoluteValueType, for: .border, edge: .minY)
                    block.setBorderColor(MarkdownTheme.ruleColor, for: .minY)
                }

                content.append(NSAttributedString(string: "\n", attributes: [.font: MarkdownTheme.bodyFont]))
                let style = NSMutableParagraphStyle()
                style.textBlocks = [block]
                style.lineHeightMultiple = MarkdownTheme.lineHeightMultiple
                // The table's own margin is ignored, so the last row's
                // cells carry the space after the table.
                if rowIndex == contents.count - 1 {
                    style.paragraphSpacing = MarkdownTheme.tableSpacingAfter
                }
                switch column < alignments.count ? alignments[column] : nil {
                case .center: style.alignment = .center
                case .right: style.alignment = .right
                default: style.alignment = .left
                }
                let full = NSRange(location: 0, length: content.length)
                content.addAttribute(.paragraphStyle, value: style, range: full)
                content.addAttribute(.markdownTableRow, value: rowIndex, range: full)
                result.append(content)
            }
        }
        return result
    }
    #elseif canImport(UIKit)
    /// Lays a table out as an aligned monospaced grid inside a code card,
    /// since UIKit has no text tables.
    private func renderGridTable(_ rows: [[String]]) -> NSMutableAttributedString {
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
    #endif

    // MARK: - Inline

    public func visitText(_ text: Markdown.Text) -> NSMutableAttributedString {
        NSMutableAttributedString(string: text.string, attributes: [
            .font: MarkdownTheme.bodyFont,
            .foregroundColor: MarkdownTheme.textColor
        ])
    }

    public mutating func visitEmphasis(_ emphasis: Emphasis) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in emphasis.children { content.append(visit(child)) }
        restyleFonts(in: content, transform: platformItalicFont(from:))
        addInlineStyle(.italic, to: content)
        return content
    }

    public mutating func visitStrong(_ strong: Strong) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in strong.children { content.append(visit(child)) }
        restyleFonts(in: content, transform: platformBoldFont(from:))
        addInlineStyle(.bold, to: content)
        return content
    }

    public mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in strikethrough.children { content.append(visit(child)) }
        content.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 0, length: content.length)
        )
        addInlineStyle(.strikethrough, to: content)
        return content
    }

    public func visitInlineCode(_ inlineCode: InlineCode) -> NSMutableAttributedString {
        NSMutableAttributedString(string: inlineCode.code, attributes: [
            .font: MarkdownTheme.codeFont,
            .foregroundColor: MarkdownTheme.textColor,
            .backgroundColor: MarkdownTheme.codeBackgroundColor,
            .markdownInlineStyle: MarkdownInlineStyle.code
        ])
    }

    public mutating func visitLink(_ link: Markdown.Link) -> NSMutableAttributedString {
        let content = NSMutableAttributedString()
        for child in link.children { content.append(visit(child)) }
        if let destination = link.destination, let url = resolveURL(destination) {
            let full = NSRange(location: 0, length: content.length)
            content.addAttribute(.link, value: url, range: full)
            content.addAttribute(.foregroundColor, value: MarkdownTheme.linkColor, range: full)
            content.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: full)
            #if canImport(AppKit)
            content.addAttribute(.cursor, value: NSCursor.pointingHand, range: full)
            #endif
        }
        return content
    }

    public func visitImage(_ image: Markdown.Image) -> NSMutableAttributedString {
        guard let source = image.source, let url = resolveURL(source) else {
            return NSMutableAttributedString()
        }
        guard url.isFileURL, let platformImage = PlatformImage(fileURL: url) else {
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
        attachment.image = platformImage
        return NSMutableAttributedString(attachment: attachment)
    }

    public func visitLineBreak(_ lineBreak: LineBreak) -> NSMutableAttributedString {
        NSMutableAttributedString(string: "\n", attributes: [.font: MarkdownTheme.bodyFont])
    }

    public func visitSoftBreak(_ softBreak: SoftBreak) -> NSMutableAttributedString {
        NSMutableAttributedString(string: " ", attributes: [.font: MarkdownTheme.bodyFont])
    }

    public func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSMutableAttributedString {
        NSMutableAttributedString()
    }

    // MARK: - Helpers

    private mutating func pushContainer(_ kind: MarkdownBlockContext.ContainerKind) {
        nextBlockID += 1
        containers.append(MarkdownBlockContext.Container(id: nextBlockID, kind: kind))
    }

    /// Records that all of `content` renders one leaf block nested in the
    /// current containers; see `MarkdownBlockContext`.
    private mutating func tag(_ content: NSMutableAttributedString, as leaf: MarkdownBlockContext.Leaf) {
        nextBlockID += 1
        let context = MarkdownBlockContext(id: nextBlockID, leaf: leaf, containers: containers)
        content.addAttribute(.markdownBlockContext, value: context, range: NSRange(location: 0, length: content.length))
    }

    /// Makes sure a whole list is followed by at least
    /// `MarkdownTheme.listSpacingAfter`, whatever its last block is.
    private func addSpacingAfterList(to result: NSMutableAttributedString) {
        guard result.length > 0 else { return }
        // The text system reads paragraph spacing from a paragraph's first
        // character, so restyle the whole last paragraph.
        let lastParagraph = (result.string as NSString).paragraphRange(for: NSRange(location: result.length - 1, length: 0))
        guard let style = result.attribute(.paragraphStyle, at: lastParagraph.location, effectiveRange: nil) as? NSParagraphStyle,
              style.paragraphSpacing < MarkdownTheme.listSpacingAfter,
              let spaced = style.mutableCopy() as? NSMutableParagraphStyle
        else { return }
        spaced.paragraphSpacing = MarkdownTheme.listSpacingAfter
        result.addAttribute(.paragraphStyle, value: spaced, range: lastParagraph)
    }

    private func addInlineStyle(_ style: MarkdownInlineStyle, to content: NSMutableAttributedString) {
        let full = NSRange(location: 0, length: content.length)
        content.enumerateAttribute(.markdownInlineStyle, in: full) { value, range, _ in
            let existing = (value as? MarkdownInlineStyle) ?? []
            content.addAttribute(.markdownInlineStyle, value: existing.union(style), range: range)
        }
    }

    private func restyleFonts(in content: NSMutableAttributedString, transform: (PlatformFont) -> PlatformFont) {
        let full = NSRange(location: 0, length: content.length)
        content.enumerateAttribute(.font, in: full) { value, range, _ in
            let base = (value as? PlatformFont) ?? MarkdownTheme.bodyFont
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
