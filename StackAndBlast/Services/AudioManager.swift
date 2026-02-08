import AVFoundation

/// Manages all game audio using procedural tone synthesis (GDD section 5.2).
///
/// Sounds are generated as PCM buffers at init time for zero-latency playback.
/// Uses AVAudioEngine with multiple player nodes for concurrent sound support.
final class AudioManager {

    static let shared = AudioManager()

    private var isSoundEnabled = true
    private let sampleRate: Float = 44100

    // MARK: - AVAudioEngine

    private let audioEngine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private let mixerNode = AVAudioMixerNode()
    private var currentPlayerIndex = 0
    private let playerCount = 6 // concurrent sound channels

    // MARK: - Pre-rendered Buffers

    private var pickupBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var placementBuffer: AVAudioPCMBuffer?
    private var chimeBuffer: AVAudioPCMBuffer?
    private var blastBuffer: AVAudioPCMBuffer?
    private var swapBuffer: AVAudioPCMBuffer?
    private var cascadeBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var gameOverBuffer: AVAudioPCMBuffer?

    // MARK: - Init

    private init() {
        setupEngine()
        generateAllBuffers()
    }

    // MARK: - Public API

    func setSoundEnabled(_ enabled: Bool) {
        isSoundEnabled = enabled
    }

    /// Soft pop — pitch varies by piece size.
    func playPickup(cellCount: Int) {
        guard isSoundEnabled else { return }
        let key = min(cellCount, 5)
        if let buffer = pickupBuffers[key] {
            playBuffer(buffer, volume: 0.25)
        }
    }

    /// Satisfying thud with bass.
    func playPlacement() {
        guard isSoundEnabled else { return }
        if let buffer = placementBuffer {
            playBuffer(buffer, volume: 0.4)
        }
    }

    /// Rising chime before blast.
    func playLineCompleteChime() {
        guard isSoundEnabled else { return }
        if let buffer = chimeBuffer {
            playBuffer(buffer, volume: 0.3)
        }
    }

    /// Boom + shatter.
    func playBlast() {
        guard isSoundEnabled else { return }
        if let buffer = blastBuffer {
            playBuffer(buffer, volume: 0.5)
        }
    }

    /// Swooping whoosh.
    func playSwap() {
        guard isSoundEnabled else { return }
        if let buffer = swapBuffer {
            playBuffer(buffer, volume: 0.3)
        }
    }

    /// Chime with escalating pitch per cascade level.
    func playCascade(level: Int) {
        guard isSoundEnabled else { return }
        let key = min(level, 8)
        if let buffer = cascadeBuffers[key] {
            let vol = min(0.3 + Float(level) * 0.05, 0.6)
            playBuffer(buffer, volume: vol)
        }
    }

    /// Descending tone.
    func playGameOver() {
        guard isSoundEnabled else { return }
        if let buffer = gameOverBuffer {
            playBuffer(buffer, volume: 0.4)
        }
    }

    // MARK: - Engine Setup

    private func setupEngine() {
        audioEngine.attach(mixerNode)
        audioEngine.connect(mixerNode, to: audioEngine.outputNode,
                            format: audioEngine.outputNode.outputFormat(forBus: 0))

        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!
        for _ in 0..<playerCount {
            let player = AVAudioPlayerNode()
            audioEngine.attach(player)
            audioEngine.connect(player, to: mixerNode, format: format)
            playerNodes.append(player)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            // Audio unavailable — sounds will silently not play
        }
    }

    // MARK: - Playback

    private func playBuffer(_ buffer: AVAudioPCMBuffer, volume: Float) {
        let player = playerNodes[currentPlayerIndex]
        currentPlayerIndex = (currentPlayerIndex + 1) % playerCount

        player.stop()
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    // MARK: - Buffer Generation

    private func generateAllBuffers() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!

        // Pickup sounds: higher pitch for larger pieces
        for cellCount in 1...5 {
            let freq: Float = 800 + Float(cellCount) * 100
            pickupBuffers[cellCount] = generateTone(frequency: freq, duration: 0.06,
                                                     decay: 15, format: format)
        }

        // Placement: low thud
        placementBuffer = generateThud(format: format)

        // Chime: ascending C5-E5-G5
        chimeBuffer = generateChime(baseMultiplier: 1.0, format: format)

        // Blast: low sweep + noise
        blastBuffer = generateBlast(format: format)

        // Swap: frequency sweep up
        swapBuffer = generateSweep(startFreq: 400, endFreq: 800, duration: 0.15, format: format)

        // Cascade sounds: chime at escalating pitches
        for level in 0...8 {
            let pitchMultiplier = pow(2.0, Float(level) / 12.0) // +1 semitone per level
            cascadeBuffers[level] = generateChime(baseMultiplier: pitchMultiplier, format: format)
        }

        // Game over: descending tone
        gameOverBuffer = generateSweep(startFreq: 392, endFreq: 131, duration: 0.8, format: format)
    }

    /// Generate a sine tone with exponential decay.
    private func generateTone(frequency: Float, duration: Float, decay: Float,
                               format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let envelope = exp(-t * decay)
            data[i] = sin(2 * .pi * frequency * t) * envelope
        }
        return buffer
    }

    /// Generate a low-frequency thud (sine at 120Hz + noise burst).
    private func generateThud(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let duration: Float = 0.12
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let envelope = exp(-t * 20)
            // Low sine + short noise burst
            let sine = sin(2 * .pi * 120 * t) * envelope
            let noise = (t < 0.02) ? Float.random(in: -0.3...0.3) * exp(-t * 80) : 0
            data[i] = sine + noise
        }
        return buffer
    }

    /// Generate an ascending 3-note chime (C5, E5, G5) with optional pitch multiplier.
    private func generateChime(baseMultiplier: Float, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let noteDuration: Float = 0.08
        let gap: Float = 0.04
        let totalDuration = noteDuration * 3 + gap * 2
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        let frequencies: [Float] = [523.25, 659.25, 783.99] // C5, E5, G5
        var writeIndex = 0

        for (noteIdx, baseFreq) in frequencies.enumerated() {
            let freq = baseFreq * baseMultiplier
            let noteFrames = Int(noteDuration * sampleRate)

            for i in 0..<noteFrames where writeIndex < Int(frameCount) {
                let t = Float(i) / sampleRate
                let envelope = exp(-t * 12)
                data[writeIndex] = sin(2 * .pi * freq * t) * envelope
                writeIndex += 1
            }

            // Gap between notes (except after last)
            if noteIdx < 2 {
                let gapFrames = Int(gap * sampleRate)
                for _ in 0..<gapFrames where writeIndex < Int(frameCount) {
                    data[writeIndex] = 0
                    writeIndex += 1
                }
            }
        }
        return buffer
    }

    /// Generate an explosion sound (descending sine sweep + noise).
    private func generateBlast(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let duration: Float = 0.3
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let progress = t / duration

            // Descending sine sweep: 200Hz → 60Hz
            let freq = 200 - 140 * progress
            let boom = sin(2 * .pi * freq * t) * exp(-t * 5)

            // White noise burst for "shatter" texture (decays quickly)
            let shatter = Float.random(in: -1...1) * exp(-t * 15) * 0.5

            data[i] = boom + shatter
        }
        return buffer
    }

    /// Generate a frequency sweep (ascending or descending).
    private func generateSweep(startFreq: Float, endFreq: Float, duration: Float,
                                format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let progress = t / duration
            let freq = startFreq + (endFreq - startFreq) * progress
            let envelope = exp(-t * 3) // gentle fade
            data[i] = sin(2 * .pi * freq * t) * envelope
        }
        return buffer
    }
}
