import SwiftUI

/// Compact media player bar with title - liquid glass style
struct MediaPlayerBar: View {
    let recording: Recording

    @EnvironmentObject var audioService: AudioService
    @State private var isDragging = false

    private var progress: Double {
        guard recording.duration > 0 else { return 0 }
        return audioService.currentTime / recording.duration
    }

    var body: some View {
        VStack(spacing: 10) {
            // Title
            Text(recording.displayTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Controls row
            HStack(spacing: 16) {
                // Rewind 15s
                Button(action: rewind) {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 44, height: 44)
                }

                // Play/Pause
                Button(action: togglePlayback) {
                    Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }

                // Forward 15s
                Button(action: forward) {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(width: 44, height: 44)
                }

                // Progress section
                HStack(spacing: 8) {
                    Text(formatTime(audioService.currentTime))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)

                    // Scrubber
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Track
                            Capsule()
                                .fill(Color.primary.opacity(0.15))
                                .frame(height: 4)

                            // Progress
                            Capsule()
                                .fill(Color.red)
                                .frame(width: max(4, geometry.size.width * progress), height: 4)

                            // Thumb
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                                .offset(x: max(0, (geometry.size.width * progress) - 7))
                        }
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDragging = true
                                    let newProgress = max(0, min(1, value.location.x / geometry.size.width))
                                    let seekTime = recording.duration * newProgress
                                    audioService.seek(to: seekTime)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                    }
                    .frame(height: 44)

                    Text(formatTime(recording.duration))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect()
        .onAppear {
            // Ensure audio session is ready for playback
            audioService.setupAudioSession()
        }
    }

    // MARK: - Actions

    private func togglePlayback() {
        if audioService.isPlaying {
            audioService.pause()
        } else {
            do {
                try audioService.play(url: recording.audioURL)
            } catch {
                print("Playback failed: \(error)")
            }
        }
    }

    private func rewind() {
        audioService.skipBackward(15)
    }

    private func forward() {
        audioService.skipForward(15)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    VStack {
        Spacer()
        MediaPlayerBar(
            recording: Recording(duration: 406, audioFileName: "I Have a Dream.mp3")
        )
        .padding()
        .environmentObject(AudioService())
    }
}
