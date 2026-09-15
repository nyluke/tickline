import SwiftUI
import TicklineKit

@main
struct TicklineApp: App {
    @ObservedObject private var appearance = AppearanceManager.shared

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            MarkdownReaderView(text: file.document.text, fileURL: file.fileURL)
        }
        .windowToolbarStyle(.unifiedCompact)
        .defaultSize(width: 860, height: 920)
        .commands {
            CommandMenu("Appearance") {
                Button("Light") { appearance.mode = .light }
                    .keyboardShortcut("1", modifiers: [.command, .shift])
                Button("Dark") { appearance.mode = .dark }
                    .keyboardShortcut("2", modifiers: [.command, .shift])
            }
        }
    }
}
