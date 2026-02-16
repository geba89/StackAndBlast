import SwiftUI

/// Grid of skin cards showing all available themes with lock/unlock/buy status.
struct SkinPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var activeSkinID = SettingsManager.shared.activeSkinID
    /// Toggled after coin purchases to force re-evaluation of unlock state.
    @State private var purchaseTrigger = false

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
                    // Coin balance header
                    HStack(spacing: 4) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        Text("\(CoinManager.shared.balance) coins")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.yellow)
                    }
                    .padding(.top, 8)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(SkinManager.shared.skins, id: \.id) { skin in
                            SkinCard(
                                skin: skin,
                                isActive: activeSkinID == skin.id,
                                purchaseTrigger: purchaseTrigger,
                                onSelect: {
                                    activeSkinID = skin.id
                                    SettingsManager.shared.activeSkinID = skin.id
                                    AnalyticsManager.shared.logSkinSelected(skinID: skin.id)
                                },
                                onCoinPurchase: {
                                    purchaseTrigger.toggle()
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
    /// Forces re-evaluation of unlock state after coin purchase.
    let purchaseTrigger: Bool
    let onSelect: () -> Void
    let onCoinPurchase: () -> Void

    /// Check if skin is unlocked via gameplay, coin purchase, OR IAP bundle.
    private var isUnlocked: Bool {
        // Touch purchaseTrigger to ensure SwiftUI re-evaluates after coin buys
        _ = purchaseTrigger
        if skin.isUnlocked() { return true }
        // Check IAP skin bundles
        let store = StoreManager.shared
        if skin.id == "neon" && store.purchasedSkinBundles.contains(StoreManager.ProductID.skinBundleNeon.rawValue) {
            return true
        }
        if skin.id == "galaxy" && store.purchasedSkinBundles.contains(StoreManager.ProductID.skinBundleGalaxy.rawValue) {
            return true
        }
        return false
    }

    /// Whether this skin can be bought via IAP.
    private var iapProductID: StoreManager.ProductID? {
        switch skin.id {
        case "neon": return .skinBundleNeon
        case "galaxy": return .skinBundleGalaxy
        default: return nil
        }
    }

    var body: some View {
        Button(action: {
            if isUnlocked { onSelect() }
        }) {
            VStack(spacing: 8) {
                // Skin name + animated badge
                HStack(spacing: 6) {
                    Text(skin.name)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(isUnlocked ? .white : .gray)

                    if skin.animationType != nil {
                        Text("ANIMATED")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }
                }

                // 6-color palette preview
                HStack(spacing: 4) {
                    ForEach(BlockColor.allCases, id: \.rawValue) { color in
                        Circle()
                            .fill(Color(uiColor: skin.colors[color] ?? color.uiColor))
                            .frame(width: 20, height: 20)
                    }
                }

                // Lock/unlock/buy status
                if !isUnlocked {
                    if let productID = iapProductID,
                       let product = StoreManager.shared.product(for: productID) {
                        // Can buy via IAP
                        Button {
                            Task { await StoreManager.shared.purchase(product) }
                        } label: {
                            Text("Buy \(product.displayPrice)")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.424, green: 0.361, blue: 0.906), in: Capsule())
                        }
                    } else if let price = skin.coinPrice {
                        // Can buy with coins
                        Button {
                            if SkinManager.shared.purchaseSkin(skin.id) {
                                onCoinPurchase()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bitcoinsign.circle.fill")
                                    .font(.caption)
                                Text("\(price)")
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Color.yellow.opacity(
                                    CoinManager.shared.canAfford(price) ? 0.15 : 0.05
                                ),
                                in: Capsule()
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(!CoinManager.shared.canAfford(price))
                        .opacity(CoinManager.shared.canAfford(price) ? 1.0 : 0.5)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                            Text(skin.unlockCondition)
                                .font(.system(.caption2, design: .rounded))
                        }
                        .foregroundStyle(.gray)
                    }
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
