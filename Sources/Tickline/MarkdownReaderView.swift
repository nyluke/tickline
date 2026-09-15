import SwiftUI
import AppKit
import TicklineKit

/// Top-level SwiftUI view shown for an open document.
struct MarkdownReaderView: View {
    let text: String
    let fileURL: URL?

    @ObservedObject private var appearance = AppearanceManager.shared

    var body: some View {
        MarkdownScrollView(text: text, fileURL: fileURL)
            .background(Color(nsColor: .textBackgroundColor))
            .frame(minWidth: 420, minHeight: 320)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        appearance.toggle()
                    } label: {
                        Image(systemName: appearance.mode.icon)
                    }
                    .help("Switch to \(appearance.mode.toggled.label) appearance")
                }
            }
    }
}

/// Bridges the AppKit text system into SwiftUI.
private struct MarkdownScrollView: NSViewRepresentable {
    let text: String
    let fileURL: URL?

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MarkdownTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 32)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        context.coordinator.apply(text: text, fileURL: fileURL, to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownTextView else { return }
        context.coordinator.apply(text: text, fileURL: fileURL, to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private var lastRenderedText: String?

        func apply(text: String, fileURL: URL?, to textView: MarkdownTextView) {
            guard text != lastRenderedText else { return }
            lastRenderedText = text
            var renderer = MarkdownRenderer(baseURL: fileURL)
            textView.textStorage?.setAttributedString(renderer.render(source: text))
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL else { return false }
            NSWorkspace.shared.open(url)
            return true
        }
    }
}
