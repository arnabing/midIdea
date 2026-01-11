import SwiftUI

/// A composite slider assembly: Icon - Slot with Ticks - Icon, with a metallic thumb.
/// Designed to replace the printed slider for a more realistic prop look.
struct TalkboySliderAssembly: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let leftGlyph: TalkboyGlyph
    let rightGlyph: TalkboyGlyph
    let label: String
    
    enum TalkboyGlyph { case speakerMin, speakerMax, turtle, hare }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                glyph(leftGlyph)
                
                // The slider track mechanism
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let thumbW: CGFloat = 20
                    let trackInset = thumbW / 2
                    
                    // Interaction logic
                    let rangeSpan = range.upperBound - range.lowerBound
                    let normalized = CGFloat((value - range.lowerBound) / rangeSpan)
                    let xPos = trackInset + normalized * (w - 2 * trackInset)
                    
                    ZStack {
                        // 1. Recessed Slot (Dark pill)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "1A1A1C"))
                            .frame(height: 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                            )
                            .shadow(color: .white.opacity(0.15), radius: 1, x: 0, y: 1) // bottom highlight
                            .offset(y: -4) // Shift slot up slightly to make room for ticks below
                        
                        // 2. Tick Marks (Below the slot)
                        HStack(spacing: 0) {
                            ForEach(0..<13) { i in
                                Rectangle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 1, height: (i % 6 == 0) ? 6 : 4)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 4)
                        .offset(y: 6) // Shift ticks down
                        
                        // 3. Metallic Thumb
                        ThumbView()
                            .position(x: xPos, y: h / 2 - 4) // Align with slot
                            .gesture(
                                DragGesture()
                                    .onChanged { g in
                                        let clampedX = min(max(g.location.x, trackInset), w - trackInset)
                                        let t = Float((clampedX - trackInset) / (w - 2 * trackInset))
                                        value = range.lowerBound + t * rangeSpan
                                    }
                            )
                    }
                }
                .frame(height: 24)
                
                glyph(rightGlyph)
            }
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "2A2A2C"))
                .tracking(0.8)
        }
    }
    
    @ViewBuilder
    private func glyph(_ g: TalkboyGlyph) -> some View {
        switch g {
        case .speakerMin:
            Image(systemName: "speaker.fill").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "2A2A2C"))
        case .speakerMax:
            Image(systemName: "speaker.wave.3.fill").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "2A2A2C"))
        case .turtle:
            Image(systemName: "tortoise.fill").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "2A2A2C"))
        case .hare:
            Image(systemName: "hare.fill").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "2A2A2C"))
        }
    }
}

private struct ThumbView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [Color(hex: "F0F0F2"), Color(hex: "C8C8CA"), Color(hex: "909092")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 18, height: 14)
            .overlay(
                VStack(spacing: 1.5) {
                    ForEach(0..<3) { _ in
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 1)
                    }
                }
                .padding(.horizontal, 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 1.5, x: 0, y: 1)
    }
}

#Preview {
    ZStack {
        Color(hex: "D8D9DD")
        VStack(spacing: 20) {
            TalkboySliderAssembly(
                value: .constant(0.5),
                range: 0...1,
                leftGlyph: .speakerMin,
                rightGlyph: .speakerMax,
                label: "VOLUME"
            )
            .frame(width: 200)
            
            TalkboySliderAssembly(
                value: .constant(1.0),
                range: 0.5...2.0,
                leftGlyph: .turtle,
                rightGlyph: .hare,
                label: "SPEED (Playback)"
            )
            .frame(width: 200)
        }
    }
}
