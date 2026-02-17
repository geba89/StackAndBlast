import SpriteKit

/// The SpriteKit scene that renders the 9×9 grid, blocks, and blast animations.
final class GameScene: SKScene {

    // MARK: - Constants

    /// Minimum padding around the grid. On iPad where the grid is capped,
    /// the effective padding is larger since the grid doesn't fill the screen.
    private let gridPadding: CGFloat = 16

    /// Corner radius for block nodes.
    private let blockCornerRadius: CGFloat = 4

    // MARK: - Cached Layout

    /// Cached cell size (computed once after scene is presented).
    private(set) var cellSize: CGFloat = 0

    /// Cached grid origin in scene coordinates (top-left corner).
    private(set) var gridOrigin: CGPoint = .zero

    /// Grid size the scene was last laid out for — triggers re-layout on change.
    private var layoutGridSize: Int = 0

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

    /// Last position where a drag trail particle was spawned (throttle particle rate).
    private var lastTrailPosition: CGPoint = .zero

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.118, green: 0.153, blue: 0.180, alpha: 1) // #1E272E
        layoutScene()
    }

    /// Called by SpriteKit when the scene's size changes (e.g. `.resizeFill` adapting
    /// to the actual device screen). Recalculates all layout to fit the new dimensions.
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        // Only re-layout if we're already presented (didMove has run)
        guard scene != nil else { return }
        layoutScene()
    }

    /// Shared layout setup — rebuilds grid, blocks, and tray for the current scene size.
    private func layoutScene() {
        // Cache layout values
        layoutGridSize = GameConstants.gridSize
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

        // Start ambient particles for animated skins
        startAmbientParticles()

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
        // Re-layout if grid size changed (e.g. settings changed between games)
        if GameConstants.gridSize != layoutGridSize {
            layoutScene()
        }

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
                    // New block — create a node (with power-up if present)
                    let node = createBlockNode(color: block.color, powerUp: block.powerUp)
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

        let trayY = trayCenterY
        let gridWidth = cellSize * CGFloat(GameConstants.gridSize)
        let trayWidth = gridWidth + gridPadding * 2
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
                blockNode.position = CGPoint(x: x, y: y)

                if let powerUp = piece.powerUp {
                    // Power-up pieces get a golden background with pulsing icon
                    blockNode.fillColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1)
                    blockNode.strokeColor = UIColor(red: 0.65, green: 0.50, blue: 0.10, alpha: 1)
                    blockNode.lineWidth = 1.0

                    let label = SKLabelNode(text: powerUp.symbol)
                    label.fontSize = blockSize.width * 0.6
                    label.fontColor = .white
                    label.verticalAlignmentMode = .center
                    label.horizontalAlignmentMode = .center
                    label.zPosition = 1
                    blockNode.addChild(label)

                    let pulse = SKAction.sequence([
                        SKAction.scale(to: 1.1, duration: 0.5),
                        SKAction.scale(to: 0.95, duration: 0.5)
                    ])
                    blockNode.run(SKAction.repeatForever(pulse))
                } else {
                    blockNode.fillColor = SkinManager.shared.colorForBlock(piece.color)
                    blockNode.strokeColor = SkinManager.shared.darkColorForBlock(piece.color)
                    blockNode.lineWidth = 0.5

                    // Colorblind symbol in tray pieces
                    if SettingsManager.shared.isColorblindMode {
                        let label = SKLabelNode(text: piece.color.colorblindSymbol)
                        label.fontSize = blockSize.width * 0.5
                        label.fontName = "HelveticaNeue-Bold"
                        label.fontColor = .white
                        label.verticalAlignmentMode = .center
                        label.horizontalAlignmentMode = .center
                        label.zPosition = 1
                        blockNode.addChild(label)
                    }
                }

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

    /// Create a rounded-rectangle block node with skinned colors and colorblind symbols.
    private func createBlockNode(color: BlockColor, powerUp: PowerUpType? = nil) -> SKShapeNode {
        let inset: CGFloat = 1.5 // gap between blocks
        let bSize = CGSize(width: cellSize - inset * 2, height: cellSize - inset * 2)

        let node = SKShapeNode(rectOf: bSize, cornerRadius: blockCornerRadius)
        // Use skinned colors instead of raw BlockColor
        node.fillColor = SkinManager.shared.colorForBlock(color)
        node.strokeColor = SkinManager.shared.darkColorForBlock(color)
        node.lineWidth = 1.0

        // Subtle inner highlight (lighter strip at top) for 3D bevel effect
        let highlightSize = CGSize(width: bSize.width - 4, height: bSize.height * 0.3)
        let highlight = SKShapeNode(rectOf: highlightSize, cornerRadius: blockCornerRadius - 1)
        highlight.fillColor = UIColor.white.withAlphaComponent(0.12)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: 0, y: bSize.height * 0.25)
        node.addChild(highlight)

        // Colorblind symbol overlay
        if SettingsManager.shared.isColorblindMode {
            let label = SKLabelNode(text: color.colorblindSymbol)
            label.fontSize = bSize.width * 0.5
            label.fontName = "HelveticaNeue-Bold"
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 1
            label.name = "colorblind_symbol"
            node.addChild(label)
        }

        // Power-up icon overlay with pulsing animation
        if let pu = powerUp {
            let puLabel = SKLabelNode(text: pu.symbol)
            puLabel.fontSize = bSize.width * 0.55
            puLabel.fontColor = .white
            puLabel.verticalAlignmentMode = .center
            puLabel.horizontalAlignmentMode = .center
            puLabel.zPosition = 2
            puLabel.name = "powerup_icon"
            node.addChild(puLabel)

            // Pulsing glow effect
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.5),
                SKAction.scale(to: 0.9, duration: 0.5)
            ])
            puLabel.run(SKAction.repeatForever(pulse))
        }

        // Animated skin effects
        if let animationType = SkinManager.shared.activeSkin.animationType {
            applySkinAnimation(to: node, blockColor: color, type: animationType)
        }

        return node
    }

    /// Apply a continuous animation effect to a block node for animated skins.
    /// Only modifies fill/stroke color — scene-level ambient particles are handled separately.
    private func applySkinAnimation(to node: SKShapeNode, blockColor: BlockColor, type: SkinAnimationType) {
        let baseColor = SkinManager.shared.colorForBlock(blockColor)
        let darkColor = SkinManager.shared.darkColorForBlock(blockColor)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        baseColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        var dHue: CGFloat = 0, dSat: CGFloat = 0, dBri: CGFloat = 0, dAlpha: CGFloat = 0
        darkColor.getHue(&dHue, saturation: &dSat, brightness: &dBri, alpha: &dAlpha)

        // Randomize phase offset per block so they don't all animate in lockstep
        let phaseOffset = CGFloat.random(in: 0...(.pi * 2))

        switch type {
        case .shimmer:
            // Smooth brightness wave with secondary sparkle overlay
            let duration: TimeInterval = 2.0
            let shimmer = SKAction.customAction(withDuration: duration) { node, elapsed in
                guard let shape = node as? SKShapeNode else { return }
                let t = (elapsed / CGFloat(duration)) * .pi * 2 + phaseOffset
                let briFactor = 0.85 + 0.2 * sin(t)
                let sparkle = 0.05 * sin(t * 3.7 + 1.2)
                let newBri = min((bri * briFactor) + sparkle, 1.0)
                shape.fillColor = UIColor(hue: hue, saturation: sat * (0.9 + 0.1 * sin(t * 0.5)), brightness: newBri, alpha: alpha)
                let strokeBri = min(dBri * (1.0 + 0.3 * sin(t)), 1.0)
                shape.strokeColor = UIColor(hue: dHue, saturation: dSat, brightness: strokeBri, alpha: dAlpha)
            }
            node.run(SKAction.repeatForever(shimmer), withKey: "skinAnim")

        case .colorShift:
            // Gentle iridescent sheen — hue shifts ±8% so colors stay recognizable
            let duration: TimeInterval = 4.0
            let shift = SKAction.customAction(withDuration: duration) { node, elapsed in
                guard let shape = node as? SKShapeNode else { return }
                let t = (elapsed / CGFloat(duration)) * .pi * 2 + phaseOffset
                // Small oscillating hue shift (±0.08) keeps colors distinguishable
                let hueShift = 0.08 * sin(t)
                let newHue = (hue + hueShift).truncatingRemainder(dividingBy: 1.0)
                let newSat = sat * (0.9 + 0.1 * sin(t * 1.5))
                let newBri = min(bri * (0.92 + 0.12 * sin(t * 0.7)), 1.0)
                shape.fillColor = UIColor(hue: newHue, saturation: newSat, brightness: newBri, alpha: alpha)
                shape.strokeColor = UIColor(hue: newHue, saturation: min(newSat * 1.1, 1.0), brightness: newBri * 0.7, alpha: dAlpha)
            }
            node.run(SKAction.repeatForever(shift), withKey: "skinAnim")

        case .ember:
            // Chaotic multi-frequency fire flicker + warm hue drift
            let duration: TimeInterval = 3.0
            let freq2 = CGFloat.random(in: 2.3...3.1)
            let freq3 = CGFloat.random(in: 4.5...6.0)
            let ember = SKAction.customAction(withDuration: duration) { node, elapsed in
                guard let shape = node as? SKShapeNode else { return }
                let t = (elapsed / CGFloat(duration)) * .pi * 2 + phaseOffset
                let flicker1 = sin(t)
                let flicker2 = 0.4 * sin(t * freq2 + 0.8)
                let flicker3 = 0.2 * sin(t * freq3 + 2.1)
                let combined = (flicker1 + flicker2 + flicker3) / 1.6
                let newBri = min(bri * (0.8 + 0.25 * combined), 1.0)
                let hueDrift = 0.03 * max(combined, 0)
                let newHue = (hue + hueDrift).truncatingRemainder(dividingBy: 1.0)
                shape.fillColor = UIColor(hue: newHue, saturation: sat, brightness: newBri, alpha: alpha)
                let strokeBri = min(dBri * (0.9 + 0.4 * max(combined, 0)), 1.0)
                shape.strokeColor = UIColor(hue: min(dHue + 0.02, 1.0), saturation: dSat, brightness: strokeBri, alpha: dAlpha)
            }
            node.run(SKAction.repeatForever(ember), withKey: "skinAnim")

        case .neonPulse:
            // Breathing stroke width + brightness pulse + random flicker
            let duration: TimeInterval = 2.5
            let neon = SKAction.customAction(withDuration: duration) { node, elapsed in
                guard let shape = node as? SKShapeNode else { return }
                let t = (elapsed / CGFloat(duration)) * .pi * 2 + phaseOffset
                let pulse = 0.5 + 0.5 * sin(t)
                shape.lineWidth = 1.0 + 2.0 * pulse
                let strokeBri = min(dBri * (1.0 + 0.5 * pulse), 1.0)
                shape.strokeColor = UIColor(hue: dHue, saturation: dSat * (0.8 + 0.2 * pulse), brightness: strokeBri, alpha: dAlpha)
                let fillBri = bri * (0.9 + 0.15 * pulse)
                shape.fillColor = UIColor(hue: hue, saturation: sat, brightness: fillBri, alpha: alpha)
                // Random micro-flicker
                if CGFloat.random(in: 0...1) < 0.03 {
                    shape.fillColor = UIColor(hue: hue, saturation: sat * 0.5, brightness: min(bri * 1.6, 1.0), alpha: alpha)
                    shape.lineWidth = 4.0
                }
            }
            node.run(SKAction.repeatForever(neon), withKey: "skinAnim")
        }
    }

    // MARK: - Scene-Level Ambient Particles

    /// Node layer for ambient skin particles (above grid, below blocks).
    private var ambientParticleNode = SKNode()

    /// Starts the scene-level ambient particle emitter for the current animated skin.
    /// Particles float across the grid area, creating atmosphere without cluttering blocks.
    func startAmbientParticles() {
        stopAmbientParticles()

        guard let animType = SkinManager.shared.activeSkin.animationType else { return }

        ambientParticleNode = SKNode()
        ambientParticleNode.zPosition = 0.5 // Between grid (0) and blocks (1)
        addChild(ambientParticleNode)

        let gridWidth = cellSize * CGFloat(GameConstants.gridSize)
        let gridHeight = cellSize * CGFloat(GameConstants.gridSize)
        let gridCenterX = gridOrigin.x + gridWidth / 2
        let gridCenterY = gridOrigin.y - gridHeight / 2

        switch animType {
        case .shimmer:
            // Floating ice crystals / snowflakes drifting slowly downward
            let spawn = SKAction.run { [weak self] in
                guard let self = self, self.ambientParticleNode.parent != nil else { return }
                let size = CGFloat.random(in: 2...5)
                let crystal = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.3)
                crystal.fillColor = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.3...0.6))
                crystal.strokeColor = UIColor(white: 1.0, alpha: 0.15)
                crystal.lineWidth = 0.5
                crystal.position = CGPoint(
                    x: gridCenterX + CGFloat.random(in: -gridWidth * 0.55...gridWidth * 0.55),
                    y: gridCenterY + gridHeight * 0.55
                )
                self.ambientParticleNode.addChild(crystal)

                let fallDuration = Double.random(in: 3.0...5.0)
                let drift = CGFloat.random(in: -30...30)
                let wobble = SKAction.customAction(withDuration: fallDuration) { node, elapsed in
                    let progress = elapsed / CGFloat(fallDuration)
                    node.position.x += sin(progress * .pi * 4 + CGFloat.random(in: 0...0.1)) * 0.3
                    node.zRotation = progress * .pi * 2
                }
                crystal.run(SKAction.group([
                    SKAction.moveBy(x: drift, y: -gridHeight * 1.1, duration: fallDuration),
                    SKAction.fadeOut(withDuration: fallDuration),
                    wobble
                ])) { crystal.removeFromParent() }
            }
            let loop = SKAction.sequence([
                SKAction.wait(forDuration: 0.15, withRange: 0.1),
                spawn
            ])
            ambientParticleNode.run(SKAction.repeatForever(loop), withKey: "ambientSpawn")

        case .colorShift:
            // Drifting rainbow motes that float upward and shimmer
            let spawn = SKAction.run { [weak self] in
                guard let self = self, self.ambientParticleNode.parent != nil else { return }
                let size = CGFloat.random(in: 2.5...5)
                let mote = SKShapeNode(circleOfRadius: size)
                let hue = CGFloat.random(in: 0...1)
                mote.fillColor = UIColor(hue: hue, saturation: 0.9, brightness: 1.0, alpha: CGFloat.random(in: 0.2...0.5))
                mote.strokeColor = .clear
                mote.position = CGPoint(
                    x: gridCenterX + CGFloat.random(in: -gridWidth * 0.55...gridWidth * 0.55),
                    y: gridCenterY - gridHeight * 0.55
                )
                self.ambientParticleNode.addChild(mote)

                let riseDuration = Double.random(in: 3.5...6.0)
                let drift = CGFloat.random(in: -40...40)
                // Hue cycles during rise
                let colorCycle = SKAction.customAction(withDuration: riseDuration) { node, elapsed in
                    guard let shape = node as? SKShapeNode else { return }
                    let progress = elapsed / CGFloat(riseDuration)
                    let newHue = (hue + progress * 0.5).truncatingRemainder(dividingBy: 1.0)
                    shape.fillColor = UIColor(hue: newHue, saturation: 0.9, brightness: 1.0, alpha: max(0, 0.4 - progress * 0.4))
                }
                mote.run(SKAction.group([
                    SKAction.moveBy(x: drift, y: gridHeight * 1.1, duration: riseDuration),
                    SKAction.scale(to: 0.3, duration: riseDuration),
                    colorCycle
                ])) { mote.removeFromParent() }
            }
            let loop = SKAction.sequence([
                SKAction.wait(forDuration: 0.12, withRange: 0.08),
                spawn
            ])
            ambientParticleNode.run(SKAction.repeatForever(loop), withKey: "ambientSpawn")

        case .ember:
            // Fire embers rising from the grid — warm particles with flickering glow
            let spawn = SKAction.run { [weak self] in
                guard let self = self, self.ambientParticleNode.parent != nil else { return }
                let size = CGFloat.random(in: 2...6)
                let ember = SKShapeNode(circleOfRadius: size)
                let warmHue = CGFloat.random(in: 0.0...0.12)
                let brightness = CGFloat.random(in: 0.8...1.0)
                ember.fillColor = UIColor(hue: warmHue, saturation: 0.95, brightness: brightness, alpha: CGFloat.random(in: 0.4...0.8))
                ember.strokeColor = UIColor(hue: warmHue, saturation: 0.6, brightness: 1.0, alpha: 0.2)
                ember.lineWidth = 1.0
                ember.position = CGPoint(
                    x: gridCenterX + CGFloat.random(in: -gridWidth * 0.55...gridWidth * 0.55),
                    y: gridCenterY - gridHeight * 0.55
                )
                self.ambientParticleNode.addChild(ember)

                let riseDuration = Double.random(in: 2.0...4.0)
                let drift = CGFloat.random(in: -50...50)
                // Flickering brightness as it rises
                let flicker = SKAction.customAction(withDuration: riseDuration) { node, elapsed in
                    guard let shape = node as? SKShapeNode else { return }
                    let progress = elapsed / CGFloat(riseDuration)
                    let flickerVal = sin(progress * .pi * CGFloat.random(in: 6...12))
                    let newAlpha = max(0, (0.7 - progress * 0.7) * (0.7 + 0.3 * flickerVal))
                    shape.fillColor = UIColor(hue: warmHue, saturation: 0.95, brightness: brightness, alpha: newAlpha)
                }
                ember.run(SKAction.group([
                    SKAction.moveBy(x: drift, y: gridHeight * 1.2, duration: riseDuration),
                    SKAction.scale(to: 0.1, duration: riseDuration),
                    flicker
                ])) { ember.removeFromParent() }
            }
            let loop = SKAction.sequence([
                SKAction.wait(forDuration: 0.08, withRange: 0.06),
                spawn
            ])
            ambientParticleNode.run(SKAction.repeatForever(loop), withKey: "ambientSpawn")

        case .neonPulse:
            // Electric sparks that flash across the grid + horizontal scanlines
            let sparkSpawn = SKAction.run { [weak self] in
                guard let self = self, self.ambientParticleNode.parent != nil else { return }
                let size = CGFloat.random(in: 1.5...3.5)
                let spark = SKShapeNode(circleOfRadius: size)
                spark.fillColor = UIColor.white.withAlphaComponent(0.9)
                spark.strokeColor = .clear
                spark.position = CGPoint(
                    x: gridCenterX + CGFloat.random(in: -gridWidth * 0.5...gridWidth * 0.5),
                    y: gridCenterY + CGFloat.random(in: -gridHeight * 0.5...gridHeight * 0.5)
                )
                self.ambientParticleNode.addChild(spark)

                // Flash in, zip in random direction, vanish
                let angle = CGFloat.random(in: 0...(.pi * 2))
                let distance = CGFloat.random(in: 15...40)
                let lifetime = Double.random(in: 0.1...0.25)
                spark.run(SKAction.sequence([
                    SKAction.group([
                        SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: lifetime),
                        SKAction.sequence([
                            SKAction.fadeAlpha(to: 1.0, duration: 0.02),
                            SKAction.fadeOut(withDuration: lifetime - 0.02)
                        ]),
                        SKAction.scale(to: 0.1, duration: lifetime)
                    ]),
                    SKAction.removeFromParent()
                ]))
            }
            let sparkLoop = SKAction.sequence([
                SKAction.wait(forDuration: 0.08, withRange: 0.06),
                sparkSpawn
            ])
            ambientParticleNode.run(SKAction.repeatForever(sparkLoop), withKey: "ambientSpawn")

            // Horizontal scanline that sweeps across the grid periodically
            let scanSpawn = SKAction.run { [weak self] in
                guard let self = self, self.ambientParticleNode.parent != nil else { return }
                let lineHeight: CGFloat = 1.5
                let scanline = SKShapeNode(rectOf: CGSize(width: gridWidth * 1.1, height: lineHeight))
                scanline.fillColor = UIColor.white.withAlphaComponent(0.08)
                scanline.strokeColor = .clear
                scanline.position = CGPoint(
                    x: gridCenterX,
                    y: gridCenterY + gridHeight * 0.55
                )
                self.ambientParticleNode.addChild(scanline)
                scanline.run(SKAction.sequence([
                    SKAction.moveBy(x: 0, y: -gridHeight * 1.1, duration: 1.2),
                    SKAction.removeFromParent()
                ]))
            }
            let scanLoop = SKAction.sequence([
                SKAction.wait(forDuration: 2.5, withRange: 1.5),
                scanSpawn
            ])
            ambientParticleNode.run(SKAction.repeatForever(scanLoop), withKey: "ambientScan")
        }
    }

    /// Stop and remove all ambient particles.
    func stopAmbientParticles() {
        ambientParticleNode.removeAllActions()
        ambientParticleNode.removeAllChildren()
        ambientParticleNode.removeFromParent()
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
            self?.run(SKAction.wait(forDuration: 0.15)) {
                self?.animateNextEvent(events: events, index: index + 1,
                                       finalGrid: finalGrid, completion: completion)
            }
        }
    }

    /// Animate one blast event: detonate → particles → shockwave ring.
    /// If the event has a `powerUpSource`, plays a dedicated power-up animation instead.
    private func animateSingleBlast(event: BlastEvent, completion: @escaping () -> Void) {
        if let powerUpType = event.powerUpSource {
            animatePowerUpEffect(event: event, type: powerUpType, completion: completion)
            return
        }

        // Audio: chime as warning before blast
        AudioManager.shared.playLineCompleteChime()

        // Phase 1: DETONATE — flash white, then scale up + fade out cleared blocks
        let detonateAction = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: GameConstants.detonateFlashDuration),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.15),
                SKAction.scale(to: 1.4, duration: 0.15)
            ])
        ])

        // Find nodes to detonate by block ID (more reliable than position matching)
        let idsToDetonate = Set(event.clearedBlockIDs)
        var nodesToDetonate: [SKShapeNode] = []
        for (id, node) in blockNodes where idsToDetonate.contains(id) {
            nodesToDetonate.append(node)
        }

        // Run detonation on all cleared blocks simultaneously
        let detonateFinished = DispatchGroup()
        for node in nodesToDetonate {
            detonateFinished.enter()
            node.run(detonateAction) {
                node.removeFromParent()
                detonateFinished.leave()
            }
        }

        // Remove detonated blocks from tracking
        for id in idsToDetonate {
            blockNodes.removeValue(forKey: id)
        }

        // After detonation, run particles + shockwave
        DispatchQueue.main.asyncAfter(deadline: .now() + GameConstants.detonateFlashDuration + 0.15) { [weak self] in
            guard let self else { completion(); return }

            // Audio + haptics for blast
            AudioManager.shared.playBlast()
            HapticManager.shared.playBlast()

            // Phase 2: COLOR-MATCHED PARTICLE EXPLOSION
            self.spawnExplosionParticles(event: event)

            // Phase 3: SCREEN SHAKE — intensity scales with group size
            self.runScreenShake(intensity: event.groupSize)

            // Phase 4: CIRCULAR SHOCKWAVE from group center
            self.spawnShockwaveRing(event: event)

            // Phase 5: PUSH adjacent blocks outward
            self.animatePushedBlocks(event: event) {
                completion()
            }
        }
    }

    // MARK: - Power-Up Effect Animations

    /// Animate a power-up clear event with a dedicated visual effect.
    private func animatePowerUpEffect(event: BlastEvent, type: PowerUpType, completion: @escaping () -> Void) {
        guard let origin = event.powerUpOrigin else {
            completion()
            return
        }

        // Phase 1: Flash line/area effect
        switch type {
        case .rowBlast:
            spawnRowFlashLine(row: origin.row)
        case .columnBlast:
            spawnColumnFlashLine(col: origin.col)
        case .colorBomb:
            spawnColorBombFlash(event: event)
        }

        // Distinct audio per power-up type
        switch type {
        case .rowBlast:    AudioManager.shared.playPowerUpRowBlast()
        case .columnBlast: AudioManager.shared.playPowerUpColumnBlast()
        case .colorBomb:   AudioManager.shared.playPowerUpColorBomb()
        }
        HapticManager.shared.playBlast()
        runScreenShake(intensity: max(event.groupSize, 5))

        // Phase 2: After the flash, detonate affected blocks
        run(SKAction.wait(forDuration: 0.2)) { [weak self] in
            guard let self else { completion(); return }

            let detonateAction = SKAction.sequence([
                SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.08),
                SKAction.group([
                    SKAction.fadeOut(withDuration: 0.15),
                    SKAction.scale(to: 1.3, duration: 0.15)
                ])
            ])

            let idsToDetonate = Set(event.clearedBlockIDs)
            let detonateGroup = DispatchGroup()

            for (id, node) in self.blockNodes where idsToDetonate.contains(id) {
                detonateGroup.enter()
                node.run(detonateAction) {
                    node.removeFromParent()
                    detonateGroup.leave()
                }
                self.blockNodes.removeValue(forKey: id)
            }

            // Particles at each cleared position
            self.spawnExplosionParticles(event: event)

            detonateGroup.notify(queue: .main) {
                completion()
            }
        }
    }

    /// Flash a bright horizontal line across the entire row.
    private func spawnRowFlashLine(row: Int) {
        let gridWidth = CGFloat(GameConstants.gridSize) * cellSize
        let centerY = gridOrigin.y - CGFloat(row) * cellSize - cellSize / 2
        let centerX = gridOrigin.x + gridWidth / 2

        let line = SKShapeNode(rectOf: CGSize(width: gridWidth + 20, height: cellSize * 0.8), cornerRadius: 4)
        line.fillColor = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 0.7)
        line.strokeColor = UIColor.white.withAlphaComponent(0.9)
        line.lineWidth = 2.0
        line.position = CGPoint(x: centerX, y: centerY)
        line.zPosition = 15
        line.setScale(0.1)
        line.alpha = 1.0
        addChild(line)

        // Expand horizontally then fade
        let scaleUp = SKAction.scaleX(to: 1.0, duration: 0.15)
        let scaleYUp = SKAction.scaleY(to: 1.0, duration: 0.08)
        let hold = SKAction.wait(forDuration: 0.1)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        line.run(SKAction.sequence([
            SKAction.group([scaleUp, scaleYUp]),
            hold,
            fade
        ])) {
            line.removeFromParent()
        }

        // Arrow symbol at center
        let arrow = SKLabelNode(text: "\u{2192}") // →
        arrow.fontSize = 40
        arrow.fontColor = .white
        arrow.position = CGPoint(x: centerX, y: centerY - 15)
        arrow.zPosition = 16
        arrow.alpha = 0.0
        addChild(arrow)
        arrow.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.wait(forDuration: 0.2),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.scale(to: 2.0, duration: 0.2)
            ])
        ])) {
            arrow.removeFromParent()
        }
    }

    /// Flash a bright vertical line down the entire column.
    private func spawnColumnFlashLine(col: Int) {
        let gridHeight = CGFloat(GameConstants.gridSize) * cellSize
        let centerX = gridOrigin.x + CGFloat(col) * cellSize + cellSize / 2
        let centerY = gridOrigin.y - gridHeight / 2

        let line = SKShapeNode(rectOf: CGSize(width: cellSize * 0.8, height: gridHeight + 20), cornerRadius: 4)
        line.fillColor = UIColor(red: 0.3, green: 0.85, blue: 1.0, alpha: 0.7)
        line.strokeColor = UIColor.white.withAlphaComponent(0.9)
        line.lineWidth = 2.0
        line.position = CGPoint(x: centerX, y: centerY)
        line.zPosition = 15
        line.setScale(0.1)
        line.alpha = 1.0
        addChild(line)

        // Expand vertically then fade
        let scaleYUp = SKAction.scaleY(to: 1.0, duration: 0.15)
        let scaleXUp = SKAction.scaleX(to: 1.0, duration: 0.08)
        let hold = SKAction.wait(forDuration: 0.1)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        line.run(SKAction.sequence([
            SKAction.group([scaleYUp, scaleXUp]),
            hold,
            fade
        ])) {
            line.removeFromParent()
        }

        // Arrow symbol at center
        let arrow = SKLabelNode(text: "\u{2193}") // ↓
        arrow.fontSize = 40
        arrow.fontColor = .white
        arrow.position = CGPoint(x: centerX, y: centerY - 15)
        arrow.zPosition = 16
        arrow.alpha = 0.0
        addChild(arrow)
        arrow.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.1),
            SKAction.wait(forDuration: 0.2),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.scale(to: 2.0, duration: 0.2)
            ])
        ])) {
            arrow.removeFromParent()
        }
    }

    /// Flash all blocks targeted by a color bomb with a star burst.
    private func spawnColorBombFlash(event: BlastEvent) {
        let groupColor = SkinManager.shared.colorForBlock(event.groupColor)

        for pos in event.clearedPositions {
            let scenePos = scenePosition(for: pos)

            // Colored glow behind each targeted block
            let glow = SKShapeNode(circleOfRadius: cellSize * 0.6)
            glow.fillColor = groupColor.withAlphaComponent(0.5)
            glow.strokeColor = UIColor.white.withAlphaComponent(0.8)
            glow.lineWidth = 2.0
            glow.position = scenePos
            glow.zPosition = 14
            glow.setScale(0.3)
            addChild(glow)

            glow.run(SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.15),
                SKAction.wait(forDuration: 0.1),
                SKAction.fadeOut(withDuration: 0.15)
            ])) {
                glow.removeFromParent()
            }
        }

        // Large star symbol at the grid center
        let gridCenterX = gridOrigin.x + CGFloat(GameConstants.gridSize) * cellSize / 2
        let gridCenterY = gridOrigin.y - CGFloat(GameConstants.gridSize) * cellSize / 2

        let star = SKLabelNode(text: "\u{2605}") // ★
        star.fontSize = 56
        star.fontColor = groupColor
        star.position = CGPoint(x: gridCenterX, y: gridCenterY - 20)
        star.zPosition = 16
        star.setScale(0.5)
        addChild(star)

        star.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.25),
                SKAction.rotate(byAngle: .pi, duration: 0.25)
            ]),
            SKAction.fadeOut(withDuration: 0.2)
        ])) {
            star.removeFromParent()
        }
    }

    /// Animate blocks being pushed away from the blast.
    /// Blocks pushed off-grid slide out and fade away.
    private func animatePushedBlocks(event: BlastEvent, completion: @escaping () -> Void) {
        guard !event.pushedBlocks.isEmpty else {
            run(SKAction.wait(forDuration: 0.15)) { completion() }
            return
        }

        let duration = GameConstants.pushAnimationDuration
        let pushGroup = DispatchGroup()

        for pushed in event.pushedBlocks {
            guard let node = blockNodes[pushed.blockID] else { continue }

            pushGroup.enter()

            if let dest = pushed.to {
                // Block slides to new position
                let targetPos = scenePosition(for: dest)
                let move = SKAction.move(to: targetPos, duration: duration)
                move.timingMode = .easeOut
                node.run(move) { pushGroup.leave() }
            } else {
                // Block pushed off-grid — slide in push direction and fade
                // Compute push direction from from-position
                let fromScene = scenePosition(for: pushed.from)
                // Infer direction: the block was at 'from' and would go 1 cell further
                // Use the direction from group center to this block
                let avgRow = CGFloat(event.clearedPositions.map(\.row).reduce(0, +)) / CGFloat(event.groupSize)
                let avgCol = CGFloat(event.clearedPositions.map(\.col).reduce(0, +)) / CGFloat(event.groupSize)
                let dxDir = fromScene.x - (gridOrigin.x + avgCol * cellSize + cellSize / 2)
                let dyDir = fromScene.y - (gridOrigin.y - avgRow * cellSize - cellSize / 2)
                let mag = max(sqrt(dxDir * dxDir + dyDir * dyDir), 1)

                let offscreenX = fromScene.x + (dxDir / mag) * cellSize * 3
                let offscreenY = fromScene.y + (dyDir / mag) * cellSize * 3

                let slideOut = SKAction.move(to: CGPoint(x: offscreenX, y: offscreenY), duration: 0.3)
                slideOut.timingMode = .easeIn
                let fade = SKAction.fadeOut(withDuration: 0.3)

                node.run(SKAction.group([slideOut, fade])) {
                    node.removeFromParent()
                    pushGroup.leave()
                }
                blockNodes.removeValue(forKey: pushed.blockID)
            }
        }

        pushGroup.notify(queue: .main) {
            completion()
        }
    }

    /// Spawn color-matched particle explosions at each cleared cell.
    private func spawnExplosionParticles(event: BlastEvent) {
        let baseColor = SkinManager.shared.colorForBlock(event.groupColor)
        let isLargeGroup = event.groupSize >= 8
        let particlesPerCell = isLargeGroup ? 8 : 6

        for pos in event.clearedPositions {
            let scenePos = scenePosition(for: pos)

            for i in 0..<particlesPerCell {
                // Mix of particle sizes
                let isLarge = i < 2
                let particleSize: CGFloat = isLarge ? 5 : 3

                let particle = SKShapeNode(rectOf: CGSize(width: particleSize, height: particleSize), cornerRadius: 1)
                particle.strokeColor = .clear
                particle.zPosition = 5
                particle.position = scenePos

                // Color variation: base color, lighter highlights, white sparkles
                if i == 0 {
                    // White sparkle
                    particle.fillColor = UIColor.white.withAlphaComponent(0.9)
                } else if i < 3 {
                    // Lighter tint
                    particle.fillColor = baseColor.withAlphaComponent(0.7)
                } else {
                    // Full color
                    particle.fillColor = baseColor
                }

                addChild(particle)

                // Random direction and distance
                let angle = CGFloat.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 20...(isLargeGroup ? 80 : 60))
                let dx = cos(angle) * distance
                let dy = sin(angle) * distance
                let duration = CGFloat.random(in: 0.25...0.4)

                let move = SKAction.moveBy(x: dx, y: dy, duration: duration)
                move.timingMode = .easeOut
                let fade = SKAction.fadeOut(withDuration: duration)
                let shrink = SKAction.scale(to: 0.1, duration: duration)

                particle.run(SKAction.group([move, fade, shrink])) {
                    particle.removeFromParent()
                }
            }
        }

        // White flash overlay at the center of the group
        spawnCenterFlash(positions: event.clearedPositions)
    }

    /// Brief white flash at the center of a cleared group.
    private func spawnCenterFlash(positions: [GridPosition]) {
        guard !positions.isEmpty else { return }

        let avgRow = CGFloat(positions.map(\.row).reduce(0, +)) / CGFloat(positions.count)
        let avgCol = CGFloat(positions.map(\.col).reduce(0, +)) / CGFloat(positions.count)
        let centerPos = CGPoint(
            x: gridOrigin.x + avgCol * cellSize + cellSize / 2,
            y: gridOrigin.y - avgRow * cellSize - cellSize / 2
        )

        let flashSize = cellSize * CGFloat(min(positions.count, 6)) * 0.6
        let flash = SKShapeNode(circleOfRadius: flashSize / 2)
        flash.fillColor = UIColor.white.withAlphaComponent(0.5)
        flash.strokeColor = .clear
        flash.position = centerPos
        flash.zPosition = 6
        flash.setScale(0.3)
        addChild(flash)

        let expand = SKAction.scale(to: 1.0, duration: 0.15)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        flash.run(SKAction.sequence([expand, fade])) {
            flash.removeFromParent()
        }
    }

    /// Screen shake — intensity scales with group size.
    private func runScreenShake(intensity groupSize: Int = 4) {
        let amplitude = min(CGFloat(groupSize) * 0.5, 5.0)
        let originalPosition = gridNode.position
        let shakeAction = SKAction.customAction(withDuration: 0.2) { node, elapsed in
            let progress = min(elapsed / 0.2, 1.0) // clamp — elapsed can overshoot duration
            let currentAmplitude = amplitude * (1.0 - progress)
            node.position = CGPoint(
                x: originalPosition.x + CGFloat.random(in: -currentAmplitude...currentAmplitude),
                y: originalPosition.y + CGFloat.random(in: -currentAmplitude...currentAmplitude)
            )
        }
        let resetPosition = SKAction.move(to: originalPosition, duration: 0.02)
        gridNode.run(SKAction.sequence([shakeAction, resetPosition]))
    }

    /// Spawn a circular expanding ring from the center of the cleared group.
    private func spawnShockwaveRing(event: BlastEvent) {
        guard !event.clearedPositions.isEmpty else { return }

        let avgRow = CGFloat(event.clearedPositions.map(\.row).reduce(0, +)) / CGFloat(event.groupSize)
        let avgCol = CGFloat(event.clearedPositions.map(\.col).reduce(0, +)) / CGFloat(event.groupSize)
        let center = CGPoint(
            x: gridOrigin.x + avgCol * cellSize + cellSize / 2,
            y: gridOrigin.y - avgRow * cellSize - cellSize / 2
        )

        let ringRadius = cellSize * 0.5
        let ring = SKShapeNode(circleOfRadius: ringRadius)
        // Tint the ring with the group color mixed with white
        let groupColor = SkinManager.shared.colorForBlock(event.groupColor)
        ring.strokeColor = groupColor.withAlphaComponent(0.6)
        ring.fillColor = .clear
        ring.lineWidth = 2.0
        ring.position = center
        ring.zPosition = 4
        addChild(ring)

        let targetScale = CGFloat(max(event.groupSize, 4)) * 1.5
        let expand = SKAction.scale(to: targetScale, duration: GameConstants.shockwaveFadeDuration)
        expand.timingMode = .easeOut
        let fade = SKAction.fadeOut(withDuration: GameConstants.shockwaveFadeDuration)
        ring.run(SKAction.group([expand, fade])) {
            ring.removeFromParent()
        }
    }

    // MARK: - Combo Overlay

    /// Display a "COMBO ×N!" text at the center of the grid that scales up and fades.
    func showComboOverlay(level: Int) {
        let gridCenterX = gridOrigin.x + CGFloat(GameConstants.gridSize) * cellSize / 2
        let gridCenterY = gridOrigin.y - CGFloat(GameConstants.gridSize) * cellSize / 2

        let label = SKLabelNode(text: "COMBO \u{00D7}\(level)!")
        label.fontName = "HelveticaNeue-Bold"
        label.fontSize = 36
        label.fontColor = level >= 4
            ? UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1) // gold
            : level >= 3 ? .red : .orange
        label.position = CGPoint(x: gridCenterX, y: gridCenterY)
        label.zPosition = 20
        label.setScale(0.5)
        label.alpha = 1.0
        addChild(label)

        let scaleUp = SKAction.scale(to: 1.5, duration: 0.3)
        scaleUp.timingMode = .easeOut
        let hold = SKAction.wait(forDuration: 0.4)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        label.run(SKAction.sequence([scaleUp, hold, fadeOut])) {
            label.removeFromParent()
        }
    }

    // MARK: - Refresh All Blocks

    /// Rebuild all block nodes and grid background from the current engine state.
    /// Used when settings change mid-game (e.g. colorblind toggle, skin change).
    func refreshAllBlocks() {
        guard let vm = viewModel else { return }
        // Rebuild grid background to pick up new skin grid colors
        setupGrid()
        // Remove all existing block nodes
        for (_, node) in blockNodes {
            node.removeFromParent()
        }
        blockNodes.removeAll()
        // Re-create from engine state
        updateGrid(vm.engine.grid)
        updateTray(vm.engine.tray)
        // Restart ambient particles for the new skin
        startAmbientParticles()
    }

    // MARK: - Bomb State

    /// Preview nodes for bomb placement (6×6 red/orange area).
    private var bombPreviewNodes: [SKShapeNode] = []

    /// Animate the bomb explosion and call completion when done.
    func animateBombExplosion(result: BombResult, completion: @escaping () -> Void) {
        // Clear bomb preview
        clearBombPreview()

        let idsToRemove = Set(result.clearedBlockIDs)
        var nodesToExplode: [SKShapeNode] = []
        for (id, node) in blockNodes where idsToRemove.contains(id) {
            nodesToExplode.append(node)
        }

        // Flash white → red → fade out
        let explodeAction = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.08),
            SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.08),
            SKAction.group([
                SKAction.fadeOut(withDuration: 0.2),
                SKAction.scale(to: 0.3, duration: 0.2)
            ])
        ])

        let animGroup = DispatchGroup()
        for node in nodesToExplode {
            animGroup.enter()
            node.run(explodeAction) {
                node.removeFromParent()
                animGroup.leave()
            }
        }

        // Remove from tracking
        for id in idsToRemove {
            blockNodes.removeValue(forKey: id)
        }

        // Heavy screen shake
        runScreenShake(intensity: 12)

        // Fire-colored particle burst at each position
        for pos in result.clearedPositions {
            let scenePos = scenePosition(for: pos)
            for _ in 0..<10 {
                let particle = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 3...6),
                                                          height: CGFloat.random(in: 3...6)),
                                           cornerRadius: 1)
                // Fire colors: orange, red, yellow mix
                let fireColors: [UIColor] = [
                    UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1),
                    UIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1),
                    UIColor.red,
                    UIColor.yellow
                ]
                particle.fillColor = fireColors.randomElement()!
                particle.strokeColor = .clear
                particle.position = scenePos
                particle.zPosition = 6
                addChild(particle)

                let angle = CGFloat.random(in: 0...(2 * .pi))
                let distance = CGFloat.random(in: 30...100)
                let dx = cos(angle) * distance
                let dy = sin(angle) * distance
                let duration = CGFloat.random(in: 0.3...0.5)

                let move = SKAction.moveBy(x: dx, y: dy, duration: duration)
                move.timingMode = .easeOut
                particle.run(SKAction.group([
                    move,
                    SKAction.fadeOut(withDuration: duration),
                    SKAction.scale(to: 0.1, duration: duration)
                ])) {
                    particle.removeFromParent()
                }
            }
        }

        // Large expanding shockwave circle from center of bomb area
        if !result.clearedPositions.isEmpty {
            let avgRow = CGFloat(result.clearedPositions.map(\.row).reduce(0, +)) / CGFloat(result.clearedPositions.count)
            let avgCol = CGFloat(result.clearedPositions.map(\.col).reduce(0, +)) / CGFloat(result.clearedPositions.count)
            let center = CGPoint(
                x: gridOrigin.x + avgCol * cellSize + cellSize / 2,
                y: gridOrigin.y - avgRow * cellSize - cellSize / 2
            )
            let ring = SKShapeNode(circleOfRadius: cellSize)
            ring.strokeColor = UIColor.orange.withAlphaComponent(0.7)
            ring.fillColor = UIColor.orange.withAlphaComponent(0.1)
            ring.lineWidth = 3.0
            ring.position = center
            ring.zPosition = 7
            addChild(ring)
            ring.run(SKAction.group([
                SKAction.scale(to: 8, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5)
            ])) {
                ring.removeFromParent()
            }
        }

        // Audio + haptic
        AudioManager.shared.playBlast()
        HapticManager.shared.playBlast()

        animGroup.notify(queue: .main) {
            completion()
        }
    }

    /// Show/update the 6×6 bomb preview at a grid position.
    private func updateBombPreview(at center: GridPosition) {
        clearBombPreview()

        let minRow = max(center.row - 2, 0)
        let maxRow = min(center.row + 3, GameConstants.gridSize - 1)
        let minCol = max(center.col - 2, 0)
        let maxCol = min(center.col + 3, GameConstants.gridSize - 1)

        for row in minRow...maxRow {
            for col in minCol...maxCol {
                let pos = GridPosition(row: row, col: col)
                let inset: CGFloat = 1.0
                let previewSize = CGSize(width: cellSize - inset * 2, height: cellSize - inset * 2)
                let node = SKShapeNode(rectOf: previewSize, cornerRadius: blockCornerRadius)
                node.fillColor = UIColor.red.withAlphaComponent(0.2)
                node.strokeColor = UIColor.orange.withAlphaComponent(0.5)
                node.lineWidth = 1.0
                node.position = scenePosition(for: pos)
                node.zPosition = 2
                addChild(node)
                bombPreviewNodes.append(node)
            }
        }
    }

    /// Remove all bomb preview nodes.
    private func clearBombPreview() {
        for node in bombPreviewNodes {
            node.removeFromParent()
        }
        bombPreviewNodes.removeAll()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isAnimating, let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Bomb mode: tap grid to place bomb (ad-based after game over)
        if viewModel?.isBombMode == true {
            if let gridPos = gridPosition(for: location) {
                updateBombPreview(at: gridPos)
            }
            return
        }

        // Coin bomb mode: tap grid to place coin-purchased bomb (during gameplay)
        if viewModel?.isCoinBombMode == true {
            if let gridPos = gridPosition(for: location) {
                updateBombPreview(at: gridPos)
            }
            return
        }

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

                lastTrailPosition = location
                viewModel?.beginDrag(piece: piece)
                AudioManager.shared.playPickup(cellCount: piece.cellCount)
                HapticManager.shared.playPickup()
                break
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Bomb mode: update preview as finger moves
        if viewModel?.isBombMode == true || viewModel?.isCoinBombMode == true {
            if let gridPos = gridPosition(for: location) {
                updateBombPreview(at: gridPos)
            }
            return
        }

        guard let dragNode = draggedPieceNode,
              let piece = draggedPiece else { return }

        // Move the drag node above the finger
        dragNode.position = CGPoint(x: location.x, y: location.y + cellSize * 2)

        // Spawn drag trail particles (throttled by distance to avoid particle spam)
        let dx = location.x - lastTrailPosition.x
        let dy = location.y - lastTrailPosition.y
        if dx * dx + dy * dy > 9 { // ~3pt movement threshold for denser trails
            lastTrailPosition = location
            spawnDragTrailParticle(at: dragNode.position, color: piece.color)
        }

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
        // Bomb mode: place bomb at last touched grid position
        if viewModel?.isBombMode == true {
            if let touch = touches.first {
                let location = touch.location(in: self)
                if let gridPos = gridPosition(for: location) {
                    viewModel?.placeBomb(at: gridPos)
                }
            }
            clearBombPreview()
            return
        }

        // Coin bomb mode: place coin-purchased bomb during gameplay
        if viewModel?.isCoinBombMode == true {
            if let touch = touches.first {
                let location = touch.location(in: self)
                if let gridPos = gridPosition(for: location) {
                    viewModel?.placeCoinBomb(at: gridPos)
                }
            }
            clearBombPreview()
            return
        }

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

            if let powerUp = piece.powerUp {
                // Power-up drag node: golden block with power-up symbol
                let inset: CGFloat = 1.5
                let bSize = CGSize(width: cellSize - inset * 2, height: cellSize - inset * 2)
                let blockNode = SKShapeNode(rectOf: bSize, cornerRadius: blockCornerRadius)
                blockNode.fillColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1)
                blockNode.strokeColor = UIColor(red: 0.65, green: 0.50, blue: 0.10, alpha: 1)
                blockNode.lineWidth = 1.5
                blockNode.position = CGPoint(x: x, y: y)

                let label = SKLabelNode(text: powerUp.symbol)
                label.fontSize = bSize.width * 0.55
                label.fontColor = .white
                label.verticalAlignmentMode = .center
                label.horizontalAlignmentMode = .center
                label.zPosition = 2
                blockNode.addChild(label)
                container.addChild(blockNode)
            } else {
                let blockNode = createBlockNode(color: piece.color)
                blockNode.position = CGPoint(x: x, y: y)
                container.addChild(blockNode)
            }
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

        // Power-up pieces: only need the single origin cell to be valid
        if piece.isPowerUp {
            guard origin.isValid else { return }
            let goldColor = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 0.3)
            let goldBorder = UIColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 0.6)
            let inset: CGFloat = 1.0
            let ghostSize = CGSize(width: cellSize - inset * 2, height: cellSize - inset * 2)
            let ghost = SKShapeNode(rectOf: ghostSize, cornerRadius: blockCornerRadius)
            ghost.fillColor = goldColor
            ghost.strokeColor = goldBorder
            ghost.lineWidth = 1.0
            ghost.position = scenePosition(for: origin)
            ghost.zPosition = 2
            addChild(ghost)
            ghostNodes.append(ghost)
            return
        }

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

    /// Spawn skin-aware drag trail particles. Each animated skin gets a unique trail;
    /// static skins get the default color-matched particle trail.
    /// All trails are long-lived and highly visible.
    private func spawnDragTrailParticle(at position: CGPoint, color: BlockColor) {
        let skin = SkinManager.shared.activeSkin
        let skinColor = SkinManager.shared.colorForBlock(color)

        switch skin.animationType {
        case .shimmer:
            // Frost trail: large bright ice crystals that drift downward slowly
            for _ in 0..<4 {
                let size = CGFloat.random(in: 4...8)
                let sparkle = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.3)
                let iceHue = CGFloat.random(in: 0.55...0.62)
                sparkle.fillColor = UIColor(hue: iceHue, saturation: 0.3, brightness: 1.0, alpha: 1.0)
                sparkle.strokeColor = UIColor.white.withAlphaComponent(0.6)
                sparkle.lineWidth = 0.5
                sparkle.position = CGPoint(
                    x: position.x + CGFloat.random(in: -12...12),
                    y: position.y + CGFloat.random(in: -8...8)
                )
                sparkle.zPosition = 9
                addChild(sparkle)
                let duration = CGFloat.random(in: 0.6...1.0)
                sparkle.run(SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -15...15), y: CGFloat.random(in: -35...(-15)), duration: duration),
                    SKAction.fadeOut(withDuration: duration),
                    SKAction.scale(to: 0.2, duration: duration),
                    SKAction.rotate(byAngle: CGFloat.random(in: -2...2), duration: duration)
                ])) { sparkle.removeFromParent() }
            }

        case .colorShift:
            // Rainbow trail: vivid color dots that spiral outward and linger
            for _ in 0..<5 {
                let size = CGFloat.random(in: 4...7)
                let dot = SKShapeNode(circleOfRadius: size)
                let hue = CGFloat.random(in: 0...1)
                dot.fillColor = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 0.9)
                dot.strokeColor = UIColor(hue: hue, saturation: 0.8, brightness: 1.0, alpha: 0.4)
                dot.lineWidth = 1.0
                let angle = CGFloat.random(in: 0...(.pi * 2))
                let spread: CGFloat = CGFloat.random(in: 4...10)
                dot.position = CGPoint(
                    x: position.x + cos(angle) * spread,
                    y: position.y + sin(angle) * spread
                )
                dot.zPosition = 9
                addChild(dot)
                let duration = CGFloat.random(in: 0.6...1.0)
                let outward = CGFloat.random(in: 20...40)
                dot.run(SKAction.group([
                    SKAction.moveBy(x: cos(angle) * outward, y: sin(angle) * outward, duration: duration),
                    SKAction.fadeOut(withDuration: duration),
                    SKAction.scale(to: 0.15, duration: duration)
                ])) { dot.removeFromParent() }
            }

        case .ember:
            // Ember trail: large warm sparks that rise high like campfire embers
            for _ in 0..<5 {
                let size = CGFloat.random(in: 4...8)
                let ember = SKShapeNode(circleOfRadius: size)
                let warmHue = CGFloat.random(in: 0.0...0.12)
                ember.fillColor = UIColor(hue: warmHue, saturation: 0.95, brightness: 1.0, alpha: 1.0)
                ember.strokeColor = UIColor(hue: warmHue, saturation: 0.5, brightness: 1.0, alpha: 0.5)
                ember.lineWidth = 1.0
                ember.position = CGPoint(
                    x: position.x + CGFloat.random(in: -10...10),
                    y: position.y + CGFloat.random(in: -6...6)
                )
                ember.zPosition = 9
                addChild(ember)
                let duration = CGFloat.random(in: 0.7...1.2)
                let riseHeight = CGFloat.random(in: 30...60)
                ember.run(SKAction.group([
                    SKAction.moveBy(x: CGFloat.random(in: -15...15), y: riseHeight, duration: duration),
                    SKAction.fadeOut(withDuration: duration),
                    SKAction.scale(to: 0.1, duration: duration)
                ])) { ember.removeFromParent() }
            }

        case .neonPulse:
            // Electric trail: bright sparks that zip outward with long travel
            for _ in 0..<6 {
                let size = CGFloat.random(in: 3...6)
                let spark = SKShapeNode(circleOfRadius: size)
                spark.fillColor = UIColor.white.withAlphaComponent(0.95)
                spark.strokeColor = skinColor.withAlphaComponent(0.7)
                spark.lineWidth = 1.5
                let angle = CGFloat.random(in: 0...(.pi * 2))
                spark.position = CGPoint(
                    x: position.x + CGFloat.random(in: -6...6),
                    y: position.y + CGFloat.random(in: -6...6)
                )
                spark.zPosition = 9
                addChild(spark)
                let duration = CGFloat.random(in: 0.3...0.6)
                let distance = CGFloat.random(in: 25...50)
                spark.run(SKAction.group([
                    SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: duration),
                    SKAction.sequence([
                        SKAction.wait(forDuration: 0.05),
                        SKAction.fadeOut(withDuration: duration - 0.05)
                    ]),
                    SKAction.scale(to: 0.1, duration: duration)
                ])) { spark.removeFromParent() }
            }

        case nil:
            // Default: color-matched particles, larger and longer than before
            for _ in 0..<3 {
                let size = CGFloat.random(in: 4...7)
                let particle = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: 2)
                particle.fillColor = skinColor.withAlphaComponent(0.85)
                particle.strokeColor = .clear
                particle.position = CGPoint(
                    x: position.x + CGFloat.random(in: -10...10),
                    y: position.y + CGFloat.random(in: -8...8)
                )
                particle.zPosition = 9
                addChild(particle)
                let duration = CGFloat.random(in: 0.5...0.8)
                let drift = SKAction.moveBy(x: CGFloat.random(in: -15...15),
                                             y: CGFloat.random(in: -25...(-10)),
                                             duration: duration)
                drift.timingMode = .easeOut
                particle.run(SKAction.group([
                    drift,
                    SKAction.fadeOut(withDuration: duration),
                    SKAction.scale(to: 0.15, duration: duration)
                ])) { particle.removeFromParent() }
            }
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

    /// Draw the grid background with alternating cell shading.
    /// Uses the active skin's grid colors when available, otherwise falls back to default dark gray.
    private func setupGrid() {
        gridNode.removeFromParent()
        gridNode = SKNode()
        gridNode.zPosition = 0
        addChild(gridNode)

        let skin = SkinManager.shared.activeSkin
        let defaultLight = UIColor(red: 0.176, green: 0.204, blue: 0.216, alpha: 1) // #2D3436
        let defaultDark = UIColor(red: 0.149, green: 0.173, blue: 0.184, alpha: 1)
        let lightColor = skin.gridLightColor ?? defaultLight
        let darkColor = skin.gridDarkColor ?? defaultDark

        for row in 0..<GameConstants.gridSize {
            for col in 0..<GameConstants.gridSize {
                let x = gridOrigin.x + CGFloat(col) * cellSize
                let y = gridOrigin.y - CGFloat(row) * cellSize // SpriteKit y is inverted

                let cell = SKShapeNode(rectOf: CGSize(width: cellSize - 1, height: cellSize - 1), cornerRadius: 2)
                cell.position = CGPoint(x: x + cellSize / 2, y: y - cellSize / 2)
                cell.strokeColor = .clear

                let isLight = (row + col) % 2 == 0
                cell.fillColor = isLight ? lightColor : darkColor
                cell.name = "cell_\(row)_\(col)"
                gridNode.addChild(cell)
            }
        }
    }

    // MARK: - Tray Setup

    /// Draw a subtle background pill behind the piece tray area.
    private func setupTrayBackground() {
        let trayY = trayCenterY
        let gridWidth = cellSize * CGFloat(GameConstants.gridSize)
        let trayWidth = gridWidth + gridPadding * 2
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

    /// Y-center of the piece tray, scaled so the tray never clips off-screen.
    private var trayCenterY: CGFloat {
        cellSize * 1.25 + 30
    }

    /// Calculate the cell size that fits both width and height constraints.
    /// On iPhone: uses full width as before. On iPad: scales up proportionally
    /// but ensures the grid + tray + HUD all fit vertically.
    ///
    /// Vertical layout (bottom to top):
    ///   bottom padding(30) + tray center offset(1.25*cell) + tray top half(1.25*cell)
    ///   + gap(24) + grid(gridSize*cell) + HUD(60)
    /// Solving: 30 + 1.25c + 1.25c + 24 + gridSize*c + 60 = height
    ///          c * (gridSize + 2.5) = height - 114
    private func calculateCellSize() -> CGFloat {
        let gridSize = CGFloat(GameConstants.gridSize)
        let widthBased = (size.width - gridPadding * 2) / gridSize
        let heightBased = (size.height - 114) / (gridSize + 2.5)
        return min(widthBased, heightBased)
    }

    /// Calculate the top-left origin of the grid in scene coordinates.
    /// Centers the grid vertically between the HUD (top) and the tray (bottom).
    private func calculateGridOrigin(cellSize: CGFloat) -> CGPoint {
        let gridWidth = cellSize * CGFloat(GameConstants.gridSize)
        let gridHeight = cellSize * CGFloat(GameConstants.gridSize)
        let x = (size.width - gridWidth) / 2
        // Available vertical zone: below HUD, above tray
        let availableTop = size.height - 60
        let availableBottom = trayCenterY + cellSize * 1.25 + 16
        // Center the grid in this zone
        let centerY = (availableTop + availableBottom) / 2
        let y = centerY + gridHeight / 2
        return CGPoint(x: x, y: min(y, availableTop))
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
