import Foundation

// MARK: - Tutorial Lessons

/// One step of the interactive tutorial: a hand-made board, the piece to drop,
/// where to drop it, and what to tell the player before and after the move.
///
/// Every lesson's outcome is checked by `TutorialLessonTests`, so the texts
/// below can't drift away from what actually happens on the board.
struct TutorialLesson {
    let title: String
    /// Shown while the player makes the move.
    let instruction: String
    /// Shown after the move has played out.
    let result: String
    /// The board, drawn with `BoardSketch` letters.
    let board: [String]
    /// The one piece in the tray.
    let piece: Piece
    /// Where the piece must be dropped (the grid cell of its origin).
    let target: GridPosition

    /// Blast goal during the tutorial — small, so each lesson is a single move.
    static let goal = 5

    /// All lessons, in order. Computed so every run gets fresh pieces and blocks.
    static var all: [TutorialLesson] {
        [
            TutorialLesson(
                title: "MAKE A BLAST",
                instruction: "Drag the blue piece onto the glowing cells. When \(goal) blocks of one color touch, they BLAST!",
                result: "Boom! 💥 Touching blocks of the same color form a group. Reach the goal and the group explodes for points.",
                board: [". . . . . . G",
                        ". . . . . . .",
                        ". . . . . . .",
                        ". B B B . . .",
                        ". . . . . . .",
                        ". . . . . . .",
                        "Y . . . . . K"],
                piece: Piece(cells: PieceDefinitions.dominoH.cells, color: .blue),
                target: GridPosition(row: 3, col: 4)
            ),
            TutorialLesson(
                title: "PUSH",
                instruction: "Blasts shove the blocks around them outward. Drop the purple piece and watch the neighbors fly!",
                result: "Blocks next to a blast get pushed one step away — and a block pushed off the edge is destroyed!",
                board: [". . . . . . .",
                        ". . . Y . . .",
                        ". . . Y . . .",
                        "G P P P . . .",
                        ". . . K . . .",
                        ". . . . . . .",
                        ". . . . . . ."],
                piece: Piece(cells: PieceDefinitions.dominoV.cells, color: .purple),
                target: GridPosition(row: 4, col: 2)
            ),
            TutorialLesson(
                title: "CHAIN REACTION",
                instruction: "Blast the coral blocks. The push will slide the lone green block up into the gap…",
                result: "CHAIN! The pushed block completed the green row. Each link in a chain doubles its points: ×2, ×4, ×8…",
                board: [". G G . G G .",
                        ". . . G . . .",
                        ". C C C . . .",
                        ". . . . . . .",
                        ". . . . . . .",
                        ". . . . . . .",
                        ". . . . . . ."],
                piece: Piece(cells: PieceDefinitions.dominoV.cells, color: .coral),
                target: GridPosition(row: 3, col: 2)
            ),
            TutorialLesson(
                title: "POWER-UPS",
                instruction: "Golden pieces in your tray are power-ups. Drop the ★ Color Bomb on the glowing cell.",
                result: "The ★ cleared every pink block — the most common color! Also watch for → Row Blast and ↓ Column Blast.",
                board: [". . . . . . .",
                        ". K . Y . K .",
                        ". B . K . G .",
                        ". K . P . K .",
                        ". C . K . B .",
                        ". . . . . . .",
                        ". . . . . . ."],
                piece: Piece(cells: [GridPosition(row: 0, col: 0)], color: .coral, powerUp: .colorBomb),
                target: GridPosition(row: 5, col: 3)
            ),
        ]
    }
}

// MARK: - Board Sketch

/// Builds boards from little text pictures, one string per row:
///
///     ". . B B ."    '.' = empty · C coral · B blue · P purple · G green · Y yellow · K pink
///
/// Spaces are ignored, so rows can be spaced out for readability.
/// Used by the tutorial lessons below and by the unit tests.
enum BoardSketch {

    static func grid(_ rows: [String]) -> [[Block?]] {
        rows.enumerated().map { rowIndex, line in
            line.filter { $0 != " " }.enumerated().map { colIndex, symbol in
                guard let color = color(for: symbol) else { return nil }
                return Block(color: color, position: GridPosition(row: rowIndex, col: colIndex))
            }
        }
    }

    static func color(for symbol: Character) -> BlockColor? {
        switch symbol {
        case "C": return .coral
        case "B": return .blue
        case "P": return .purple
        case "G": return .green
        case "Y": return .yellow
        case "K": return .pink
        default:  return nil
        }
    }
}
