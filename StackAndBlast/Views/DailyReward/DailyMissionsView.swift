import SwiftUI

/// Sheet listing today's three missions with their progress and rewards,
/// plus the bonus for completing all three.
struct DailyMissionsView: View {
    @Environment(\.dismiss) private var dismiss

    /// Hold a reference so SwiftUI's Observation tracks mission progress.
    private let manager = MissionManager.shared

    private let coral = Color(red: 0.882, green: 0.439, blue: 0.333)
    private let green = Color(red: 0.0, green: 0.722, blue: 0.580)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Refreshes every minute
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text("New missions in \(Self.timeUntilMidnight(from: context.date))")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.gray)
                    }
                    .padding(.bottom, 4)

                    ForEach(manager.missions.indices, id: \.self) { index in
                        MissionRow(
                            mission: manager.missions[index],
                            progress: manager.progress[index],
                            isCompleted: manager.isCompleted(index),
                            accent: coral,
                            doneColor: green
                        )
                    }

                    // Bonus for finishing all three
                    HStack(spacing: 14) {
                        Image(systemName: manager.bonusAwarded ? "checkmark.seal.fill" : "gift.fill")
                            .font(.title2)
                            .foregroundStyle(manager.bonusAwarded ? green : .yellow)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Complete all 3 missions")
                                .font(.system(.subheadline, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text("\(manager.completedCount)/\(manager.missions.count) done")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        CoinReward(amount: MissionManager.allCompleteBonus, isPaid: manager.bonusAwarded)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1))

                    Text("Missions count in Classic, Blast Rush and the Daily Challenge. Coins are added as soon as a mission is done.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.118, green: 0.153, blue: 0.180).ignoresSafeArea())
            .navigationTitle("Daily Missions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            manager.refreshIfNewDay()
        }
    }

    /// "5h 12m" until local midnight, when the next missions arrive.
    static func timeUntilMidnight(from now: Date) -> String {
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        let minutes = max(0, Int(tomorrow.timeIntervalSince(now) / 60))
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// One mission: icon, description, progress bar and coin reward.
private struct MissionRow: View {
    let mission: DailyMission
    let progress: Int
    let isCompleted: Bool
    let accent: Color
    let doneColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : mission.icon)
                .font(.title2)
                .foregroundStyle(isCompleted ? doneColor : accent)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text(mission.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(isCompleted ? .gray : .white)
                    .strikethrough(isCompleted, color: .gray)
                ProgressView(value: Double(progress), total: Double(mission.target))
                    .tint(isCompleted ? doneColor : accent)
                Text("\(progress)/\(mission.target)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.gray)
            }

            Spacer(minLength: 8)

            CoinReward(amount: mission.reward, isPaid: isCompleted)
        }
        .padding()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// "+30" coins, dimmed once it has been paid out.
private struct CoinReward: View {
    let amount: Int
    let isPaid: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bitcoinsign.circle.fill")
            Text("+\(amount)")
                .fontWeight(.bold)
        }
        .font(.system(.subheadline, design: .rounded))
        .foregroundStyle(isPaid ? .gray : .yellow)
    }
}
