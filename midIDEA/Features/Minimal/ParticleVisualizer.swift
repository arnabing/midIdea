import SwiftUI

// MARK: - Particle Model

private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat          // Position
    var y: CGFloat
    var vx: CGFloat         // Velocity
    var vy: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
    var lifetime: Double    // Total lifetime in seconds
    var age: Double = 0     // Current age
    var wanderPhase: Double // Sinusoidal horizontal wander offset

    var progress: Double { age / lifetime }

    /// Opacity envelope: fade-in 10%, fade-out 30%
    var envelopeOpacity: Double {
        if progress < 0.1 {
            return progress / 0.1
        } else if progress > 0.7 {
            return (1.0 - progress) / 0.3
        }
        return 1.0
    }
}

// MARK: - Particle Visualizer

/// Canvas-based particle emitter at 120Hz, layered on a dim MeshGradient.
/// Particles spawn center-biased, drift upward with sinusoidal wander.
/// Audio controls count, size, speed, and glow intensity.
struct ParticleVisualizer: View {
    let audioLevel: Float  // -60 to 0 dB
    let frequencyBands: [Float]  // [bass, mid, treble] normalized 0-1
    let onsetBands: [Float]      // [bass, mid, treble] spectral flux onset 0-1
    let isRecording: Bool
    let isIdle: Bool

    @State private var interpolator = AudioInterpolator()
    @State private var bandInterpolator = BandInterpolator()
    @State private var particles: [Particle] = []
    @State private var lastFrameTime: Double = CACurrentMediaTime()

    private var normalizedLevel: Float {
        let clamped = max(-60, min(0, audioLevel))
        return (clamped + 60) / 60
    }

    private let maxParticles = 120

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dim MeshGradient background
                dimBackground(size: geo.size)

                // Particle canvas at 120Hz
                TimelineView(.animation) { context in
                    let now = CACurrentMediaTime()
                    let physics = interpolator.getPhysics(at: now)
                    let bandPhysics = bandInterpolator.getPhysics(at: now)

                    Canvas { ctx, size in
                        updateParticles(now: now, size: size, smoothed: physics.smoothed, peak: physics.peak, bands: bandPhysics.bands)

                        for particle in particles {
                            let effectiveOpacity = particle.envelopeOpacity * particle.opacity * Double(0.5 + physics.smoothed * 0.5)

                            // Glow layer (larger, transparent)
                            let glowSize = particle.size * 3.0
                            let glowRect = CGRect(
                                x: particle.x - glowSize / 2,
                                y: particle.y - glowSize / 2,
                                width: glowSize,
                                height: glowSize
                            )
                            ctx.opacity = effectiveOpacity * 0.25
                            ctx.fill(
                                Circle().path(in: glowRect),
                                with: .color(particle.color)
                            )

                            // Core particle
                            let coreRect = CGRect(
                                x: particle.x - particle.size / 2,
                                y: particle.y - particle.size / 2,
                                width: particle.size,
                                height: particle.size
                            )
                            ctx.opacity = effectiveOpacity
                            ctx.fill(
                                Circle().path(in: coreRect),
                                with: .color(particle.color)
                            )
                        }
                    }
                    .allowsHitTesting(false)
                    .blendMode(.plusLighter)  // Additive blending for glow
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onChange(of: audioLevel) { _, _ in
            interpolator.updateSample(normalizedLevel)
        }
        .onChange(of: frequencyBands) { _, newBands in
            bandInterpolator.updateBands(newBands)
        }
        .onChange(of: onsetBands) { _, newOnsets in
            bandInterpolator.updateOnsets(newOnsets)
        }
        .onChange(of: isRecording) { _, recording in
            if !recording {
                interpolator.reset()
                bandInterpolator.reset()
            }
        }
    }

    // MARK: - Particle Simulation

    private func updateParticles(now: Double, size: CGSize, smoothed: Float, peak: Float, bands: [Float] = [0, 0, 0]) {
        let dt = min(now - lastFrameTime, 0.05)  // Cap delta to avoid jumps
        // Note: lastFrameTime updated via DispatchQueue to avoid mutating state in Canvas
        DispatchQueue.main.async { lastFrameTime = now }

        let audio = Double(smoothed)
        let peakVal = Double(peak)
        let bass = bands.count > 0 ? Double(bands[0]) : audio
        let mid = bands.count > 1 ? Double(bands[1]) : audio

        // Age and move existing particles
        var alive: [Particle] = []
        for var p in particles {
            p.age += dt
            if p.age >= p.lifetime { continue }

            // Movement: bass drives upward speed, mid drives horizontal wander
            let speedMul = 1.0 + bass * 3.5
            p.y += p.vy * dt * speedMul
            p.x += sin(now * 2.0 + p.wanderPhase) * 0.5 * (1.0 + mid * 2.0)
            p.x += p.vx * dt

            alive.append(p)
        }

        // Spawn new particles: mid drives spawn rate
        let baseCount = isIdle ? 1 : 2
        let audioCount = Int(mid * 80) + Int(bass * 30) + Int(peakVal * 30)
        let spawnCount = min(baseCount + audioCount, maxParticles - alive.count)

        for _ in 0..<max(0, spawnCount) {
            let p = spawnParticle(size: size, audio: audio, peak: peakVal, bass: bass)
            alive.append(p)
        }

        // Trim to max
        if alive.count > maxParticles {
            alive = Array(alive.suffix(maxParticles))
        }

        DispatchQueue.main.async { particles = alive }
    }

    private func spawnParticle(size: CGSize, audio: Double, peak: Double, bass: Double = 0) -> Particle {
        // Center-biased Gaussian spawn (Box-Muller approximation)
        let u1 = Double.random(in: 0.001...1.0)
        let u2 = Double.random(in: 0.0...1.0)
        let gaussian = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)

        // Ring expands with volume
        let spread = 0.15 + audio * 0.35
        let cx = size.width * 0.5 + gaussian * spread * size.width * 0.5
        let cy = size.height * 0.5 + Double.random(in: -1...1) * spread * size.height * 0.3

        // Size: bass drives base particle size, peak drives burst size
        let baseSize: CGFloat = CGFloat(2 + Double.random(in: 0...6) + bass * 6)
        let burstSize: CGFloat = CGFloat(peak * Double.random(in: 8...16))
        let particleSize = baseSize + burstSize

        // Lifetime: shorter when loud
        let lifetime = Double.random(in: 1.5...4.0) * (1.0 - audio * 0.5)

        // Color from palette
        let colorIndex = Int.random(in: 0..<CachedColors.particleColors.count)

        return Particle(
            x: cx,
            y: cy,
            vx: CGFloat(Double.random(in: -10...10)),
            vy: CGFloat(-20 - Double.random(in: 0...40) - audio * 60),  // Upward drift
            size: particleSize,
            color: CachedColors.particleColors[colorIndex],
            opacity: Double.random(in: 0.5...1.0),
            lifetime: max(0.5, lifetime),
            wanderPhase: Double.random(in: 0...(2 * .pi))
        )
    }

    // MARK: - Dim Background

    @ViewBuilder
    private func dimBackground(size: CGSize) -> some View {
        // Subtle dark mesh as backdrop for particles
        MeshGradient(
            width: 4,
            height: 4,
            points: [
                SIMD2(0, 0), SIMD2(0.33, 0), SIMD2(0.66, 0), SIMD2(1, 0),
                SIMD2(0, 0.33), SIMD2(0.33, 0.33), SIMD2(0.66, 0.33), SIMD2(1, 0.33),
                SIMD2(0, 0.66), SIMD2(0.33, 0.66), SIMD2(0.66, 0.66), SIMD2(1, 0.66),
                SIMD2(0, 1), SIMD2(0.33, 1), SIMD2(0.66, 1), SIMD2(1, 1)
            ],
            colors: [
                Color(hex: "0A0A1A"), Color(hex: "0D0D25"), Color(hex: "0D0D25"), Color(hex: "0A0A1A"),
                Color(hex: "0D0D25"), Color(hex: "141430"), Color(hex: "141430"), Color(hex: "0D0D25"),
                Color(hex: "0D0D25"), Color(hex: "141430"), Color(hex: "141430"), Color(hex: "0D0D25"),
                Color(hex: "0A0A1A"), Color(hex: "0D0D25"), Color(hex: "0D0D25"), Color(hex: "0A0A1A")
            ],
            smoothsColors: true
        )
    }
}
