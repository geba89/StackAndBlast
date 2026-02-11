import UIKit

/// Defines a cosmetic skin theme with 6 block colors and an unlock condition.
struct SkinDefinition {
    let id: String
    let name: String
    /// Maps each BlockColor to its themed UIColor.
    let colors: [BlockColor: UIColor]
    /// Dark variants for stroke/border.
    let darkColors: [BlockColor: UIColor]
    /// Human-readable unlock requirement.
    let unlockCondition: String
    /// Returns true if the player has met the unlock condition.
    let isUnlocked: () -> Bool
}

/// Manages cosmetic skin themes — 6 skins unlocked via gameplay milestones.
@Observable
final class SkinManager {

    static let shared = SkinManager()

    /// All available skins in display order.
    let skins: [SkinDefinition]

    private init() {
        skins = SkinManager.buildSkins()
    }

    // MARK: - Active Skin

    /// The currently selected skin definition.
    var activeSkin: SkinDefinition {
        let id = SettingsManager.shared.activeSkinID
        return skins.first(where: { $0.id == id }) ?? skins[0]
    }

    /// Get the themed color for a block.
    func colorForBlock(_ color: BlockColor) -> UIColor {
        activeSkin.colors[color] ?? color.uiColor
    }

    /// Get the themed dark color for a block border.
    func darkColorForBlock(_ color: BlockColor) -> UIColor {
        activeSkin.darkColors[color] ?? color.uiColorDark
    }

    // MARK: - Skin Definitions

    private static func buildSkins() -> [SkinDefinition] {
        let stats = StatsManager.shared

        return [
            // Default — always unlocked
            SkinDefinition(
                id: "default",
                name: "Default",
                colors: [
                    .coral:  UIColor(red: 0.882, green: 0.439, blue: 0.333, alpha: 1),
                    .blue:   UIColor(red: 0.035, green: 0.518, blue: 0.890, alpha: 1),
                    .purple: UIColor(red: 0.424, green: 0.361, blue: 0.906, alpha: 1),
                    .green:  UIColor(red: 0.0, green: 0.722, blue: 0.580, alpha: 1),
                    .yellow: UIColor(red: 0.992, green: 0.796, blue: 0.431, alpha: 1),
                    .pink:   UIColor(red: 0.992, green: 0.475, blue: 0.659, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.882, green: 0.439, blue: 0.333, alpha: 0.7),
                    .blue:   UIColor(red: 0.035, green: 0.518, blue: 0.890, alpha: 0.7),
                    .purple: UIColor(red: 0.424, green: 0.361, blue: 0.906, alpha: 0.7),
                    .green:  UIColor(red: 0.0, green: 0.722, blue: 0.580, alpha: 0.7),
                    .yellow: UIColor(red: 0.992, green: 0.796, blue: 0.431, alpha: 0.7),
                    .pink:   UIColor(red: 0.992, green: 0.475, blue: 0.659, alpha: 0.7)
                ],
                unlockCondition: "Always unlocked",
                isUnlocked: { true }
            ),

            // Neon — 10 games played
            SkinDefinition(
                id: "neon",
                name: "Neon",
                colors: [
                    .coral:  UIColor(red: 1.0, green: 0.2, blue: 0.4, alpha: 1),
                    .blue:   UIColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 1),
                    .purple: UIColor(red: 0.8, green: 0.2, blue: 1.0, alpha: 1),
                    .green:  UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1),
                    .yellow: UIColor(red: 1.0, green: 1.0, blue: 0.2, alpha: 1),
                    .pink:   UIColor(red: 1.0, green: 0.2, blue: 0.8, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.8, green: 0.1, blue: 0.2, alpha: 1),
                    .blue:   UIColor(red: 0.0, green: 0.6, blue: 0.8, alpha: 1),
                    .purple: UIColor(red: 0.6, green: 0.1, blue: 0.8, alpha: 1),
                    .green:  UIColor(red: 0.1, green: 0.8, blue: 0.2, alpha: 1),
                    .yellow: UIColor(red: 0.8, green: 0.8, blue: 0.1, alpha: 1),
                    .pink:   UIColor(red: 0.8, green: 0.1, blue: 0.6, alpha: 1)
                ],
                unlockCondition: "Play 10 games",
                isUnlocked: { stats.totalGamesPlayed >= 10 }
            ),

            // Pastel — 1K high score
            SkinDefinition(
                id: "pastel",
                name: "Pastel",
                colors: [
                    .coral:  UIColor(red: 1.0, green: 0.71, blue: 0.71, alpha: 1),
                    .blue:   UIColor(red: 0.71, green: 0.83, blue: 1.0, alpha: 1),
                    .purple: UIColor(red: 0.83, green: 0.71, blue: 1.0, alpha: 1),
                    .green:  UIColor(red: 0.71, green: 1.0, blue: 0.83, alpha: 1),
                    .yellow: UIColor(red: 1.0, green: 0.96, blue: 0.71, alpha: 1),
                    .pink:   UIColor(red: 1.0, green: 0.71, blue: 0.88, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.85, green: 0.55, blue: 0.55, alpha: 1),
                    .blue:   UIColor(red: 0.55, green: 0.68, blue: 0.85, alpha: 1),
                    .purple: UIColor(red: 0.68, green: 0.55, blue: 0.85, alpha: 1),
                    .green:  UIColor(red: 0.55, green: 0.85, blue: 0.68, alpha: 1),
                    .yellow: UIColor(red: 0.85, green: 0.80, blue: 0.55, alpha: 1),
                    .pink:   UIColor(red: 0.85, green: 0.55, blue: 0.73, alpha: 1)
                ],
                unlockCondition: "Score 1,000+ in one game",
                isUnlocked: { stats.highestSingleGameScore >= 1000 }
            ),

            // Retro — 100 total blasts
            SkinDefinition(
                id: "retro",
                name: "Retro",
                colors: [
                    .coral:  UIColor(red: 0.8, green: 0.267, blue: 0.0, alpha: 1),
                    .blue:   UIColor(red: 0.0, green: 0.267, blue: 0.8, alpha: 1),
                    .purple: UIColor(red: 0.4, green: 0.0, blue: 0.6, alpha: 1),
                    .green:  UIColor(red: 0.0, green: 0.4, blue: 0.2, alpha: 1),
                    .yellow: UIColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 1),
                    .pink:   UIColor(red: 0.6, green: 0.0, blue: 0.4, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.6, green: 0.15, blue: 0.0, alpha: 1),
                    .blue:   UIColor(red: 0.0, green: 0.15, blue: 0.6, alpha: 1),
                    .purple: UIColor(red: 0.25, green: 0.0, blue: 0.4, alpha: 1),
                    .green:  UIColor(red: 0.0, green: 0.25, blue: 0.1, alpha: 1),
                    .yellow: UIColor(red: 0.6, green: 0.4, blue: 0.0, alpha: 1),
                    .pink:   UIColor(red: 0.4, green: 0.0, blue: 0.25, alpha: 1)
                ],
                unlockCondition: "Trigger 100 blasts",
                isUnlocked: { stats.totalBlasts >= 100 }
            ),

            // Monochrome — 50 games played
            SkinDefinition(
                id: "monochrome",
                name: "Monochrome",
                colors: [
                    .coral:  UIColor(white: 0.88, alpha: 1),
                    .blue:   UIColor(white: 0.69, alpha: 1),
                    .purple: UIColor(white: 0.50, alpha: 1),
                    .green:  UIColor(white: 0.75, alpha: 1),
                    .yellow: UIColor(white: 0.82, alpha: 1),
                    .pink:   UIColor(white: 0.56, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(white: 0.70, alpha: 1),
                    .blue:   UIColor(white: 0.50, alpha: 1),
                    .purple: UIColor(white: 0.35, alpha: 1),
                    .green:  UIColor(white: 0.57, alpha: 1),
                    .yellow: UIColor(white: 0.65, alpha: 1),
                    .pink:   UIColor(white: 0.40, alpha: 1)
                ],
                unlockCondition: "Play 50 games",
                isUnlocked: { stats.totalGamesPlayed >= 50 }
            ),

            // Galaxy — 5K score + 500 blasts
            SkinDefinition(
                id: "galaxy",
                name: "Galaxy",
                colors: [
                    .coral:  UIColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 1),
                    .blue:   UIColor(red: 0.27, green: 0.72, blue: 0.82, alpha: 1),
                    .purple: UIColor(red: 0.867, green: 0.627, blue: 0.867, alpha: 1),
                    .green:  UIColor(red: 0.596, green: 0.847, blue: 0.784, alpha: 1),
                    .yellow: UIColor(red: 0.969, green: 0.863, blue: 0.435, alpha: 1),
                    .pink:   UIColor(red: 1.0, green: 0.412, blue: 0.706, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.8, green: 0.3, blue: 0.45, alpha: 1),
                    .blue:   UIColor(red: 0.15, green: 0.55, blue: 0.65, alpha: 1),
                    .purple: UIColor(red: 0.65, green: 0.45, blue: 0.65, alpha: 1),
                    .green:  UIColor(red: 0.40, green: 0.65, blue: 0.58, alpha: 1),
                    .yellow: UIColor(red: 0.75, green: 0.65, blue: 0.30, alpha: 1),
                    .pink:   UIColor(red: 0.8, green: 0.3, blue: 0.55, alpha: 1)
                ],
                unlockCondition: "Score 5,000+ and trigger 500 blasts",
                isUnlocked: { stats.highestSingleGameScore >= 5000 && stats.totalBlasts >= 500 }
            )
        ]
    }
}
