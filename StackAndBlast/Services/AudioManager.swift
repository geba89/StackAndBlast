import AVFoundation

/// Manages all game audio using procedural tone synthesis (GDD section 5.2).
///
/// Sounds are generated as PCM buffers at init time for zero-latency playback.
/// Uses AVAudioEngine with multiple player nodes for concurrent sound support.
/// All tones use a warmWave blend (sine + triangle + 2nd harmonic) for a softer timbre.
final class AudioManager {

    static let shared = AudioManager()

    private var isSoundEnabled = true
    private let sampleRate: Float = 44100

    // MARK: - AVAudioEngine

    private let audioEngine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private let mixerNode = AVAudioMixerNode()
    private var currentPlayerIndex = 0
    private let playerCount = 8 // concurrent sound channels (increased for chords)

    // MARK: - Pre-rendered Buffers

    private var pickupBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var placementBuffer: AVAudioPCMBuffer?
    private var chimeBuffer: AVAudioPCMBuffer?
    private var blastBuffer: AVAudioPCMBuffer?
    private var swapBuffer: AVAudioPCMBuffer?
    private var cascadeBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var gameOverBuffer: AVAudioPCMBuffer?
    private var powerUpRowBlastBuffer: AVAudioPCMBuffer?
    private var powerUpColumnBlastBuffer: AVAudioPCMBuffer?
    private var powerUpColorBombBuffer: AVAudioPCMBuffer?

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
            playBuffer(buffer, volume: 0.12)
        }
    }

    /// Warm punchy thud.
    func playPlacement() {
        guard isSoundEnabled else { return }
        if let buffer = placementBuffer {
            playBuffer(buffer, volume: 0.30)
        }
    }

    /// Warm rising chime before blast.
    func playLineCompleteChime() {
        guard isSoundEnabled else { return }
        if let buffer = chimeBuffer {
            playBuffer(buffer, volume: 0.25)
        }
    }

    /// Warm whoosh with filtered noise.
    func playBlast() {
        guard isSoundEnabled else { return }
        if let buffer = blastBuffer {
            playBuffer(buffer, volume: 0.40)
        }
    }

    /// Swooping whoosh.
    func playSwap() {
        guard isSoundEnabled else { return }
        if let buffer = swapBuffer {
            playBuffer(buffer, volume: 0.25)
        }
    }

    /// Building chord per cascade level — single ping → dyad → triad → full chord + sweep.
    func playCascade(level: Int) {
        guard isSoundEnabled else { return }
        let key = min(level, 8)
        if let buffer = cascadeBuffers[key] {
            let vol = min(0.20 + Float(level) * 0.04, 0.50)
            playBuffer(buffer, volume: vol)
        }
    }

    /// Slow sad descending tone.
    func playGameOver() {
        guard isSoundEnabled else { return }
        if let buffer = gameOverBuffer {
            playBuffer(buffer, volume: 0.35)
        }
    }

    /// Horizontal "zip" — fast ascending sweep.
    func playPowerUpRowBlast() {
        guard isSoundEnabled else { return }
        if let buffer = powerUpRowBlastBuffer {
            playBuffer(buffer, volume: 0.30)
        }
    }

    /// Vertical "zip" — fast descending sweep.
    func playPowerUpColumnBlast() {
        guard isSoundEnabled else { return }
        if let buffer = powerUpColumnBlastBuffer {
            playBuffer(buffer, volume: 0.30)
        }
    }

    /// Sparkly 4-note arpeggio.
    func playPowerUpColorBomb() {
        guard isSoundEnabled else { return }
        if let buffer = powerUpColorBombBuffer {
            playBuffer(buffer, volume: 0.30)
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

    // MARK: - Warm Wave Generator

    /// Blended waveform: 60% sine + 25% triangle + 15% second harmonic.
    /// Produces warmer, less robotic tones than pure sine.
    private func warmWave(phase: Float) -> Float {
        // Normalize phase to [0, 2pi)
        let p = phase.truncatingRemainder(dividingBy: 2 * .pi)

        // Sine component (fundamental)
        let sine = sin(p)

        // Triangle wave component
        let normalized = p / (2 * .pi) // [0, 1)
        let triangle: Float
        if normalized < 0.25 {
            triangle = 4 * normalized
        } else if normalized < 0.75 {
            triangle = 2 - 4 * normalized
        } else {
            triangle = -4 + 4 * normalized
        }

        // Second harmonic (octave above, adds brightness without harshness)
        let harmonic = sin(2 * p) * 0.5

        return 0.60 * sine + 0.25 * triangle + 0.15 * harmonic
    }

    // MARK: - Buffer Generation

    private func generateAllBuffers() {
        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!

        // Pickup sounds: warm pings, higher pitch for larger pieces
        for cellCount in 1...5 {
            let freq: Float = 1200 + Float(cellCount) * 50
            pickupBuffers[cellCount] = generateWarmTone(frequency: freq, duration: 0.025,
                                                         decay: 80, format: format)
        }

        // Placement: warm punchy thud
        placementBuffer = generateWarmThud(format: format)

        // Chime: warm ascending C5-E5-G5
        chimeBuffer = generateWarmChime(format: format)

        // Blast: warm sweep + filtered noise whoosh
        blastBuffer = generateWarmBlast(format: format)

        // Swap: warm frequency sweep up
        swapBuffer = generateWarmSweep(startFreq: 400, endFreq: 800, duration: 0.15, format: format)

        // Cascade sounds: building chords per level
        for level in 0...8 {
            cascadeBuffers[level] = generateCascadeChord(level: level, format: format)
        }

        // Game over: slow sad descending tone
        gameOverBuffer = generateWarmSweep(startFreq: 330, endFreq: 131, duration: 1.2, format: format)

        // Power-up sounds
        powerUpRowBlastBuffer = generateWarmSweep(startFreq: 200, endFreq: 1200, duration: 0.12, format: format)
        powerUpColumnBlastBuffer = generateWarmSweep(startFreq: 1200, endFreq: 200, duration: 0.12, format: format)
        powerUpColorBombBuffer = generateColorBombArpeggio(format: format)
    }

    /// Generate a warm tone with exponential decay.
    private func generateWarmTone(frequency: Float, duration: Float, decay: Float,
                                   format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let envelope = exp(-t * decay)
            let phase = 2 * .pi * frequency * t
            data[i] = warmWave(phase: phase) * envelope
        }
        return buffer
    }

    /// Warm low-frequency thud (warmWave at 160Hz + short filtered noise burst).
    private func generateWarmThud(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let duration: Float = 0.07
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let envelope = exp(-t * 35)
            let phase = 2 * .pi * 160 * t
            let tone = warmWave(phase: phase) * envelope
            // Short filtered noise burst (only first 10ms)
            let noise = (t < 0.01) ? Float.random(in: -0.2...0.2) * exp(-t * 120) : 0
            data[i] = tone + noise
        }
        return buffer
    }

    /// Warm ascending 3-note chime (C5, E5, G5) using warmWave.
    private func generateWarmChime(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let noteDuration: Float = 0.08
        let gap: Float = 0.04
        let totalDuration = noteDuration * 3 + gap * 2
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        let frequencies: [Float] = [523.25, 659.25, 783.99] // C5, E5, G5
        var writeIndex = 0

        for (noteIdx, freq) in frequencies.enumerated() {
            let noteFrames = Int(noteDuration * sampleRate)

            for i in 0..<noteFrames where writeIndex < Int(frameCount) {
                let t = Float(i) / sampleRate
                let envelope = exp(-t * 12)
                let phase = 2 * .pi * freq * t
                data[writeIndex] = warmWave(phase: phase) * envelope
                writeIndex += 1
            }

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

    /// Warm blast sound (descending warmWave sweep + filtered noise "whoosh").
    private func generateWarmBlast(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let duration: Float = 0.3
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        // Simple low-pass state for filtered noise
        var filteredNoise: Float = 0

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let progress = t / duration

            // Descending warmWave sweep: 200Hz -> 60Hz
            let freq = 200 - 140 * progress
            let phase = 2 * .pi * freq * t
            let boom = warmWave(phase: phase) * exp(-t * 5)

            // Filtered noise "whoosh" — low-pass cutoff sweeps down with the boom
            let rawNoise = Float.random(in: -1...1)
            let alpha = max(0.02, 0.15 * (1 - progress)) // filter coefficient decreases over time
            filteredNoise = filteredNoise + alpha * (rawNoise - filteredNoise)
            let whoosh = filteredNoise * exp(-t * 8) * 0.4

            data[i] = boom + whoosh
        }
        return buffer
    }

    /// Generate cascade chord that builds with level:
    /// 0: single C5 ping, 1: C5+G5 dyad, 2: C5+E5+G5 triad,
    /// 3: C5+E5+G5+C6, 4+: full chord + ascending sweep overlay.
    private func generateCascadeChord(level: Int, format: AVAudioFormat) -> AVAudioPCMBuffer {
        // Duration scales up: 0.15s at level 0, up to 0.30s at level 4+
        let duration = min(0.15 + Float(level) * 0.04, 0.30)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        // Notes for building chord: C5, G5, E5, C6
        let allNotes: [Float] = [523.25, 783.99, 659.25, 1046.50]
        let noteCount = min(level + 1, allNotes.count)
        let notes = Array(allNotes.prefix(noteCount))

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let envelope = exp(-t * (10 - min(Float(level), 4)))

            // Sum all chord notes simultaneously
            var sample: Float = 0
            for freq in notes {
                let phase = 2 * .pi * freq * t
                sample += warmWave(phase: phase)
            }
            // Normalize by note count to prevent clipping
            sample = sample / Float(noteCount) * envelope

            // Level 4+: add ascending sweep overlay for sparkle
            if level >= 4 {
                let sweepProgress = t / duration
                let sweepFreq = 800 + 1200 * sweepProgress
                let sweepPhase = 2 * .pi * sweepFreq * t
                let sweep = warmWave(phase: sweepPhase) * exp(-t * 6) * 0.3
                sample += sweep
            }

            data[i] = sample
        }
        return buffer
    }

    /// Rapid 4-note arpeggio C5-E5-G5-C6 for color bomb power-up (sparkly cascade).
    private func generateColorBombArpeggio(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let noteDuration: Float = 0.03 // 30ms per note
        let totalDuration = noteDuration * 4
        let frameCount = AVAudioFrameCount(totalDuration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        let frequencies: [Float] = [523.25, 659.25, 783.99, 1046.50] // C5, E5, G5, C6
        var writeIndex = 0

        for freq in frequencies {
            let noteFrames = Int(noteDuration * sampleRate)
            for i in 0..<noteFrames where writeIndex < Int(frameCount) {
                let t = Float(i) / sampleRate
                let envelope = exp(-t * 20)
                let phase = 2 * .pi * freq * t
                data[writeIndex] = warmWave(phase: phase) * envelope
                writeIndex += 1
            }
        }
        return buffer
    }

    /// Generate a warm frequency sweep (ascending or descending).
    private func generateWarmSweep(startFreq: Float, endFreq: Float, duration: Float,
                                    format: AVAudioFormat) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        // Slower decay for game over (longer duration), faster for short sweeps
        let decayRate: Float = duration > 0.5 ? 1.5 : 3.0

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            let progress = t / duration
            let freq = startFreq + (endFreq - startFreq) * progress
            let envelope = exp(-t * decayRate)
            let phase = 2 * .pi * freq * t
            data[i] = warmWave(phase: phase) * envelope
        }
        return buffer
    }
}
