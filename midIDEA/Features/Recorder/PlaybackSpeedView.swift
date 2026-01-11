import SwiftUI

struct PlaybackSpeedView: View {
    @Binding var rate: Float

    private let minRate: Float = 0.5
    private let maxRate: Float = 2.0

    var body: some View {
        VStack(spacing: 8) {
            // Speed label
            HStack {
                Image(systemName: "tortoise.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)

                Spacer()

                Text(speedLabel)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(rate != 1.0 ? .orange : .primary)

                Spacer()

                Image(systemName: "hare.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Slider styled like a tape speed control
            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color("SliderTrack"))
                    .frame(height: 8)

                // Custom slider
                GeometryReader { geometry in
                    let sliderWidth = geometry.size.width - 24
                    let normalizedValue = CGFloat((rate - minRate) / (maxRate - minRate))
                    let offset = normalizedValue * sliderWidth

                    // Filled track
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.3), .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: offset + 12, height: 8)
                        Spacer()
                    }

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .overlay(
                            Circle()
                                .stroke(Color.orange, lineWidth: 2)
                        )
                        .offset(x: offset, y: -8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newValue = Float(value.location.x / sliderWidth)
                                    let clampedValue = max(0, min(1, newValue))
                                    rate = minRate + (clampedValue * (maxRate - minRate))
                                }
                        )
                }
                .frame(height: 24)
            }

            // Preset buttons
            HStack(spacing: 12) {
                SpeedPresetButton(label: "0.5x", isSelected: rate == 0.5) { rate = 0.5 }
                SpeedPresetButton(label: "1x", isSelected: rate == 1.0) { rate = 1.0 }
                SpeedPresetButton(label: "1.5x", isSelected: rate == 1.5) { rate = 1.5 }
                SpeedPresetButton(label: "2x", isSelected: rate == 2.0) { rate = 2.0 }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var speedLabel: String {
        String(format: "%.1fx", rate)
    }
}

struct SpeedPresetButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.shared.playButtonPress()
            action()
        }) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange)
                        }
                    }
                )
                .glassEffect(isSelected ? .clear : .regular.interactive(), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PlaybackSpeedView(rate: .constant(1.0))
        .padding()
}
