import GoogleMobileAds
import UIKit

/// Manages rewarded video ads for the bomb continue mechanic.
/// Follows the same singleton pattern as AudioManager and ScoreManager.
final class AdManager: NSObject {

    static let shared = AdManager()

    /// Whether a rewarded ad is loaded and ready to show.
    private(set) var isRewardedAdReady: Bool = false

    /// Rewarded ad unit ID for the bomb continue mechanic.
    private let rewardedAdUnitID = "ca-app-pub-2741592186352961/8805323485"

    private var rewardedAd: GADRewardedAd?
    private var rewardCompletion: ((Bool) -> Void)?

    private override init() {
        super.init()
    }

    /// Initialize the Google Mobile Ads SDK. Call once at app start.
    func configure() {
        GADMobileAds.sharedInstance().start { _ in
            self.loadRewardedAd()
        }
    }

    /// Preload the next rewarded ad so it's ready when the player needs it.
    func loadRewardedAd() {
        loadRewardedAd(completion: nil)
    }

    /// Load a rewarded ad with an optional completion callback.
    func loadRewardedAd(completion: ((Bool) -> Void)?) {
        GADRewardedAd.load(withAdUnitID: rewardedAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { completion?(false); return }
            if let error {
                print("[AdManager] Failed to load rewarded ad: \(error.localizedDescription)")
                self.rewardedAd = nil
                self.isRewardedAdReady = false
                completion?(false)
                return
            }
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.isRewardedAdReady = true
            completion?(true)
        }
    }

    /// Present a rewarded ad. Calls completion with `true` if reward was earned.
    func showRewardedAd(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd else {
            completion(false)
            return
        }

        rewardCompletion = completion
        ad.present(fromRootViewController: viewController) { [weak self] in
            // User earned the reward
            self?.rewardCompletion?(true)
            self?.rewardCompletion = nil
        }
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        // Ad dismissed — if reward wasn't granted yet, call failure
        if let completion = rewardCompletion {
            completion(false)
            rewardCompletion = nil
        }
        // Preload the next ad
        isRewardedAdReady = false
        loadRewardedAd()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdManager] Ad failed to present: \(error.localizedDescription)")
        rewardCompletion?(false)
        rewardCompletion = nil
        isRewardedAdReady = false
        loadRewardedAd()
    }
}
