import Foundation

/// Links to the game's App Store page.
enum AppStoreLinks {
    /// TODO before release: the app's Apple ID — the number App Store Connect shows
    /// under the app → App Information → General Information → Apple ID
    /// (e.g. "6471234567"). Until it's set, share texts carry no link and Settings
    /// hides "Rate Stack & Blast".
    static let appID = ""

    /// The app's App Store page (for share texts), once the ID is set.
    static var appPage: URL? { appPageURL(appID: appID) }

    /// Opens the App Store straight on "Write a Review", once the ID is set.
    static var writeReview: URL? { writeReviewURL(appID: appID) }

    static func appPageURL(appID: String) -> URL? {
        isValid(appID) ? URL(string: "https://apps.apple.com/app/id\(appID)") : nil
    }

    static func writeReviewURL(appID: String) -> URL? {
        isValid(appID) ? URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review") : nil
    }

    /// Apple IDs are all digits.
    private static func isValid(_ appID: String) -> Bool {
        !appID.isEmpty && appID.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
