#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Central place for the visual language of rendered documents, so the
/// renderer stays focused on structure rather than styling.
public enum MarkdownTheme {
    public static let bodySize: CGFloat = 16
    public static let readingWidth: CGFloat = 760
    public static let lineHeightMultiple: CGFloat = 1.5
    public static let paragraphSpacing: CGFloat = 14

    public static var bodyFont: PlatformFont {
        PlatformFont.systemFont(ofSize: bodySize, weight: .regular)
    }

    public static var codeFont: PlatformFont {
        PlatformFont.monospacedSystemFont(ofSize: bodySize - 1.5, weight: .regular)
    }

    public static func headingFont(level: Int) -> PlatformFont {
        let sizes: [Int: CGFloat] = [1: 30, 2: 24, 3: 20, 4: 17, 5: 16, 6: 16]
        let weight: PlatformFont.Weight = level <= 2 ? .bold : .semibold
        return PlatformFont.systemFont(ofSize: sizes[level] ?? bodySize, weight: weight)
    }

    public static func headingSpacing(level: Int) -> (before: CGFloat, after: CGFloat) {
        switch level {
        case 1: return (28, 14)
        case 2: return (22, 10)
        default: return (16, 8)
        }
    }

    public static var textColor: PlatformColor {
        #if canImport(AppKit)
        return .labelColor
        #elseif canImport(UIKit)
        return .label
        #endif
    }

    public static var secondaryTextColor: PlatformColor {
        #if canImport(AppKit)
        return .secondaryLabelColor
        #elseif canImport(UIKit)
        return .secondaryLabel
        #endif
    }

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

    public static var ruleColor: PlatformColor {
        #if canImport(AppKit)
        return .separatorColor
        #elseif canImport(UIKit)
        return .separator
        #endif
    }
}
