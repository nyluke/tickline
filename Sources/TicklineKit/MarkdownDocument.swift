import SwiftUI
import UniformTypeIdentifiers

public extension UTType {
    static var markdownText: UTType {
        UTType(exportedAs: "net.daringfireball.markdown")
    }
}

/// A read-only Markdown file. Tickline is a viewer, not an editor, so writing
/// is intentionally unsupported.
public struct MarkdownDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.markdownText, .plainText] }

    public var text: String

    public init(text: String = "") {
        self.text = text
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
