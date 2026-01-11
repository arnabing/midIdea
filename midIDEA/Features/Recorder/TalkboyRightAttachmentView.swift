import SwiftUI

struct TalkboyRightAttachmentView: View {
    let height: CGFloat
    
    // Width is proportional to height, similar to left attachment
    private var width: CGFloat {
        height * 0.35 // Slightly narrower than left attachment
    }
    
    var body: some View {
        ZStack {
            // 1. Microphone Handle Chassis
            RightAttachmentShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "2C2C2E"), Color(hex: "1C1C1E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RightAttachmentShape()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 5, x: -2, y: 2)
            
            // 2. Grip Texture / Detail lines
            VStack(spacing: height * 0.02) {
                ForEach(0..<8) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: width * 0.5, height: 2)
                }
            }
            .position(x: width * 0.5, y: height * 0.6)
            
            // 3. Microphone Head (Top part)
            VStack(spacing: 0) {
                // Neck
                Rectangle()
                    .fill(Color(hex: "151517"))
                    .frame(width: width * 0.4, height: height * 0.05)
                
                // Mic Head
                ZStack {
                    RoundedRectangle(cornerRadius: width * 0.15)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "404042"), Color(hex: "202022")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: width * 0.6, height: height * 0.15)
                    
                    // Mesh Pattern
                    MicMeshPattern()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: width * 0.5, height: height * 0.12)
                }
            }
            .position(x: width * 0.5, y: height * 0.25) // Extend out from the side? Or just sit on top?
            // "Coming out on the right side" usually means the extendable mic handle.
            // For now, I'll position it near the top of this attachment.
            
            // 4. Extendable Arm Joint (Visual only)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: "505052"), Color(hex: "303032")], startPoint: .top, endPoint: .bottom))
                .frame(width: width * 0.6)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .position(x: width * 0.5, y: height * 0.45)
            
        }
        .frame(width: width, height: height)
    }
}

// Custom Shape for the Right Attachment Chassis
struct RightAttachmentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        
        // Starts from left (attached to main body)
        p.move(to: CGPoint(x: 0, y: 0))
        
        // Top edge - slopes down slightly or straight?
        // Let's make it follow the contour.
        p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.05))
        
        // Right edge - rounded
        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.15), control: CGPoint(x: w, y: h * 0.05))
        p.addLine(to: CGPoint(x: w, y: h * 0.85))
        
        // Bottom edge - rounded return
        p.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.95), control: CGPoint(x: w, y: h * 0.95))
        p.addLine(to: CGPoint(x: 0, y: h))
        
        p.closeSubpath()
        return p
    }
}

struct MicMeshPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 4
        
        // Horizontal lines
        for y in stride(from: 0, to: rect.height, by: step) {
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
        }
        
        // Vertical lines
        for x in stride(from: 0, to: rect.width, by: step) {
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: rect.height))
        }
        
        return p
    }
}

#Preview {
    ZStack {
        Color.gray
        TalkboyRightAttachmentView(height: 400)
    }
}
