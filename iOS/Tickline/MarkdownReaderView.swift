import SwiftUI
import UIKit
import TicklineKit

/// Top-level SwiftUI view shown for an open document.
struct MarkdownReaderView: View {
    let text: String
    let fileURL: URL?

    @ObservedObject private var appearance = AppearanceManager.shared

    var body: some View {
        MarkdownScrollView(text: text, fileURL: fileURL)
            .background(Color(uiColor: .systemBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appearance.toggle()
                    } label: {
                        Image(systemName: appearance.mode.icon)
                    }
                    .accessibilityLabel("Switch to \(appearance.mode.toggled.label) appearance")
                }
            }
    }
}

/// Bridges the UIKit text system into SwiftUI. `UITextView` is scrollable
/// on its own, so there's no separate scroll view wrapper to manage here.
private struct MarkdownScrollView: UIViewRepresentable {
    let text: String
    let fileURL: URL?

    func makeUIView(context: Context) -> MarkdownTextView {
        let textView = MarkdownTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 32, left: 8, bottom: 32, right: 8)
        textView.delegate = context.coordinator

        context.coordinator.apply(text: text, fileURL: fileURL, to: textView)
        return textView
    }

    func updateUIView(_ textView: MarkdownTextView, context: Context) {
        context.coordinator.apply(text: text, fileURL: fileURL, to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        private var lastRenderedText: String?

        func apply(text: String, fileURL: URL?, to textView: MarkdownTextView) {
            guard text != lastRenderedText else { return }
            lastRenderedText = text
            var renderer = MarkdownRenderer(baseURL: fileURL)
            textView.textStorage.setAttributedString(renderer.render(source: text))
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith url: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            UIApplication.shared.open(url)
            return false
        }
    }
}
