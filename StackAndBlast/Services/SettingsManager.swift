import Foundation

/// Persists user preferences via UserDefaults.
/// Manages sound, haptics, colorblind mode, and active skin selection.
@Observable
final class SettingsManager {

    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Settings

    /// Whether game sounds are enabled.
    var isSoundEnabled: Bool {
        didSet { defaults.set(isSoundEnabled, forKey: "isSoundEnabled") }
    }

    /// Whether haptic feedback is enabled.
    var isHapticsEnabled: Bool {
        didSet { defaults.set(isHapticsEnabled, forKey: "isHapticsEnabled") }
    }

    /// Whether colorblind symbols are shown on blocks.
    var isColorblindMode: Bool {
        didSet { defaults.set(isColorblindMode, forKey: "isColorblindMode") }
    }

    /// The ID of the currently selected skin theme.
    var activeSkinID: String {
        didSet { defaults.set(activeSkinID, forKey: "activeSkinID") }
    }

    /// Grid size (8, 9, 10, or 12). Takes effect on next new game.
    var gridSize: Int {
        didSet { defaults.set(gridSize, forKey: "gridSize") }
    }

    // MARK: - Init

    private init() {
        // Load saved values (defaults: sound on, haptics on, colorblind off, default skin)
        let d = UserDefaults.standard
        isSoundEnabled = d.object(forKey: "isSoundEnabled") as? Bool ?? true
        isHapticsEnabled = d.object(forKey: "isHapticsEnabled") as? Bool ?? true
        isColorblindMode = d.bool(forKey: "isColorblindMode")
        activeSkinID = d.string(forKey: "activeSkinID") ?? "default"
        gridSize = d.object(forKey: "gridSize") as? Int ?? 9
    }
}
