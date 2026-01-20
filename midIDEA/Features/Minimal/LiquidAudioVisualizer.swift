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

// MARK: - Render State (Reference Type for 120Hz Physics)

/// Reference type for frame-by-frame physics calculations.
/// Using a class avoids triggering SwiftUI View rebuilds on every frame.
private class RenderState {
    var smoothedLevel: Float = 0
    var previousLevel: Float = 0
    var peakIntensity: Float = 0
}

/// GPU-accelerated liquid visualizer using MeshGradient.
/// Renders at 120Hz on ProMotion displays with minimal CPU usage.
struct LiquidAudioVisualizer: View {
    let audioLevel: Float  // -60 to 0 dB
    let isRecording: Bool
    let isIdle: Bool
    var colorMode: VisualizerColorMode = .ocean

    // Reference type for physics state (doesn't trigger View rebuilds)
    @State private var renderState = RenderState()

    // Normalized raw audio level (0 to 1)
    private var normalizedLevel: Float {
        let clamped = max(-60, min(0, audioLevel))
        return (clamped + 60) / 60
    }

    // MARK: - Physics Calculation

    /// Calculate smoothed level and peak intensity for current frame.
    /// Mutates RenderState class directly (safe - doesn't trigger View rebuilds).
    private func calculatePhysics(targetLevel: Float) -> (smoothed: Float, peak: Float) {
        // 1. Smooth the raw audio level - AGGRESSIVE: more responsive
        let smoothingFactor: Float = 0.18  // was 0.12
        let newSmoothed = renderState.smoothedLevel + (targetLevel - renderState.smoothedLevel) * smoothingFactor

        // 2. Calculate peak intensity (spikes on sudden volume, then decays)
        let delta = newSmoothed - renderState.previousLevel
        let decayRate: Float = 0.88  // was 0.92 - faster decay for snappier feel

        var newPeak = renderState.peakIntensity * decayRate
        if delta > 0.05 {  // AGGRESSIVE: was 0.15 - trigger on normal speech
            newPeak = min(1.0, newPeak + delta * 3.0)  // was delta * 2.0
        }

        // 3. Update state (safe because RenderState is a class)
        renderState.previousLevel = renderState.smoothedLevel
        renderState.smoothedLevel = newSmoothed
        renderState.peakIntensity = newPeak

        return (newSmoothed, newPeak)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Layer 1: MeshGradient (GPU-rendered at 120Hz on ProMotion)
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate

                    // Calculate physics synchronously (fast, no SwiftUI overhead)
                    let physics = calculatePhysics(targetLevel: normalizedLevel)

                    MeshGradient(
                        width: 4,
                        height: 4,
                        points: meshPoints(time: time, smoothed: physics.smoothed, peak: physics.peak),
                        colors: meshColors(time: time, smoothed: physics.smoothed)
                    )
                    .blur(radius: 0)  // v3: Zero blur for sharp color bands like reference
                    .saturation(1.2)
                }
                .drawingGroup()  // Force Metal/GPU rendering

                // Layer 2: Film grain noise for texture
                NoiseTextureView()
                    .opacity(0.025)  // Very subtle - CIRandomGenerator is high contrast
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    // MARK: - Mesh Points (Voice-Driven Animation + Peak Explosion)

    /// 4x4 grid = 16 points. Creates horizontal wave bands like reference animation.
    /// Audio amplifies wave height - baseline smooth waves always visible, voice makes waves bigger.
    private func meshPoints(time: Double, smoothed: Float, peak: Float) -> [SIMD2<Float>] {
        let audio = Double(smoothed)
        let baseSpeed: Double = 0.08  // v3: SLOWER - elegant flow like reference
        let t = time * baseSpeed

        // v3: HUGE amplitude - visible waves like reference
        let baseAmp: Float = 0.25  // was 0.12 - massive baseline waves always visible
        let audioAmp: Float = Float(audio * 0.35)  // voice amplifies further
        let amp: Float = baseAmp + audioAmp

        // v3: Gentler explosion for this style
        let explosion = peak * 0.15  // was 0.35 - less jarring

        // Wave function for vertical (Y) movement only - creates horizontal bands
        func wave(_ phase: Double, _ intensity: Float) -> Float {
            Float(sin(t + phase) * Double(amp * intensity))
        }

        // Radial offset from center (0.5, 0.5) for explosion effect
        func radialPush(_ x: Float, _ y: Float) -> SIMD2<Float> {
            let dx = x - 0.5
            let dy = y - 0.5
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0.001 else { return SIMD2(x, y) }
            let pushX = (dx / dist) * explosion
            let pushY = (dy / dist) * explosion
            return SIMD2(x + pushX, y + pushY)
        }

        // 4x4 grid layout for HORIZONTAL WAVE BANDS:
        // Each row moves together vertically (Y only) to create rippling horizontal stripes
        // Rows have different phases so bands undulate at different times

        let basePoints: [(Float, Float)] = [
            // Row 0 (top) - fixed at top edge
            (0, 0),
            (0.33, 0),
            (0.66, 0),
            (1, 0),

            // Row 1 - moves as a horizontal band (same Y offset across row)
            (0, 0.33 + wave(0, 0.5)),
            (0.33, 0.33 + wave(0, 0.6)),
            (0.66, 0.33 + wave(0, 0.6)),
            (1, 0.33 + wave(0, 0.5)),

            // Row 2 - moves as a horizontal band (different phase)
            (0, 0.66 + wave(1.5, 0.6)),
            (0.33, 0.66 + wave(1.5, 0.7)),
            (0.66, 0.66 + wave(1.5, 0.7)),
            (1, 0.66 + wave(1.5, 0.6)),

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
    private func oceanMeshColors(audioIntensity: Double) -> [Color] {
        let boost = 0.8 + audioIntensity * 0.2

        return [
            // Row 0 - top (white/cream)
            Color(hex: "FFFEF5").opacity(0.95 * boost),
            Color(hex: "FFFDF0").opacity(0.95 * boost),
            Color(hex: "FFFEF5").opacity(0.95 * boost),
            Color(hex: "FFFDF0").opacity(0.95 * boost),

            // Row 1 - light cyan
            Color(hex: "E0FFFF").opacity(0.9 * boost),
            Color(hex: "B0E0E6").opacity(0.9 * boost),
            Color(hex: "AFEEEE").opacity(0.9 * boost),
            Color(hex: "E0FFFF").opacity(0.9 * boost),

            // Row 2 - cyan/teal
            Color(hex: "40E0D0").opacity(0.85 * boost),
            Color(hex: "00CED1").opacity(0.85 * boost),
            Color(hex: "20B2AA").opacity(0.85 * boost),
            Color(hex: "48D1CC").opacity(0.85 * boost),

            // Row 3 - bottom (deep blue)
            Color(hex: "0077B6").opacity(0.9 * boost),
            Color(hex: "0096C7").opacity(0.9 * boost),
            Color(hex: "00B4D8").opacity(0.9 * boost),
            Color(hex: "0077B6").opacity(0.9 * boost)
        ]
    }

    private func coolMeshColors(audioIntensity: Double) -> [Color] {
        // Base opacities - bright base with subtle audio boost
        let boost = 0.6 + audioIntensity * 0.4
        let baseOpacities: [Double] = [0.3, 0.5, 0.5, 0.3, 0.5, 0.7, 0.7, 0.5, 0.5, 0.7, 0.7, 0.5, 0.3, 0.5, 0.5, 0.3]

        if isRecording {
            // Warm reds/oranges when recording
            let colors = [
                Color(hex: "ff6b6b"), Color(hex: "ffa502"), Color(hex: "ff4757"), Color(hex: "ff6b6b"),
                Color(hex: "ffa502"), Color(hex: "ff6348"), Color(hex: "ffc048"), Color(hex: "ffa502"),
                Color(hex: "ff4757"), Color(hex: "ffc048"), Color(hex: "ee5a24"), Color(hex: "ff4757"),
                Color(hex: "ff6b6b"), Color(hex: "ffa502"), Color(hex: "ff4757"), Color(hex: "ff6b6b")
            ]
            return zip(colors, baseOpacities).map { $0.opacity(min(1.0, $1 * boost)) }
        } else {
            // Cool blues/purples when idle
            let colors = [
                Color(hex: "667eea"), Color(hex: "764ba2"), Color(hex: "6B8DD6"), Color(hex: "667eea"),
                Color(hex: "764ba2"), Color(hex: "8E37D7"), Color(hex: "00d2d3"), Color(hex: "764ba2"),
                Color(hex: "6B8DD6"), Color(hex: "00d2d3"), Color(hex: "5f27cd"), Color(hex: "6B8DD6"),
                Color(hex: "667eea"), Color(hex: "764ba2"), Color(hex: "6B8DD6"), Color(hex: "667eea")
            ]
            return zip(colors, baseOpacities).map { $0.opacity(min(1.0, $1 * boost)) }
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
        let colors: [Color] = [
            Color(hex: "ff6b6b"), Color(hex: "ffa502"), Color(hex: "ff9ff3"), Color(hex: "ff6b6b"),
            Color(hex: "ffa502"), Color(hex: "ee5a24"), Color(hex: "ff4757"), Color(hex: "ffa502"),
            Color(hex: "ff9ff3"), Color(hex: "ff4757"), Color(hex: "c44569"), Color(hex: "ff9ff3"),
            Color(hex: "ff6b6b"), Color(hex: "ffa502"), Color(hex: "ff9ff3"), Color(hex: "ff6b6b")
        ]
        let baseOpacities: [Double] = [0.3, 0.5, 0.5, 0.3, 0.5, 0.7, 0.7, 0.5, 0.5, 0.7, 0.7, 0.5, 0.3, 0.5, 0.5, 0.3]
        let boost = 0.6 + audioIntensity * 0.4
        return zip(colors, baseOpacities).map { $0.opacity(min(1.0, $1 * boost)) }
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
