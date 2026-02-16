import AppTrackingTransparency
import GoogleMobileAds
import UIKit

/// Manages all ad placements: bomb rewarded ad, double-score rewarded ad, and interstitials.
final class AdManager: NSObject {

    static let shared = AdManager()

    // MARK: - Ad Readiness State

    /// Whether the bomb rewarded ad is loaded and ready.
    private(set) var isRewardedAdReady: Bool = false

    /// Whether the double-score rewarded ad is loaded and ready.
    private(set) var isDoubleScoreAdReady: Bool = false

    /// Whether an interstitial ad is loaded and ready.
    private(set) var isInterstitialReady: Bool = false

    // MARK: - Ad Unit IDs (replace with real IDs from AdMob console)

    private let bombRewardedAdUnitID = "ca-app-pub-2741592186352961/8805323485"
    // TODO: Replace with real ad unit IDs from AdMob console
    private let doubleScoreRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313" // Test ID
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Test ID

    // MARK: - Ad Instances

    private var bombRewardedAd: GADRewardedAd?
    private var doubleScoreRewardedAd: GADRewardedAd?
    private var interstitialAd: GADInterstitialAd?

    // MARK: - Callbacks

    private var bombRewardCompletion: ((Bool) -> Void)?
    private var doubleScoreRewardCompletion: ((Bool) -> Void)?
    private var interstitialCompletion: (() -> Void)?

    // MARK: - Frequency Capping

    /// Number of interstitials shown this session (max 3).
    private var interstitialsShownThisSession = 0
    private let maxInterstitialsPerSession = 3

    /// Show interstitial every N games.
    private let interstitialFrequency = 3

    private override init() {
        super.init()
    }

    // MARK: - SDK Init

    /// Initialize the Google Mobile Ads SDK and preload all ad types.
    func configure() {
        GADMobileAds.sharedInstance().start { _ in
            self.loadBombRewardedAd()
            self.loadDoubleScoreAd()
            self.loadInterstitialAd()
        }
    }

    /// Request ATT permission, then initialize the AdMob SDK.
    func requestTrackingThenConfigure() {
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async {
                self.configure()
            }
        }
    }

    // MARK: - Bomb Rewarded Ad

    func loadBombRewardedAd() {
        loadBombRewardedAd(completion: nil)
    }

    func loadBombRewardedAd(completion: ((Bool) -> Void)?) {
        GADRewardedAd.load(withAdUnitID: bombRewardedAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { completion?(false); return }
            if let error {
                print("[AdManager] Failed to load bomb rewarded ad: \(error.localizedDescription)")
                self.bombRewardedAd = nil
                self.isRewardedAdReady = false
                completion?(false)
                return
            }
            self.bombRewardedAd = ad
            self.bombRewardedAd?.fullScreenContentDelegate = self
            self.isRewardedAdReady = true
            completion?(true)
        }
    }

    /// Present the bomb rewarded ad. Calls completion with `true` if reward was earned.
    func showRewardedAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let ad = bombRewardedAd else {
            completion(false)
            return
        }

        bombRewardCompletion = completion
        ad.present(fromRootViewController: viewController) { [weak self] in
            self?.bombRewardCompletion?(true)
            self?.bombRewardCompletion = nil
        }
    }

    // MARK: - Double-Score Rewarded Ad

    func loadDoubleScoreAd() {
        GADRewardedAd.load(withAdUnitID: doubleScoreRewardedAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("[AdManager] Failed to load double-score ad: \(error.localizedDescription)")
                self.doubleScoreRewardedAd = nil
                self.isDoubleScoreAdReady = false
                return
            }
            self.doubleScoreRewardedAd = ad
            self.doubleScoreRewardedAd?.fullScreenContentDelegate = self
            self.isDoubleScoreAdReady = true
        }
    }

    /// Present the double-score rewarded ad. Calls completion with `true` if reward was earned.
    func showDoubleScoreAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let ad = doubleScoreRewardedAd else {
            completion(false)
            return
        }

        doubleScoreRewardCompletion = completion
        ad.present(fromRootViewController: viewController) { [weak self] in
            self?.doubleScoreRewardCompletion?(true)
            self?.doubleScoreRewardCompletion = nil
        }
    }

    // MARK: - Interstitial Ad

    func loadInterstitialAd() {
        GADInterstitialAd.load(withAdUnitID: interstitialAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                print("[AdManager] Failed to load interstitial: \(error.localizedDescription)")
                self.interstitialAd = nil
                self.isInterstitialReady = false
                return
            }
            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
            self.isInterstitialReady = true
        }
    }

    /// Show interstitial if frequency and cap conditions are met.
    /// Skips if user has purchased Remove Ads IAP.
    func showInterstitialIfNeeded(sessionGameCount: Int, completion: @escaping () -> Void) {
        // Skip if user paid to remove ads
        if StoreManager.shared.hasRemovedAds {
            completion()
            return
        }

        // Frequency: every Nth game, starting from game 3
        guard sessionGameCount > 0, sessionGameCount % interstitialFrequency == 0 else {
            completion()
            return
        }

        // Session cap
        guard interstitialsShownThisSession < maxInterstitialsPerSession else {
            completion()
            return
        }

        guard let ad = interstitialAd, let rootVC = rootViewController() else {
            completion()
            return
        }

        interstitialCompletion = completion
        interstitialsShownThisSession += 1
        AnalyticsManager.shared.logInterstitialShown(sessionGameCount: sessionGameCount)
        ad.present(fromRootViewController: rootVC)
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        return windowScene.windows.first?.rootViewController
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        // Identify which ad was dismissed using identity comparison
        if let bombAd = bombRewardedAd, ad === bombAd {
            if let completion = bombRewardCompletion {
                completion(false)
                bombRewardCompletion = nil
            }
            isRewardedAdReady = false
            loadBombRewardedAd()
        } else if let dsAd = doubleScoreRewardedAd, ad === dsAd {
            if let completion = doubleScoreRewardCompletion {
                completion(false)
                doubleScoreRewardCompletion = nil
            }
            isDoubleScoreAdReady = false
            loadDoubleScoreAd()
        } else if let intAd = interstitialAd, ad === intAd {
            interstitialCompletion?()
            interstitialCompletion = nil
            isInterstitialReady = false
            loadInterstitialAd()
        }
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdManager] Ad failed to present: \(error.localizedDescription)")

        if let bombAd = bombRewardedAd, ad === bombAd {
            bombRewardCompletion?(false)
            bombRewardCompletion = nil
            isRewardedAdReady = false
            loadBombRewardedAd()
        } else if let dsAd = doubleScoreRewardedAd, ad === dsAd {
            doubleScoreRewardCompletion?(false)
            doubleScoreRewardCompletion = nil
            isDoubleScoreAdReady = false
            loadDoubleScoreAd()
        } else if let intAd = interstitialAd, ad === intAd {
            interstitialCompletion?()
            interstitialCompletion = nil
            isInterstitialReady = false
            loadInterstitialAd()
        }
    }
}
