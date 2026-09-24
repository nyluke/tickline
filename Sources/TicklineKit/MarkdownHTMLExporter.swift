import Foundation

/// Turns a selection of text built by `MarkdownRenderer` back into HTML for
/// the pasteboard, so pasting into a web app like Gmail keeps headings,
/// lists, quotes, emphasis, links, code, and tables.
///
/// Structure comes from the `.markdownBlockContext` and inline-style
/// attributes the renderer records. Styles are inline because web apps drop
/// `<style>` blocks on paste. Text color and the page background are left
/// to the destination, and rules and tints use their light-mode values
/// whatever the app's appearance, since the paste usually lands on a white
/// page.
public enum MarkdownHTMLExporter {
    public static func html(from text: NSAttributedString, range: NSRange) -> String {
        let range = NSIntersectionRange(range, NSRange(location: 0, length: text.length))
        guard range.length > 0 else { return "" }

        let segments = blockSegments(in: text, range: range)
        let selected = (text.string as NSString).substring(with: range)
        if segments.count == 1, !selected.contains("\n") {
            // A few words from within one block paste as inline text rather
            // than as a paragraph of their own.
            let segment = segments[0]
            return "<span style=\"\(fontCSS(for: segment.context.leaf))\">\(inlineHTML(text, range: segment.range))</span>"
        }

        var html = "<div style=\"font-family: \(MarkdownTheme.bodyFontCSS); font-size: \(px(MarkdownTheme.bodySize)); "
            + "line-height: \(px(lineHeight(of: MarkdownTheme.bodyFont, multiple: MarkdownTheme.lineHeightMultiple)));\">"
        var open: [MarkdownBlockContext.Container] = []
        for segment in segments {
            let containers = segment.context.containers
            var shared = 0
            while shared < open.count, shared < containers.count, open[shared].id == containers[shared].id {
                shared += 1
            }
            for container in open[shared...].reversed() {
                html += closingTag(for: container.kind)
            }
            open.removeSubrange(shared...)
            for index in shared..<containers.count {
                let next = index + 1 < containers.count ? containers[index + 1].kind : nil
                html += openingTag(for: containers[index].kind, next: next)
                open.append(containers[index])
            }
            html += leafHTML(for: segment, in: text)
        }
        for container in open.reversed() {
            html += closingTag(for: container.kind)
        }
        return html + "</div>"
    }

    // MARK: - Blocks

    private struct Segment {
        let context: MarkdownBlockContext
        var range: NSRange
    }

    /// Splits `range` into the selected part of each block it touches.
    private static func blockSegments(in text: NSAttributedString, range: NSRange) -> [Segment] {
        var segments: [Segment] = []
        text.enumerateAttribute(.markdownBlockContext, in: range) { value, runRange, _ in
            let context = (value as? MarkdownBlockContext)
                ?? MarkdownBlockContext(id: -1, leaf: .paragraph, containers: [])
            if let last = segments.last, last.context.id == context.id {
                segments[segments.count - 1].range.length += runRange.length
            } else {
                segments.append(Segment(context: context, range: runRange))
            }
        }
        return segments
    }

    private static func openingTag(
        for kind: MarkdownBlockContext.ContainerKind,
        next: MarkdownBlockContext.ContainerKind?
    ) -> String {
        switch kind {
        case .blockQuote:
            // 6 + 3 + 11 puts the text 20pt in, with the bar where the app draws it.
            return "<blockquote style=\"margin: 0 0 0 6px; padding-left: 11px; border-left: 3px solid #bfbfbf;\">"
        case .list(ordered: false):
            return "<ul style=\"\(listCSS)\">"
        case .list(ordered: true):
            // Start from the first selected item, which may be mid-list.
            var start = ""
            if case .listItem(let number, _) = next, number != 1 {
                start = " start=\"\(number)\""
            }
            return "<ol\(start) style=\"\(listCSS)\">"
        case .listItem(_, isTask: false):
            return "<li>"
        case .listItem(_, isTask: true):
            // The ☐/☑ glyph stays in the item's text in place of a bullet.
            return "<li style=\"list-style-type: none;\">"
        }
    }

    private static var listCSS: String {
        "margin: 0 0 \(px(MarkdownTheme.listSpacingAfter)); padding-left: \(px(MarkdownTheme.listIndent));"
    }

    private static func closingTag(for kind: MarkdownBlockContext.ContainerKind) -> String {
        switch kind {
        case .blockQuote: return "</blockquote>"
        case .list(ordered: false): return "</ul>"
        case .list(ordered: true): return "</ol>"
        case .listItem: return "</li>"
        }
    }

    private static func leafHTML(for segment: Segment, in text: NSAttributedString) -> String {
        switch segment.context.leaf {
        case .paragraph:
            var spacing = MarkdownTheme.paragraphSpacing
            if case .listItem = segment.context.containers.last?.kind {
                spacing = MarkdownTheme.listItemSpacing
            }
            return "<p style=\"margin: 0 0 \(px(spacing));\">\(inlineHTML(text, range: segment.range))</p>"
        case .heading(let level):
            let level = min(max(level, 1), 6)
            let font = MarkdownTheme.headingFont(level: level)
            let spacing = MarkdownTheme.headingSpacing(level: level)
            // CSS margins collapse, so the space above includes what the
            // preceding paragraph would add in the app.
            var style = "\(fontCSS(for: segment.context.leaf)); "
                + "line-height: \(px(lineHeight(of: font, multiple: MarkdownTheme.headingLineHeightMultiple))); "
                + "margin: \(px(MarkdownTheme.paragraphSpacing + spacing.before)) 0 \(px(spacing.after));"
            if MarkdownTheme.headingHasRule(level: level) {
                style += " padding-bottom: 0.3em; border-bottom: 1px solid \(ruleCSS);"
            }
            return "<h\(level) style=\"\(style)\">\(inlineHTML(text, range: segment.range))</h\(level)>"
        case .codeBlock:
            return preformattedHTML(text, range: segment.range)
        case .table(let rows):
            return tableHTML(rows: rows, selecting: selectedTableRows(segment, in: text))
        case .rule:
            return "<hr style=\"border: none; border-top: 1px solid \(ruleCSS); margin: 0 0 \(px(MarkdownTheme.paragraphSpacing));\">"
        }
    }

    private static func preformattedHTML(_ text: NSAttributedString, range: NSRange) -> String {
        let code = (text.string as NSString).substring(with: trimmingTrailingNewline(range, in: text))
        return "<pre style=\"font-family: \(MarkdownTheme.codeFontCSS); font-size: \(px(MarkdownTheme.codeFont.pointSize)); "
            + "line-height: 1.3; white-space: pre-wrap; background-color: #f3f3f3; border-radius: 8px; "
            + "padding: 10px 14px; margin: 0 0 \(px(MarkdownTheme.paragraphSpacing));\">"
            + escape(code)
            + "</pre>"
    }

    /// Copies the header row and body rows in the app's table style: a heavy
    /// rule under the header and light rules between body rows. `selecting`
    /// limits it to the rows the selection touches.
    private static func tableHTML(rows: [[String]], selecting selectedRows: IndexSet?) -> String {
        let columnCount = rows.map(\.count).max() ?? 0
        var html = "<table style=\"border-collapse: collapse; margin: 0 0 \(px(MarkdownTheme.tableSpacingAfter));\">"
        var isFirstBodyRow = true
        for (rowIndex, row) in rows.enumerated() where selectedRows?.contains(rowIndex) ?? true {
            let isHeader = rowIndex == 0
            var style = "text-align: left; vertical-align: top; padding: 5px 10px;"
            if isHeader {
                style += " font-weight: bold; border-bottom: 1px solid #4f4f4f;"
            } else if !isFirstBodyRow {
                style += " border-top: 1px solid \(ruleCSS);"
            }
            let tag = isHeader ? "th" : "td"
            html += "<tr>"
            for column in 0..<columnCount {
                let cell = column < row.count ? row[column] : ""
                html += "<\(tag) style=\"\(style)\">\(escape(cell))</\(tag)>"
            }
            html += "</tr>"
            if !isHeader { isFirstBodyRow = false }
        }
        return html + "</table>"
    }

    /// The rows of a table that `segment` touches, or nil for all of them
    /// when the table isn't laid out by rows (the iOS grid fallback).
    private static func selectedTableRows(_ segment: Segment, in text: NSAttributedString) -> IndexSet? {
        var rows = IndexSet()
        text.enumerateAttribute(.markdownTableRow, in: trimmingTrailingNewline(segment.range, in: text)) { value, _, _ in
            if let row = value as? Int { rows.insert(row) }
        }
        return rows.isEmpty ? nil : rows
    }

    // MARK: - Inline

    private static func inlineHTML(_ text: NSAttributedString, range: NSRange) -> String {
        let nsString = text.string as NSString
        var html = ""
        text.enumerateAttributes(in: trimmingTrailingNewline(range, in: text)) { attributes, runRange, _ in
            if attributes[.markdownListMarker] != nil { return }
            // Skip image attachments; the pasteboard HTML can't reference local files usefully.
            let raw = nsString.substring(with: runRange).replacingOccurrences(of: "\u{FFFC}", with: "")
            guard !raw.isEmpty else { return }

            var piece = escape(raw)
                .replacingOccurrences(of: "\n", with: "<br>")
                .replacingOccurrences(of: "\t", with: " ")
            let style = (attributes[.markdownInlineStyle] as? MarkdownInlineStyle) ?? []
            if style.contains(.code) {
                piece = "<code style=\"font-family: \(MarkdownTheme.codeFontCSS); font-size: \(px(MarkdownTheme.codeFont.pointSize)); "
                    + "background-color: #f3f3f3; padding: 1px 3px; border-radius: 3px;\">\(piece)</code>"
            }
            if style.contains(.strikethrough) { piece = "<s>\(piece)</s>" }
            if style.contains(.italic) { piece = "<em>\(piece)</em>" }
            if style.contains(.bold) { piece = "<strong>\(piece)</strong>" }
            if let href = linkString(attributes[.link]) {
                piece = "<a href=\"\(escape(href))\">\(piece)</a>"
            }
            html += piece
        }
        return html
    }

    private static func fontCSS(for leaf: MarkdownBlockContext.Leaf) -> String {
        switch leaf {
        case .heading(let level):
            let size = MarkdownTheme.headingFont(level: level).pointSize
            return "font-family: \(MarkdownTheme.bodyFontCSS); font-size: \(px(size)); font-weight: 600"
        case .codeBlock:
            return "font-family: \(MarkdownTheme.codeFontCSS); font-size: \(px(MarkdownTheme.codeFont.pointSize))"
        case .paragraph, .table, .rule:
            return "font-family: \(MarkdownTheme.bodyFontCSS); font-size: \(px(MarkdownTheme.bodySize))"
        }
    }

    // MARK: - Helpers

    private static func trimmingTrailingNewline(_ range: NSRange, in text: NSAttributedString) -> NSRange {
        guard range.length > 0,
              (text.string as NSString).character(at: NSMaxRange(range) - 1) == 0x0A
        else { return range }
        return NSRange(location: range.location, length: range.length - 1)
    }

    private static func linkString(_ value: Any?) -> String? {
        switch value {
        case let url as URL: return url.absoluteString
        case let string as String: return string
        default: return nil
        }
    }

    /// Rules and row lines: black at 18% on a white page.
    private static let ruleCSS = "#d1d1d1"

    /// The line height the app gives `font`, in points, for CSS.
    private static func lineHeight(of font: PlatformFont, multiple: CGFloat) -> CGFloat {
        (ceil(font.ascender - font.descender + font.leading) * multiple).rounded()
    }

    private static func px(_ value: CGFloat) -> String {
        String(format: "%gpx", Double(value))
    }

    private static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
