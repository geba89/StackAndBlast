import SpriteKit

/// The SpriteKit scene that renders the 9×9 grid, blocks, and blast animations.
final class GameScene: SKScene {

    // MARK: - Constants

    /// Padding around the grid.
    private let gridPadding: CGFloat = 16

    /// Corner radius for block nodes.
    private let blockCornerRadius: CGFloat = 4

    // MARK: - Nodes

    private var gridNode = SKNode()
    private var blockNodes: [UUID: SKShapeNode] = [:]

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.118, green: 0.153, blue: 0.180, alpha: 1) // #1E272E
        setupGrid()
    }

    // MARK: - Grid Setup

    /// Draw the 9×9 grid background with alternating cell shading.
    private func setupGrid() {
        gridNode.removeFromParent()
        gridNode = SKNode()
        addChild(gridNode)

        let cellSize = calculateCellSize()
        let gridOrigin = calculateGridOrigin(cellSize: cellSize)

        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                let x = gridOrigin.x + CGFloat(col) * cellSize
                let y = gridOrigin.y - CGFloat(row) * cellSize // SpriteKit y is inverted

                let cell = SKShapeNode(rectOf: CGSize(width: cellSize - 1, height: cellSize - 1), cornerRadius: 2)
                cell.position = CGPoint(x: x + cellSize / 2, y: y - cellSize / 2)
                cell.strokeColor = .clear

                // Alternating checkerboard pattern (two shades of dark gray)
                let isLight = (row + col) % 2 == 0
                cell.fillColor = isLight
                    ? UIColor(red: 0.176, green: 0.204, blue: 0.216, alpha: 1) // #2D3436
                    : UIColor(red: 0.149, green: 0.173, blue: 0.184, alpha: 1) // slightly darker
                cell.name = "cell_\(row)_\(col)"
                gridNode.addChild(cell)
            }
        }
    }

    // MARK: - Layout Helpers

    /// Calculate the cell size based on the available scene width.
    func calculateCellSize() -> CGFloat {
        let availableWidth = size.width - (gridPadding * 2)
        return availableWidth / CGFloat(GameConstants.gridSize)
    }

    /// Calculate the top-left origin of the grid in scene coordinates.
    func calculateGridOrigin(cellSize: CGFloat) -> CGPoint {
        let gridWidth = cellSize * CGFloat(GameConstants.gridSize)
        let x = (size.width - gridWidth) / 2
        // Place grid in the upper portion of the screen, leaving room for piece tray
        let y = size.height * 0.85
        return CGPoint(x: x, y: y)
    }

    /// Convert a grid position to scene coordinates (center of the cell).
    func scenePosition(for gridPos: GridPosition) -> CGPoint {
        let cellSize = calculateCellSize()
        let origin = calculateGridOrigin(cellSize: cellSize)
        let x = origin.x + CGFloat(gridPos.col) * cellSize + cellSize / 2
        let y = origin.y - CGFloat(gridPos.row) * cellSize - cellSize / 2
        return CGPoint(x: x, y: y)
    }
}
