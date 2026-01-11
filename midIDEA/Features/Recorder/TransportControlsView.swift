import SwiftUI

struct TransportControlsView: View {
    let isPlaying: Bool
    let isRecording: Bool
    let onRewind: () -> Void
    let onFastForward: () -> Void
    let onPlay: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Stop button
            TransportButton(
                icon: "stop.fill",
                color: .primary,
                isActive: false,
                action: onStop
            )

            // Rewind button
            TransportButton(
                icon: "backward.fill",
                color: .primary,
                isActive: false,
                action: onRewind
            )

            // Fast Forward button
            TransportButton(
                icon: "forward.fill",
                color: .primary,
                isActive: false,
                action: onFastForward
            )

            // Play button
            TransportButton(
                icon: isPlaying ? "pause.fill" : "play.fill",
                color: .green,
                isActive: isPlaying,
                action: onPlay
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    }
}

struct TransportButton: View {
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticService.shared.playButtonPress()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isActive ? color : .primary)
                .frame(width: 44, height: 36)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    TransportControlsView(
        isPlaying: false,
        isRecording: false,
        onRewind: {},
        onFastForward: {},
        onPlay: {},
        onStop: {}
    )
    .padding()
}
