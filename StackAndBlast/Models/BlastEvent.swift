import Foundation

/// A block that was pushed by the blast shockwave.
struct PushedBlock {
    let blockID: UUID
    let from: GridPosition
    /// New position after push. Nil means pushed off the grid (destroyed).
    let to: GridPosition?
}

/// A power-up that was triggered when its block was blasted.
struct TriggeredPowerUp {
    let type: PowerUpType
    let position: GridPosition
    let color: BlockColor
}

/// Describes a single blast event (one color group cleared at one cascade level).
/// Used by the rendering layer to orchestrate blast animations in sequence.
struct BlastEvent {
    /// All grid positions cleared by this group.
    let clearedPositions: [GridPosition]

    /// Block UUIDs that were removed (for node lookup in the scene).
    let clearedBlockIDs: [UUID]

    /// The color of the group that was cleared (for color-matched particles).
    let groupColor: BlockColor

    /// The cascade level (0 = initial blast, 1 = first cascade, etc.).
    let cascadeLevel: Int

    /// Blocks pushed outward by the blast shockwave.
    let pushedBlocks: [PushedBlock]

    /// Power-ups that were inside this blast group and should fire their effects.
    let triggeredPowerUps: [TriggeredPowerUp]

    /// If this event represents a power-up clear (not a regular blast), the type of power-up.
    let powerUpSource: PowerUpType?

    /// The grid position where the power-up block was (for drawing row/column flash lines).
    let powerUpOrigin: GridPosition?

    /// Number of cells cleared in this group.
    var groupSize: Int { clearedPositions.count }
}
