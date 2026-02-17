import GameKit
import UIKit

/// Manages Game Center authentication, leaderboard score submission, and leaderboard UI presentation.
@Observable
final class LeaderboardManager: NSObject {

    static let shared = LeaderboardManager()

    // MARK: - Leaderboard IDs (must match App Store Connect configuration)

    private enum LeaderboardID {
        static let classic = "classic_highscore"
        static let blastRush = "blast_rush_highscore"
        static let dailyChallenge = "daily_challenge_highscore"
    }

    // MARK: - State

    /// Whether the local player is authenticated with Game Center.
    private(set) var isAuthenticated: Bool = false

    private override init() {
        super.init()
    }

    // MARK: - Authentication

    /// Authenticate the local player with Game Center.
    /// Call once at app launch. If the player isn't signed in, GameKit shows a sign-in prompt.
    func configure() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }

            if let error {
                print("[LeaderboardManager] Auth failed: \(error.localizedDescription)")
                self.isAuthenticated = false
                return
            }

            if let vc = viewController {
                // GameKit wants to present a sign-in view controller
                self.presentViewController(vc)
                return
            }

            // Successfully authenticated
            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            if self.isAuthenticated {
                print("[LeaderboardManager] Authenticated as \(GKLocalPlayer.local.displayName)")
            }
        }
    }

    // MARK: - Score Submission

    /// Submit a score to the leaderboard matching the given game mode.
    func submitScore(_ score: Int, mode: GameMode) {
        guard isAuthenticated, score > 0 else { return }

        let leaderboardID = leaderboardID(for: mode)
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                   leaderboardIDs: [leaderboardID]) { error in
            if let error {
                print("[LeaderboardManager] Score submit failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Leaderboard UI

    /// Present the Game Center leaderboard view controller.
    func showLeaderboard() {
        guard isAuthenticated else { return }

        let gcVC = GKGameCenterViewController(state: .leaderboards)
        gcVC.gameCenterDelegate = self
        presentViewController(gcVC)
    }

    // MARK: - Helpers

    private func leaderboardID(for mode: GameMode) -> String {
        switch mode {
        case .classic:        return LeaderboardID.classic
        case .blastRush:      return LeaderboardID.blastRush
        case .dailyChallenge: return LeaderboardID.dailyChallenge
        }
    }

    private func presentViewController(_ vc: UIViewController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Walk the presentation chain to find the topmost presented VC
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(vc, animated: true)
    }
}

// MARK: - GKGameCenterControllerDelegate

extension LeaderboardManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
