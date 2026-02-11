import SwiftUI

/// Grid of skin cards showing all available themes with lock/unlock status.
struct SkinPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activeSkinID = SettingsManager.shared.activeSkinID

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
                        ForEach(SkinManager.shared.skins, id: \.id) { skin in
                            SkinCard(
                                skin: skin,
                                isActive: activeSkinID == skin.id,
                                onSelect: {
                                    activeSkinID = skin.id
                                    SettingsManager.shared.activeSkinID = skin.id
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Block Skins")
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

// MARK: - Skin Card

private struct SkinCard: View {
    let skin: SkinDefinition
    let isActive: Bool
    let onSelect: () -> Void

    private var isUnlocked: Bool { skin.isUnlocked() }

    var body: some View {
        Button(action: {
            if isUnlocked { onSelect() }
        }) {
            VStack(spacing: 8) {
                // Skin name
                Text(skin.name)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(isUnlocked ? .white : .gray)

                // 6-color palette preview
                HStack(spacing: 4) {
                    ForEach(BlockColor.allCases, id: \.rawValue) { color in
                        Circle()
                            .fill(Color(uiColor: skin.colors[color] ?? color.uiColor))
                            .frame(width: 20, height: 20)
                    }
                }

                // Lock/unlock status
                if !isUnlocked {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text(skin.unlockCondition)
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundStyle(.gray)
                } else if isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Active")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color(red: 0.0, green: 0.722, blue: 0.580))
                } else {
                    Text("Tap to select")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isActive ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isActive ? Color(red: 0.0, green: 0.722, blue: 0.580) : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .opacity(isUnlocked ? 1.0 : 0.6)
        }
        .disabled(!isUnlocked)
    }
}
