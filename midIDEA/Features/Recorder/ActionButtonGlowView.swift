import SwiftUI

/// iOS 26 Liquid Glass Action Button glow effect
/// Two-phase animation: press burst (300ms) + recording pulse (every 3s)
struct ActionButtonGlowView: View {
    let isRecording: Bool
    let isPressActive: Bool

    @State private var glowScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.0
    @State private var recordingTimer: Timer?
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            // Outer liquid glass ring (continuous rotation during recording)
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color.red.opacity(0.8),
                            Color.orange.opacity(0.6),
                            Color.red.opacity(0.4),
                            Color.red.opacity(0.8)
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 220, height: 220)
                .blur(radius: 4)
                .rotationEffect(.degrees(rotationAngle))
                .opacity(isRecording ? 0.7 : 0)
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: rotationAngle)

            // Press burst layer (short animation)
            ZStack {
                // Outer burst with material
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.red.opacity(0.7),
                                        Color.orange.opacity(0.4),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .blendMode(.plusLighter)
                    }
                    .frame(width: 200, height: 200)

                // Inner bright core
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                Color.red.opacity(0.6),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blendMode(.screen)
            }
            .scaleEffect(isPressActive ? 1.6 : 1.0)
            .opacity(isPressActive ? 0.9 : 0.0)
            .blur(radius: isPressActive ? 8 : 2)
            .animation(.easeOut(duration: 0.3), value: isPressActive)

            // Recording pulse (persistent during recording)
            ZStack {
                // Layered concentric rings with materials
                ForEach(0..<3) { index in
                    Circle()
                        .fill(.regularMaterial)
                        .overlay {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.red.opacity(0.5 - Double(index) * 0.15),
                                            Color.orange.opacity(0.3 - Double(index) * 0.1),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 60
                                    )
                                )
                                .blendMode(.plusLighter)
                        }
                        .frame(width: 140 + CGFloat(index) * 20, height: 140 + CGFloat(index) * 20)
                        .opacity(0.6 - Double(index) * 0.15)
                }

                // Central glow core with vibrancy
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.red.opacity(0.5),
                                Color.orange.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                    .blendMode(.screen)
            }
            .scaleEffect(glowScale)
            .opacity(glowOpacity)
            .blur(radius: 6)
        }
        .allowsHitTesting(false)
        .onChange(of: isRecording) { _, recording in
            if recording {
                DebugLogger.logActionButton("Starting recording glow animation")
                startRecordingGlow()
                startRotation()
            } else {
                DebugLogger.logActionButton("Stopping recording glow animation")
                stopRecordingGlow()
                stopRotation()
            }
        }
        .onChange(of: isPressActive) { _, pressed in
            if pressed {
                DebugLogger.logActionButton("Action Button press burst triggered")
                HapticService.shared.playButtonPress()
            }
        }
    }

    private func startRecordingGlow() {
        // Initial pulse immediately
        withAnimation(.easeInOut(duration: 0.8)) {
            glowScale = 1.25
            glowOpacity = 0.7
        }

        // Discrete pulse every 3 seconds (battery-friendly)
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            guard isRecording else { return }

            DebugLogger.logAnimation("Recording pulse - scale: 1.25, opacity: 0.7")

            withAnimation(.easeInOut(duration: 0.9)) {
                glowScale = 1.35
                glowOpacity = 0.8
            }

            withAnimation(.easeInOut(duration: 0.9).delay(0.9)) {
                glowScale = 1.15
                glowOpacity = 0.4
            }
        }
    }

    private func stopRecordingGlow() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        withAnimation(.easeOut(duration: 0.6)) {
            glowScale = 1.0
            glowOpacity = 0.0
        }
    }

    private func startRotation() {
        rotationAngle = 0
        withAnimation {
            rotationAngle = 360
        }
    }

    private func stopRotation() {
        withAnimation(.easeOut(duration: 0.5)) {
            rotationAngle = 0
        }
    }
}

#if DEBUG
struct ActionButtonGlowView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 50) {
                // Press burst preview
                ActionButtonGlowView(isRecording: false, isPressActive: true)
                    .frame(width: 300, height: 300)

                // Recording pulse preview
                ActionButtonGlowView(isRecording: true, isPressActive: false)
                    .frame(width: 300, height: 300)
            }
        }
    }
}
#endif
