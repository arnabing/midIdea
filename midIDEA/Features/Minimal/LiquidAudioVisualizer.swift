import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Color Mode

enum VisualizerColorMode: String, CaseIterable {
    case ocean = "Ocean"  // Default - matches reference animation
    case cool = "Cool Blues"
    case lavaLamp = "Lava Lamp"
    case rainbow = "Rainbow"
    case sunset = "Sunset"
    case aurora = "Aurora"
}

// MARK: - Visual Style

enum VisualizerStyle: String, CaseIterable {
    case liquidOcean = "Liquid Ocean"       // Smooth ocean waves
    case plasmaPulse = "Plasma Pulse"       // High contrast dramatic
    case breathingAura = "Breathing Aura"   // Alive idle, cool→warm crossfade
    case radiantPulse = "Radiant Pulse"     // Radial center breathing, neon energy
}

// MARK: - Cached Color Palettes (Pre-computed, not per-frame)

private enum CachedColors {
    // Ocean palette - computed once at launch
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
}

// MARK: - Audio Interpolator (Smooth 20Hz→120Hz)

/// Interpolates between audio samples for smooth 120Hz rendering from 20Hz data.
/// Uses smoothstep interpolation and physics-based smoothing.
private final class AudioInterpolator: ObservableObject {
    // Sample buffer
    private var previousSample: Float = 0
    private var currentSample: Float = 0
    private var lastUpdateTime: TimeInterval = 0
    private let sampleInterval: TimeInterval = 0.05  // 20Hz from AudioService

    // Physics state
    private var smoothedLevel: Float = 0
    private var previousSmoothed: Float = 0
    private var peakIntensity: Float = 0

    /// Called when new audio sample arrives (20Hz)
    func updateSample(_ normalizedLevel: Float) {
        previousSample = currentSample
        currentSample = normalizedLevel
        lastUpdateTime = CACurrentMediaTime()
    }

    /// Called every render frame (120Hz) - returns interpolated & smoothed values
    func getPhysics(at time: TimeInterval) -> (smoothed: Float, peak: Float) {
        // Use CACurrentMediaTime to match updateSample's time source
        // (context.date uses different epoch, causing flickering)
        let now = CACurrentMediaTime()
        let elapsed = now - lastUpdateTime
        let t = Float(min(max(elapsed / sampleInterval, 0), 1.0))
        let eased = t * t * (3 - 2 * t)  // Smoothstep for natural motion
        let interpolatedLevel = previousSample + (currentSample - previousSample) * eased

        // Apply physics smoothing on top of interpolation
        let smoothingFactor: Float = 0.18
        smoothedLevel += (interpolatedLevel - smoothedLevel) * smoothingFactor

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

/// GPU-accelerated liquid visualizer using MeshGradient.
/// Renders at 120Hz on ProMotion displays with smooth audio interpolation.
/// Supports multiple visual styles, all voice-reactive.
struct LiquidAudioVisualizer: View {
    let audioLevel: Float  // -60 to 0 dB
    let isRecording: Bool
    let isIdle: Bool
    var colorMode: VisualizerColorMode = .ocean
    var visualStyle: VisualizerStyle = .liquidOcean

    // Audio interpolator for smooth 20Hz→120Hz rendering
    @State private var interpolator = AudioInterpolator()

    // State-based ambient animation (only used by Siri Glow and Plasma styles)
    @State private var animationPhase = false

    // Normalized raw audio level (0 to 1)
    private var normalizedLevel: Float {
        let clamped = max(-60, min(0, audioLevel))
        return (clamped + 60) / 60
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Main MeshGradient with voice reactivity
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let physics = interpolator.getPhysics(at: time)

                    meshGradientView(time: time, physics: physics)
                }
                // Note: Removed .drawingGroup() - MeshGradient is already GPU-accelerated
                // and drawingGroup can cause frame sync flickering with TimelineView

                // Film grain noise for texture (using faster blend mode)
                NoiseTextureView()
                    .opacity(0.02)
                    .blendMode(.plusLighter)  // Faster than .overlay
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onChange(of: audioLevel) { _, _ in
            // Feed new audio sample to interpolator
            interpolator.updateSample(normalizedLevel)
        }
        .onChange(of: isRecording) { _, recording in
            if !recording {
                interpolator.reset()
            }
        }
        .onAppear {
            // Start ambient animation only for styles that use animationPhase (Plasma Pulse)
            // liquidOcean, breathingAura, radiantPulse use time-based motion directly
            if visualStyle == .plasmaPulse {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    animationPhase = true
                }
            }
        }
        .onChange(of: visualStyle) { _, newStyle in
            // Start/stop ambient animation when switching styles
            if newStyle == .plasmaPulse && !animationPhase {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    animationPhase = true
                }
            }
        }
    }

    // MARK: - Mesh Gradient View (Style-based)

    @ViewBuilder
    private func meshGradientView(time: Double, physics: (smoothed: Float, peak: Float)) -> some View {
        // Note: Brightness is now baked into colors to avoid recompositing flicker
        // from the .brightness() modifier changing every frame

        switch visualStyle {
        case .liquidOcean:
            MeshGradient(
                width: 4,
                height: 4,
                points: meshPoints(time: time, smoothed: physics.smoothed, peak: physics.peak),
                colors: meshColors(time: time, smoothed: physics.smoothed),
                smoothsColors: true
            )
            .saturation(1.2)

        case .plasmaPulse:
            MeshGradient(
                width: 4,
                height: 4,
                points: plasmaPoints(time: time, smoothed: physics.smoothed, peak: physics.peak),
                colors: plasmaColors(time: time, smoothed: physics.smoothed, peak: physics.peak),
                smoothsColors: true
            )
            .saturation(1.5)

        case .breathingAura:
            let breathWeight = max(0, 1 - Double(physics.smoothed) * 3)
            let auraOpacity = 0.4 + breathWeight * 0.45 * (0.5 + 0.5 * sin(time * 1.2566)) // 5s sine
                + Double(physics.smoothed) * 0.5
            MeshGradient(
                width: 4,
                height: 4,
                points: auraPoints(time: time, smoothed: physics.smoothed, peak: physics.peak),
                colors: auraColors(time: time, smoothed: physics.smoothed),
                smoothsColors: true
            )
            .opacity(min(1.0, auraOpacity))
            .saturation(1.3)

        case .radiantPulse:
            MeshGradient(
                width: 4,
                height: 4,
                points: radiantPoints(time: time, smoothed: physics.smoothed, peak: physics.peak),
                colors: radiantColors(time: time, smoothed: physics.smoothed, peak: physics.peak),
                smoothsColors: true
            )
            .saturation(1.4)
        }
    }

    // MARK: - Mesh Points (Voice-Driven Animation + Peak Explosion)

    /// 4x4 grid = 16 points. Creates horizontal wave bands like reference animation.
    /// Audio amplifies wave height - baseline smooth waves always visible, voice makes waves bigger.
    /// IMPORTANT: Points are clamped to prevent row crossover which causes visible seams/lines.
    private func meshPoints(time: Double, smoothed: Float, peak: Float) -> [SIMD2<Float>] {
        let audio = Double(smoothed)
        let baseSpeed: Double = 0.08  // Slow, elegant flow
        let t = time * baseSpeed

        // Reduced amplitude to prevent row crossover (was causing flickering seams)
        // Row 1 range: [0.18, 0.48], Row 2 range: [0.52, 0.82] - no overlap possible
        let baseAmp: Float = 0.08  // Reduced from 0.25
        let audioAmp: Float = Float(audio * 0.12)  // Reduced from 0.5
        let amp: Float = baseAmp + audioAmp  // Max total: 0.20

        // Peak explosion - clamped to prevent points leaving bounds
        let explosion = min(peak * 0.15, 0.12)  // Capped at 0.12

        // Wave function for vertical (Y) movement only
        func wave(_ phase: Double, _ intensity: Float) -> Float {
            Float(sin(t + phase) * Double(amp * intensity))
        }

        // Radial offset from center for explosion effect (clamped)
        func radialPush(_ x: Float, _ y: Float) -> SIMD2<Float> {
            let dx = x - 0.5
            let dy = y - 0.5
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return SIMD2(x, y) }
            let pushX = (dx / dist) * explosion
            let pushY = (dy / dist) * explosion
            // Clamp to valid mesh range with margin
            let newX = max(0.02, min(0.98, x + pushX))
            let newY = max(0.02, min(0.98, y + pushY))
            return SIMD2(newX, newY)
        }

        // Row Y positions with safe margins to prevent crossover
        // Row 0: 0.0 (fixed)
        // Row 1: 0.33 ± 0.15 max → range [0.18, 0.48]
        // Row 2: 0.66 ± 0.15 max → range [0.51, 0.81]
        // Row 3: 1.0 (fixed)

        // Clamp row Y to prevent crossing into adjacent rows
        func clampRow1(_ y: Float) -> Float {
            max(0.12, min(0.48, y))  // Can't go below 0.12 or above 0.48
        }
        func clampRow2(_ y: Float) -> Float {
            max(0.52, min(0.88, y))  // Can't go below 0.52 or above 0.88
        }

        let basePoints: [(Float, Float)] = [
            // Row 0 (top) - fixed at top edge
            (0, 0),
            (0.33, 0),
            (0.66, 0),
            (1, 0),

            // Row 1 - moves as a horizontal band (clamped to prevent crossover)
            (0, clampRow1(0.33 + wave(0, 0.8))),
            (0.33, clampRow1(0.33 + wave(0, 1.0))),
            (0.66, clampRow1(0.33 + wave(0, 1.0))),
            (1, clampRow1(0.33 + wave(0, 0.8))),

            // Row 2 - moves as a horizontal band (different phase, clamped)
            (0, clampRow2(0.66 + wave(1.5, 0.8))),
            (0.33, clampRow2(0.66 + wave(1.5, 1.0))),
            (0.66, clampRow2(0.66 + wave(1.5, 1.0))),
            (1, clampRow2(0.66 + wave(1.5, 0.8))),

            // Row 3 (bottom) - fixed at bottom edge
            (0, 1),
            (0.33, 1),
            (0.66, 1),
            (1, 1)
        ]

        // Apply radial explosion to interior points (indices 5, 6, 9, 10)
        return basePoints.enumerated().map { index, point in
            let isInterior = [5, 6, 9, 10].contains(index)
            if isInterior {
                return radialPush(point.0, point.1)
            }
            return SIMD2(point.0, point.1)
        }
    }

    // MARK: - Plasma Pulse Points (High Contrast Dramatic)

    /// Dramatic mesh distortion with aggressive peak response.
    /// Uses clamping to prevent row crossover and mesh artifacts.
    private func plasmaPoints(time: Double, smoothed: Float, peak: Float) -> [SIMD2<Float>] {
        let audio = Double(smoothed)
        let t = time * 0.15  // Faster movement

        // Reduced amplitude to prevent row crossover
        let baseAmp: Float = 0.10  // Reduced from 0.15
        let audioAmp: Float = Float(audio * 0.15)  // Reduced from 0.5
        let amp = baseAmp + audioAmp  // Max: 0.25

        // Clamped explosion on peaks
        let explosion = min(peak * 0.2, 0.15)  // Capped

        func wave(_ phase: Double, _ intensity: Float) -> Float {
            Float(sin(t + phase) * Double(amp * intensity))
        }

        // Clamp row Y to prevent crossing
        func clampRow1(_ y: Float) -> Float {
            max(0.12, min(0.48, y))
        }
        func clampRow2(_ y: Float) -> Float {
            max(0.52, min(0.88, y))
        }

        func radialPush(_ x: Float, _ y: Float, scale: Float = 1.0) -> SIMD2<Float> {
            let dx = x - 0.5
            let dy = y - 0.5
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return SIMD2(x, y) }
            let push = explosion * scale
            // Clamp to valid range
            let newX = max(0.02, min(0.98, x + (dx / dist) * push))
            let newY = max(0.02, min(0.98, y + (dy / dist) * push))
            return SIMD2(newX, newY)
        }

        let breathe: Float = animationPhase ? 0.02 : -0.02  // Reduced from 0.04

        let basePoints: [(Float, Float)] = [
            (0, 0),
            (max(0.1, 0.33 + breathe), 0),
            (min(0.9, 0.66 - breathe), 0),
            (1, 0),

            (0, clampRow1(0.33 + wave(0, 0.8))),
            (0.33, clampRow1(0.33 + wave(0.5, 1.0))),
            (0.66, clampRow1(0.33 + wave(1.0, 1.0))),
            (1, clampRow1(0.33 + wave(1.5, 0.8))),

            (0, clampRow2(0.66 + wave(2.0, 0.8))),
            (0.33, clampRow2(0.66 + wave(2.5, 1.0))),
            (0.66, clampRow2(0.66 + wave(3.0, 1.0))),
            (1, clampRow2(0.66 + wave(3.5, 0.8))),

            (0, 1),
            (max(0.1, 0.33 - breathe), 1),
            (min(0.9, 0.66 + breathe), 1),
            (1, 1)
        ]

        return basePoints.enumerated().map { index, point in
            let isInterior = [5, 6, 9, 10].contains(index)
            if isInterior {
                return radialPush(point.0, point.1, scale: 1.2)
            }
            return SIMD2(point.0, point.1)
        }
    }

    /// Plasma colors - high contrast with peak-triggered flashes
    private func plasmaColors(time: Double, smoothed: Float, peak: Float) -> [Color] {
        let audioIntensity = Double(smoothed)
        let peakFlash = Double(peak)

        // Use cached plasma colors with dynamic intensity
        let boost = 0.6 + audioIntensity * 0.4 + peakFlash * 0.3

        return CachedColors.plasma.enumerated().map { index, color in
            let row = index / 4
            let isCenter = [5, 6, 9, 10].contains(index)
            // Center glows brighter on peaks
            let centerBoost = isCenter ? peakFlash * 0.4 : 0
            // Edges more transparent
            let baseOpacity: Double = row == 0 || row == 3 ? 0.5 : 0.85
            return color.opacity(min(1.0, (baseOpacity + centerBoost) * boost))
        }
    }

    // MARK: - Breathing Aura Points

    /// Breathing Aura: visible idle breathing with X-axis drift, 10x dynamic range.
    /// 5s sine cycle moves rows ±0.06 when idle, audio crossfades to voice-driven motion.
    private func auraPoints(time: Double, smoothed: Float, peak: Float) -> [SIMD2<Float>] {
        let audio = Double(smoothed)
        let breathWeight = max(0, 1 - audio * 3)  // Fades out fast as voice takes over
        let breathCycle = sin(time * 1.2566)  // 5s period (2π/5)
        let breathAmp: Float = Float(breathWeight * 0.06)  // ±0.06 when idle
        let audioAmp: Float = Float(audio * 0.30)  // Up to 0.30 when speaking (10x range from ~0.03 idle)
        let amp = breathAmp + audioAmp

        // X-axis drift: 7s horizontal sine for elliptical Lissajous (interior points only)
        let xDrift = Float(breathWeight * 0.04 * sin(time * 0.8976))  // 2π/7

        let explosion = min(peak * 0.15, 0.12)

        func wave(_ phase: Double, _ intensity: Float) -> Float {
            Float(sin(time * 0.08 + phase) * Double(amp * intensity))
                + Float(breathCycle) * breathAmp * intensity
        }

        func clampRow1(_ y: Float) -> Float { max(0.12, min(0.48, y)) }
        func clampRow2(_ y: Float) -> Float { max(0.52, min(0.88, y)) }

        func radialPush(_ x: Float, _ y: Float) -> SIMD2<Float> {
            let dx = x - 0.5
            let dy = y - 0.5
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return SIMD2(x, y) }
            let newX = max(0.02, min(0.98, x + (dx / dist) * explosion))
            let newY = max(0.02, min(0.98, y + (dy / dist) * explosion))
            return SIMD2(newX, newY)
        }

        let basePoints: [(Float, Float)] = [
            (0, 0), (0.33, 0), (0.66, 0), (1, 0),

            (0, clampRow1(0.33 + wave(0, 0.8))),
            (max(0.02, min(0.98, 0.33 + xDrift)), clampRow1(0.33 + wave(0.3, 1.0))),
            (max(0.02, min(0.98, 0.66 - xDrift)), clampRow1(0.33 + wave(0.6, 1.0))),
            (1, clampRow1(0.33 + wave(0.9, 0.8))),

            (0, clampRow2(0.66 + wave(1.5, 0.8))),
            (max(0.02, min(0.98, 0.33 - xDrift)), clampRow2(0.66 + wave(1.8, 1.0))),
            (max(0.02, min(0.98, 0.66 + xDrift)), clampRow2(0.66 + wave(2.1, 1.0))),
            (1, clampRow2(0.66 + wave(2.4, 0.8))),

            (0, 1), (0.33, 1), (0.66, 1), (1, 1)
        ]

        return basePoints.enumerated().map { index, point in
            if [5, 6, 9, 10].contains(index) {
                return radialPush(point.0, point.1)
            }
            return SIMD2(point.0, point.1)
        }
    }

    /// Breathing Aura colors: cool blues/purples when idle → warm amber/white when speaking.
    /// Center points flash white-hot on peaks.
    private func auraColors(time: Double, smoothed: Float) -> [Color] {
        let audio = Double(smoothed)
        let warmth = min(1.0, audio * 2.5)  // 0→1 crossfade threshold

        return (0..<16).map { i in
            let cool = CachedColors.auraCool[i]
            let warm = CachedColors.auraWarm[i]
            let isCenter = [5, 6, 9, 10].contains(i)
            let row = i / 4
            let baseOpacity: Double = (row == 0 || row == 3) ? 0.7 : 0.9

            // Crossfade cool→warm based on audio level
            if warmth < 0.01 {
                return cool.opacity(baseOpacity)
            } else if warmth > 0.99 {
                let centerFlash = isCenter ? min(0.3, audio * 0.5) : 0
                return warm.opacity(min(1.0, baseOpacity + centerFlash))
            } else {
                // Blend by mixing opacity-weighted layers
                let centerFlash = isCenter ? min(0.3, audio * 0.5) : 0
                // Use warm color with warmth-weighted opacity for crossfade effect
                return warm.opacity(min(1.0, baseOpacity * warmth + centerFlash))
                    // Note: true color blending requires both layers; we approximate with warm dominance
            }
        }
    }

    // MARK: - Radiant Pulse Points

    /// Radiant Pulse: radial breathing from center, multi-frequency motion, adaptive speed.
    /// Interior points pulse toward/away from (0.5, 0.5) instead of row-based waves.
    private func radiantPoints(time: Double, smoothed: Float, peak: Float) -> [SIMD2<Float>] {
        let audio = Double(smoothed)

        // Adaptive breath speed: 6s idle → 2s at full voice
        let breathSpeed = 1.047 + audio * 2.094  // 2π/6 to 2π/2
        let breathPhase = time * breathSpeed

        // Multi-frequency: 3 layered sines for complex non-repeating shimmer
        func multiSine(_ t: Double, _ offset: Double) -> Double {
            sin(t * 0.4 + offset) * 0.5
            + sin(t * 1.1 + offset * 1.3) * 0.3
            + sin(t * 2.3 + offset * 0.7) * 0.2
        }

        // Harmonic wave: fundamental + 1.7x harmonic
        func harmonicWave(_ phase: Double) -> Double {
            sin(phase) * 0.7 + sin(phase * 1.7) * 0.3
        }

        let baseAmp: Float = 0.06
        let audioAmp: Float = Float(audio * 0.25)
        let amp = baseAmp + audioAmp

        // Stronger peak explosions (cap at 0.20 vs 0.12 in Ocean)
        let explosion = min(peak * 0.25, 0.20)

        func clampRow1(_ y: Float) -> Float { max(0.12, min(0.48, y)) }
        func clampRow2(_ y: Float) -> Float { max(0.52, min(0.88, y)) }

        // Radial pulse: interior points breathe toward/away from center
        func radialBreath(_ x: Float, _ y: Float, index: Int) -> SIMD2<Float> {
            let dx = x - 0.5
            let dy = y - 0.5
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return SIMD2(x, y) }

            let breathOffset = harmonicWave(breathPhase + Double(index) * 0.5)
            let radialAmp = Double(amp) * 0.5 * breathOffset
            let explodeAmp = Double(explosion)

            let totalPush = Float(radialAmp + explodeAmp)
            let newX = max(0.02, min(0.98, x + (dx / dist) * totalPush))
            let newY = y + (dy / dist) * totalPush  // Y will be clamped by row
            return SIMD2(newX, newY)
        }

        let shimmer = multiSine(time, 0)

        let basePoints: [(Float, Float)] = [
            (0, 0), (0.33, 0), (0.66, 0), (1, 0),

            (0, clampRow1(0.33 + Float(shimmer) * amp * 0.5)),
            (0.33, clampRow1(0.33 + Float(multiSine(time, 1.0)) * amp)),
            (0.66, clampRow1(0.33 + Float(multiSine(time, 2.0)) * amp)),
            (1, clampRow1(0.33 + Float(multiSine(time, 3.0)) * amp * 0.5)),

            (0, clampRow2(0.66 + Float(multiSine(time, 4.0)) * amp * 0.5)),
            (0.33, clampRow2(0.66 + Float(multiSine(time, 5.0)) * amp)),
            (0.66, clampRow2(0.66 + Float(multiSine(time, 6.0)) * amp)),
            (1, clampRow2(0.66 + Float(multiSine(time, 7.0)) * amp * 0.5)),

            (0, 1), (0.33, 1), (0.66, 1), (1, 1)
        ]

        // Apply radial breathing to interior points
        return basePoints.enumerated().map { index, point in
            if [5, 6, 9, 10].contains(index) {
                let breathed = radialBreath(point.0, point.1, index: index)
                // Re-clamp Y after radial push
                let clampedY: Float
                if index < 8 {
                    clampedY = clampRow1(breathed.y)
                } else {
                    clampedY = clampRow2(breathed.y)
                }
                return SIMD2(breathed.x, clampedY)
            }
            return SIMD2(point.0, point.1)
        }
    }

    /// Radiant Pulse colors: muted pastels when idle, fully saturated neons when speaking.
    /// Crossfade at smoothed=0.5.
    private func radiantColors(time: Double, smoothed: Float, peak: Float) -> [Color] {
        let audio = Double(smoothed)
        let neonMix = min(1.0, audio * 2.0)  // 0→1 crossfade, full neon at smoothed=0.5
        let peakFlash = Double(peak)

        return (0..<16).map { i in
            let pastel = CachedColors.radiantPastel[i]
            let neon = CachedColors.radiantNeon[i]
            let isCenter = [5, 6, 9, 10].contains(i)
            let row = i / 4
            let baseOpacity: Double = (row == 0 || row == 3) ? 0.5 : 0.85

            let centerBoost = isCenter ? peakFlash * 0.4 : 0
            let boost = 0.6 + audio * 0.4 + peakFlash * 0.2

            if neonMix < 0.01 {
                return pastel.opacity(min(1.0, baseOpacity * boost))
            } else if neonMix > 0.99 {
                return neon.opacity(min(1.0, (baseOpacity + centerBoost) * boost))
            } else {
                // Crossfade: use neon with neonMix-weighted opacity
                return neon.opacity(min(1.0, (baseOpacity + centerBoost) * boost * neonMix))
            }
        }
    }

    // MARK: - Mesh Colors (Audio-Reactive)

    private func meshColors(time: Double, smoothed: Float) -> [Color] {
        // Audio-reactive intensity boost using smoothed level
        let audioIntensity = Double(smoothed)

        switch colorMode {
        case .ocean:
            return oceanMeshColors(audioIntensity: audioIntensity)
        case .cool:
            return coolMeshColors(audioIntensity: audioIntensity)
        case .lavaLamp:
            return lavaLampMeshColors(time: time, audioIntensity: audioIntensity)
        case .rainbow:
            return rainbowMeshColors(time: time, audioIntensity: audioIntensity)
        case .sunset:
            return sunsetMeshColors(audioIntensity: audioIntensity)
        case .aurora:
            return auroraMeshColors(time: time, audioIntensity: audioIntensity)
        }
    }

    // MARK: - Color Palettes (16 colors for 4x4 grid)

    /// Ocean: Vertical gradient matching reference animation
    /// White/cream top → light cyan → cyan/teal → deep blue bottom
    /// Uses cached colors for performance (eliminates per-frame Color(hex:) parsing)
    private func oceanMeshColors(audioIntensity: Double) -> [Color] {
        let boost = 0.7 + audioIntensity * 0.4  // 1.5x boost for more visible voice response

        // Apply opacity to cached colors (fast operation vs Color(hex:) parsing)
        return zip(CachedColors.ocean, CachedColors.oceanOpacities).map { color, opacity in
            color.opacity(opacity * boost)
        }
    }

    private func coolMeshColors(audioIntensity: Double) -> [Color] {
        // Uses cached colors for performance
        let boost = 0.6 + audioIntensity * 0.4
        let colors = isRecording ? CachedColors.coolWarm : CachedColors.coolBlues

        return zip(colors, CachedColors.coolOpacities).map { color, opacity in
            color.opacity(min(1.0, opacity * boost))
        }
    }

    private func lavaLampMeshColors(time: Double, audioIntensity: Double) -> [Color] {
        // Slow down time-based cycling by 5x (0.08 -> 0.016)
        let slowTime = time * 0.016
        let shift = sin(slowTime) * 0.1
        let boost = 0.6 + audioIntensity * 0.4

        if isRecording {
            // Warm lava colors
            let baseOpacities: [Double] = [0.3, 0.5, 0.5, 0.3, 0.5, 0.7, 0.7, 0.5, 0.5, 0.7, 0.7, 0.5, 0.3, 0.5, 0.5, 0.3]
            return (0..<16).map { i in
                let hue = fmod(0.02 + Double(i) * 0.01 + shift * 0.3, 0.12)
                let saturation = 0.7 + audioIntensity * 0.3
                return Color(hue: hue, saturation: saturation, brightness: 0.95).opacity(min(1.0, baseOpacities[i] * boost))
            }
        } else {
            // Cool purple/blue lava
            let baseOpacities: [Double] = [0.2, 0.4, 0.4, 0.2, 0.4, 0.6, 0.6, 0.4, 0.4, 0.6, 0.6, 0.4, 0.2, 0.4, 0.4, 0.2]
            return (0..<16).map { i in
                let hue = fmod(0.65 + Double(i) * 0.02 + shift, 1.0)
                let saturation = 0.5 + audioIntensity * 0.35
                return Color(hue: hue, saturation: saturation, brightness: 0.85).opacity(min(1.0, baseOpacities[i] * boost))
            }
        }
    }

    private func rainbowMeshColors(time: Double, audioIntensity: Double) -> [Color] {
        // Slow down cycle speed by 5x (0.2 -> 0.04, 0.08 -> 0.016)
        let cycleSpeed = isRecording ? 0.04 : 0.016
        let baseHue = fmod(time * cycleSpeed, 1.0)
        let saturation = 0.7 + audioIntensity * 0.3  // Vivid base
        let brightness = 0.8 + audioIntensity * 0.2
        let boost = 0.6 + audioIntensity * 0.4

        let baseOpacities: [Double] = [0.3, 0.5, 0.5, 0.3, 0.5, 0.7, 0.7, 0.5, 0.5, 0.7, 0.7, 0.5, 0.3, 0.5, 0.5, 0.3]

        return (0..<16).map { i in
            let row = i / 4
            let col = i % 4
            let hue = fmod(baseHue + Double(row + col) * 0.08, 1.0)
            return Color(hue: hue, saturation: saturation, brightness: brightness).opacity(min(1.0, baseOpacities[i] * boost))
        }
    }

    private func sunsetMeshColors(audioIntensity: Double) -> [Color] {
        // Uses cached colors for performance
        let boost = 0.6 + audioIntensity * 0.4
        return zip(CachedColors.sunset, CachedColors.coolOpacities).map { color, opacity in
            color.opacity(min(1.0, opacity * boost))
        }
    }

    private func auroraMeshColors(time: Double, audioIntensity: Double) -> [Color] {
        // Slow down time-based shift by 5x (0.1 -> 0.02)
        let slowTime = time * 0.02
        let shift = sin(slowTime) * 0.08
        let boost = 0.6 + audioIntensity * 0.4

        if isRecording {
            // Warmer aurora (greens shift to yellows)
            let baseOpacities: [Double] = [0.3, 0.5, 0.5, 0.3, 0.5, 0.7, 0.7, 0.5, 0.5, 0.7, 0.7, 0.5, 0.3, 0.5, 0.5, 0.3]
            return (0..<16).map { i in
                let baseHue = [0.25, 0.30, 0.20, 0.25, 0.30, 0.35, 0.28, 0.30, 0.20, 0.28, 0.33, 0.20, 0.25, 0.30, 0.20, 0.25][i]
                let hue = fmod(baseHue + shift, 1.0)
                let saturation = 0.7 + audioIntensity * 0.3
                return Color(hue: hue, saturation: saturation, brightness: 1.0).opacity(min(1.0, baseOpacities[i] * boost))
            }
        } else {
            // Cool aurora (greens/teals)
            let baseOpacities: [Double] = [0.2, 0.4, 0.4, 0.2, 0.4, 0.6, 0.6, 0.4, 0.4, 0.6, 0.6, 0.4, 0.2, 0.4, 0.4, 0.2]
            return (0..<16).map { i in
                let baseHue = [0.35, 0.42, 0.50, 0.35, 0.42, 0.38, 0.45, 0.42, 0.50, 0.45, 0.40, 0.50, 0.35, 0.42, 0.50, 0.35][i]
                let hue = fmod(baseHue + shift, 1.0)
                let saturation = 0.5 + audioIntensity * 0.4
                return Color(hue: hue, saturation: saturation, brightness: 0.9).opacity(min(1.0, baseOpacities[i] * boost))
            }
        }
    }

}

// MARK: - Noise Texture View

/// Film grain / noise texture overlay for added depth
/// Uses CIRandomGenerator for true pixel-level noise (fine film grain)
/// IMPORTANT: Noise is generated ONCE and cached to avoid per-frame CPU cost
struct NoiseTextureView: View {
    // Static cached noise image - generated only once using Core Image
    private static let cachedNoise: UIImage = {
        // Use Core Image's random generator for true pixel noise
        guard let filter = CIFilter(name: "CIRandomGenerator"),
              let noiseImage = filter.outputImage else {
            return UIImage()
        }

        // Crop to usable size (CIRandomGenerator produces infinite extent)
        let cropped = noiseImage.cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256))

        // Create context and render to CGImage
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(cropped, from: cropped.extent) else {
            return UIImage()
        }

        return UIImage(cgImage: cgImage)
    }()

    var body: some View {
        Image(uiImage: Self.cachedNoise)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

// MARK: - Preview

#Preview("Cool Blues - Idle") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -60,
            isRecording: false,
            isIdle: true,
            colorMode: .cool
        )
    }
    .ignoresSafeArea()
}

#Preview("Lava Lamp - Idle") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -60,
            isRecording: false,
            isIdle: true,
            colorMode: .lavaLamp
        )
    }
    .ignoresSafeArea()
}

#Preview("Rainbow - Recording") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -20,
            isRecording: true,
            isIdle: false,
            colorMode: .rainbow
        )
    }
    .ignoresSafeArea()
}

#Preview("Aurora - Idle") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -45,
            isRecording: false,
            isIdle: true,
            colorMode: .aurora
        )
    }
    .ignoresSafeArea()
}

#Preview("Sunset - Recording") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -15,
            isRecording: true,
            isIdle: false,
            colorMode: .sunset
        )
    }
    .ignoresSafeArea()
}

#Preview("Breathing Aura - Idle") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -60,
            isRecording: false,
            isIdle: true,
            visualStyle: .breathingAura
        )
    }
    .ignoresSafeArea()
}

#Preview("Breathing Aura - Speaking") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -15,
            isRecording: true,
            isIdle: false,
            visualStyle: .breathingAura
        )
    }
    .ignoresSafeArea()
}

#Preview("Radiant Pulse - Idle") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -60,
            isRecording: false,
            isIdle: true,
            visualStyle: .radiantPulse
        )
    }
    .ignoresSafeArea()
}

#Preview("Radiant Pulse - Speaking") {
    ZStack {
        Color(hex: "0A0A0F")
        LiquidAudioVisualizer(
            audioLevel: -15,
            isRecording: true,
            isIdle: false,
            visualStyle: .radiantPulse
        )
    }
    .ignoresSafeArea()
}
