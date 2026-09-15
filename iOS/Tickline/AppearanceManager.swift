import SwiftUI
import Combine

enum AppearanceMode: String {
    case light
    case dark

    var toggled: AppearanceMode { self == .light ? .dark : .light }
    var colorScheme: ColorScheme { self == .light ? .light : .dark }
    var label: String { self == .light ? "Light" : "Dark" }
    var icon: String { self == .light ? "sun.max.fill" : "moon.fill" }
}

/// Overrides the app's appearance (independent of the system setting) and
/// persists the choice. Tickline defaults to light mode on first launch.
///
/// Unlike the macOS version, there's nothing imperative to "apply" here —
/// the reader view feeds `mode.colorScheme` into `.preferredColorScheme(_:)`
/// directly, so this class is just published, persisted state.
@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    private static let defaultsKey = "TicklineAppearanceMode"

    @Published var mode: AppearanceMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.defaultsKey) }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let saved = AppearanceMode(rawValue: raw) {
            mode = saved
        } else {
            mode = .light
        }
    }

    func toggle() {
        mode = mode.toggled
    }
}
