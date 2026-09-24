import Foundation

/// Records which Markdown block a run of rendered text came from, so any
/// selection of the rendered text can be turned back into structured HTML
/// when it's copied. Every character of a rendered block, including its
/// trailing "\n", carries one of these under `.markdownBlockContext`.
public struct MarkdownBlockContext {
    public enum Leaf {
        case paragraph
        case heading(level: Int)
        case codeBlock
        /// Cell text by row; the first row is the header.
        case table(rows: [[String]])
        case rule
    }

    public enum ContainerKind {
        case blockQuote
        case list(ordered: Bool)
        /// `number` is the item's 1-based position as displayed (its
        /// ordinal in an ordered list). Task items keep their ☐/☑ glyph as
        /// text instead of getting a list bullet.
        case listItem(number: Int, isTask: Bool)
    }

    public struct Container {
        /// Distinguishes two adjacent containers of the same kind, e.g. two
        /// sibling list items.
        public let id: Int
        public let kind: ContainerKind
    }

    /// Unique per rendered block, so the lines of one multi-line block
    /// (a code block, or a paragraph with hard breaks) can be regrouped.
    public let id: Int
    public let leaf: Leaf
    /// Enclosing containers, outermost first.
    public let containers: [Container]
}

/// Inline Markdown formatting applied to a run of rendered text. Recorded
/// explicitly rather than inferred from fonts, since the body font may
/// itself be monospaced.
public struct MarkdownInlineStyle: OptionSet, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let bold = MarkdownInlineStyle(rawValue: 1 << 0)
    public static let italic = MarkdownInlineStyle(rawValue: 1 << 1)
    public static let strikethrough = MarkdownInlineStyle(rawValue: 1 << 2)
    public static let code = MarkdownInlineStyle(rawValue: 1 << 3)
}

public extension NSAttributedString.Key {
    static let markdownBlockContext = NSAttributedString.Key("MarkdownBlockContext")
    static let markdownInlineStyle = NSAttributedString.Key("MarkdownInlineStyle")
    /// Marks a list item's bullet or number (and the tab after it), which
    /// HTML lists draw themselves.
    static let markdownListMarker = NSAttributedString.Key("MarkdownListMarker")
    /// The row index (0 is the header) of a table cell's text, where the
    /// table is laid out as a real table.
    static let markdownTableRow = NSAttributedString.Key("MarkdownTableRow")
}
