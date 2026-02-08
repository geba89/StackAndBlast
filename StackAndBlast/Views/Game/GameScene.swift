import SpriteKit

/// The SpriteKit scene that renders the 9×9 grid, blocks, and blast animations.
final class GameScene: SKScene {

    // MARK: - Constants

    /// Padding around the grid.
    private let gridPadding: CGFloat = 16

    /// Corner radius for block nodes.
    private let blockCornerRadius: CGFloat = 4

    // MARK: - Cached Layout

    /// Cached cell size (computed once after scene is presented).
    private(set) var cellSize: CGFloat = 0

    /// Cached grid origin in scene coordinates (top-left corner).
    private(set) var gridOrigin: CGPoint = .zero

    // MARK: - Node Layers

    /// Background grid checkerboard.
    private var gridNode = SKNode()

    /// Layer for block sprites (above grid, below effects).
    private var blocksNode = SKNode()

    /// Active block nodes keyed by Block UUID for O(1) lookup.
    private var blockNodes: [UUID: SKShapeNode] = [:]

    /// Layer for the piece tray at the bottom of the screen.
    private var trayNode = SKNode()

    /// Tray piece container nodes keyed by Piece UUID for hit-testing.
    var trayPieceNodes: [UUID: SKNode] = [:]

    /// Scale factor for tray pieces relative to grid cells.
    private let trayPieceScale: CGFloat = 0.6

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.118, green: 0.153, blue: 0.180, alpha: 1) // #1E272E

        // Cache layout values
        cellSize = calculateCellSize()
        gridOrigin = calculateGridOrigin(cellSize: cellSize)

        setupGrid()

        // Block layer sits above the grid background
        blocksNode.removeFromParent()
        blocksNode = SKNode()
        blocksNode.zPosition = 1
        addChild(blocksNode)

        // Tray layer at the bottom
        trayNode.removeFromParent()
        trayNode = SKNode()
        trayNode.zPosition = 1
        addChild(trayNode)

        setupTrayBackground()
    }

    // MARK: - Public API

    /// Update the visual grid to match the engine's grid state.
    /// Diffs current block nodes against the new grid — adds, removes, or repositions as needed.
    func updateGrid(_ grid: [[Block?]]) {
        // Collect all blocks currently in the new grid
        var newBlockIDs = Set<UUID>()

        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                guard let block = grid[row][col] else { continue }
                newBlockIDs.insert(block.id)

                let targetPosition = scenePosition(for: GridPosition(row: row, col: col))

                if let existingNode = blockNodes[block.id] {
                    // Block already has a node — update position if it moved
                    if existingNode.position != targetPosition {
                        existingNode.position = targetPosition
                    }
                } else {
                    // New block — create a node
                    let node = createBlockNode(color: block.color)
                    node.position = targetPosition
                    blocksNode.addChild(node)
                    blockNodes[block.id] = node
                }
            }
        }

        // Remove nodes for blocks that no longer exist on the grid
        for (id, node) in blockNodes where !newBlockIDs.contains(id) {
            node.removeFromParent()
            blockNodes.removeValue(forKey: id)
        }
    }

    /// Update the piece tray to show the given pieces.
    func updateTray(_ pieces: [Piece]) {
        // Remove old piece nodes
        for (_, node) in trayPieceNodes {
            node.removeFromParent()
        }
        trayPieceNodes.removeAll()

        guard !pieces.isEmpty else { return }

        let trayY = size.height * 0.10
        let trayWidth = size.width - gridPadding * 4
        let slotWidth = trayWidth / CGFloat(pieces.count)
        let startX = (size.width - trayWidth) / 2

        for (index, piece) in pieces.enumerated() {
            let container = SKNode()
            container.name = "tray_piece_\(piece.id)"

            // Calculate piece bounding box for centering
            let minRow = piece.cells.map(\.row).min() ?? 0
            let maxRow = piece.cells.map(\.row).max() ?? 0
            let minCol = piece.cells.map(\.col).min() ?? 0
            let maxCol = piece.cells.map(\.col).max() ?? 0
            let pieceWidth = CGFloat(maxCol - minCol + 1)
            let pieceHeight = CGFloat(maxRow - minRow + 1)

            let miniCellSize = cellSize * trayPieceScale
            let offsetX = -pieceWidth * miniCellSize / 2
            let offsetY = pieceHeight * miniCellSize / 2

            for cell in piece.cells {
                let x = offsetX + CGFloat(cell.col - minCol) * miniCellSize + miniCellSize / 2
                let y = offsetY - CGFloat(cell.row - minRow) * miniCellSize - miniCellSize / 2

                let inset: CGFloat = 1.0
                let blockSize = CGSize(width: miniCellSize - inset * 2, height: miniCellSize - inset * 2)
                let blockNode = SKShapeNode(rectOf: blockSize, cornerRadius: 3)
                blockNode.fillColor = piece.color.uiColor
                blockNode.strokeColor = piece.color.uiColorDark
                blockNode.lineWidth = 0.5
                blockNode.position = CGPoint(x: x, y: y)
                container.addChild(blockNode)
            }

            // Position in the tray slot
            let slotCenterX = startX + slotWidth * (CGFloat(index) + 0.5)
            container.position = CGPoint(x: slotCenterX, y: trayY)

            trayNode.addChild(container)
            trayPieceNodes[piece.id] = container
        }
    }

    // MARK: - Block Node Factory

    /// Create a rounded-rectangle block node with the GDD visual style.
    private func createBlockNode(color: BlockColor) -> SKShapeNode {
        let inset: CGFloat = 1.5 // gap between blocks
        let blockSize = CGSize(width: cellSize - inset * 2, height: cellSize - inset * 2)

        let node = SKShapeNode(rectOf: blockSize, cornerRadius: blockCornerRadius)
        node.fillColor = color.uiColor
        node.strokeColor = color.uiColorDark
        node.lineWidth = 1.0

        // Subtle inner highlight (lighter strip at top) for 3D bevel effect
        let highlightSize = CGSize(width: blockSize.width - 4, height: blockSize.height * 0.3)
        let highlight = SKShapeNode(rectOf: highlightSize, cornerRadius: blockCornerRadius - 1)
        highlight.fillColor = UIColor.white.withAlphaComponent(0.12)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: 0, y: blockSize.height * 0.25)
        node.addChild(highlight)

        return node
    }

    // MARK: - Grid Setup

    /// Draw the 9×9 grid background with alternating cell shading.
    private func setupGrid() {
        gridNode.removeFromParent()
        gridNode = SKNode()
        gridNode.zPosition = 0
        addChild(gridNode)

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
                    : UIColor(red: 0.149, green: 0.173, blue: 0.184, alpha: 1)
                cell.name = "cell_\(row)_\(col)"
                gridNode.addChild(cell)
            }
        }
    }

    // MARK: - Tray Setup

    /// Draw a subtle background pill behind the piece tray area.
    private func setupTrayBackground() {
        let trayY = size.height * 0.10
        let trayWidth = size.width - gridPadding * 2
        let trayHeight: CGFloat = cellSize * 2.5

        let bg = SKShapeNode(rectOf: CGSize(width: trayWidth, height: trayHeight), cornerRadius: 12)
        bg.fillColor = UIColor(red: 0.14, green: 0.17, blue: 0.19, alpha: 1)
        bg.strokeColor = UIColor(red: 0.2, green: 0.23, blue: 0.25, alpha: 1)
        bg.lineWidth = 0.5
        bg.position = CGPoint(x: size.width / 2, y: trayY)
        bg.zPosition = -1
        trayNode.addChild(bg)
    }

    // MARK: - Layout Helpers

    /// Calculate the cell size based on the available scene width.
    private func calculateCellSize() -> CGFloat {
        let availableWidth = size.width - (gridPadding * 2)
        return availableWidth / CGFloat(GameConstants.gridSize)
    }

    /// Calculate the top-left origin of the grid in scene coordinates.
    private func calculateGridOrigin(cellSize: CGFloat) -> CGPoint {
        let gridWidth = cellSize * CGFloat(GameConstants.gridSize)
        let x = (size.width - gridWidth) / 2
        // Place grid in the upper portion of the screen, leaving room for piece tray
        let y = size.height * 0.85
        return CGPoint(x: x, y: y)
    }

    /// Convert a grid position to scene coordinates (center of the cell).
    func scenePosition(for gridPos: GridPosition) -> CGPoint {
        let x = gridOrigin.x + CGFloat(gridPos.col) * cellSize + cellSize / 2
        let y = gridOrigin.y - CGFloat(gridPos.row) * cellSize - cellSize / 2
        return CGPoint(x: x, y: y)
    }

    /// Convert a scene point to a grid position. Returns nil if outside the grid.
    func gridPosition(for point: CGPoint) -> GridPosition? {
        let col = Int((point.x - gridOrigin.x) / cellSize)
        let row = Int((gridOrigin.y - point.y) / cellSize)
        let pos = GridPosition(row: row, col: col)
        return pos.isValid ? pos : nil
    }
}
