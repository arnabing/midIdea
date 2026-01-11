import SwiftUI

struct TapeReelView: View {
    let isAnimating: Bool
    let isRecording: Bool

    @State private var rotation: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let reelSize = size * 0.85 // Reel is slightly smaller than the window assembly

            ZStack {
                // 1. Window Background (The dark void inside the player)
                Circle()
                    .fill(Color(hex: "151517"))
                    .frame(width: size, height: size)
                
                // 2. The Spinning Reel
                TapeReel(size: reelSize)
                    .rotationEffect(.degrees(rotation))
                    
                // 3. Glass Lens (Reflections & Tint)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear,
                                Color.black.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.94, height: size * 0.94)
                
                // Specular Highlight (Glossy reflection on glass)
                Circle()
                    .trim(from: 0.1, to: 0.35)
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
                    .frame(width: size * 0.88, height: size * 0.88)
                    .rotationEffect(.degrees(-45))
                    .blur(radius: 2)

                // 4. Window Bezel (The plastic rim holding the glass)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "F0F0F2"), // Top highlight
                                Color(hex: "B0B0B2"), // Mid tone
                                Color(hex: "808082")  // Bottom shadow
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: size * 0.06
                    )
                    .frame(width: size * 0.97, height: size * 0.97)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 2, y: 2) // Drop shadow for depth
                
                // Inner bevel of the rim (simulates thickness)
                Circle()
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
                    .frame(width: size * 0.94, height: size * 0.94)

                // Recording indicator glow (ring inside the glass or on the rim)
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .frame(width: size * 0.9, height: size * 0.9)
                        .modifier(PulsingModifier())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimation()
            }
        }
    }

    private func startAnimation() {
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
}

struct TapeReel: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Reel body (dark gray)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: "4A4A4C"), Color(hex: "2C2C2E")],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)

            // Metallic center hub
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "D0D0D2"), Color(hex: "808082"), Color(hex: "A0A0A2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.35, height: size * 0.35)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)

            // Center screw
            Circle()
                .fill(Color(hex: "606062"))
                .frame(width: size * 0.12, height: size * 0.12)

            // Spokes (6 teeth to match reference)
            ForEach(0..<6, id: \.self) { index in
                ReelSpoke(length: size * 0.35, width: size * 0.14)
                    .rotationEffect(.degrees(Double(index) * 60))
            }

            // Inner circle masking spokes for clean hub look
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "C0C0C2"), Color(hex: "A0A0A2")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.28, height: size * 0.28)

            // Outer ring details
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "5A5A5C"), Color(hex: "3A3A3C")],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: size * 0.05
                )
                .frame(width: size * 0.9, height: size * 0.9)
        }
    }
}

struct ReelSpoke: View {
    let length: CGFloat
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "C0C0C2"), Color(hex: "808082")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: length)
            .offset(y: -length / 4)
    }
}

#Preview {
    ZStack {
        Color(hex: "C8C8CA")
        TapeReelView(isAnimating: true, isRecording: true)
            .frame(width: 150, height: 150)
    }
}
