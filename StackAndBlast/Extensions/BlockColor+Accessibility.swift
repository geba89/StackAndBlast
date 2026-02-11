import Foundation

/// Colorblind-accessible Unicode symbols for each block color.
/// When colorblind mode is enabled, these characters are rendered
/// inside each block to distinguish colors by shape.
extension BlockColor {
    var colorblindSymbol: String {
        switch self {
        case .coral:  return "\u{25CF}" // ●  filled circle
        case .blue:   return "\u{25A0}" // ■  filled square
        case .purple: return "\u{25B2}" // ▲  filled triangle
        case .green:  return "\u{25C6}" // ◆  filled diamond
        case .yellow: return "\u{2605}" // ★  filled star
        case .pink:   return "\u{2665}" // ♥  heart
        }
    }
}
