import SwiftUI

struct TalkboySlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let leftIcon: String
    let rightIcon: String

    private let tickCount = 10

    var body: some View {
        VStack(spacing: 6) {
            // Slider track with icons
            HStack(spacing: 6) {
                Image(systemName: leftIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "4A4A4C"))

                // Custom slider track with tick marks
                GeometryReader { geometry in
                    let trackWidth = geometry.size.width
                    let normalizedValue = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                    let thumbWidth: CGFloat = 22
                    let thumbPosition = normalizedValue * (trackWidth - thumbWidth)

                    ZStack(alignment: .leading) {
                        // Tick marks BEHIND track
                        HStack(spacing: 0) {
                            ForEach(0...tickCount, id: \.self) { i in
                                Rectangle()
                                    .fill(Color(hex: "3A3A3C"))
                                    .frame(width: 1.5, height: 12)
                                if i < tickCount {
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, thumbWidth / 2)

                        // Track groove (recessed)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "2A2A2C"), Color(hex: "3A3A3C"), Color(hex: "4A4A4C")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
                            )

                        // Metallic thumb
                        ZStack {
                            // Thumb base
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: "F0F0F2"),
                                            Color(hex: "D8D8DA"),
                                            Color(hex: "B8B8BA"),
                                            Color(hex: "A0A0A2")
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            // Top highlight
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.6), Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )

                            // Grip lines on thumb
                            VStack(spacing: 2) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Rectangle()
                                        .fill(Color(hex: "7A7A7C"))
                                        .frame(width: 12, height: 1)
                                }
                            }

                            // Border
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color(hex: "8A8A8C"), lineWidth: 0.5)
                        }
                        .frame(width: thumbWidth, height: 16)
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                        .offset(x: thumbPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    let newPosition = gesture.location.x
                                    let normalizedNew = Float(newPosition / trackWidth)
                                    let clampedValue = max(0, min(1, normalizedNew))
                                    value = range.lowerBound + (clampedValue * (range.upperBound - range.lowerBound))
                                }
                        )
                    }
                }
                .frame(height: 18)

                Image(systemName: rightIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "4A4A4C"))
            }

            // Label
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Color(hex: "3A3A3C"))
                .tracking(0.5)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "C8C8CA")
        VStack(spacing: 24) {
            TalkboySlider(
                value: .constant(0.7),
                range: 0...1,
                label: "VOLUME",
                leftIcon: "speaker.fill",
                rightIcon: "speaker.wave.3.fill"
            )
            .frame(width: 130)

            TalkboySlider(
                value: .constant(1.0),
                range: 0.5...2.0,
                label: "SPEED (Playback)",
                leftIcon: "tortoise.fill",
                rightIcon: "hare.fill"
            )
            .frame(width: 130)
        }
        .padding()
    }
}
