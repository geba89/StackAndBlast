import UIKit

/// UIColor mapping for SpriteKit rendering (GDD section 5.1).
extension BlockColor {
    var uiColor: UIColor {
        switch self {
        case .coral:  return UIColor(red: 0.882, green: 0.439, blue: 0.333, alpha: 1) // #E17055
        case .blue:   return UIColor(red: 0.035, green: 0.518, blue: 0.890, alpha: 1) // #0984E3
        case .purple: return UIColor(red: 0.424, green: 0.361, blue: 0.906, alpha: 1) // #6C5CE7
        case .green:  return UIColor(red: 0.0, green: 0.722, blue: 0.580, alpha: 1)   // #00B894
        case .yellow: return UIColor(red: 0.992, green: 0.796, blue: 0.431, alpha: 1) // #FDCB6E
        case .pink:   return UIColor(red: 0.992, green: 0.475, blue: 0.659, alpha: 1) // #FD79A8
        }
    }

    /// Slightly darker variant for inner border/shadow effect.
    var uiColorDark: UIColor {
        uiColor.withAlphaComponent(0.7)
    }
}
