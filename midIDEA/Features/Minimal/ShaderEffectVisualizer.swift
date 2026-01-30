import SwiftUI
import Inferno

/// Shader Effects visualizer: stitchable Metal effects layered on a MeshGradient base.
/// Silence = clean Breathing Aura MeshGradient.
/// Loud = full chromatic split + radial glow + noise distortion + hue shift.
struct ShaderEffectVisualizer: View {
    let audioLevel: Float  // -60 to 0 dB
    let isRecording: Bool
    let isIdle: Bool

    @State private var interpolator = AudioInterpolator()

    private var normalizedLevel: Float {
        let clamped = max(-60, min(0, audioLevel))
        return (clamped + 60) / 60
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let physics = interpolator.getPhysics(at: time)
                let smoothed = physics.smoothed
                let peak = physics.peak
                let size = geo.size

                // Base: Breathing Aura MeshGradient
                baseMeshGradient(time: time, smoothed: smoothed, peak: peak)
                    // Layer 1: RGB channel split via Inferno colorPlanes
                    .layerEffect(
                        InfernoShaderLibrary.colorPlanes(
                            .float2(
                                Float(smoothed * 12.0),
                                Float(smoothed * 8.0)
                            )
                        ),
                        maxSampleOffset: CGSize(width: 20, height: 20),
                        isEnabled: smoothed > 0.05
                    )
                    // Layer 2: Radial glow pulse
                    .colorEffect(
                        ShaderLibrary.radialGlow(
                            .float2(Float(size.width), Float(size.height)),
                            .float(Float(time)),
                            .float(smoothed)
                        ),
                        isEnabled: smoothed > 0.02
                    )
                    // Layer 3: Water ripple distortion via Inferno
                    .distortionEffect(
                        InfernoShaderLibrary.water(
                            .float2(Float(size.width), Float(size.height)),
                            .float(Float(time)),
                            .float(2.0 + peak * 6.0),     // speed: 2-8
                            .float(1.0 + peak * 4.0),     // strength: 1-5
                            .float(8.0 + smoothed * 12.0)  // frequency: 8-20
                        ),
                        maxSampleOffset: CGSize(width: 15, height: 15),
                        isEnabled: peak > 0.1
                    )
                    // Layer 4: Hue shift driven by audio
                    .colorEffect(
                        ShaderLibrary.hueShift(
                            .float(smoothed * 0.3)
                        ),
                        isEnabled: smoothed > 0.05
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onChange(of: audioLevel) { _, _ in
            interpolator.updateSample(normalizedLevel)
        }
        .onChange(of: isRecording) { _, recording in
            if !recording {
                interpolator.reset()
            }
        }
    }

    // MARK: - Base MeshGradient (Breathing Aura style)

    @ViewBuilder
    private func baseMeshGradient(time: Double, smoothed: Float, peak: Float) -> some View {
        let audio = Double(smoothed)
        let breathWeight = max(0, 1 - audio * 3)
        let breathCycle = sin(time * 1.2566)
        let breathAmp: Float = Float(breathWeight * 0.06)
        let audioAmp: Float = Float(audio * 0.30)
        let amp = breathAmp + audioAmp

        let xDrift = Float(breathWeight * 0.04 * sin(time * 0.8976))
        let warmth = min(1.0, audio * 2.5)

        let auraOpacity = 0.4 + breathWeight * 0.45 * (0.5 + 0.5 * sin(time * 1.2566))
            + audio * 0.5

        MeshGradient(
            width: 4,
            height: 4,
            points: auraPoints(time: time, amp: amp, breathCycle: breathCycle, breathAmp: breathAmp, xDrift: xDrift, peak: peak),
            colors: auraColors(warmth: warmth, audio: audio),
            smoothsColors: true
        )
        .opacity(min(1.0, auraOpacity))
        .saturation(1.3)
    }

    private func auraPoints(time: Double, amp: Float, breathCycle: Double, breathAmp: Float, xDrift: Float, peak: Float) -> [SIMD2<Float>] {
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

    private func auraColors(warmth: Double, audio: Double) -> [Color] {
        (0..<16).map { i in
            let cool = CachedColors.auraCool[i]
            let warm = CachedColors.auraWarm[i]
            let isCenter = [5, 6, 9, 10].contains(i)
            let row = i / 4
            let baseOpacity: Double = (row == 0 || row == 3) ? 0.7 : 0.9
            let centerFlash = isCenter ? min(0.3, audio * 0.5) : 0

            if warmth < 0.01 {
                return cool.opacity(baseOpacity)
            } else {
                return warm.opacity(min(1.0, baseOpacity * warmth + centerFlash))
            }
        }
    }
}
