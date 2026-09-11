import AppKit

/// An image attachment that scales itself down to fit the available line
/// width (and a sane max height), recomputed on every layout pass so images
/// stay well-behaved as the window is resized.
final class ScaledImageAttachment: NSTextAttachment {
    static let maxHeight: CGFloat = 480

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: NSRect,
        glyphPosition position: NSPoint,
        characterIndex charIndex: Int
    ) -> NSRect {
        guard let size = image?.size, size.width > 0, size.height > 0 else {
            return super.attachmentBounds(
                for: textContainer,
                proposedLineFragment: lineFrag,
                glyphPosition: position,
                characterIndex: charIndex
            )
        }
        let maxWidth = max(lineFrag.width, 1)
        var width = min(size.width, maxWidth)
        var height = width * size.height / size.width
        if height > Self.maxHeight {
            height = Self.maxHeight
            width = height * size.width / size.height
        }
        return NSRect(x: 0, y: 0, width: width, height: height)
    }
}
