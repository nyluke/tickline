#if canImport(AppKit)
import AppKit

public typealias PlatformFont = NSFont
public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit

public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
#endif

/// Bold/italic emphasis needs a platform-specific way to derive a variant
/// of an existing font, since `NSFontManager` has no UIKit equivalent.
func platformBoldFont(from font: PlatformFont) -> PlatformFont {
    #if canImport(AppKit)
    return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
    #elseif canImport(UIKit)
    guard let descriptor = font.fontDescriptor.withSymbolicTraits(
        font.fontDescriptor.symbolicTraits.union(.traitBold)
    ) else { return font }
    return UIFont(descriptor: descriptor, size: font.pointSize)
    #endif
}

func platformItalicFont(from font: PlatformFont) -> PlatformFont {
    #if canImport(AppKit)
    return NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
    #elseif canImport(UIKit)
    guard let descriptor = font.fontDescriptor.withSymbolicTraits(
        font.fontDescriptor.symbolicTraits.union(.traitItalic)
    ) else { return font }
    return UIFont(descriptor: descriptor, size: font.pointSize)
    #endif
}

extension PlatformImage {
    /// Loads an image from a local file URL, uniformly across platforms.
    convenience init?(fileURL url: URL) {
        #if canImport(AppKit)
        self.init(contentsOf: url)
        #elseif canImport(UIKit)
        self.init(contentsOfFile: url.path)
        #endif
    }
}
