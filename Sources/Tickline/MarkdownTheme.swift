import AppKit

/// Central place for the visual language of rendered documents, so the
/// renderer stays focused on structure rather than styling.
enum MarkdownTheme {
    static let bodySize: CGFloat = 16
    static let readingWidth: CGFloat = 760
    static let lineHeightMultiple: CGFloat = 1.5
    static let paragraphSpacing: CGFloat = 14

    static var bodyFont: NSFont {
        NSFont.systemFont(ofSize: bodySize, weight: .regular)
    }

    static var codeFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: bodySize - 1.5, weight: .regular)
    }

    static func headingFont(level: Int) -> NSFont {
        let sizes: [Int: CGFloat] = [1: 30, 2: 24, 3: 20, 4: 17, 5: 16, 6: 16]
        let weight: NSFont.Weight = level <= 2 ? .bold : .semibold
        return NSFont.systemFont(ofSize: sizes[level] ?? bodySize, weight: weight)
    }

    static func headingSpacing(level: Int) -> (before: CGFloat, after: CGFloat) {
        switch level {
        case 1: return (28, 14)
        case 2: return (22, 10)
        default: return (16, 8)
        }
    }

    static var textColor: NSColor { .labelColor }
    static var secondaryTextColor: NSColor { .secondaryLabelColor }
    static var linkColor: NSColor { .linkColor }
    static var codeBackgroundColor: NSColor { .init(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.08)
            : NSColor(white: 0.0, alpha: 0.045)
    }}
    static var quoteBarColor: NSColor { .tertiaryLabelColor }
    static var ruleColor: NSColor { .separatorColor }
}
