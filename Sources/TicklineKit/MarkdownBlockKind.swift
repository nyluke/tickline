import Foundation

/// Marks paragraph ranges that need custom full-width background drawing
/// (a code block card, a block quote's side bar, or a horizontal rule) —
/// things `NSAttributedString.Key.backgroundColor` can't do on its own
/// because it only paints behind glyphs, not the full text container width.
public enum MarkdownBlockKind {
    case codeBlock
    case blockQuote
    case rule
}

public extension NSAttributedString.Key {
    static let markdownBlockKind = NSAttributedString.Key("MarkdownBlockKind")
}
