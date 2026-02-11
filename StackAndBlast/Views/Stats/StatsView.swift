import SwiftUI

/// Displays lifetime gameplay statistics in a 2-column grid.
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss

    private let stats = StatsManager.shared
    private let scoreManager = ScoreManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.118, green: 0.153, blue: 0.180)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        LazyVGrid(columns: columns, spacing: 12) {
                            StatCard(title: "Games Played", value: "\(stats.totalGamesPlayed)", icon: "gamecontroller.fill")
                            StatCard(title: "Total Score", value: formatNumber(stats.totalScore), icon: "star.fill")
                            StatCard(title: "Total Blasts", value: "\(stats.totalBlasts)", icon: "flame.fill")
                            StatCard(title: "Pieces Placed", value: formatNumber(stats.totalPiecesPlaced), icon: "square.grid.3x3.fill")
                            StatCard(title: "Best Combo", value: "\(stats.highestCombo)x", icon: "bolt.fill")
                            StatCard(title: "Best Score", value: formatNumber(stats.highestSingleGameScore), icon: "trophy.fill")
                        }

                        // High scores by game mode
                        VStack(spacing: 0) {
                            Text("HIGH SCORES")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 12)

                            HighScoreRow(label: "Classic", score: scoreManager.classicHighScore, icon: "flame.fill")
                            HighScoreRow(label: "Daily Challenge", score: scoreManager.dailyChallengeHighScore, icon: "calendar")
                            HighScoreRow(label: "Blast Rush", score: scoreManager.blastRushHighScore, icon: "bolt.fill")
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }
            }
            .navigationTitle("Lifetime Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 10_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}

// MARK: - High Score Row

private struct HighScoreRow: View {
    let label: String
    let score: Int
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.882, green: 0.439, blue: 0.333))
                .frame(width: 20)
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("\(score)")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color(red: 0.882, green: 0.439, blue: 0.333))

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}
