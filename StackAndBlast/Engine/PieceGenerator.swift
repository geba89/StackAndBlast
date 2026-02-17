import Foundation

/// SplitMix64 deterministic RNG — produces the same sequence for a given seed
/// across all devices and process launches. Used for Daily Challenge mode.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

/// Generates piece trays using a weighted random bag system (GDD section 3.2).
///
/// Each tray of 3 pieces is drawn from a bag that guarantees at least one piece
/// of 3+ cells to keep the game playable. Difficulty scales by shifting weights
/// toward larger pieces as score increases.
///
/// Supports deterministic output via `setSeed()` for Daily Challenge mode.
final class PieceGenerator {

    /// Optional seeded RNG for deterministic piece generation (Daily Challenge).
    private var seededRNG: SeededRandomNumberGenerator?

    /// Tracks tray count to determine when to include a power-up piece.
    private var trayCount: Int = 0

    // MARK: - Seed Control

    /// Enable deterministic mode with the given seed (for Daily Challenge).
    func setSeed(_ seed: UInt64) {
        seededRNG = SeededRandomNumberGenerator(seed: seed)
        trayCount = 0
    }

    /// Return to system random (for Classic / Blast Rush modes).
    func clearSeed() {
        seededRNG = nil
        trayCount = 0
    }

    /// Compute a stable seed from a date string using FNV-1a hash.
    /// Unlike `String.hashValue`, this is deterministic across processes and devices.
    static func seedForDate(_ date: Date = Date()) -> UInt64 {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: date)
        return fnv1aHash(dateString)
    }

    // MARK: - Tray Generation

    /// Generate a tray of 3 random pieces. Every few trays, one piece is replaced with a power-up.
    func generateTray() -> [Piece] {
        trayCount += 1
        var pieces: [Piece] = []

        // Guarantee at least one piece of 3+ cells
        let guaranteed = randomTemplate(minCells: 3)
        pieces.append(pieceFromTemplate(guaranteed))

        // Check if this tray should include a power-up piece (every 3rd tray, starting from tray 2)
        let includePowerUp = trayCount >= 2 && trayCount % GameConstants.powerUpTrayInterval == 0

        // Fill remaining slots with weighted random pieces (or a power-up)
        for i in 1..<GameConstants.piecesPerTray {
            if includePowerUp && i == 1 {
                pieces.append(createPowerUpPiece())
            } else {
                let template = randomTemplate()
                pieces.append(pieceFromTemplate(template))
            }
        }

        return shuffled(pieces)
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
        let roll: Double
        if var rng = seededRNG {
            roll = Double.random(in: 0..<totalWeight, using: &rng)
            seededRNG = rng
        } else {
            roll = Double.random(in: 0..<totalWeight)
        }

        var remaining = roll
        for template in templates {
            remaining -= template.category.weight
            if remaining <= 0 {
                return template
            }
        }

        return templates.last!
    }

    /// Create a Piece from a template with a random color.
    private func pieceFromTemplate(_ template: PieceDefinitions.Template) -> Piece {
        let color: BlockColor
        if var rng = seededRNG {
            color = BlockColor.allCases.randomElement(using: &rng)!
            seededRNG = rng
        } else {
            color = BlockColor.allCases.randomElement()!
        }
        return Piece(cells: template.cells, color: color)
    }

    /// Create a single-cell power-up piece with a random power-up type.
    private func createPowerUpPiece() -> Piece {
        let powerUp: PowerUpType
        let color: BlockColor
        if var rng = seededRNG {
            powerUp = PowerUpType.allCases.randomElement(using: &rng)!
            color = BlockColor.allCases.randomElement(using: &rng)!
            seededRNG = rng
        } else {
            powerUp = PowerUpType.allCases.randomElement()!
            color = BlockColor.allCases.randomElement()!
        }
        // Power-up pieces are always single-cell
        return Piece(cells: [GridPosition(row: 0, col: 0)], color: color, powerUp: powerUp)
    }

    /// Shuffle using the seeded RNG when set, otherwise system random.
    private func shuffled(_ array: [Piece]) -> [Piece] {
        if var rng = seededRNG {
            let result = array.shuffled(using: &rng)
            seededRNG = rng
            return result
        }
        return array.shuffled()
    }

    // MARK: - FNV-1a Hash

    /// FNV-1a 64-bit hash — deterministic across all processes and devices.
    private static func fnv1aHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037 // FNV offset basis
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211 // FNV prime
        }
        return hash
    }
}
