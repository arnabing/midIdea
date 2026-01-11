import SwiftUI

struct TalkboyButtonBar: View {
    let isRecording: Bool
    let isPlaying: Bool

    let onRecord: () -> Void
    let onStop: () -> Void
    let onPlay: () -> Void
    let onRewind: () -> Void
    let onFastForward: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // RECORD button (LEFT side - aligns with Action Button)
            TalkboyButton(
                icon: "circle.fill",
                label: "RECORD",
                isActive: isRecording,
                activeColor: .red,
                action: onRecord
            )

            // STOP button
            TalkboyButton(
                icon: "stop.fill",
                label: "STOP",
                isActive: false,
                activeColor: .primary,
                action: onStop
            )

            // Rewind button
            TalkboyButton(
                icon: "backward.fill",
                label: "REW",
                isActive: false,
                activeColor: .primary,
                action: onRewind
            )

            // Fast Forward button
            TalkboyButton(
                icon: "forward.fill",
                label: "FF",
                isActive: false,
                activeColor: .primary,
                action: onFastForward
            )

            // PLAY button
            TalkboyButton(
                icon: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "PAUSE" : "PLAY",
                isActive: isPlaying,
                activeColor: .green,
                action: onPlay
            )

            Spacer()
        }
    }
}

struct TalkboyButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 4) {
            // Label above button
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "4A4A4C"))
                .shadow(color: .white.opacity(0.5), radius: 0, x: 0, y: 1)

            // Button
            Button(action: {
                HapticService.shared.playButtonPress()
                action()
            }) {
                ZStack {
                    // Button body with 3D effect
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: isPressed
                                    ? [Color(hex: "1C1C1E"), Color(hex: "2C2C2E")]
                                    : [Color(hex: "3C3C3E"), Color(hex: "1C1C1E")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(
                            color: isPressed ? .clear : .black.opacity(0.5),
                            radius: isPressed ? 0 : 2,
                            x: 0,
                            y: isPressed ? 0 : 2
                        )

                    // Inner highlight
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .padding(1)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isActive ? activeColor : .white)
                        .shadow(color: isActive ? activeColor.opacity(0.5) : .clear, radius: 4)
                }
                .frame(width: 50, height: 36)
            }
            .buttonStyle(TalkboyButtonStyle(isPressed: $isPressed))
        }
    }
}

struct TalkboyButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

#Preview {
    ZStack {
        Color(hex: "A8A9AD")
        TalkboyButtonBar(
            isRecording: false,
            isPlaying: false,
            onRecord: {},
            onStop: {},
            onPlay: {},
            onRewind: {},
            onFastForward: {}
        )
        .padding()
    }
}
