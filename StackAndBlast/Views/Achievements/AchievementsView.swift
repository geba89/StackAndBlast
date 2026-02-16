import SwiftUI

/// Full-screen view showing all achievements in a 2-column grid.
struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manager = AchievementManager.shared

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
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(manager.achievements) { achievement in
                            AchievementCard(
                                achievement: achievement,
                                isUnlocked: manager.isUnlocked(achievement.id)
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Achievements")
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
}

// MARK: - Achievement Card

private struct AchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color(red: 0.882, green: 0.439, blue: 0.333) : Color.white.opacity(0.1))
                    .frame(width: 44, height: 44)

                if isUnlocked {
                    Image(systemName: achievement.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
            }

            // Name
            Text(achievement.name)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(isUnlocked ? .white : .gray)
                .multilineTextAlignment(.center)

            // Description
            Text(achievement.description)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Coin reward
            HStack(spacing: 4) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(isUnlocked ? Color(red: 0.0, green: 0.722, blue: 0.580) : .gray)
                Text(isUnlocked ? "Earned" : "+\(achievement.coinReward)")
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(isUnlocked ? Color(red: 0.0, green: 0.722, blue: 0.580) : .gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isUnlocked ? 0.08 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isUnlocked ? Color(red: 0.882, green: 0.439, blue: 0.333).opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}
