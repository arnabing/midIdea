import SwiftUI

/// A pulsing blue gradient glow effect positioned around the Dynamic Island area.
/// Creates a soft, ethereal blob effect inspired by iOS 26 Liquid Glass design.
struct DynamicIslandGlow: View {
    let isRecording: Bool

    @State private var phase: CGFloat = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Primary blue blob - large soft gradient
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "4A90D9").opacity(0.6),
                                Color(hex: "5B9FE8").opacity(0.4),
                                Color(hex: "7BB5F0").opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 80)
                    .scaleEffect(scale)
                    .blur(radius: 30)
                    .position(x: geo.size.width / 2, y: 60)

                // Secondary accent blob - offset for depth
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "6BADE8").opacity(0.5),
                                Color(hex: "89C4F4").opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 140, height: 50)
                    .scaleEffect(scale * 1.1)
                    .offset(x: sin(phase) * 10)
                    .blur(radius: 25)
                    .position(x: geo.size.width / 2, y: 55)

                // Highlight blob - bright center accent
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color(hex: "A8D4F7").opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 100, height: 35)
                    .scaleEffect(scale * 0.9)
                    .blur(radius: 15)
                    .position(x: geo.size.width / 2, y: 58)

                // Subtle grain texture overlay
                GrainOverlay()
                    .frame(width: 250, height: 120)
                    .position(x: geo.size.width / 2, y: 60)
                    .opacity(0.3)
            }
            .opacity(opacity)
        }
        .allowsHitTesting(false)
        .onChange(of: isRecording) { _, recording in
            if recording {
                startAnimations()
            } else {
                stopAnimations()
            }
        }
        .onAppear {
            if isRecording {
                startAnimations()
            }
        }
    }

    private func startAnimations() {
        // Fade in
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 1.0
        }

        // Pulsing scale
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            scale = 1.15
        }

        // Phase animation for subtle movement
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
            phase = .pi * 2
        }
    }

    private func stopAnimations() {
        withAnimation(.easeOut(duration: 0.5)) {
            opacity = 0.0
            scale = 1.0
        }
    }
}

/// Subtle noise/grain texture for the glass effect
private struct GrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<200 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let opacity = Double.random(in: 0.02...0.08)

                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .blendMode(.overlay)
    }
}

#Preview {
    ZStack {
        Color.black
        DynamicIslandGlow(isRecording: true)
    }
    .ignoresSafeArea()
}
