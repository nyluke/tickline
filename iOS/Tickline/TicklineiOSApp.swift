import SwiftUI
import TicklineKit

@main
struct TicklineiOSApp: App {
    @ObservedObject private var appearance = AppearanceManager.shared

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            MarkdownReaderView(text: file.document.text, fileURL: file.fileURL)
                .preferredColorScheme(appearance.mode.colorScheme)
        }
    }
}
