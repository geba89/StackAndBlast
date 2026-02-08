import Foundation

/// Generates piece trays using a weighted random bag system (GDD section 3.2).
///
/// Each tray of 3 pieces is drawn from a bag that guarantees at least one piece
/// of 3+ cells to keep the game playable. Difficulty scales by shifting weights
/// toward larger pieces as score increases.
final class PieceGenerator {

    /// Generate a tray of 3 random pieces.
    func generateTray() -> [Piece] {
        var pieces: [Piece] = []

        // Guarantee at least one piece of 3+ cells
        let guaranteed = randomTemplate(minCells: 3)
        pieces.append(pieceFromTemplate(guaranteed))

        // Fill remaining slots with weighted random pieces
        for _ in 1..<GameConstants.piecesPerTray {
            let template = randomTemplate()
            pieces.append(pieceFromTemplate(template))
        }

        return pieces.shuffled()
    }

    // MARK: - Private

    /// Pick a random template, optionally requiring a minimum cell count.
    private func randomTemplate(minCells: Int = 1) -> PieceDefinitions.Template {
        let candidates = PieceDefinitions.all.filter { $0.cells.count >= minCells }
        return weightedRandom(from: candidates)
    }

    /// Weighted random selection based on category spawn weights.
    private func weightedRandom(from templates: [PieceDefinitions.Template]) -> PieceDefinitions.Template {
        let totalWeight = templates.reduce(0.0) { $0 + $1.category.weight }
        var roll = Double.random(in: 0..<totalWeight)

        for template in templates {
            roll -= template.category.weight
            if roll <= 0 {
                return template
            }
        }

        // Fallback (shouldn't reach here)
        return templates.last!
    }

    /// Create a Piece from a template with a random color.
    private func pieceFromTemplate(_ template: PieceDefinitions.Template) -> Piece {
        let color = BlockColor.allCases.randomElement()!
        return Piece(cells: template.cells, color: color)
    }
}
