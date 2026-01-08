import SwiftUI

struct VUMeterView: View {
    let level: Float // dB value, typically -160 to 0

    private let barCount = 20
    private let minDb: Float = -60
    private let maxDb: Float = 0

    private var normalizedLevel: Float {
        let clamped = max(minDb, min(maxDb, level))
        return (clamped - minDb) / (maxDb - minDb)
    }

    private var activeBars: Int {
        Int(Float(barCount) * normalizedLevel)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .opacity(index < activeBars ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }

    private func barColor(for index: Int) -> Color {
        let ratio = Float(index) / Float(barCount)
        if ratio < 0.6 {
            return .green
        } else if ratio < 0.8 {
            return .yellow
        } else {
            return .red
        }
    }
}

// Alternative VU Meter with classic needle style
struct ClassicVUMeterView: View {
    let level: Float

    private var normalizedLevel: Float {
        let minDb: Float = -60
        let maxDb: Float = 0
        let clamped = max(minDb, min(maxDb, level))
        return (clamped - minDb) / (maxDb - minDb)
    }

    private var needleAngle: Double {
        // Map 0-1 to -45 to +45 degrees
        Double(-45 + (normalizedLevel * 90))
    }

    var body: some View {
        ZStack {
            // Meter background
            Arc(startAngle: .degrees(-45), endAngle: .degrees(45))
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)

            // Active level arc
            Arc(startAngle: .degrees(-45), endAngle: .degrees(needleAngle))
                .stroke(
                    LinearGradient(
                        colors: [.green, .yellow, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 3
                )

            // Needle
            Rectangle()
                .fill(Color.red)
                .frame(width: 2, height: 40)
                .offset(y: -20)
                .rotationEffect(.degrees(needleAngle))

            // Center pivot
            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
        }
        .frame(height: 50)
    }
}

struct Arc: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) * 0.4

        path.addArc(
            center: center,
            radius: radius,
            startAngle: Angle(degrees: -180) + startAngle,
            endAngle: Angle(degrees: -180) + endAngle,
            clockwise: false
        )

        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        VUMeterView(level: -20)
            .frame(height: 30)

        ClassicVUMeterView(level: -15)
            .frame(height: 60)
    }
    .padding()
}
