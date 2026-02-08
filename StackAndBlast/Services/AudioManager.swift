import AVFoundation

/// Manages all game audio: sound effects and background music (GDD section 5.2).
///
/// Uses AVAudioEngine for layered sound playback. Each game event has a dedicated
/// sound with parameters tuned per the GDD audio design table.
final class AudioManager {

    static let shared = AudioManager()

    private var isSoundEnabled = true

    private init() {}

    // MARK: - Public API

    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }

    /// Play the block pickup sound (soft pop, pitch varies by piece size).
    func playPickup(cellCount: Int) {
        guard isSoundEnabled else { return }
        // TODO: Implement with AVAudioEngine
    }

    /// Play the block placement sound (satisfying thud with bass).
    func playPlacement() {
        guard isSoundEnabled else { return }
        // TODO: Implement with AVAudioEngine
    }

    /// Play the line completion warning chime (ascending tone).
    func playLineCompleteChime() {
        guard isSoundEnabled else { return }
        // TODO: Implement with AVAudioEngine
    }

    /// Play the blast/explosion sound (boom + shatter + whoosh).
    func playBlast() {
        guard isSoundEnabled else { return }
        // TODO: Implement with AVAudioEngine
    }

    /// Play the block swap sound (swooping whoosh + click).
    func playSwap() {
        guard isSoundEnabled else { return }
        // TODO: Implement with AVAudioEngine
    }

    /// Play the cascade combo sound at escalating pitch.
    func playCascade(level: Int) {
        guard isSoundEnabled else { return }
        // TODO: Implement with AVAudioEngine — pitch increases by +1 semitone per level
    }

    /// Play the game over sound (descending tone with echo).
    func playGameOver() {
        guard isSoundEnabled else { return }
        // TODO: Implement with AVAudioEngine
    }
}
