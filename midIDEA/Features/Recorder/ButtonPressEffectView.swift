import SwiftUI

/// iOS 26 Liquid Glass button press effect with depth and materials
struct ButtonPressEffect: ViewModifier {
    let isPressed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.88 : 1.0)
            .shadow(
                color: Color.black.opacity(isPressed ? 0.15 : 0.4),
                radius: isPressed ? 3 : 8,
                x: 0,
                y: isPressed ? 2 : 4
            )
            .animation(.spring(response: 0.18, dampingFraction: 0.68), value: isPressed)
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    DebugLogger.logAnimation("Button pressed - scale: 0.88")
                } else {
                    DebugLogger.logAnimation("Button released - scale: 1.0")
                }
            }
    }
}

/// Enhanced liquid glass button visual indicator with layered materials
struct ButtonVisualIndicator: View {
    let isPressed: Bool
    let color: Color

    var body: some View {
        ZStack {
            // Base liquid glass layer
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    // Inner gradient glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    color.opacity(isPressed ? 0.9 : 0.6),
                                    color.opacity(isPressed ? 0.6 : 0.3),
                                    color.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .blendMode(.plusLighter)
                }
                .overlay {
                    // Specular highlight (top-left)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPressed ? 0.15 : 0.3),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.overlay)
                }

            // Outer ring with material
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            color.opacity(isPressed ? 0.8 : 0.5),
                            color.opacity(isPressed ? 0.5 : 0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: isPressed ? 1.5 : 1.0
                )
                .background {
                    Circle()
                        .fill(.regularMaterial)
                        .opacity(isPressed ? 0.4 : 0.2)
                }

            // Depth shadow inner ring (pressed state)
            if isPressed {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 8,
                            endRadius: 14
                        )
                    )
                    .blendMode(.multiply)
                    .transition(.opacity)
            }
        }
        .modifier(ButtonPressEffect(isPressed: isPressed))
        .allowsHitTesting(false) // CRITICAL: Don't block touch targets
    }
}

/// Liquid glass slider indicator
struct SliderVisualIndicator: View {
    let value: Double
    let range: ClosedRange<Double>
    let color: Color

    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        ZStack {
            // Background track with material
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .stroke(color.opacity(0.3), lineWidth: 1)
                }

            // Filled portion with gradient
            GeometryReader { geometry in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.8),
                                color.opacity(0.5)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * normalizedValue)
            }

            // Thumb indicator with liquid glass
            HStack {
                Spacer()
                Circle()
                    .fill(.regularMaterial)
                    .overlay {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        color.opacity(0.8),
                                        color.opacity(0.4)
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 6
                                )
                            )
                    }
                    .frame(width: 12, height: 12)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .offset(x: -6) // Align with track edge
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Apply button press effect with depth
    func buttonPressEffect(isPressed: Bool) -> some View {
        modifier(ButtonPressEffect(isPressed: isPressed))
    }
}
