import SwiftUI

struct TalkboyFaceplateView: View {
    @Binding var volume: Float
    @Binding var playbackSpeed: Float
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Faceplate base
                RoundedRectangle(cornerRadius: w * 0.04)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "D8D8DA"), Color(hex: "C0C0C3")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // Inner Shadow to look recessed
                    .overlay(
                        RoundedRectangle(cornerRadius: w * 0.04)
                            .stroke(Color.black.opacity(0.3), lineWidth: 4)
                            .blur(radius: 2)
                            .offset(x: 1, y: 1)
                            .mask(RoundedRectangle(cornerRadius: w * 0.04).fill(LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    )
                    // Outer Rim Highlight
                    .overlay(
                        RoundedRectangle(cornerRadius: w * 0.04)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            .offset(x: -0.5, y: -0.5)
                            .mask(RoundedRectangle(cornerRadius: w * 0.04))
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1) // Subtle drop shadow inside the recess? No, it's recessed.
                    // Actually, if it's recessed, the BODY casts a shadow ONTO the faceplate.
                    // Or the faceplate is a separate plate set IN.
                    // Let's assume it's a plate set IN.

                // Talkboy Logo
                Text("Talkboy\u{2122}")
                    .font(.system(size: h * 0.14, weight: .black, design: .default))
                    .italic()
                    .foregroundColor(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, w * 0.08)
                    .padding(.top, h * 0.05)
                    .position(x: w * 0.45, y: h * 0.12)
                
                // Swoosh Line
                SwooshContour()
                    .stroke(
                        Color.black.opacity(0.6),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: w, height: h)
                
                // Black Bars (Vents/Design)
                VStack(alignment: .leading, spacing: h * 0.035) {
                    TalkboyBar(width: w * 0.45, height: h * 0.09) // Top thick
                    TalkboyBar(width: w * 0.48, height: h * 0.07) // Middle
                    TalkboyBar(width: w * 0.75, height: h * 0.04) // Bottom thin long
                }
                .position(x: w * 0.42, y: h * 0.58)

                // Integrated Sliders
                HStack(spacing: w * 0.1) {
                    // Volume Slider
                    TalkboySliderAssembly(
                        value: $volume,
                        range: 0...1,
                        leftGlyph: .speakerMin,
                        rightGlyph: .speakerMax,
                        label: "VOLUME"
                    )
                    .frame(width: w * 0.35)
                    
                    // Speed Slider
                    TalkboySliderAssembly(
                        value: $playbackSpeed,
                        range: 0.5...2.0,
                        leftGlyph: .turtle,
                        rightGlyph: .hare,
                        label: "SPEED (Playback)"
                    )
                    .frame(width: w * 0.35)
                }
                .position(x: w * 0.5, y: h * 0.82)
            }
        }
    }
}

private struct TalkboyBar: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: height * 0.3)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "1A1A1C"), Color(hex: "0C0C0E")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: height * 0.3)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .white.opacity(0.2), radius: 1, x: 0, y: 1)
    }
}

private struct SwooshContour: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        
        let startY = h * 0.28
        p.move(to: CGPoint(x: 0, y: startY))
        
        p.addCurve(
            to: CGPoint(x: w * 0.55, y: h * 0.20),
            control1: CGPoint(x: w * 0.25, y: startY + h * 0.1),
            control2: CGPoint(x: w * 0.45, y: h * 0.15)
        )
        
        return p
    }
}

#Preview {
    ZStack {
        Color(hex: "BFC0C4")
        TalkboyFaceplateView(volume: .constant(0.5), playbackSpeed: .constant(1.0))
            .frame(width: 320, height: 320)
            .padding()
    }
}
