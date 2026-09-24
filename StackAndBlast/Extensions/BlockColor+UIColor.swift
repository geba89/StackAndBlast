import UIKit

/// UIColor mapping for SpriteKit rendering — the bright "Candy Pop" palette.
extension BlockColor {
    var uiColor: UIColor {
        switch self {
        case .coral:  return UIColor(red: 1.0, green: 0.416, blue: 0.302, alpha: 1) // #FF6A4D
        case .blue:   return UIColor(red: 0.184, green: 0.608, blue: 1.0, alpha: 1) // #2F9BFF
        case .purple: return UIColor(red: 0.608, green: 0.361, blue: 1.0, alpha: 1) // #9B5CFF
        case .green:  return UIColor(red: 0.122, green: 0.82, blue: 0.545, alpha: 1) // #1FD18B
        case .yellow: return UIColor(red: 1.0, green: 0.773, blue: 0.239, alpha: 1) // #FFC53D
        case .pink:   return UIColor(red: 1.0, green: 0.373, blue: 0.659, alpha: 1) // #FF5FA8
        }
    }

    /// Slightly darker variant for inner border/shadow effect.
    var uiColorDark: UIColor {
        uiColor.withAlphaComponent(0.7)
    }
}
