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

    // MARK: - ViewModel Reference

    /// Bridge to the ViewModel for executing game actions.
    weak var viewModel: GameViewModel?

    // MARK: - Drag State

    /// The piece model currently being dragged.
    private var draggedPiece: Piece?

    /// The visual node following the finger during drag.
    private var draggedPieceNode: SKNode?

    /// Ghost preview nodes showing where the piece will land on the grid.
    private var ghostNodes: [SKShapeNode] = []

    /// The current grid position the dragged piece snaps to.
    private var currentHoverPosition: GridPosition?

    /// Offset from drag node center to cell (0,0) position.
    /// Computed once per drag to align visual position with grid placement.
    private var dragOriginOffset: CGPoint = .zero

    /// Whether animations are playing (blocks touch input).
    var isAnimating: Bool = false

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
        blockNodes.removeAll()

        // Tray layer at the bottom
        trayNode.removeFromParent()
        trayNode = SKNode()
        trayNode.zPosition = 1
        addChild(trayNode)
        trayPieceNodes.removeAll()

        setupTrayBackground()

        // Push current engine state if ViewModel is already wired
        // (handles race between didMove, .onAppear, and .onChange ordering)
        if let vm = viewModel {
            updateGrid(vm.engine.grid)
            updateTray(vm.engine.tray)
        }
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

    // MARK: - Blast Animation System

    /// Animate a full blast sequence with cascading events (GDD section 3.4).
    /// Shows the pre-blast grid, then processes each cascade level in sequence,
    /// and finally displays the resolved grid state.
    func animateBlastSequence(
        events: [BlastEvent],
        preBlastGrid: [[Block?]],
        finalGrid: [[Block?]],
        completion: @escaping () -> Void
    ) {
        // Show the board with all pieces placed (lines are full, about to blast)
        updateGrid(preBlastGrid)

        // Process events sequentially
        animateNextEvent(events: events, index: 0, finalGrid: finalGrid, completion: completion)
    }

    /// Recursively process blast events one at a time.
    private func animateNextEvent(
        events: [BlastEvent],
        index: Int,
        finalGrid: [[Block?]],
        completion: @escaping () -> Void
    ) {
        guard index < events.count else {
            // All blast events animated — show the final resolved grid
            updateGrid(finalGrid)
            completion()
            return
        }

        let event = events[index]

        // Play cascade audio/haptic for chain reactions (level > 0)
        if event.cascadeLevel > 0 {
            AudioManager.shared.playCascade(level: event.cascadeLevel)
            HapticManager.shared.playCascade()
        }

        animateSingleBlast(event: event) { [weak self] in
            // Brief pause between cascade levels
            self?.run(SKAction.wait(forDuration: GameConstants.pushSettleDuration)) {
                self?.animateNextEvent(events: events, index: index + 1,
                                       finalGrid: finalGrid, completion: completion)
            }
        }
    }

    /// Animate one blast event through all phases: detonate → particles → shockwave → swap.
    private func animateSingleBlast(event: BlastEvent, completion: @escaping () -> Void) {
        let allClearedPositions = collectClearedPositions(event: event)

        // Audio: line completion chime as warning before blast
        AudioManager.shared.playLineCompleteChime()

        // Phase 1: DETONATE — flash white, then fade out cleared blocks
        let detonateGroup = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: GameConstants.detonateFlashDuration),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.scale(to: 1.4, duration: 0.15)
            ])
        ])

        // Find nodes to detonate
        var nodesToDetonate: [SKShapeNode] = []
        for (_, node) in blockNodes {
            // Check if this block is at a cleared position
            let nodeGridPos = gridPosition(for: node.position)
            if let pos = nodeGridPos,
               allClearedPositions.contains(pos) {
                nodesToDetonate.append(node)
            }
        }

        // Run detonation on all cleared blocks simultaneously
        let detonateFinished = DispatchGroup()
        for node in nodesToDetonate {
            detonateFinished.enter()
            node.run(detonateGroup) {
                node.removeFromParent()
                detonateFinished.leave()
            }
        }

        // Remove detonated blocks from tracking
        blockNodes = blockNodes.filter { _, node in !nodesToDetonate.contains(node) }

        // After detonation completes, run particles + shockwave + swap
        DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.detonateFlashDuration + 0.15) { [weak self] in
            guard let self else { completion(); return }

            // Audio + haptics for blast
            AudioManager.shared.playBlast()
            HapticManager.shared.playBlast()

            // Phase 2: PARTICLE EXPLOSION
            self.spawnExplosionParticles(at: allClearedPositions, event: event)

            // Phase 3: SCREEN SHAKE
            self.runScreenShake()

            // Phase 3b: SHOCKWAVE RINGS
            self.spawnShockwaves(event: event)

            // Audio for swap
            if !event.swapPairs.isEmpty {
                AudioManager.shared.playSwap()
            }

            // Phase 4: SWAP/PUSH ANIMATIONS
            self.animateDisplacements(event: event) {
                completion()
            }
        }
    }

    /// Collect all grid positions that were cleared by this blast event.
    private func collectClearedPositions(event: BlastEvent) -> Set<GridPosition> {
        var positions = Set<GridPosition>()
        for row in event.clearedRows {
            for col in 0..<GameConstants.gridSize {
                positions.insert(GridPosition(row: row, col: col))
            }
        }
        for col in event.clearedColumns {
            for row in 0..<GameConstants.gridSize {
                positions.insert(GridPosition(row: row, col: col))
            }
        }
        return positions
    }

    /// Spawn particle explosion effects at each cleared cell position.
    private func spawnExplosionParticles(at positions: Set<GridPosition>, event: BlastEvent) {
        for pos in positions {
            let scenePos = scenePosition(for: pos)

            // Create a burst of small colored squares
            for _ in 0..<6 {
                let particle = SKShapeNode(rectOf: CGSize(width: 4, height: 4), cornerRadius: 1)
                particle.fillColor = UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1) // warm orange
                particle.strokeColor = .clear
                particle.position = scenePos
                particle.zPosition = 5
                addChild(particle)

                // Random direction and distance
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 20...60)
                let dx = cos(angle) * distance
                let dy = sin(angle) * distance

                let move = SKAction.moveBy(x: dx, y: dy, duration: 0.3)
                move.timingMode = .easeOut
                let fade = SKAction.fadeOut(withDuration: 0.3)
                let scale = SKAction.scale(to: 0.2, duration: 0.3)

                particle.run(SKAction.group([move, fade, scale])) {
                    particle.removeFromParent()
                }
            }
        }
    }

    /// Run screen shake on the grid node.
    private func runScreenShake() {
        let originalPosition = gridNode.position
        let shakeAction = SKAction.customAction(withDuration: 0.2) { node, elapsed in
            let progress = min(elapsed / 0.2, 1.0) // clamp — elapsed can overshoot duration
            let amplitude: CGFloat = 3.0 * (1.0 - progress)
            node.position = CGPoint(
                x: originalPosition.x + CGFloat.random(in: -amplitude...amplitude),
                y: originalPosition.y + CGFloat.random(in: -amplitude...amplitude)
            )
        }
        let resetPosition = SKAction.move(to: originalPosition, duration: 0.02)
        gridNode.run(SKAction.sequence([shakeAction, resetPosition]))
    }

    /// Spawn shockwave ring effects for cleared rows and columns.
    private func spawnShockwaves(event: BlastEvent) {
        let gridWidth = cellSize * CGFloat(GameConstants.gridSize)

        // Horizontal shockwaves for cleared rows
        for row in event.clearedRows {
            let y = gridOrigin.y - CGFloat(row) * cellSize - cellSize / 2
            let wave = SKShapeNode(rectOf: CGSize(width: gridWidth, height: 2))
            wave.fillColor = UIColor.white.withAlphaComponent(0.4)
            wave.strokeColor = .clear
            wave.position = CGPoint(x: size.width / 2, y: y)
            wave.zPosition = 4
            addChild(wave)

            let expand = SKAction.scaleY(to: 8, duration: GameConstants.shockwaveFadeDuration)
            let fade = SKAction.fadeOut(withDuration: GameConstants.shockwaveFadeDuration)
            wave.run(SKAction.group([expand, fade])) {
                wave.removeFromParent()
            }
        }

        // Vertical shockwaves for cleared columns
        let gridHeight = cellSize * CGFloat(GameConstants.gridSize)
        for col in event.clearedColumns {
            let x = gridOrigin.x + CGFloat(col) * cellSize + cellSize / 2
            let wave = SKShapeNode(rectOf: CGSize(width: 2, height: gridHeight))
            wave.fillColor = UIColor.white.withAlphaComponent(0.4)
            wave.strokeColor = .clear
            wave.position = CGPoint(x: x, y: gridOrigin.y - gridHeight / 2)
            wave.zPosition = 4
            addChild(wave)

            let expand = SKAction.scaleX(to: 8, duration: GameConstants.shockwaveFadeDuration)
            let fade = SKAction.fadeOut(withDuration: GameConstants.shockwaveFadeDuration)
            wave.run(SKAction.group([expand, fade])) {
                wave.removeFromParent()
            }
        }
    }

    /// Animate block displacements from the shockwave push.
    private func animateDisplacements(event: BlastEvent, completion: @escaping () -> Void) {
        guard !event.displacements.isEmpty else {
            completion()
            return
        }

        let animationGroup = DispatchGroup()

        for (blockID, displacement) in event.displacements {
            guard let node = blockNodes[blockID] else { continue }

            let dx = CGFloat(displacement.col) * cellSize
            let dy = -CGFloat(displacement.row) * cellSize // SpriteKit y is inverted

            animationGroup.enter()

            // Check if this block is part of a swap pair for curved arc animation
            let isSwap = event.swapPairs.contains { $0.0 == blockID || $0.1 == blockID }

            if isSwap {
                // Curved arc path for swaps — blocks curve slightly as they pass each other
                let arcHeight: CGFloat = cellSize * 0.4
                let midPoint = CGPoint(
                    x: node.position.x + dx / 2,
                    y: node.position.y + dy / 2 + arcHeight
                )
                let endPoint = CGPoint(x: node.position.x + dx, y: node.position.y + dy)

                let path = CGMutablePath()
                path.move(to: node.position)
                path.addQuadCurve(to: endPoint, control: midPoint)

                let followPath = SKAction.follow(path, asOffset: false, orientToPath: false,
                                                  duration: GameConstants.swapAnimationDuration)
                followPath.timingMode = .easeInEaseOut
                node.run(followPath) { animationGroup.leave() }
            } else {
                // Simple slide for non-swap displacements
                let move = SKAction.moveBy(x: dx, y: dy, duration: GameConstants.swapAnimationDuration)
                move.timingMode = .easeInEaseOut
                node.run(move) { animationGroup.leave() }
            }
        }

        animationGroup.notify(queue: .main) {
            completion()
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimating, let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Hit-test against tray pieces
        for (pieceID, trayNode) in trayPieceNodes {
            // Use a generous hit area around each tray piece
            let trayLocation = touch.location(in: trayNode)
            let hitArea = CGRect(x: -cellSize * 2, y: -cellSize * 2,
                                 width: cellSize * 4, height: cellSize * 4)

            if hitArea.contains(trayLocation),
               let piece = viewModel?.engine.tray.first(where: { $0.id == pieceID }) {
                // Start dragging this piece
                draggedPiece = piece

                // Compute offset from drag node center to cell (0,0)
                // so grid snapping aligns with the visual piece position
                let minCol = piece.cells.map(\.col).min() ?? 0
                let maxCol = piece.cells.map(\.col).max() ?? 0
                let minRow = piece.cells.map(\.row).min() ?? 0
                let maxRow = piece.cells.map(\.row).max() ?? 0
                let pieceWidth = CGFloat(maxCol - minCol + 1)
                let pieceHeight = CGFloat(maxRow - minRow + 1)
                dragOriginOffset = CGPoint(
                    x: -pieceWidth * cellSize / 2 + cellSize / 2,
                    y: pieceHeight * cellSize / 2 - cellSize / 2
                )

                // Create a full-size copy of the piece for dragging
                let dragNode = createDragNode(for: piece)
                // Offset above finger so the piece is visible
                dragNode.position = CGPoint(x: location.x, y: location.y + cellSize * 2)
                dragNode.zPosition = 10
                addChild(dragNode)
                draggedPieceNode = dragNode

                // Fade out the tray version
                trayNode.alpha = 0.3

                viewModel?.beginDrag(piece: piece)
                AudioManager.shared.playPickup(cellCount: piece.cellCount)
                HapticManager.shared.playPickup()
                break
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              let dragNode = draggedPieceNode,
              let piece = draggedPiece else { return }

        let location = touch.location(in: self)

        // Move the drag node above the finger
        dragNode.position = CGPoint(x: location.x, y: location.y + cellSize * 2)

        // Determine which grid cell the piece origin (cell 0,0) snaps to
        // Offset from drag node center to where cell (0,0) visually sits
        let snapPoint = CGPoint(
            x: dragNode.position.x + dragOriginOffset.x,
            y: dragNode.position.y + dragOriginOffset.y
        )
        let newHoverPosition = gridPosition(for: snapPoint)

        if newHoverPosition != currentHoverPosition {
            currentHoverPosition = newHoverPosition
            updateGhostPreview(piece: piece, at: newHoverPosition)
            viewModel?.updateHover(position: newHoverPosition ?? GridPosition(row: -1, col: -1))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let piece = draggedPiece else { return }

        if let hoverPos = currentHoverPosition, viewModel?.engine.canPlace(piece, at: hoverPos) == true {
            // Valid placement — execute it
            viewModel?.endDrag()
        } else {
            // Invalid — bounce piece back to tray
            viewModel?.cancelDrag()
            // Restore tray piece opacity
            if let trayNode = trayPieceNodes[piece.id] {
                trayNode.alpha = 1.0
            }
        }

        cleanupDragState()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let piece = draggedPiece, let trayNode = trayPieceNodes[piece.id] {
            trayNode.alpha = 1.0
        }
        viewModel?.cancelDrag()
        cleanupDragState()
    }

    // MARK: - Drag Helpers

    /// Create a full-size visual copy of a piece for dragging.
    private func createDragNode(for piece: Piece) -> SKNode {
        let container = SKNode()

        // Center the piece around its bounding box
        let minRow = piece.cells.map(\.row).min() ?? 0
        let maxRow = piece.cells.map(\.row).max() ?? 0
        let minCol = piece.cells.map(\.col).min() ?? 0
        let maxCol = piece.cells.map(\.col).max() ?? 0
        let pieceWidth = CGFloat(maxCol - minCol + 1)
        let pieceHeight = CGFloat(maxRow - minRow + 1)
        let offsetX = -pieceWidth * cellSize / 2
        let offsetY = pieceHeight * cellSize / 2

        for cell in piece.cells {
            let x = offsetX + CGFloat(cell.col - minCol) * cellSize + cellSize / 2
            let y = offsetY - CGFloat(cell.row - minRow) * cellSize - cellSize / 2
            let blockNode = createBlockNode(color: piece.color)
            blockNode.position = CGPoint(x: x, y: y)
            container.addChild(blockNode)
        }

        // Slight scale-up while dragging for visual feedback
        container.setScale(1.05)
        container.alpha = 0.9

        return container
    }

    /// Show ghost preview on the grid at the hover position.
    private func updateGhostPreview(piece: Piece, at position: GridPosition?) {
        // Remove old ghosts
        for ghost in ghostNodes {
            ghost.removeFromParent()
        }
        ghostNodes.removeAll()

        guard let origin = position else { return }

        let positions = piece.absolutePositions(at: origin)
        let isValid = positions.allSatisfy {
            $0.isValid && viewModel?.engine.grid[$0.row][$0.col] == nil
        }

        let ghostColor: UIColor = isValid
            ? UIColor.green.withAlphaComponent(0.25)
            : UIColor.red.withAlphaComponent(0.25)

        let borderColor: UIColor = isValid
            ? UIColor.green.withAlphaComponent(0.5)
            : UIColor.red.withAlphaComponent(0.5)

        for pos in positions where pos.isValid {
            let inset: CGFloat = 1.0
            let ghostSize = CGSize(width: cellSize - inset * 2, height: cellSize - inset * 2)
            let ghost = SKShapeNode(rectOf: ghostSize, cornerRadius: blockCornerRadius)
            ghost.fillColor = ghostColor
            ghost.strokeColor = borderColor
            ghost.lineWidth = 1.0
            ghost.position = scenePosition(for: pos)
            ghost.zPosition = 2
            addChild(ghost)
            ghostNodes.append(ghost)
        }
    }

    /// Clean up all drag-related visual state.
    private func cleanupDragState() {
        draggedPieceNode?.removeFromParent()
        draggedPieceNode = nil
        draggedPiece = nil
        currentHoverPosition = nil
        dragOriginOffset = .zero

        for ghost in ghostNodes {
            ghost.removeFromParent()
        }
        ghostNodes.removeAll()
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
