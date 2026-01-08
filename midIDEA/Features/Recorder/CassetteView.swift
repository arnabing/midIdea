import SwiftUI

struct CassetteView: View {
    let isAnimating: Bool
    let isRecording: Bool

    @State private var reelRotation: Double = 0

    var body: some View {
        ZStack {
            // Cassette body
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color("CassetteLight"), Color("CassetteDark")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            // Inner tape window
            CassetteWindowView(
                reelRotation: reelRotation,
                isRecording: isRecording
            )
            .padding(.horizontal, 30)
            .padding(.vertical, 20)

            // Label area
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.9))
                    .frame(height: 24)
                    .overlay(
                        Text("SIDE A")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    )
                    .padding(.horizontal, 50)
                    .padding(.bottom, 12)
            }
        }
        .onChange(of: isAnimating) { _, animating in
            if animating {
                startReelAnimation()
            }
        }
        .onAppear {
            if isAnimating {
                startReelAnimation()
            }
        }
    }

    private func startReelAnimation() {
        withAnimation(
            .linear(duration: isRecording ? 2.0 : 1.5)
            .repeatForever(autoreverses: false)
        ) {
            reelRotation = 360
        }
    }
}

struct CassetteWindowView: View {
    let reelRotation: Double
    let isRecording: Bool

    var body: some View {
        ZStack {
            // Window background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("TapeWindow"))

            HStack(spacing: 30) {
                // Left reel (supply)
                ReelView(rotation: reelRotation, size: .large)

                // Tape ribbon
                TapeRibbonView()

                // Right reel (take-up)
                ReelView(rotation: reelRotation, size: .small)
            }
            .padding(.horizontal, 10)

            // Recording indicator light
            if isRecording {
                VStack {
                    HStack {
                        Spacer()
                        RecordingIndicatorView()
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
    }
}

struct ReelView: View {
    let rotation: Double
    let size: ReelSize

    enum ReelSize {
        case large, small

        var diameter: CGFloat {
            switch self {
            case .large: return 50
            case .small: return 40
            }
        }
    }

    var body: some View {
        ZStack {
            // Reel base
            Circle()
                .fill(Color("ReelBase"))
                .frame(width: size.diameter, height: size.diameter)

            // Reel hub
            Circle()
                .fill(Color("ReelHub"))
                .frame(width: size.diameter * 0.4, height: size.diameter * 0.4)

            // Reel spokes
            ForEach(0..<6, id: \.self) { index in
                Rectangle()
                    .fill(Color("ReelSpoke"))
                    .frame(width: 2, height: size.diameter * 0.35)
                    .offset(y: -size.diameter * 0.15)
                    .rotationEffect(.degrees(Double(index) * 60))
            }

            // Center hole
            Circle()
                .fill(Color("TapeWindow"))
                .frame(width: size.diameter * 0.15, height: size.diameter * 0.15)
        }
        .rotationEffect(.degrees(rotation))
    }
}

struct TapeRibbonView: View {
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle()
                    .fill(Color("TapeRibbon"))
                    .frame(height: 2)
            }
        }
        .frame(width: 40)
    }
}

struct RecordingIndicatorView: View {
    @State private var isGlowing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .shadow(color: isGlowing ? .red : .clear, radius: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) {
                    isGlowing = true
                }
            }
    }
}

#Preview {
    CassetteView(isAnimating: true, isRecording: true)
        .frame(height: 140)
        .padding()
}
