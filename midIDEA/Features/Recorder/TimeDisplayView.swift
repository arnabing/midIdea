import SwiftUI

struct TimeDisplayView: View {
    let currentTime: TimeInterval
    let duration: TimeInterval?
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 4) {
            if isRecording {
                // Recording indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .modifier(PulsingModifier())
            }

            // Current time
            Text(formatTime(currentTime))
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .foregroundColor(isRecording ? .red : .primary)

            // Duration (if playing)
            if let duration = duration {
                Text("/")
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(.secondary)

                Text(formatTime(duration))
                    .font(.system(size: 24, weight: .light, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 8))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PulsingModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    isPulsing = true
                }
            }
    }
}

#Preview {
    VStack(spacing: 20) {
        TimeDisplayView(currentTime: 125, duration: nil, isRecording: true)
        TimeDisplayView(currentTime: 45, duration: 180, isRecording: false)
    }
    .padding()
}
