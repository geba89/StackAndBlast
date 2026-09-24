// swift-tools-version:5.9
//
// Unit tests for the UI-free game logic (engine, models, a few services).
//
// The iOS app is still built from StackAndBlast.xcodeproj (generated from project.yml).
// This package only exists so the rules of the game can be tested quickly from the
// command line — on a Mac or on Linux CI — without a simulator:
//
//     swift test
//
// Only files that depend on Foundation/Observation may be listed in `sources`
// (no UIKit, SwiftUI, SpriteKit, or Firebase), otherwise Linux builds break.
import PackageDescription

let package = Package(
    name: "StackAndBlastCore",
    platforms: [.iOS(.v17), .macOS(.v14)], // @Observable needs iOS 17 / macOS 14
    targets: [
        .target(
            name: "StackAndBlastCore",
            path: "StackAndBlast",
            exclude: [
                // App-only code (UIKit / SwiftUI / SpriteKit / Firebase / ads)
                "App", "Extensions", "ViewModels", "Views", "Resources",
                "Info.plist", "PrivacyInfo.xcprivacy", "StackAndBlast.entitlements",
                "Services/AchievementManager.swift", "Services/AdManager.swift",
                "Services/AnalyticsManager.swift", "Services/AudioManager.swift",
                "Services/DailyChallengeRewardManager.swift", "Services/HapticManager.swift",
                "Services/LeaderboardManager.swift", "Services/NetworkMonitor.swift",
                "Services/ScoreManager.swift", "Services/SkinManager.swift",
                "Services/StatsManager.swift", "Services/StoreManager.swift",
                "Services/StreakManager.swift",
            ],
            sources: [
                "Models",
                "Engine",
                "Services/SettingsManager.swift",
                "Services/CoinManager.swift",
                "Services/MissionManager.swift",
            ]
        ),
        .testTarget(
            name: "StackAndBlastCoreTests",
            dependencies: ["StackAndBlastCore"],
            path: "Tests/StackAndBlastCoreTests"
        ),
    ]
)
