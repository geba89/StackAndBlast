import Foundation

/// Something that happened during a game that daily missions can count.
enum MissionEvent {
    /// A regular blast (not a power-up clear) of `size` blocks of one color.
    case blast(color: BlockColor, size: Int)
    /// How many blasts one move caused.
    case combo(Int)
    /// A normal piece was placed.
    case piecePlaced
    /// A power-up piece was used.
    case powerUpUsed
    /// The current game's score after a move.
    case score(Int)
    /// A game in this mode ended.
    case gameFinished(GameMode)
}

/// One of the three small goals of the day, e.g. "Blast 3 blue groups".
struct DailyMission: Equatable {

    enum Kind: Equatable {
        case blastColor(BlockColor) // blast N groups of one color
        case blasts                 // trigger N blasts
        case bigBlast               // blast one group of N+ blocks
        case combo                  // get a ×N combo in one move
        case score                  // score N in one game
        case pieces                 // place N pieces
        case powerUps               // use N power-ups
        case playBlastRush          // finish a Blast Rush game
        case finishDaily            // finish today's Daily Challenge
    }

    let kind: Kind
    /// How much progress completes the mission.
    let target: Int
    /// Coins paid when it's completed.
    let reward: Int

    /// Player-facing description.
    var title: String {
        switch kind {
        case .blastColor(let color): return "Blast \(target) \(color.missionName) groups"
        case .blasts:                return "Trigger \(target) blasts"
        case .bigBlast:              return "Blast a group of \(target)+ blocks"
        case .combo:                 return "Get a ×\(target) combo in one move"
        case .score:                 return "Score \(target.grouped) in one game"
        case .pieces:                return "Place \(target) pieces"
        case .powerUps:              return target == 1 ? "Use a power-up" : "Use \(target) power-ups"
        case .playBlastRush:         return "Play a game of Blast Rush"
        case .finishDaily:           return "Finish today's Daily Challenge"
        }
    }

    /// SF Symbol shown next to the mission.
    var icon: String {
        switch kind {
        case .blastColor, .blasts: return "flame.fill"
        case .bigBlast:            return "burst.fill"
        case .combo:               return "link"
        case .score:               return "star.fill"
        case .pieces:              return "square.grid.2x2.fill"
        case .powerUps:            return "bolt.fill"
        case .playBlastRush:       return "timer"
        case .finishDaily:         return "calendar"
        }
    }

    /// Progress after `event`, starting from `current`. Counting missions add one per
    /// matching event; "reach a value" missions (big blast, combo, score) keep the best
    /// value seen. Never exceeds the target.
    func progress(after event: MissionEvent, from current: Int) -> Int {
        let updated: Int
        switch (kind, event) {
        case (.blastColor(let wanted), .blast(let color, _)) where color == wanted:
            updated = current + 1
        case (.blasts, .blast):
            updated = current + 1
        case (.bigBlast, .blast(_, let size)):
            updated = max(current, size)
        case (.combo, .combo(let count)):
            updated = max(current, count)
        case (.score, .score(let points)):
            updated = max(current, points)
        case (.pieces, .piecePlaced):
            updated = current + 1
        case (.powerUps, .powerUpUsed):
            updated = current + 1
        case (.playBlastRush, .gameFinished(.blastRush)),
             (.finishDaily, .gameFinished(.dailyChallenge)):
            updated = current + 1
        default:
            updated = current
        }
        return min(updated, target)
    }
}

// MARK: - Picking the Day's Missions

extension DailyMission {

    /// Today's three missions — one easy, one medium, one hard — the same for every
    /// player on the same day (seeded by the day key, like the Daily Challenge).
    static func missions(forDay dayKey: String) -> [DailyMission] {
        var rng = SeededRandomNumberGenerator(seed: PieceGenerator.seedForKey("missions-" + dayKey))
        let color = BlockColor.allCases.randomElement(using: &rng)!

        let easy = [
            DailyMission(kind: .pieces, target: 30, reward: 30),
            DailyMission(kind: .blasts, target: 5, reward: 30),
            DailyMission(kind: .blastColor(color), target: 2, reward: 30),
            DailyMission(kind: .powerUps, target: 1, reward: 30),
            DailyMission(kind: .playBlastRush, target: 1, reward: 30),
        ]
        let medium = [
            DailyMission(kind: .score, target: 1_500, reward: 50),
            DailyMission(kind: .combo, target: 2, reward: 50),
            DailyMission(kind: .blasts, target: 12, reward: 50),
            DailyMission(kind: .blastColor(color), target: 4, reward: 50),
            DailyMission(kind: .powerUps, target: 3, reward: 50),
            DailyMission(kind: .finishDaily, target: 1, reward: 50),
        ]
        let hard = [
            DailyMission(kind: .score, target: 3_000, reward: 80),
            DailyMission(kind: .combo, target: 3, reward: 80),
            DailyMission(kind: .bigBlast, target: 14, reward: 80),
            DailyMission(kind: .blasts, target: 25, reward: 80),
            DailyMission(kind: .pieces, target: 120, reward: 80),
        ]

        // One from each tier, never two of the same kind on the same day
        var picked: [DailyMission] = []
        for pool in [easy, medium, hard] {
            let fresh = pool.filter { candidate in !picked.contains { $0.kind.family == candidate.kind.family } }
            picked.append(fresh.randomElement(using: &rng)!)
        }
        return picked
    }
}

extension DailyMission.Kind {
    /// Kinds that would feel like the same goal twice ("blast N blue groups" and
    /// "trigger N blasts" count as different; the same case twice does not).
    var family: String {
        switch self {
        case .blastColor:    return "blastColor"
        case .blasts:        return "blasts"
        case .bigBlast:      return "bigBlast"
        case .combo:         return "combo"
        case .score:         return "score"
        case .pieces:        return "pieces"
        case .powerUps:      return "powerUps"
        case .playBlastRush: return "playBlastRush"
        case .finishDaily:   return "finishDaily"
        }
    }
}

extension BlockColor {
    /// Color name for mission texts ("Blast 3 blue groups").
    var missionName: String {
        switch self {
        case .coral:  return "coral"
        case .blue:   return "blue"
        case .purple: return "purple"
        case .green:  return "green"
        case .yellow: return "yellow"
        case .pink:   return "pink"
        }
    }
}
