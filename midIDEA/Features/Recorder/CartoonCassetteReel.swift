import SwiftUI

struct CartoonCassetteReel: View {
    var isAnimating: Bool
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // 1. Dark Background (The hole)
            Circle()
                .fill(Color(hex: "2b333a")) // Dark grey/black
            
            // 2. Red Accent Ring (Static)
            Circle()
                .stroke(Color(hex: "c13e3e"), lineWidth: 3)
                .padding(2)
            
            // 3. Spinning Hub
            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                
                ZStack {
                    // White Spoked Hub - Using Shapes instead of Path for reliability
                    ZStack {
                        // White base circle
                        Circle()
                            .fill(Color(hex: "e8eff3")) // White/Light Grey
                            .padding(size * 0.2)
                        
                        // Dark Center Pin
                        Circle()
                            .fill(Color(hex: "2b333a"))
                            .frame(width: size * 0.15)
                        
                        // 3 Dark "Windows" / Spokes
                        ForEach(0..<3) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: "2b333a"))
                                .frame(width: size * 0.12, height: size * 0.25)
                                .offset(y: -size * 0.18)
                                .rotationEffect(.degrees(Double(i) * 120))
                        }
                    }
                }
                .rotationEffect(.degrees(rotation))
                .animation(isAnimating ? Animation.linear(duration: 2).repeatForever(autoreverses: false) : .linear(duration: 0), value: rotation)
            }
        }
        .onAppear {
            if isAnimating {
                rotation = 360
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                rotation = 0
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            } else {
                // Stop animation
                let currentRotation = rotation
                rotation = currentRotation // Keep position
            }
        }
    }
}

#Preview {
    CartoonCassetteReel(isAnimating: true)
        .frame(width: 100, height: 100)
        .padding()
        .background(Color.gray)
}
