import Foundation
import Observation
import StoreKit

/// Manages in-app purchases via StoreKit 2.
/// Handles product loading, purchasing, transaction listening, and entitlement verification.
@Observable
final class StoreManager {

    static let shared = StoreManager()

    // MARK: - Product IDs

    enum ProductID: String, CaseIterable {
        case removeAds = "com.piotrgebski.StackAndBlast.removeAds"
        case coinPackSmall = "com.piotrgebski.StackAndBlast.coinPack.small"
        case coinPackLarge = "com.piotrgebski.StackAndBlast.coinPack.large"
        case starterBundle = "com.piotrgebski.StackAndBlast.starterBundle"
        case skinBundleNeon = "com.piotrgebski.StackAndBlast.skinBundle.neon"
        case skinBundleGalaxy = "com.piotrgebski.StackAndBlast.skinBundle.galaxy"
    }

    // MARK: - State

    /// All fetched products from the App Store.
    var products: [Product] = []

    /// Whether a purchase is currently in progress.
    var isPurchasing = false

    /// Whether the user has purchased the Remove Ads IAP.
    var hasRemovedAds: Bool {
        didSet { defaults.set(hasRemovedAds, forKey: "iap_hasRemovedAds") }
    }

    /// Whether the user has purchased the Starter Bundle.
    var hasStarterBundle: Bool {
        didSet { defaults.set(hasStarterBundle, forKey: "iap_hasStarterBundle") }
    }

    /// Set of purchased skin bundle product IDs.
    var purchasedSkinBundles: Set<String> {
        didSet { defaults.set(Array(purchasedSkinBundles), forKey: "iap_purchasedSkinBundles") }
    }

    /// Whether the starter bundle is still available (first 3 days after install).
    var isStarterBundleAvailable: Bool {
        guard !hasStarterBundle else { return false }
        guard let firstLaunch = defaults.object(forKey: "iap_firstLaunchDate") as? Date else {
            // First launch — record the date
            defaults.set(Date(), forKey: "iap_firstLaunchDate")
            return true
        }
        let daysSinceFirstLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
        return daysSinceFirstLaunch < 3
    }

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private var transactionTask: Task<Void, Never>?

    private init() {
        hasRemovedAds = defaults.bool(forKey: "iap_hasRemovedAds")
        hasStarterBundle = defaults.bool(forKey: "iap_hasStarterBundle")
        let savedBundles = defaults.stringArray(forKey: "iap_purchasedSkinBundles") ?? []
        purchasedSkinBundles = Set(savedBundles)

        // Record first launch date if not set
        if defaults.object(forKey: "iap_firstLaunchDate") == nil {
            defaults.set(Date(), forKey: "iap_firstLaunchDate")
        }
    }

    // MARK: - Transaction Listener

    /// Start listening for StoreKit transaction updates (renewals, revocations, etc.).
    /// Call once at app launch.
    func startTransactionListener() {
        transactionTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.handleVerifiedTransaction(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Load Products

    /// Fetch products from the App Store. Call early in app lifecycle.
    func loadProducts() async {
        do {
            let ids = ProductID.allCases.map(\.rawValue)
            print("[StoreManager] Loading products for IDs: \(ids)")
            products = try await Product.products(for: ids)
            print("[StoreManager] Loaded \(products.count) products: \(products.map { "\($0.displayName) — \($0.displayPrice)" })")
        } catch {
            print("[StoreManager] Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    /// Purchase a product. Returns true if the purchase was successful.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await handleVerifiedTransaction(transaction)
                    await transaction.finish()
                    AnalyticsManager.shared.logIAPPurchase(
                        productID: product.id,
                        price: product.displayPrice
                    )
                    return true
                }
                return false

            case .userCancelled, .pending:
                return false

            @unknown default:
                return false
            }
        } catch {
            print("[StoreManager] Purchase failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restore previously purchased products.
    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                await handleVerifiedTransaction(transaction)
            }
        }
    }

    // MARK: - Product Helpers

    /// Get a loaded product by its ID.
    func product(for id: ProductID) -> Product? {
        products.first(where: { $0.id == id.rawValue })
    }

    // MARK: - Private

    @MainActor
    private func handleVerifiedTransaction(_ transaction: Transaction) {
        guard let productID = ProductID(rawValue: transaction.productID) else { return }

        switch productID {
        case .removeAds:
            hasRemovedAds = true

        case .coinPackSmall:
            CoinManager.shared.earn(500, source: "iap_coin_pack_small")

        case .coinPackLarge:
            CoinManager.shared.earn(3000, source: "iap_coin_pack_large")

        case .starterBundle:
            hasStarterBundle = true
            hasRemovedAds = true
            CoinManager.shared.earn(1000, source: "iap_starter_bundle")

        case .skinBundleNeon:
            purchasedSkinBundles.insert(productID.rawValue)

        case .skinBundleGalaxy:
            purchasedSkinBundles.insert(productID.rawValue)
        }
    }
}
