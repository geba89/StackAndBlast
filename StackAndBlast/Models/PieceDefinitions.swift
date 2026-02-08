import Foundation

/// All polyomino shapes and their spawn weights (GDD section 3.2).
///
/// Cell offsets are relative to the piece origin (0,0) at top-left.
enum PieceDefinitions {

    /// A shape template: relative cell offsets + category weight.
    struct Template {
        let name: String
        let cells: [GridPosition]
        let category: Category
    }

    enum Category: CaseIterable {
        case monomino   // 1 cell  — 10% weight
        case domino     // 2 cells — 15% weight
        case triomino   // 3 cells — 30% weight
        case tetromino  // 4 cells — 30% weight
        case pentomino  // 5 cells — 15% weight

        var weight: Double {
            switch self {
            case .monomino:  return 0.10
            case .domino:    return 0.15
            case .triomino:  return 0.30
            case .tetromino: return 0.30
            case .pentomino: return 0.15
            }
        }
    }

    // MARK: - Monominoes

    static let dot = Template(
        name: "dot",
        cells: [GridPosition(row: 0, col: 0)],
        category: .monomino
    )

    // MARK: - Dominoes

    static let dominoH = Template(
        name: "domino_h",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1)],
        category: .domino
    )

    static let dominoV = Template(
        name: "domino_v",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0)],
        category: .domino
    )

    // MARK: - Triominoes

    static let lineH3 = Template(
        name: "line_h3",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 0, col: 2)],
        category: .triomino
    )

    static let lineV3 = Template(
        name: "line_v3",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0), GridPosition(row: 2, col: 0)],
        category: .triomino
    )

    static let lSmallRight = Template(
        name: "l_small_right",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1)],
        category: .triomino
    )

    static let lSmallLeft = Template(
        name: "l_small_left",
        cells: [GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1)],
        category: .triomino
    )

    static let lSmallUpRight = Template(
        name: "l_small_up_right",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 0)],
        category: .triomino
    )

    static let lSmallUpLeft = Template(
        name: "l_small_up_left",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 1)],
        category: .triomino
    )

    // MARK: - Tetrominoes (Tetris set)

    static let lineH4 = Template(
        name: "line_h4",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 0, col: 2), GridPosition(row: 0, col: 3)],
        category: .tetromino
    )

    static let lineV4 = Template(
        name: "line_v4",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0), GridPosition(row: 2, col: 0), GridPosition(row: 3, col: 0)],
        category: .tetromino
    )

    static let square = Template(
        name: "square",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1)],
        category: .tetromino
    )

    static let tUp = Template(
        name: "t_up",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 0, col: 2), GridPosition(row: 1, col: 1)],
        category: .tetromino
    )

    static let tDown = Template(
        name: "t_down",
        cells: [GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1), GridPosition(row: 1, col: 2)],
        category: .tetromino
    )

    static let tLeft = Template(
        name: "t_left",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1), GridPosition(row: 2, col: 0)],
        category: .tetromino
    )

    static let tRight = Template(
        name: "t_right",
        cells: [GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1), GridPosition(row: 2, col: 1)],
        category: .tetromino
    )

    static let lRight = Template(
        name: "l_right",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 0), GridPosition(row: 2, col: 0), GridPosition(row: 2, col: 1)],
        category: .tetromino
    )

    static let lLeft = Template(
        name: "l_left",
        cells: [GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 1), GridPosition(row: 2, col: 0), GridPosition(row: 2, col: 1)],
        category: .tetromino
    )

    static let sShape = Template(
        name: "s_shape",
        cells: [GridPosition(row: 0, col: 1), GridPosition(row: 0, col: 2), GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1)],
        category: .tetromino
    )

    static let zShape = Template(
        name: "z_shape",
        cells: [GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 1), GridPosition(row: 1, col: 1), GridPosition(row: 1, col: 2)],
        category: .tetromino
    )

    // MARK: - Pentominoes (selected subset)

    static let plus = Template(
        name: "plus",
        cells: [
            GridPosition(row: 0, col: 1),
            GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1), GridPosition(row: 1, col: 2),
            GridPosition(row: 2, col: 1)
        ],
        category: .pentomino
    )

    static let uShape = Template(
        name: "u_shape",
        cells: [
            GridPosition(row: 0, col: 0), GridPosition(row: 0, col: 2),
            GridPosition(row: 1, col: 0), GridPosition(row: 1, col: 1), GridPosition(row: 1, col: 2)
        ],
        category: .pentomino
    )

    static let largeLRight = Template(
        name: "large_l_right",
        cells: [
            GridPosition(row: 0, col: 0),
            GridPosition(row: 1, col: 0),
            GridPosition(row: 2, col: 0),
            GridPosition(row: 3, col: 0), GridPosition(row: 3, col: 1)
        ],
        category: .pentomino
    )

    static let largeLLeft = Template(
        name: "large_l_left",
        cells: [
            GridPosition(row: 0, col: 1),
            GridPosition(row: 1, col: 1),
            GridPosition(row: 2, col: 1),
            GridPosition(row: 3, col: 0), GridPosition(row: 3, col: 1)
        ],
        category: .pentomino
    )

    // MARK: - All templates

    static let all: [Template] = [
        // Monominoes
        dot,
        // Dominoes
        dominoH, dominoV,
        // Triominoes
        lineH3, lineV3, lSmallRight, lSmallLeft, lSmallUpRight, lSmallUpLeft,
        // Tetrominoes
        lineH4, lineV4, square, tUp, tDown, tLeft, tRight, lRight, lLeft, sShape, zShape,
        // Pentominoes
        plus, uShape, largeLRight, largeLLeft,
    ]
}
