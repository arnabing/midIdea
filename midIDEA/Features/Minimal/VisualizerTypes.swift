import SwiftUI

// MARK: - Color Mode

enum VisualizerColorMode: String, CaseIterable {
    case ocean = "Ocean"
    case cool = "Cool Blues"
    case lavaLamp = "Lava Lamp"
    case rainbow = "Rainbow"
    case sunset = "Sunset"
    case aurora = "Aurora"
}

// MARK: - Visual Style

enum VisualizerStyle: String, CaseIterable {
    // MeshGradient styles (1-4)
    case liquidOcean = "Liquid Ocean"
    case plasmaPulse = "Plasma Pulse"
    case breathingAura = "Breathing Aura"
    case radiantPulse = "Radiant Pulse"
    // New rendering approaches (5-7)
    case metalOrb = "Metal Orb"
    case shaderGlow = "Shader Glow"
    case particleField = "Particle Field"

    /// Whether this style uses the MeshGradient-based LiquidAudioVisualizer
    var isMeshGradientStyle: Bool {
        switch self {
        case .liquidOcean, .plasmaPulse, .breathingAura, .radiantPulse:
            return true
        case .metalOrb, .shaderGlow, .particleField:
            return false
        }
    }
}

// MARK: - Audio Interpolator (Smooth 60Hz→120Hz)

/// Interpolates between audio samples for smooth 120Hz rendering from 60Hz data.
/// Uses ElevenLabs-style easeInOutCubic smoothing (Apache 2.0, from elevenlabs/components-swift).
final class AudioInterpolator: ObservableObject {
    // Sample buffer
    private var previousSample: Float = 0
    private var currentSample: Float = 0
    private var lastUpdateTime: TimeInterval = 0
    private let sampleInterval: TimeInterval = 1.0/43.0  // ~43Hz from AVAudioEngine tap (1024 samples @ 44.1kHz)

    // Physics state
    private var smoothedLevel: Float = 0
    private var previousSmoothed: Float = 0
    private var peakIntensity: Float = 0

    /// Called when new audio sample arrives (60Hz)
    func updateSample(_ normalizedLevel: Float) {
        previousSample = currentSample
        currentSample = normalizedLevel
        lastUpdateTime = CACurrentMediaTime()
    }

    /// Called every render frame (120Hz) - returns interpolated & smoothed values
    func getPhysics(at time: TimeInterval) -> (smoothed: Float, peak: Float) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastUpdateTime
        let t = Float(min(max(elapsed / sampleInterval, 0), 1.0))

        // Interpolate between samples
        let eased = t * t * (3 - 2 * t)  // Smoothstep for inter-sample motion
        let interpolatedLevel = previousSample + (currentSample - previousSample) * eased

        // Asymmetric attack/release smoothing (like an audio compressor):
        // - Attack: fast (0.6 per frame) — snappy response to voice onset
        // - Release: slow (0.12 per frame) — smooth decay when voice stops
        let isRising = interpolatedLevel > smoothedLevel
        let factor: Float = isRising ? 0.6 : 0.12
        smoothedLevel += (interpolatedLevel - smoothedLevel) * factor

        // Peak detection with decay
        let delta = smoothedLevel - previousSmoothed
        peakIntensity *= 0.88  // Decay
        if delta > 0.05 {
            peakIntensity = min(1.0, peakIntensity + delta * 3.0)
        }
        previousSmoothed = smoothedLevel

        return (smoothedLevel, peakIntensity)
    }

    /// Reset state (e.g., when recording stops)
    func reset() {
        previousSample = 0
        currentSample = 0
        smoothedLevel = 0
        previousSmoothed = 0
        peakIntensity = 0
    }
}

// MARK: - Band Interpolator (Smooth 3-band FFT at 120Hz)

/// Interpolates 3 frequency bands (bass/mid/treble) from ~43Hz audio data to 120Hz rendering.
/// Each band has independent asymmetric attack/release and peak detection.
/// Onset-aware: spectral flux onset signal temporarily speeds up release for rhythmic snapping.
final class BandInterpolator: ObservableObject {
    // Sample buffer per band
    private var previousBands: [Float] = [0, 0, 0]
    private var currentBands: [Float] = [0, 0, 0]
    private var lastUpdateTime: TimeInterval = 0
    private let sampleInterval: TimeInterval = 1.0/43.0

    // Physics state per band
    private var smoothedBands: [Float] = [0, 0, 0]
    private var previousSmoothed: [Float] = [0, 0, 0]
    private var bandPeaks: [Float] = [0, 0, 0]

    // Onset-gated release state
    private var currentOnsets: [Float] = [0, 0, 0]
    private var onsetDecay: [Float] = [0, 0, 0]

    /// Called when new frequency band data arrives (~43Hz)
    func updateBands(_ bands: [Float]) {
        guard bands.count == 3 else { return }
        previousBands = currentBands
        currentBands = bands
        lastUpdateTime = CACurrentMediaTime()
    }

    /// Called when new onset data arrives (~43Hz)
    func updateOnsets(_ onsets: [Float]) {
        guard onsets.count == 3 else { return }
        currentOnsets = onsets
        for i in 0..<3 {
            // When onset > 0.3 threshold, reset onset decay to 1.0 for fast release
            if onsets[i] > 0.3 {
                onsetDecay[i] = 1.0
            }
        }
    }

    /// Called every render frame (120Hz) — returns interpolated & smoothed band values + peaks
    func getPhysics(at time: TimeInterval) -> (bands: [Float], peaks: [Float]) {
        let now = CACurrentMediaTime()
        let elapsed = now - lastUpdateTime
        let t = Float(min(max(elapsed / sampleInterval, 0), 1.0))
        let eased = t * t * (3 - 2 * t)  // Smoothstep

        var bands = [Float](repeating: 0, count: 3)
        var peaks = [Float](repeating: 0, count: 3)

        // Per-band attack/release/decay tuning:
        // Bass (0):   sustained, slower decay for thumping feel
        // Mid (1):    slightly faster, good for vocals
        // Treble (2): fast attack for transients, faster release to avoid smearing
        let attacks: [Float] = [0.55, 0.65, 0.82]
        let baseReleases: [Float] = [0.10, 0.14, 0.18]
        let peakDecays: [Float] = [0.90, 0.88, 0.85]

        // Onset boost factors per band: bass needs sharpest pulse for kicks
        let onsetBoosts: [Float] = [3.5, 3.0, 2.5]

        for i in 0..<3 {
            // Decay onset influence: 0.92 per frame at 120Hz = ~83ms half-life
            onsetDecay[i] *= 0.92

            // Onset-boosted release: when onset detected, release speeds up dramatically
            // Speech plosives (~0.2-0.4 onset) → release goes from 0.10 to ~0.21 (barely noticeable)
            // Music kicks (~0.8-1.0 onset) → release goes from 0.10 to ~0.45 (night and day)
            let release = min(0.6, baseReleases[i] * (1.0 + onsetDecay[i] * onsetBoosts[i]))

            // Interpolate between samples
            let interpolated = previousBands[i] + (currentBands[i] - previousBands[i]) * eased

            // Asymmetric attack/release per band
            let isRising = interpolated > smoothedBands[i]
            let factor: Float = isRising ? attacks[i] : release
            smoothedBands[i] += (interpolated - smoothedBands[i]) * factor

            // Peak detection with decay — onset boosts peak sensitivity
            let delta = smoothedBands[i] - previousSmoothed[i]
            bandPeaks[i] *= peakDecays[i]
            if delta > 0.03 {
                // Onset-boosted peaks: kicks/transients produce stronger peak flashes
                let peakGain = 3.0 * (1.0 + currentOnsets[i] * 2.0)
                bandPeaks[i] = min(1.0, bandPeaks[i] + delta * peakGain)
            }
            previousSmoothed[i] = smoothedBands[i]

            bands[i] = smoothedBands[i]
            peaks[i] = bandPeaks[i]
        }

        return (bands, peaks)
    }

    /// Reset state (e.g., when recording stops)
    func reset() {
        previousBands = [0, 0, 0]
        currentBands = [0, 0, 0]
        smoothedBands = [0, 0, 0]
        previousSmoothed = [0, 0, 0]
        bandPeaks = [0, 0, 0]
        currentOnsets = [0, 0, 0]
        onsetDecay = [0, 0, 0]
    }
}

// MARK: - Cached Color Palettes (Pre-computed, not per-frame)

enum CachedColors {
    // Ocean palette
    static let ocean: [Color] = [
        Color(hex: "FFFEF5"), Color(hex: "FFFDF0"), Color(hex: "FFFEF5"), Color(hex: "FFFDF0"),
        Color(hex: "E0FFFF"), Color(hex: "B0E0E6"), Color(hex: "AFEEEE"), Color(hex: "E0FFFF"),
        Color(hex: "40E0D0"), Color(hex: "00CED1"), Color(hex: "20B2AA"), Color(hex: "48D1CC"),
        Color(hex: "0077B6"), Color(hex: "0096C7"), Color(hex: "00B4D8"), Color(hex: "0077B6")
    ]
    static let oceanOpacities: [Double] = [
        0.95, 0.95, 0.95, 0.95,
        0.90, 0.90, 0.90, 0.90,
        0.85, 0.85, 0.85, 0.85,
        0.90, 0.90, 0.90, 0.90
    ]

    // Cool blues palette
    static let coolBlues: [Color] = [
        Color(hex: "667eea"), Color(hex: "764ba2"), Color(hex: "6B8DD6"), Color(hex: "667eea"),
        Color(hex: "764ba2"), Color(hex: "8E37D7"), Color(hex: "00d2d3"), Color(hex: "764ba2"),
        Color(hex: "6B8DD6"), Color(hex: "00d2d3"), Color(hex: "5f27cd"), Color(hex: "6B8DD6"),
        Color(hex: "667eea"), Color(hex: "764ba2"), Color(hex: "6B8DD6"), Color(hex: "667eea")
    ]
    static let coolWarm: [Color] = [
        Color(hex: "ff6b6b"), Color(hex: "ffa502"), Color(hex: "ff4757"), Color(hex: "ff6b6b"),
        Color(hex: "ffa502"), Color(hex: "ff6348"), Color(hex: "ffc048"), Color(hex: "ffa502"),
        Color(hex: "ff4757"), Color(hex: "ffc048"), Color(hex: "ee5a24"), Color(hex: "ff4757"),
        Color(hex: "ff6b6b"), Color(hex: "ffa502"), Color(hex: "ff4757"), Color(hex: "ff6b6b")
    ]
    static let coolOpacities: [Double] = [
        0.3, 0.5, 0.5, 0.3,
        0.5, 0.7, 0.7, 0.5,
        0.5, 0.7, 0.7, 0.5,
        0.3, 0.5, 0.5, 0.3
    ]

    // Sunset palette
    static let sunset: [Color] = [
        Color(hex: "ff6b6b"), Color(hex: "ffa502"), Color(hex: "ff9ff3"), Color(hex: "ff6b6b"),
        Color(hex: "ffa502"), Color(hex: "ee5a24"), Color(hex: "ff4757"), Color(hex: "ffa502"),
        Color(hex: "ff9ff3"), Color(hex: "ff4757"), Color(hex: "c44569"), Color(hex: "ff9ff3"),
        Color(hex: "ff6b6b"), Color(hex: "ffa502"), Color(hex: "ff9ff3"), Color(hex: "ff6b6b")
    ]

    // Breathing Aura - cool (idle) palette: deep blues/purples
    static let auraCool: [Color] = [
        Color(hex: "1A1A3E"), Color(hex: "2B2D6E"), Color(hex: "1E2056"), Color(hex: "1A1A3E"),
        Color(hex: "2B2D6E"), Color(hex: "3A3F9F"), Color(hex: "4B4FCF"), Color(hex: "2B2D6E"),
        Color(hex: "1E2056"), Color(hex: "4B4FCF"), Color(hex: "3A3F9F"), Color(hex: "1E2056"),
        Color(hex: "1A1A3E"), Color(hex: "2B2D6E"), Color(hex: "1E2056"), Color(hex: "1A1A3E")
    ]

    // Breathing Aura - warm (speaking) palette: ambers/whites
    static let auraWarm: [Color] = [
        Color(hex: "FFF8E7"), Color(hex: "FFE4B5"), Color(hex: "FFF0D0"), Color(hex: "FFF8E7"),
        Color(hex: "FFD080"), Color(hex: "FFB347"), Color(hex: "FFA500"), Color(hex: "FFD080"),
        Color(hex: "FFF0D0"), Color(hex: "FFFFFF"), Color(hex: "FFFAF0"), Color(hex: "FFF0D0"),
        Color(hex: "FFF8E7"), Color(hex: "FFE4B5"), Color(hex: "FFF0D0"), Color(hex: "FFF8E7")
    ]

    // Radiant Pulse - pastel (idle) palette
    static let radiantPastel: [Color] = [
        Color(hex: "E8D5F5"), Color(hex: "D5E8F5"), Color(hex: "F5D5E8"), Color(hex: "E8D5F5"),
        Color(hex: "D5F5E8"), Color(hex: "C8B8E8"), Color(hex: "B8D8E8"), Color(hex: "D5F5E8"),
        Color(hex: "F5E8D5"), Color(hex: "B8E8D8"), Color(hex: "E8B8C8"), Color(hex: "F5E8D5"),
        Color(hex: "E8D5F5"), Color(hex: "D5E8F5"), Color(hex: "F5D5E8"), Color(hex: "E8D5F5")
    ]

    // Radiant Pulse - neon (speaking) palette
    static let radiantNeon: [Color] = [
        Color(hex: "FF00FF"), Color(hex: "00FFFF"), Color(hex: "FF0080"), Color(hex: "FF00FF"),
        Color(hex: "00FF80"), Color(hex: "8000FF"), Color(hex: "FF4000"), Color(hex: "00FF80"),
        Color(hex: "FFFF00"), Color(hex: "00FF40"), Color(hex: "FF0040"), Color(hex: "FFFF00"),
        Color(hex: "FF00FF"), Color(hex: "00FFFF"), Color(hex: "FF0080"), Color(hex: "FF00FF")
    ]

    // Plasma pulse - high contrast
    static let plasma: [Color] = [
        Color(hex: "FF0080"), Color(hex: "7928CA"), Color(hex: "FF0080"), Color(hex: "7928CA"),
        Color(hex: "FF4D4D"), Color(hex: "F97316"), Color(hex: "FACC15"), Color(hex: "4ADE80"),
        Color(hex: "0EA5E9"), Color(hex: "8B5CF6"), Color(hex: "EC4899"), Color(hex: "F43F5E"),
        Color(hex: "7928CA"), Color(hex: "FF0080"), Color(hex: "7928CA"), Color(hex: "FF0080")
    ]

    // Particle field palette - ethereal blues/purples/whites
    static let particleColors: [Color] = [
        Color(hex: "B8D4FF"), // Light blue
        Color(hex: "D4B8FF"), // Light purple
        Color(hex: "FFB8D4"), // Light pink
        Color(hex: "FFFFFF"), // White
        Color(hex: "B8FFD4"), // Light green
        Color(hex: "FFD4B8"), // Light orange
        Color(hex: "8EC5FF"), // Medium blue
        Color(hex: "C58EFF"), // Medium purple
    ]
}
