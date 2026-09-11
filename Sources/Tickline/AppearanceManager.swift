import AppKit
import Combine

enum AppearanceMode: String {
    case light
    case dark

    var toggled: AppearanceMode { self == .light ? .dark : .light }
    var nsAppearance: NSAppearance? { NSAppearance(named: self == .light ? .aqua : .darkAqua) }
    var label: String { self == .light ? "Light" : "Dark" }
    var icon: String { self == .light ? "sun.max.fill" : "moon.fill" }
}

/// Overrides the app's appearance (independent of the system setting) and
/// persists the choice. Tickline defaults to light mode on first launch.
@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    private static let defaultsKey = "TicklineAppearanceMode"

    @Published var mode: AppearanceMode {
        didSet { apply() }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let saved = AppearanceMode(rawValue: raw) {
            mode = saved
        } else {
            mode = .light
        }
        apply()
    }

    func toggle() {
        mode = mode.toggled
    }

    private func apply() {
        NSApplication.shared.appearance = mode.nsAppearance
        UserDefaults.standard.set(mode.rawValue, forKey: Self.defaultsKey)
    }
}
