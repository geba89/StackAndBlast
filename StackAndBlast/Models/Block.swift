import Foundation

/// The 6 block colors defined in the GDD (section 5.1).
enum BlockColor: Int, CaseIterable, Codable {
    case coral   // #E17055
    case blue    // #0984E3
    case purple  // #6C5CE7
    case green   // #00B894
    case yellow  // #FDCB6E
    case pink    // #FD79A8
}

/// A single block occupying one cell on the grid.
struct Block: Identifiable, Hashable {
    let id: UUID
    let color: BlockColor
    var position: GridPosition

    init(color: BlockColor, position: GridPosition, id: UUID = UUID()) {
        self.id = id
        self.color = color
        self.position = position
    }
}
