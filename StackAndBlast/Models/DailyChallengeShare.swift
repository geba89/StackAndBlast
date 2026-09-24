import Foundation

/// Wordle-style, spoiler-free summary of a Daily Challenge run. Everyone played the
/// same pieces, so friends can compare *how* they blasted without giving anything away:
///
///     Stack & Blast Daily 2026-09-24 🥇
///     💥 2,450 · best combo ×3
///     🟦🟦🟪🟥🟩🟨🟦🟧
///     🟩🟩
enum DailyChallengeShare {

    /// Colored squares per line, and the most shown before "+N more blasts".
    static let squaresPerLine = 8
    static let maxSquares = 24

    /// - Parameters:
    ///   - medal: tier emoji (🥉🥈🥇), if the run earned one.
    ///   - blastColors: the color of every regular blast, in the order they happened.
    static func text(dayKey: String, score: Int, bestCombo: Int, medal: String?, blastColors: [BlockColor]) -> String {
        var lines = ["Stack & Blast Daily \(dayKey)" + (medal.map { " " + $0 } ?? "")]

        var stats = "💥 \(score.grouped)"
        if bestCombo >= 2 {
            stats += " · best combo ×\(bestCombo)"
        }
        lines.append(stats)

        let squares = blastColors.prefix(maxSquares).map(\.shareSquare)
        for start in stride(from: 0, to: squares.count, by: squaresPerLine) {
            lines.append(squares[start..<min(start + squaresPerLine, squares.count)].joined())
        }
        if blastColors.count > maxSquares {
            lines.append("+\(blastColors.count - maxSquares) more blasts")
        }
        return lines.joined(separator: "\n")
    }
}

extension BlockColor {
    /// Closest square emoji (there's no pink square, so pink uses red).
    var shareSquare: String {
        switch self {
        case .coral:  return "🟧"
        case .blue:   return "🟦"
        case .purple: return "🟪"
        case .green:  return "🟩"
        case .yellow: return "🟨"
        case .pink:   return "🟥"
        }
    }
}

extension Int {
    /// "2,450" — with the player's own digit grouping.
    var grouped: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}
