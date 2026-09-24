import SwiftUI
import UIKit

/// Branded score card rendered as an image for sharing.
struct ScoreCardView: View {
    let score: Int
    let blasts: Int
    let maxCombo: Int
    let piecesPlaced: Int
    let gameMode: GameMode

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text("STACK & BLAST")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(gameModeLabel)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.candyGold)
            }

            // Score
            VStack(spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray)
                OutlinedTitle(text: score.grouped, size: 48)
            }

            // Stats row
            HStack(spacing: 20) {
                MiniStat(label: "BLASTS", value: "\(blasts)")
                MiniStat(label: "COMBO", value: maxCombo > 0 ? "×\(maxCombo)" : "-")
                MiniStat(label: "PIECES", value: "\(piecesPlaced)")
            }

            // Call to action
            Text("Can you beat me?")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))
                .italic()
        }
        .padding(24)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(colors: [.candyTop, .candyMid, .candyBottom],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private var gameModeLabel: String {
        switch gameMode {
        case .classic: return "Classic Mode"
        case .dailyChallenge: return "Daily Challenge"
        case .blastRush: return "Blast Rush"
        case .tutorial: return "Tutorial"
        }
    }
}

// MARK: - Mini Stat

private struct MiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.gray)
        }
    }
}

// MARK: - Share Helper

/// Renders the ScoreCardView to a UIImage and presents a share sheet.
enum ShareHelper {

    @MainActor
    static func shareScoreCard(
        score: Int,
        blasts: Int,
        maxCombo: Int,
        piecesPlaced: Int,
        gameMode: GameMode,
        dailySummary: String? = nil
    ) {
        let cardView = ScoreCardView(
            score: score,
            blasts: blasts,
            maxCombo: maxCombo,
            piecesPlaced: piecesPlaced,
            gameMode: gameMode
        )

        // Render the SwiftUI view to a UIImage
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = UIScreen.main.scale

        guard let image = renderer.uiImage else { return }

        // TODO: Replace with actual App Store URL
        let appStoreURL = "https://apps.apple.com/app/stack-and-blast/id000000000"
        // Daily Challenge: the Wordle-style emoji summary (everyone had the same pieces)
        let text = dailySummary.map { "\($0)\n\(appStoreURL)" }
            ?? "I scored \(score) in Stack & Blast! Can you beat me? \(appStoreURL)"

        let activityVC = UIActivityViewController(
            activityItems: [image, text],
            applicationActivities: nil
        )

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // iPad requires popover source
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(
                x: rootVC.view.bounds.midX,
                y: rootVC.view.bounds.midY,
                width: 0, height: 0
            )
        }

        rootVC.present(activityVC, animated: true)

        AnalyticsManager.shared.logShareScore(score: score, mode: gameMode.analyticsName)
    }
}

// MARK: - GameMode Analytics Name

extension GameMode {
    var analyticsName: String {
        switch self {
        case .classic: return "classic"
        case .dailyChallenge: return "daily_challenge"
        case .blastRush: return "blast_rush"
        case .tutorial: return "tutorial"
        }
    }
}
