import SwiftUI

struct TalkboyBodyView: View {
    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let cornerRadius = height * 0.08

            ZStack {
                // Main chassis - 3D Volume Effect
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "F0F1F5"), // Bright Highlight top-left
                                Color(hex: "D8D9DD"), // Base silver
                                Color(hex: "BFC0C4"), // Shadow start
                                Color(hex: "8A8B8F")  // Deep shadow bottom-right
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    // Inner "Rim" Highlight for 3D thickness (Top/Left)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.9), .white.opacity(0.1), .black.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    // Additional edge highlight
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            .blur(radius: 0.5)
                            .offset(x: -1, y: -1)
                            .mask(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .center))
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 12, x: 8, y: 10) // Deeper drop shadow for "pop-out"

                // Brushed metal grain
                BrushedMetalOverlay(opacity: 0.15, lineSpacing: 2.0)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                // Bottom bevel shadow (grounding)
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(10, height * 0.1))
                        .blur(radius: 4)
                        .mask(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
        }
    }
}

/// Brushed metal overlay (subtle horizontal strokes).
struct BrushedMetalOverlay: View {
    var opacity: Double = 0.07
    var lineSpacing: CGFloat = 2.2

    var body: some View {
        Canvas { ctx, size in
            var path = Path()
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += lineSpacing
            }
            ctx.stroke(path, with: .color(.white.opacity(opacity)), lineWidth: 1)
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

#Preview {
    TalkboyBodyView()
        .frame(width: 500, height: 280)
        .padding()
}
