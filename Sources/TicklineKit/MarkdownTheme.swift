#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Central place for the visual language of rendered documents, so the
/// renderer stays focused on structure rather than styling.
///
/// The Mac follows VS Code's Markdown preview on a Solarized Light page:
/// 14pt system text on a 22pt line, semibold headings with a rule under
/// the top two levels, tight lists, and ruled tables. iOS keeps its larger
/// 16pt layout.
public enum MarkdownTheme {
    #if canImport(AppKit)
    public static let bodySize: CGFloat = 14
    /// 1.3 × the system font's 17pt natural line height gives a 22pt line.
    public static let lineHeightMultiple: CGFloat = 1.3
    public static let headingLineHeightMultiple: CGFloat = 1.06
    #elseif canImport(UIKit)
    public static let bodySize: CGFloat = 16
    public static let lineHeightMultiple: CGFloat = 1.5
    public static let headingLineHeightMultiple: CGFloat = 1.15
    #endif
    public static let readingWidth: CGFloat = 760
    public static let paragraphSpacing: CGFloat = 14

    public static var bodyFont: PlatformFont {
        PlatformFont.systemFont(ofSize: bodySize, weight: .regular)
    }

    public static var codeFont: PlatformFont {
        PlatformFont.monospacedSystemFont(ofSize: bodySize - 1.5, weight: .regular)
    }

    public static func headingFont(level: Int) -> PlatformFont {
        #if canImport(AppKit)
        let scales: [Int: CGFloat] = [1: 2, 2: 1.5, 3: 1.25, 4: 1, 5: 0.875, 6: 0.85]
        return PlatformFont.systemFont(ofSize: bodySize * (scales[level] ?? 1), weight: .semibold)
        #elseif canImport(UIKit)
        let sizes: [Int: CGFloat] = [1: 30, 2: 24, 3: 20, 4: 17, 5: 16, 6: 16]
        let weight: PlatformFont.Weight = level <= 2 ? .bold : .semibold
        return PlatformFont.systemFont(ofSize: sizes[level] ?? bodySize, weight: weight)
        #endif
    }

    /// CSS `font-family` values matching `bodyFont` and `codeFont`, used
    /// when copying a selection as HTML.
    public static let bodyFontCSS = "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif"
    public static let codeFontCSS = "ui-monospace, 'SF Mono', Menlo, Monaco, Consolas, monospace"

    /// Space above and below a heading. The text system doesn't collapse
    /// adjacent spacing the way CSS margins do, so `before` is what's left
    /// after the preceding paragraph's own spacing.
    public static func headingSpacing(level: Int) -> (before: CGFloat, after: CGFloat) {
        #if canImport(AppKit)
        return (10, 16)
        #elseif canImport(UIKit)
        switch level {
        case 1: return (0, 14)
        case 2: return (0, 10)
        default: return (0, 8)
        }
        #endif
    }

    /// Whether a heading gets a full-width rule underneath it.
    public static func headingHasRule(level: Int) -> Bool {
        #if canImport(AppKit)
        return level <= 2
        #elseif canImport(UIKit)
        return false
        #endif
    }

    // Lists
    #if canImport(AppKit)
    /// Indent per nesting level.
    public static let listIndent: CGFloat = 40
    /// Space after each item, and after a paragraph that's followed by more
    /// blocks in the same item.
    public static let listItemSpacing: CGFloat = 0
    public static let listParagraphSpacing: CGFloat = 14
    /// Space after a whole list.
    public static let listSpacingAfter: CGFloat = 10
    #elseif canImport(UIKit)
    public static let listIndent: CGFloat = 24
    public static let listItemSpacing: CGFloat = 6
    public static let listParagraphSpacing: CGFloat = 6
    public static let listSpacingAfter: CGFloat = 0
    #endif

    /// Space after a table laid out as a real table (the Mac app and copied
    /// HTML; iOS draws tables as a code-style grid).
    public static let tableSpacingAfter: CGFloat = 10

    /// The page color behind the document. On the Mac it's a warm cream
    /// (252, 246, 229) in light mode; dark mode keeps the standard text
    /// background.
    public static var backgroundColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? .textBackgroundColor
                : NSColor(srgbRed: 252 / 255, green: 246 / 255, blue: 229 / 255, alpha: 1)
        }
        #elseif canImport(UIKit)
        return .systemBackground
        #endif
    }

    public static var textColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .labelColor : solarizedText
        }
        #elseif canImport(UIKit)
        return .label
        #endif
    }

    public static var secondaryTextColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .secondaryLabelColor : solarizedText
        }
        #elseif canImport(UIKit)
        return .secondaryLabel
        #endif
    }

    #if canImport(AppKit)
    /// Solarized base00 (#657B83), the text color in the light theme.
    private static let solarizedText = NSColor(srgbRed: 101 / 255, green: 123 / 255, blue: 131 / 255, alpha: 1)
    #endif

    public static var linkColor: PlatformColor {
        #if canImport(AppKit)
        return .linkColor
        #elseif canImport(UIKit)
        return .link
        #endif
    }

    public static var codeBackgroundColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.08)
                : NSColor(white: 0.0, alpha: 0.045)
        }
        #elseif canImport(UIKit)
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.08)
                : UIColor(white: 0.0, alpha: 0.045)
        }
        #endif
    }

    public static var quoteBarColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.35)
                : NSColor(white: 0.0, alpha: 0.25)
        }
        #elseif canImport(UIKit)
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 1.0, alpha: 0.35)
                : UIColor(white: 0.0, alpha: 0.25)
        }
        #endif
    }

    /// Horizontal rules, heading underlines, and lines between table rows.
    public static var ruleColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.18)
                : NSColor(white: 0.0, alpha: 0.18)
        }
        #elseif canImport(UIKit)
        return .separator
        #endif
    }

    #if canImport(AppKit)
    /// The heavier line under a table's header row. (Only the Mac draws
    /// real tables; iOS falls back to a monospaced grid.)
    public static var tableHeaderRuleColor: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.69)
                : NSColor(white: 0.0, alpha: 0.69)
        }
    }
    #endif
}
