import SwiftUI

/// Modern waveform player with scrolling bars and center playhead
struct WaveformPlayer: View {
    let recording: Recording

    @EnvironmentObject var audioService: AudioService
    @State private var samples: [Float] = []
    @State private var isLoading = true

    // Waveform styling
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let minBarHeight: CGFloat = 4
    private let containerHeight: CGFloat = 60
    private let playButtonSize: CGFloat = 48

    /// Current playback progress [0.0...1.0]
    private var progress: Double {
        guard recording.duration > 0 else { return 0 }
        return audioService.currentTime / recording.duration
    }

    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            playPauseButton
                .zIndex(1)  // Ensure button stays on top

            // Scrolling Waveform Container
            if isLoading {
                loadingView
            } else {
                waveformScrollContainer
            }
        }
        .frame(height: containerHeight)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
        .task {
            await loadWaveform()
        }
        .onAppear {
            audioService.setupAudioSession()
        }
    }

    // MARK: - Play/Pause Button

    private var playPauseButton: some View {
        Button(action: togglePlayback) {
            Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 20))
                .foregroundStyle(.primary)
                .frame(width: playButtonSize, height: playButtonSize)
                .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack(spacing: 2) {
            ForEach(0..<40, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: barWidth, height: containerHeight * 0.4)
            }
        }
    }

    // MARK: - Waveform Scroll Container

    private var waveformScrollContainer: some View {
        GeometryReader { geometry in
            ZStack {
                // Scrolling waveform bars
                waveformBars(containerWidth: geometry.size.width)

                // Fixed center playhead
                centerPlayhead
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill geometry reader
            .clipped()  // Prevent overflow
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleScrub(value: value, containerWidth: geometry.size.width)
                    }
            )
        }
    }

    // MARK: - Waveform Bars

    private func waveformBars(containerWidth: CGFloat) -> some View {
        let offset = calculateOffset(containerWidth: containerWidth)

        return HStack(spacing: barSpacing) {
            ForEach(Array(samples.enumerated()), id: \.offset) { index, amplitude in
                waveformBar(
                    amplitude: amplitude,
                    index: index,
                    totalBars: samples.count
                )
            }
        }
        .offset(x: offset)
    }

    private func waveformBar(amplitude: Float, index: Int, totalBars: Int) -> some View {
        let barHeight = max(minBarHeight, CGFloat(amplitude) * containerHeight)
        let barProgress = Double(index) / Double(totalBars)
        let isPastPlayhead = barProgress <= progress

        return RoundedRectangle(cornerRadius: 2)
            .fill(isPastPlayhead ? Color.primary.opacity(0.8) : Color.primary.opacity(0.3))
            .frame(width: barWidth, height: barHeight)
    }

    // MARK: - Center Playhead

    private var centerPlayhead: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }

    // MARK: - Scroll Offset Calculation

    /// Calculate horizontal offset so waveform scrolls under center playhead
    private func calculateOffset(containerWidth: CGFloat) -> CGFloat {
        let totalWaveformWidth = CGFloat(samples.count) * (barWidth + barSpacing)
        let centerX = containerWidth / 2
        let progressOffset = CGFloat(progress) * totalWaveformWidth

        // Calculate base offset (center - progress position)
        let baseOffset = centerX - progressOffset

        // Clamp offset to prevent waveform from scrolling past edges
        let minOffset = containerWidth - totalWaveformWidth - barSpacing
        let maxOffset = barSpacing

        return max(minOffset, min(maxOffset, baseOffset))
    }

    // MARK: - Gestures

    private func handleScrub(value: DragGesture.Value, containerWidth: CGFloat) {
        // Direct mapping: screen position → timeline position
        let dragX = value.location.x
        let newProgress = max(0, min(1, dragX / containerWidth))
        let seekTime = recording.duration * newProgress
        audioService.seek(to: seekTime)
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

    private func loadWaveform() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let generatedSamples = try await WaveformGenerator.generate(
                from: recording.audioURL,
                sampleCount: 200
            )
            samples = generatedSamples
        } catch {
            print("Waveform generation failed: \(error)")
            // Fallback to moderate amplitude bars
            samples = Array(repeating: 0.5, count: 200)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        WaveformPlayer(
            recording: Recording(duration: 406, audioFileName: "test.m4a")
        )
        .padding()
        .environmentObject(AudioService())
    }
    .background(Color(.systemBackground))
}
