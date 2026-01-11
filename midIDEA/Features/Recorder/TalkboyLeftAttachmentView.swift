import SwiftUI

struct TalkboyLeftAttachmentView: View {
    let height: CGFloat
    let action: () -> Void
    
    // Width is proportional to height to maintain the wedge shape
    private var width: CGFloat {
        height * 0.45
    }
    
    var body: some View {
        ZStack {
            // Chassis Extension (Wedge Shape)
            LeftAttachmentShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "D8D9DD"),
                            Color(hex: "BFC0C4"),
                            Color(hex: "A8A9AD"),
                            Color(hex: "9A9B9F")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    LeftAttachmentShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.3), .clear],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                )
                .overlay(
                    LeftAttachmentShape()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.black.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 6, x: -2, y: 4)
            
            // Brushed metal texture
            BrushedMetalOverlay(opacity: 0.12, lineSpacing: 2.0)
                .clipShape(LeftAttachmentShape())
            
            // Speaker Grille
            SpeakerGrille()
                .frame(width: width * 0.65, height: width * 0.65) // Slightly smaller to reveal more "triangle"
                .position(x: width * 0.60, y: height * 0.72) // Higher and more to right
                .onTapGesture(perform: action)
        }
        .frame(width: width, height: height)
    }
}

private struct LeftAttachmentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        
        // Start top-right (connecting to main body)
        p.move(to: CGPoint(x: w, y: h * 0.05)) // Start slightly down from top edge of main body to match bevel? No, let's go flush.
        
        // Let's assume flush with main body top-right corner of this view
        p.move(to: CGPoint(x: w, y: 0))
        
        // Diagonal line down to the left, stopping above the speaker area curve
        // The image shows a long diagonal.
        // Let's say it goes to x=0 around y=60%
        // But the speaker is round at the bottom left.
        
        // Right side (vertical, connects to main unit)
        p.addLine(to: CGPoint(x: w, y: h))
        
        // Bottom edge
        p.addLine(to: CGPoint(x: w * 0.3, y: h))
        
        // Bottom-Left Corner (Rounded)
        let cornerRadius = w * 0.3
        p.addQuadCurve(
            to: CGPoint(x: 0, y: h - cornerRadius),
            control: CGPoint(x: 0, y: h)
        )
        
        // Left edge (short vertical section before the diagonal slope starts?)
        // Or just the diagonal connects to the arc.
        // Looking at reference: It seems the diagonal goes all the way to the rounded corner area.
        
        // Let's draw a line from current point (0, h-cornerRadius) up to the top right (w, 0)
        // But maybe slightly curved or straight. Reference looks straight.
        p.addLine(to: CGPoint(x: w, y: 0))
        
        p.closeSubpath()
        
        return p
    }
}

private struct SpeakerGrille: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Outer Rim
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "8A8A8C"), Color(hex: "5A5A5C")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 2)
                
                // Black Mesh Background
                Circle()
                    .fill(Color(hex: "151515"))
                    .padding(4)
                
                // Holes Pattern
                // 5x5 grid clipped to circle
                Canvas { ctx, size in
                    let holeSize = size.width * 0.12
                    let spacing = size.width * 0.18
                    let offset = (size.width - (spacing * 4)) / 2
                    
                    for r in 0..<5 {
                        for c in 0..<5 {
                            let x = offset + CGFloat(c) * spacing
                            let y = offset + CGFloat(r) * spacing
                            
                            // Check if inside circle radius
                            let center = CGPoint(x: size.width/2, y: size.height/2)
                            let point = CGPoint(x: x, y: y)
                            let dist = sqrt(pow(point.x - center.x, 2) + pow(point.y - center.y, 2))
                            
                            if dist < (size.width/2 - holeSize/2) {
                                let rect = CGRect(
                                    x: x - holeSize/2,
                                    y: y - holeSize/2,
                                    width: holeSize,
                                    height: holeSize
                                )
                                ctx.fill(Path(ellipseIn: rect), with: .color(Color.black))
                                // Inner shadow simulation for hole
                                ctx.stroke(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)
                            }
                        }
                    }
                }
                .padding(4)
                
                // Slight dome reflection
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .padding(4)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        TalkboyLeftAttachmentView(height: 300, action: {})
    }
}
