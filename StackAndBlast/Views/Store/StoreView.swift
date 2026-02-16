import SwiftUI
import StoreKit

/// Full-screen store for IAP products: remove ads, coin packs, skin bundles.
struct StoreView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.118, green: 0.153, blue: 0.180)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Coin balance header
                        CoinBalanceHeader()

                        // Starter bundle (time-limited offer)
                        if store.isStarterBundleAvailable,
                           let product = store.product(for: .starterBundle) {
                            StoreSection(title: "SPECIAL OFFER") {
                                StarterBundleCard(product: product)
                            }
                        }

                        // Remove Ads
                        if !store.hasRemovedAds,
                           let product = store.product(for: .removeAds) {
                            StoreSection(title: "REMOVE ADS") {
                                ProductCard(
                                    title: "Remove All Ads",
                                    description: "No more interstitials — play uninterrupted",
                                    icon: "nosign",
                                    product: product
                                )
                            }
                        }

                        // Coin Packs
                        StoreSection(title: "COIN PACKS") {
                            if let small = store.product(for: .coinPackSmall) {
                                ProductCard(
                                    title: "500 Coins",
                                    description: "A quick boost",
                                    icon: "bitcoinsign.circle.fill",
                                    product: small
                                )
                            }
                            if let large = store.product(for: .coinPackLarge) {
                                ProductCard(
                                    title: "3,000 Coins",
                                    description: "Best value — 6× more!",
                                    icon: "bitcoinsign.circle.fill",
                                    product: large,
                                    isBestValue: true
                                )
                            }
                        }

                        // Skin Bundles
                        StoreSection(title: "SKIN BUNDLES") {
                            if let neon = store.product(for: .skinBundleNeon) {
                                SkinBundleCard(
                                    skinName: "Neon",
                                    product: neon,
                                    isPurchased: store.purchasedSkinBundles.contains(neon.id)
                                )
                            }
                            if let galaxy = store.product(for: .skinBundleGalaxy) {
                                SkinBundleCard(
                                    skinName: "Galaxy",
                                    product: galaxy,
                                    isPurchased: store.purchasedSkinBundles.contains(galaxy.id)
                                )
                            }
                        }

                        // Restore Purchases
                        Button {
                            Task { await store.restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.gray)
                        }
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .task {
                if store.products.isEmpty {
                    await store.loadProducts()
                }
            }
        }
    }
}

// MARK: - Coin Balance Header

private struct CoinBalanceHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            Text("\(CoinManager.shared.balance)")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text("coins")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Store Section

private struct StoreSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.gray)
                .padding(.horizontal)

            VStack(spacing: 8) {
                content
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Product Card

private struct ProductCard: View {
    let title: String
    let description: String
    let icon: String
    let product: Product
    var isBestValue: Bool = false

    @State private var store = StoreManager.shared

    var body: some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.yellow, in: Capsule())
                        }
                    }
                    Text(description)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.gray)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.0, green: 0.722, blue: 0.580), in: Capsule())
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(store.isPurchasing)
    }
}

// MARK: - Starter Bundle Card

private struct StarterBundleCard: View {
    let product: Product
    @State private var store = StoreManager.shared

    var body: some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "star.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("STARTER BUNDLE")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.black)
                        Text("Remove Ads + 1,000 Coins")
                            .font(.system(.subheadline, design: .rounded))
                        Text("Limited time — first 3 days only!")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.yellow)
                    }
                    Spacer()
                }

                Text(product.displayPrice)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .foregroundStyle(.black)
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.yellow.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .disabled(store.isPurchasing)
        .padding(.horizontal)
    }
}

// MARK: - Skin Bundle Card

private struct SkinBundleCard: View {
    let skinName: String
    let product: Product
    let isPurchased: Bool
    @State private var store = StoreManager.shared

    var body: some View {
        Button {
            if !isPurchased {
                Task { await store.purchase(product) }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.424, green: 0.361, blue: 0.906))
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(skinName) Skin")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    Text("Unlock the \(skinName) block skin")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.gray)
                }

                Spacer()

                if isPurchased {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.0, green: 0.722, blue: 0.580))
                } else {
                    Text(product.displayPrice)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.424, green: 0.361, blue: 0.906), in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isPurchased || store.isPurchasing)
    }
}
