import Foundation
import Observation

/// Central coin currency manager. Tracks balance, earnings, and spending.
/// Coins are earned from gameplay, ads, achievements, daily rewards, and IAP.
@Observable
final class CoinManager {

    static let shared = CoinManager()

    private let defaults = UserDefaults.standard

    // MARK: - State

    private(set) var balance: Int {
        didSet { defaults.set(balance, forKey: "coin_balance") }
    }

    private(set) var totalEarned: Int {
        didSet { defaults.set(totalEarned, forKey: "coin_totalEarned") }
    }

    private(set) var totalSpent: Int {
        didSet { defaults.set(totalSpent, forKey: "coin_totalSpent") }
    }

    // MARK: - Init

    private init() {
        balance = defaults.integer(forKey: "coin_balance")
        totalEarned = defaults.integer(forKey: "coin_totalEarned")
        totalSpent = defaults.integer(forKey: "coin_totalSpent")
    }

    // MARK: - Actions

    /// Award coins from a specific source (gameplay, ad, achievement, etc.).
    func earn(_ amount: Int, source: String) {
        guard amount > 0 else { return }
        balance += amount
        totalEarned += amount
    }

    /// Spend coins. Returns false if insufficient balance.
    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard amount > 0, balance >= amount else { return false }
        balance -= amount
        totalSpent += amount
        return true
    }

    /// Check if the player can afford a given cost.
    func canAfford(_ amount: Int) -> Bool {
        balance >= amount
    }

    // MARK: - Score-to-Coins Conversion

    /// Convert a game score into coins. Higher scores yield proportionally more.
    static func coinsForScore(_ score: Int) -> Int {
        switch score {
        case 0..<100:    return 10
        case 100..<500:  return 20
        case 500..<1000: return 30
        case 1000..<2000: return 50
        case 2000..<5000: return 75
        default:          return 100
        }
    }
}
