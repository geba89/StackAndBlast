import UIKit

/// Types of animation effects for animated skins.
enum SkinAnimationType {
    /// Rainbow hue rotation with saturation modulation (Holographic, Prismatic).
    case colorShift
    /// Frost shimmer — brightness pulse with stroke glow and subtle scale (Ice).
    case shimmer
    /// Fire flicker — chaotic multi-frequency brightness with warm hue shifts (Ember, Lava).
    case ember
    /// Electric neon — pulsing glow ring with stroke width animation and flicker (Void).
    case neonPulse
}

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
    /// Coin price to purchase this skin (nil = gameplay unlock only).
    let coinPrice: Int?
    /// Animation effect type (nil = static blocks).
    let animationType: SkinAnimationType?
    /// Custom grid checkerboard light cell color (nil = default dark gray).
    let gridLightColor: UIColor?
    /// Custom grid checkerboard dark cell color (nil = default dark gray).
    let gridDarkColor: UIColor?

    init(id: String, name: String,
         colors: [BlockColor: UIColor], darkColors: [BlockColor: UIColor],
         unlockCondition: String, isUnlocked: @escaping () -> Bool,
         coinPrice: Int? = nil, animationType: SkinAnimationType? = nil,
         gridLightColor: UIColor? = nil, gridDarkColor: UIColor? = nil) {
        self.id = id
        self.name = name
        self.colors = colors
        self.darkColors = darkColors
        self.unlockCondition = unlockCondition
        self.isUnlocked = isUnlocked
        self.coinPrice = coinPrice
        self.animationType = animationType
        self.gridLightColor = gridLightColor
        self.gridDarkColor = gridDarkColor
    }
}

/// Manages cosmetic skin themes — 12 skins unlocked via gameplay milestones, coins, or IAP.
@Observable
final class SkinManager {

    static let shared = SkinManager()

    /// All available skins in display order.
    let skins: [SkinDefinition]

    private let defaults = UserDefaults.standard

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

    // MARK: - Coin Purchase

    /// Purchase a skin with coins. Returns true on success.
    func purchaseSkin(_ skinID: String) -> Bool {
        guard let skin = skins.first(where: { $0.id == skinID }),
              let price = skin.coinPrice,
              CoinManager.shared.spend(price) else { return false }

        defaults.set(true, forKey: "skin_purchased_\(skinID)")
        AnalyticsManager.shared.logSkinUnlocked(skinID: skinID)
        return true
    }

    // MARK: - Skin Definitions

    private static func buildSkins() -> [SkinDefinition] {
        let stats = StatsManager.shared
        let defaults = UserDefaults.standard

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
            ),

            // MARK: - Coin-Purchasable Skins

            // Ocean — calming blues and teals
            SkinDefinition(
                id: "ocean",
                name: "Ocean",
                colors: [
                    .coral:  UIColor(red: 0.10, green: 0.70, blue: 0.80, alpha: 1),
                    .blue:   UIColor(red: 0.00, green: 0.50, blue: 0.85, alpha: 1),
                    .purple: UIColor(red: 0.30, green: 0.40, blue: 0.75, alpha: 1),
                    .green:  UIColor(red: 0.20, green: 0.75, blue: 0.70, alpha: 1),
                    .yellow: UIColor(red: 0.60, green: 0.85, blue: 0.90, alpha: 1),
                    .pink:   UIColor(red: 0.40, green: 0.60, blue: 0.90, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.06, green: 0.50, blue: 0.58, alpha: 1),
                    .blue:   UIColor(red: 0.00, green: 0.35, blue: 0.60, alpha: 1),
                    .purple: UIColor(red: 0.20, green: 0.28, blue: 0.53, alpha: 1),
                    .green:  UIColor(red: 0.14, green: 0.53, blue: 0.50, alpha: 1),
                    .yellow: UIColor(red: 0.42, green: 0.60, blue: 0.63, alpha: 1),
                    .pink:   UIColor(red: 0.28, green: 0.42, blue: 0.63, alpha: 1)
                ],
                unlockCondition: "Purchase for 200 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_ocean") },
                coinPrice: 200
            ),

            // Sunset — warm oranges, reds, pinks
            SkinDefinition(
                id: "sunset",
                name: "Sunset",
                colors: [
                    .coral:  UIColor(red: 0.95, green: 0.35, blue: 0.20, alpha: 1),
                    .blue:   UIColor(red: 0.80, green: 0.25, blue: 0.40, alpha: 1),
                    .purple: UIColor(red: 0.65, green: 0.20, blue: 0.55, alpha: 1),
                    .green:  UIColor(red: 1.00, green: 0.60, blue: 0.20, alpha: 1),
                    .yellow: UIColor(red: 1.00, green: 0.80, blue: 0.30, alpha: 1),
                    .pink:   UIColor(red: 0.95, green: 0.40, blue: 0.50, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.67, green: 0.25, blue: 0.14, alpha: 1),
                    .blue:   UIColor(red: 0.56, green: 0.18, blue: 0.28, alpha: 1),
                    .purple: UIColor(red: 0.46, green: 0.14, blue: 0.39, alpha: 1),
                    .green:  UIColor(red: 0.70, green: 0.42, blue: 0.14, alpha: 1),
                    .yellow: UIColor(red: 0.70, green: 0.56, blue: 0.21, alpha: 1),
                    .pink:   UIColor(red: 0.67, green: 0.28, blue: 0.35, alpha: 1)
                ],
                unlockCondition: "Purchase for 200 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_sunset") },
                coinPrice: 200
            ),

            // Forest — greens and earth tones
            SkinDefinition(
                id: "forest",
                name: "Forest",
                colors: [
                    .coral:  UIColor(red: 0.55, green: 0.35, blue: 0.17, alpha: 1),
                    .blue:   UIColor(red: 0.20, green: 0.55, blue: 0.35, alpha: 1),
                    .purple: UIColor(red: 0.40, green: 0.50, blue: 0.25, alpha: 1),
                    .green:  UIColor(red: 0.15, green: 0.65, blue: 0.30, alpha: 1),
                    .yellow: UIColor(red: 0.75, green: 0.70, blue: 0.30, alpha: 1),
                    .pink:   UIColor(red: 0.60, green: 0.45, blue: 0.30, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.39, green: 0.25, blue: 0.12, alpha: 1),
                    .blue:   UIColor(red: 0.14, green: 0.39, blue: 0.25, alpha: 1),
                    .purple: UIColor(red: 0.28, green: 0.35, blue: 0.18, alpha: 1),
                    .green:  UIColor(red: 0.10, green: 0.46, blue: 0.21, alpha: 1),
                    .yellow: UIColor(red: 0.53, green: 0.49, blue: 0.21, alpha: 1),
                    .pink:   UIColor(red: 0.42, green: 0.32, blue: 0.21, alpha: 1)
                ],
                unlockCondition: "Purchase for 300 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_forest") },
                coinPrice: 300
            ),

            // Candy — bright pinks, magentas, sugary colors
            SkinDefinition(
                id: "candy",
                name: "Candy",
                colors: [
                    .coral:  UIColor(red: 1.00, green: 0.30, blue: 0.50, alpha: 1),
                    .blue:   UIColor(red: 0.50, green: 0.75, blue: 1.00, alpha: 1),
                    .purple: UIColor(red: 0.80, green: 0.40, blue: 0.90, alpha: 1),
                    .green:  UIColor(red: 0.55, green: 0.95, blue: 0.55, alpha: 1),
                    .yellow: UIColor(red: 1.00, green: 0.90, blue: 0.40, alpha: 1),
                    .pink:   UIColor(red: 1.00, green: 0.50, blue: 0.80, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.70, green: 0.21, blue: 0.35, alpha: 1),
                    .blue:   UIColor(red: 0.35, green: 0.53, blue: 0.70, alpha: 1),
                    .purple: UIColor(red: 0.56, green: 0.28, blue: 0.63, alpha: 1),
                    .green:  UIColor(red: 0.39, green: 0.67, blue: 0.39, alpha: 1),
                    .yellow: UIColor(red: 0.70, green: 0.63, blue: 0.28, alpha: 1),
                    .pink:   UIColor(red: 0.70, green: 0.35, blue: 0.56, alpha: 1)
                ],
                unlockCondition: "Purchase for 300 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_candy") },
                coinPrice: 300
            ),

            // Ice — cool whites, light blues, silver (animated: shimmer)
            SkinDefinition(
                id: "ice",
                name: "Ice",
                colors: [
                    .coral:  UIColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 1),
                    .blue:   UIColor(red: 0.60, green: 0.80, blue: 0.95, alpha: 1),
                    .purple: UIColor(red: 0.75, green: 0.78, blue: 0.92, alpha: 1),
                    .green:  UIColor(red: 0.70, green: 0.90, blue: 0.88, alpha: 1),
                    .yellow: UIColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1),
                    .pink:   UIColor(red: 0.82, green: 0.85, blue: 0.95, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.60, green: 0.65, blue: 0.69, alpha: 1),
                    .blue:   UIColor(red: 0.42, green: 0.56, blue: 0.67, alpha: 1),
                    .purple: UIColor(red: 0.53, green: 0.55, blue: 0.65, alpha: 1),
                    .green:  UIColor(red: 0.49, green: 0.63, blue: 0.62, alpha: 1),
                    .yellow: UIColor(red: 0.63, green: 0.65, blue: 0.67, alpha: 1),
                    .pink:   UIColor(red: 0.58, green: 0.60, blue: 0.67, alpha: 1)
                ],
                unlockCondition: "Purchase for 400 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_ice") },
                coinPrice: 400,
                animationType: .shimmer
            ),

            // Holographic — rainbow iridescent (animated: color shift)
            SkinDefinition(
                id: "holographic",
                name: "Holographic",
                colors: [
                    .coral:  UIColor(red: 1.0, green: 0.4, blue: 0.5, alpha: 1),
                    .blue:   UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1),
                    .purple: UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1),
                    .green:  UIColor(red: 0.2, green: 0.9, blue: 0.6, alpha: 1),
                    .yellow: UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1),
                    .pink:   UIColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.7, green: 0.28, blue: 0.35, alpha: 1),
                    .blue:   UIColor(red: 0.21, green: 0.42, blue: 0.70, alpha: 1),
                    .purple: UIColor(red: 0.49, green: 0.21, blue: 0.63, alpha: 1),
                    .green:  UIColor(red: 0.14, green: 0.63, blue: 0.42, alpha: 1),
                    .yellow: UIColor(red: 0.70, green: 0.63, blue: 0.21, alpha: 1),
                    .pink:   UIColor(red: 0.70, green: 0.28, blue: 0.56, alpha: 1)
                ],
                unlockCondition: "Purchase for 500 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_holographic") },
                coinPrice: 500,
                animationType: .colorShift
            ),

            // MARK: - Expanded Skins

            // Lava — hot reds, oranges, deep ember tones
            SkinDefinition(
                id: "lava",
                name: "Lava",
                colors: [
                    .coral:  UIColor(red: 0.95, green: 0.20, blue: 0.10, alpha: 1),
                    .blue:   UIColor(red: 0.85, green: 0.35, blue: 0.05, alpha: 1),
                    .purple: UIColor(red: 0.70, green: 0.15, blue: 0.10, alpha: 1),
                    .green:  UIColor(red: 1.00, green: 0.55, blue: 0.10, alpha: 1),
                    .yellow: UIColor(red: 1.00, green: 0.75, blue: 0.15, alpha: 1),
                    .pink:   UIColor(red: 0.90, green: 0.25, blue: 0.20, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.65, green: 0.12, blue: 0.06, alpha: 1),
                    .blue:   UIColor(red: 0.60, green: 0.22, blue: 0.03, alpha: 1),
                    .purple: UIColor(red: 0.48, green: 0.08, blue: 0.06, alpha: 1),
                    .green:  UIColor(red: 0.70, green: 0.38, blue: 0.06, alpha: 1),
                    .yellow: UIColor(red: 0.70, green: 0.52, blue: 0.10, alpha: 1),
                    .pink:   UIColor(red: 0.63, green: 0.15, blue: 0.12, alpha: 1)
                ],
                unlockCondition: "Purchase for 300 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_lava") },
                coinPrice: 300,
                animationType: .ember,
                gridLightColor: UIColor(red: 0.22, green: 0.10, blue: 0.08, alpha: 1),
                gridDarkColor: UIColor(red: 0.18, green: 0.07, blue: 0.05, alpha: 1)
            ),

            // Arctic — icy blues, frost whites, silver
            SkinDefinition(
                id: "arctic",
                name: "Arctic",
                colors: [
                    .coral:  UIColor(red: 0.70, green: 0.88, blue: 0.95, alpha: 1),
                    .blue:   UIColor(red: 0.45, green: 0.72, blue: 0.92, alpha: 1),
                    .purple: UIColor(red: 0.65, green: 0.70, blue: 0.88, alpha: 1),
                    .green:  UIColor(red: 0.55, green: 0.85, blue: 0.85, alpha: 1),
                    .yellow: UIColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 1),
                    .pink:   UIColor(red: 0.75, green: 0.80, blue: 0.92, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.50, green: 0.65, blue: 0.70, alpha: 1),
                    .blue:   UIColor(red: 0.30, green: 0.50, blue: 0.65, alpha: 1),
                    .purple: UIColor(red: 0.45, green: 0.48, blue: 0.62, alpha: 1),
                    .green:  UIColor(red: 0.38, green: 0.60, blue: 0.60, alpha: 1),
                    .yellow: UIColor(red: 0.60, green: 0.63, blue: 0.67, alpha: 1),
                    .pink:   UIColor(red: 0.52, green: 0.56, blue: 0.65, alpha: 1)
                ],
                unlockCondition: "Purchase for 300 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_arctic") },
                coinPrice: 300,
                gridLightColor: UIColor(red: 0.14, green: 0.18, blue: 0.22, alpha: 1),
                gridDarkColor: UIColor(red: 0.11, green: 0.15, blue: 0.19, alpha: 1)
            ),

            // Sakura — cherry blossom pinks and soft whites
            SkinDefinition(
                id: "sakura",
                name: "Sakura",
                colors: [
                    .coral:  UIColor(red: 1.00, green: 0.72, blue: 0.77, alpha: 1),
                    .blue:   UIColor(red: 0.82, green: 0.70, blue: 0.88, alpha: 1),
                    .purple: UIColor(red: 0.90, green: 0.60, blue: 0.75, alpha: 1),
                    .green:  UIColor(red: 0.75, green: 0.88, blue: 0.75, alpha: 1),
                    .yellow: UIColor(red: 1.00, green: 0.92, blue: 0.82, alpha: 1),
                    .pink:   UIColor(red: 1.00, green: 0.62, blue: 0.72, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.75, green: 0.50, blue: 0.54, alpha: 1),
                    .blue:   UIColor(red: 0.58, green: 0.49, blue: 0.62, alpha: 1),
                    .purple: UIColor(red: 0.63, green: 0.42, blue: 0.53, alpha: 1),
                    .green:  UIColor(red: 0.53, green: 0.62, blue: 0.53, alpha: 1),
                    .yellow: UIColor(red: 0.70, green: 0.65, blue: 0.58, alpha: 1),
                    .pink:   UIColor(red: 0.70, green: 0.43, blue: 0.50, alpha: 1)
                ],
                unlockCondition: "Purchase for 400 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_sakura") },
                coinPrice: 400,
                gridLightColor: UIColor(red: 0.20, green: 0.16, blue: 0.17, alpha: 1),
                gridDarkColor: UIColor(red: 0.17, green: 0.13, blue: 0.14, alpha: 1)
            ),

            // Midnight — deep navy, dark purples, starlight accents
            SkinDefinition(
                id: "midnight",
                name: "Midnight",
                colors: [
                    .coral:  UIColor(red: 0.55, green: 0.35, blue: 0.75, alpha: 1),
                    .blue:   UIColor(red: 0.20, green: 0.30, blue: 0.70, alpha: 1),
                    .purple: UIColor(red: 0.40, green: 0.20, blue: 0.65, alpha: 1),
                    .green:  UIColor(red: 0.25, green: 0.50, blue: 0.65, alpha: 1),
                    .yellow: UIColor(red: 0.80, green: 0.78, blue: 0.55, alpha: 1),
                    .pink:   UIColor(red: 0.60, green: 0.30, blue: 0.58, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.38, green: 0.24, blue: 0.52, alpha: 1),
                    .blue:   UIColor(red: 0.12, green: 0.20, blue: 0.48, alpha: 1),
                    .purple: UIColor(red: 0.28, green: 0.12, blue: 0.45, alpha: 1),
                    .green:  UIColor(red: 0.16, green: 0.35, blue: 0.45, alpha: 1),
                    .yellow: UIColor(red: 0.56, green: 0.54, blue: 0.38, alpha: 1),
                    .pink:   UIColor(red: 0.42, green: 0.20, blue: 0.40, alpha: 1)
                ],
                unlockCondition: "Trigger 200 blasts",
                isUnlocked: { stats.totalBlasts >= 200 },
                gridLightColor: UIColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1),
                gridDarkColor: UIColor(red: 0.07, green: 0.07, blue: 0.14, alpha: 1)
            ),

            // Tropical — bright greens, teals, warm coral
            SkinDefinition(
                id: "tropical",
                name: "Tropical",
                colors: [
                    .coral:  UIColor(red: 1.00, green: 0.50, blue: 0.35, alpha: 1),
                    .blue:   UIColor(red: 0.00, green: 0.75, blue: 0.80, alpha: 1),
                    .purple: UIColor(red: 0.45, green: 0.55, blue: 0.85, alpha: 1),
                    .green:  UIColor(red: 0.10, green: 0.85, blue: 0.45, alpha: 1),
                    .yellow: UIColor(red: 1.00, green: 0.85, blue: 0.20, alpha: 1),
                    .pink:   UIColor(red: 1.00, green: 0.45, blue: 0.60, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.70, green: 0.35, blue: 0.24, alpha: 1),
                    .blue:   UIColor(red: 0.00, green: 0.52, blue: 0.56, alpha: 1),
                    .purple: UIColor(red: 0.32, green: 0.38, blue: 0.60, alpha: 1),
                    .green:  UIColor(red: 0.06, green: 0.60, blue: 0.30, alpha: 1),
                    .yellow: UIColor(red: 0.70, green: 0.60, blue: 0.14, alpha: 1),
                    .pink:   UIColor(red: 0.70, green: 0.32, blue: 0.42, alpha: 1)
                ],
                unlockCondition: "Purchase for 400 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_tropical") },
                coinPrice: 400
            ),

            // Ember — warm amber, charcoal, glowing orange (animated: shimmer)
            SkinDefinition(
                id: "ember",
                name: "Ember",
                colors: [
                    .coral:  UIColor(red: 0.90, green: 0.45, blue: 0.15, alpha: 1),
                    .blue:   UIColor(red: 0.75, green: 0.55, blue: 0.25, alpha: 1),
                    .purple: UIColor(red: 0.60, green: 0.30, blue: 0.20, alpha: 1),
                    .green:  UIColor(red: 0.85, green: 0.65, blue: 0.20, alpha: 1),
                    .yellow: UIColor(red: 1.00, green: 0.80, blue: 0.25, alpha: 1),
                    .pink:   UIColor(red: 0.80, green: 0.40, blue: 0.25, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.63, green: 0.30, blue: 0.10, alpha: 1),
                    .blue:   UIColor(red: 0.52, green: 0.38, blue: 0.16, alpha: 1),
                    .purple: UIColor(red: 0.42, green: 0.20, blue: 0.13, alpha: 1),
                    .green:  UIColor(red: 0.60, green: 0.45, blue: 0.13, alpha: 1),
                    .yellow: UIColor(red: 0.70, green: 0.56, blue: 0.16, alpha: 1),
                    .pink:   UIColor(red: 0.56, green: 0.28, blue: 0.16, alpha: 1)
                ],
                unlockCondition: "Purchase for 500 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_ember") },
                coinPrice: 500,
                animationType: .ember,
                gridLightColor: UIColor(red: 0.20, green: 0.14, blue: 0.08, alpha: 1),
                gridDarkColor: UIColor(red: 0.16, green: 0.10, blue: 0.05, alpha: 1)
            ),

            // Prismatic — full rainbow spectrum (animated: color shift)
            SkinDefinition(
                id: "prismatic",
                name: "Prismatic",
                colors: [
                    .coral:  UIColor(red: 1.00, green: 0.30, blue: 0.30, alpha: 1),
                    .blue:   UIColor(red: 0.20, green: 0.50, blue: 1.00, alpha: 1),
                    .purple: UIColor(red: 0.60, green: 0.20, blue: 0.90, alpha: 1),
                    .green:  UIColor(red: 0.10, green: 0.90, blue: 0.30, alpha: 1),
                    .yellow: UIColor(red: 1.00, green: 0.90, blue: 0.10, alpha: 1),
                    .pink:   UIColor(red: 1.00, green: 0.30, blue: 0.70, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.70, green: 0.20, blue: 0.20, alpha: 1),
                    .blue:   UIColor(red: 0.14, green: 0.35, blue: 0.70, alpha: 1),
                    .purple: UIColor(red: 0.42, green: 0.14, blue: 0.63, alpha: 1),
                    .green:  UIColor(red: 0.06, green: 0.63, blue: 0.20, alpha: 1),
                    .yellow: UIColor(red: 0.70, green: 0.63, blue: 0.06, alpha: 1),
                    .pink:   UIColor(red: 0.70, green: 0.20, blue: 0.49, alpha: 1)
                ],
                unlockCondition: "Purchase for 600 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_prismatic") },
                coinPrice: 600,
                animationType: .colorShift
            ),

            // Void — ultra dark with neon electric accents (animated: shimmer)
            SkinDefinition(
                id: "void",
                name: "Void",
                colors: [
                    .coral:  UIColor(red: 0.90, green: 0.10, blue: 0.30, alpha: 1),
                    .blue:   UIColor(red: 0.10, green: 0.40, blue: 0.90, alpha: 1),
                    .purple: UIColor(red: 0.50, green: 0.10, blue: 0.85, alpha: 1),
                    .green:  UIColor(red: 0.10, green: 0.85, blue: 0.50, alpha: 1),
                    .yellow: UIColor(red: 0.85, green: 0.85, blue: 0.10, alpha: 1),
                    .pink:   UIColor(red: 0.85, green: 0.10, blue: 0.65, alpha: 1)
                ],
                darkColors: [
                    .coral:  UIColor(red: 0.55, green: 0.05, blue: 0.18, alpha: 1),
                    .blue:   UIColor(red: 0.05, green: 0.25, blue: 0.55, alpha: 1),
                    .purple: UIColor(red: 0.30, green: 0.05, blue: 0.52, alpha: 1),
                    .green:  UIColor(red: 0.05, green: 0.52, blue: 0.30, alpha: 1),
                    .yellow: UIColor(red: 0.52, green: 0.52, blue: 0.05, alpha: 1),
                    .pink:   UIColor(red: 0.52, green: 0.05, blue: 0.40, alpha: 1)
                ],
                unlockCondition: "Purchase for 750 coins",
                isUnlocked: { defaults.bool(forKey: "skin_purchased_void") },
                coinPrice: 750,
                animationType: .neonPulse,
                gridLightColor: UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1),
                gridDarkColor: UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)
            )
        ]
    }
}
