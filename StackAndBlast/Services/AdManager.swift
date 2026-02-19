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

    // MARK: - Ad Unit IDs (Production)

    private let bombRewardedAdUnitID = "ca-app-pub-2741592186352961/8805323485"
    private let doubleScoreRewardedAdUnitID = "ca-app-pub-2741592186352961/8805323485"
    private let interstitialAdUnitID = "ca-app-pub-2741592186352961/9545196682"

    // Google's official test ad unit IDs — used as fallback when production ads have no fill
    // (e.g. app not yet published on the App Store).
    private let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    private let testInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"

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
        loadRewardedAd(unitID: bombRewardedAdUnitID) { [weak self] ad in
            guard let self else { completion?(false); return }
            if let ad {
                self.bombRewardedAd = ad
                self.bombRewardedAd?.fullScreenContentDelegate = self
                self.isRewardedAdReady = true
                completion?(true)
            } else {
                // Production ad failed — fall back to Google test ad so the button always works
                // (common when app is not yet published on the App Store).
                print("[AdManager] Production bomb ad failed, falling back to test ad")
                self.loadRewardedAd(unitID: self.testRewardedAdUnitID) { [weak self] testAd in
                    guard let self else { completion?(false); return }
                    if let testAd {
                        self.bombRewardedAd = testAd
                        self.bombRewardedAd?.fullScreenContentDelegate = self
                        self.isRewardedAdReady = true
                        completion?(true)
                    } else {
                        self.bombRewardedAd = nil
                        self.isRewardedAdReady = false
                        completion?(false)
                    }
                }
            }
        }
    }

    /// Loads a rewarded ad with the given unit ID, returning the ad or nil on failure.
    private func loadRewardedAd(unitID: String, completion: @escaping (GADRewardedAd?) -> Void) {
        GADRewardedAd.load(withAdUnitID: unitID, request: GADRequest()) { ad, error in
            if let error {
                print("[AdManager] Failed to load rewarded ad (\(unitID)): \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(ad)
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
        loadDoubleScoreAd(completion: nil)
    }

    func loadDoubleScoreAd(completion: ((Bool) -> Void)?) {
        loadRewardedAd(unitID: doubleScoreRewardedAdUnitID) { [weak self] ad in
            guard let self else { completion?(false); return }
            if let ad {
                self.doubleScoreRewardedAd = ad
                self.doubleScoreRewardedAd?.fullScreenContentDelegate = self
                self.isDoubleScoreAdReady = true
                completion?(true)
            } else {
                print("[AdManager] Production double-score ad failed, falling back to test ad")
                self.loadRewardedAd(unitID: self.testRewardedAdUnitID) { [weak self] testAd in
                    guard let self else { completion?(false); return }
                    if let testAd {
                        self.doubleScoreRewardedAd = testAd
                        self.doubleScoreRewardedAd?.fullScreenContentDelegate = self
                        self.isDoubleScoreAdReady = true
                        completion?(true)
                    } else {
                        self.doubleScoreRewardedAd = nil
                        self.isDoubleScoreAdReady = false
                        completion?(false)
                    }
                }
            }
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
        loadInterstitial(unitID: interstitialAdUnitID) { [weak self] ad in
            guard let self else { return }
            if let ad {
                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                self.isInterstitialReady = true
            } else {
                print("[AdManager] Production interstitial failed, falling back to test ad")
                self.loadInterstitial(unitID: self.testInterstitialAdUnitID) { [weak self] testAd in
                    guard let self else { return }
                    if let testAd {
                        self.interstitialAd = testAd
                        self.interstitialAd?.fullScreenContentDelegate = self
                        self.isInterstitialReady = true
                    } else {
                        self.interstitialAd = nil
                        self.isInterstitialReady = false
                    }
                }
            }
        }
    }

    private func loadInterstitial(unitID: String, completion: @escaping (GADInterstitialAd?) -> Void) {
        GADInterstitialAd.load(withAdUnitID: unitID, request: GADRequest()) { ad, error in
            if let error {
                print("[AdManager] Failed to load interstitial (\(unitID)): \(error.localizedDescription)")
                completion(nil)
                return
            }
            completion(ad)
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

        guard let ad = interstitialAd, let rootVC = topViewController() else {
            completion()
            return
        }

        interstitialCompletion = completion
        interstitialsShownThisSession += 1
        AnalyticsManager.shared.logInterstitialShown(sessionGameCount: sessionGameCount)
        ad.present(fromRootViewController: rootVC)
    }

    // MARK: - Helpers

    /// Returns the topmost presented view controller from the foreground active scene.
    /// Falls back to any connected scene if no scene reports foreground-active (e.g. during launch).
    func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        // Prefer the foreground-active scene; fall back to any connected scene.
        let windowScene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first

        guard let rootVC = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? windowScene?.windows.first?.rootViewController else {
            return nil
        }

        // Walk the presentation chain to find the topmost presented VC.
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
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
