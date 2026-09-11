import SwiftUI

@main
struct TicklineApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            MarkdownReaderView(text: file.document.text, fileURL: file.fileURL)
        }
        .windowToolbarStyle(.unifiedCompact)
    }
}
