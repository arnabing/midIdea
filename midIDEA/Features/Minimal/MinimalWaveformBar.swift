import SwiftUI

/// A floating waveform indicator bar with iOS 26 Liquid Glass styling.
/// Displays live audio levels with gradient bars, recording duration, and stop button.
struct MinimalWaveformBar: View {
    let isRecording: Bool
    let audioLevel: Float
    let duration: TimeInterval
    let onStop: () -> Void

    @State private var waveformLevels: [CGFloat] = Array(repeating: 0.1, count: 30)
    @State private var animatedLevels: [CGFloat] = Array(repeating: 0.1, count: 30)

    var body: some View {
        HStack(spacing: 4) {
            // Waveform bars with gradient
            HStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { index in
                    MinimalWaveformBarShape(
                        height: barHeight(for: index),
                        isRecording: isRecording,
                        index: index
                    )
                }
            }
            .frame(height: 28)

            Spacer()

            // Duration text with glow
            Text(formatDuration(duration))
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color(hex: "4A90D9").opacity(0.5), radius: 4)
                .frame(width: 52, alignment: .trailing)

            // Stop button
            if isRecording {
                Button(action: onStop) {
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 8,
                                    endRadius: 16
                                )
                            )
                            .frame(width: 32, height: 32)
                            .blur(radius: 2)

                        // Button
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 26, height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(hex: "0A0A0F"))
                                    .frame(width: 10, height: 10)
                            )
                            .shadow(color: .white.opacity(0.3), radius: 4)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(hex: "4A90D9").opacity(0.3),
                                    Color(hex: "7BB5F0").opacity(0.15),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color(hex: "4A90D9").opacity(0.2), radius: 15, x: 0, y: 5)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        )
        .onChange(of: audioLevel) { _, newLevel in
            updateWaveform(with: newLevel)
        }
    }

    // MARK: - Waveform Logic

    private func barHeight(for index: Int) -> CGFloat {
        let level = animatedLevels[index]
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 28
        return minHeight + (maxHeight - minHeight) * level
    }

    private func updateWaveform(with level: Float) {
        // Shift existing levels left
        var newLevels = Array(waveformLevels.dropFirst())

        // Normalize dB level to 0-1 range
        let normalizedLevel = CGFloat((level + 60) / 60).clamped(to: 0...1)

        // Add variation for visual interest
        let variation = CGFloat.random(in: -0.1...0.1)
        let finalLevel = (normalizedLevel + variation).clamped(to: 0.05...1.0)

        newLevels.append(finalLevel)
        waveformLevels = newLevels

        // Animate to new levels smoothly
        withAnimation(.easeOut(duration: 0.1)) {
            animatedLevels = newLevels
        }
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Individual Waveform Bar

private struct MinimalWaveformBarShape: View {
    let height: CGFloat
    let isRecording: Bool
    let index: Int

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: isRecording
                        ? [
                            Color(hex: "4A90D9"),
                            Color(hex: "7BB5F0"),
                            Color(hex: "A8D4F7")
                        ]
                        : [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.2)
                        ],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: height)
            .shadow(
                color: isRecording
                    ? Color(hex: "4A90D9").opacity(0.4)
                    : Color.clear,
                radius: 3
            )
    }
}

// MARK: - CGFloat Extension

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview("Recording State") {
    ZStack {
        Color(hex: "0A0A0F")
            .ignoresSafeArea()

        VStack {
            Spacer()
            MinimalWaveformBar(
                isRecording: true,
                audioLevel: -25,
                duration: 14,
                onStop: {}
            )
            .padding()
        }
    }
}

#Preview("Idle State") {
    ZStack {
        Color(hex: "0A0A0F")
            .ignoresSafeArea()

        VStack {
            Spacer()
            MinimalWaveformBar(
                isRecording: false,
                audioLevel: -60,
                duration: 0,
                onStop: {}
            )
            .padding()
        }
    }
}
