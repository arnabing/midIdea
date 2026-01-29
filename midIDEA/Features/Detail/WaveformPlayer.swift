import SwiftUI

/// Modern waveform player with scrolling bars and center playhead
struct WaveformPlayer: View {
    let recording: Recording

    @EnvironmentObject var audioService: AudioService
    @State private var samples: [Float] = []
    @State private var isLoading = true
    @State private var interpolator = PlaybackInterpolator()
    @State private var scrubStartProgress: Double? = nil
    @State private var isScrubbing = false
    @State private var scrubProgress: Double = 0

    // Waveform styling
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let minBarHeight: CGFloat = 4
    private let containerHeight: CGFloat = 60
    private let playButtonSize: CGFloat = 48

    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            playPauseButton
                .zIndex(1)  // Ensure button stays on top

            // Scrolling Waveform Container
            // Always show waveform container - loading is rare with pre-generation
            waveformScrollContainer
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
        .onChange(of: audioService.currentTime) { oldTime, newTime in
            // Skip interpolator updates during active scrubbing
            guard !isScrubbing else { return }

            // Detect seeks (time jump > 200ms suggests scrub)
            if abs(newTime - oldTime) > 0.2 {
                interpolator.reset(to: newTime, playing: audioService.isPlaying)  // Instant jump for seeks, preserve playing state
            } else {
                interpolator.updatePosition(newTime, playing: audioService.isPlaying)
            }
        }
        .onChange(of: audioService.isPlaying) { _, isPlaying in
            // Update interpolator playing state immediately when playback starts/stops
            if isPlaying {
                interpolator.updatePosition(audioService.currentTime, playing: true)
            } else {
                interpolator.reset(to: audioService.currentTime, playing: false)
            }
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

    // MARK: - Waveform Scroll Container

    private var waveformScrollContainer: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                // Use scrub progress during active dragging, otherwise use interpolated time
                let progress = computeProgress(at: context.date.timeIntervalSinceReferenceDate)

                waveformContent(
                    containerWidth: geometry.size.width,
                    progress: progress
                )
            }
        }
    }

    private func computeProgress(at renderTime: TimeInterval) -> Double {
        if isScrubbing {
            return scrubProgress
        } else {
            let interpolatedTime = interpolator.getInterpolatedTime(at: renderTime)
            return recording.duration > 0 ? interpolatedTime / recording.duration : 0
        }
    }

    private func waveformContent(containerWidth: CGFloat, progress: Double) -> some View {
        ZStack {
            waveformBars(containerWidth: containerWidth, progress: progress)
            centerPlayhead
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleScrub(value: value, containerWidth: containerWidth)
                }
                .onEnded { value in
                    // Final seek and reset interpolator
                    handleScrub(value: value, containerWidth: containerWidth)
                    isScrubbing = false
                    scrubStartProgress = nil
                    interpolator.reset(to: audioService.currentTime, playing: audioService.isPlaying)
                }
        )
    }

    // MARK: - Waveform Bars

    private func waveformBars(containerWidth: CGFloat, progress: Double) -> some View {
        let offset = calculateOffset(containerWidth: containerWidth, progress: progress)

        return HStack(spacing: barSpacing) {
            ForEach(Array(samples.enumerated()), id: \.offset) { index, amplitude in
                waveformBar(
                    amplitude: amplitude,
                    index: index,
                    totalBars: samples.count,
                    progress: progress
                )
            }
        }
        .offset(x: offset)
        .animation(isScrubbing ? nil : .spring(response: 0.15, dampingFraction: 1.0), value: offset)
    }

    private func waveformBar(amplitude: Float, index: Int, totalBars: Int, progress: Double) -> some View {
        let barHeight = max(minBarHeight, CGFloat(amplitude) * containerHeight)
        let barProgress = Double(index) / Double(totalBars)
        let isPastPlayhead = barProgress <= progress

        return RoundedRectangle(cornerRadius: 2)
            .fill(isPastPlayhead ? Color.primary.opacity(0.8) : Color.primary.opacity(0.3))
            .frame(width: barWidth, height: barHeight)
            .animation(.linear(duration: 0.05), value: isPastPlayhead)  // Smooth color fade
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
    private func calculateOffset(containerWidth: CGFloat, progress: Double) -> CGFloat {
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
        // Capture initial progress at start of drag
        if scrubStartProgress == nil {
            isScrubbing = true
            scrubStartProgress = recording.duration > 0 ? audioService.currentTime / recording.duration : 0
        }

        // Translation-based scrubbing: drag left = scroll forward, drag right = scroll backward
        let totalWaveformWidth = CGFloat(samples.count) * (barWidth + barSpacing)
        let progressDelta = -value.translation.width / totalWaveformWidth  // Negative = reverse direction
        let newProgress = max(0, min(1, (scrubStartProgress ?? 0) + progressDelta))

        // Update scrub progress for immediate visual feedback
        scrubProgress = newProgress

        // Seek audio (batched by gesture updates)
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
        // Check for cached waveform first (memory)
        if let cachedSamples = recording.waveformSamples {
            // Instant display - no loading state
            samples = cachedSamples
            isLoading = false
            return
        }

        // Try loading from disk
        if let diskSamples = recording.loadWaveform() {
            samples = diskSamples
            isLoading = false
            return
        }

        // Fallback: Generate on-demand (for old recordings)
        isLoading = true
        defer { isLoading = false }

        do {
            let generatedSamples = try await WaveformGenerator.generate(
                from: recording.audioURL,
                sampleCount: 200
            )
            samples = generatedSamples

            // Cache for next time
            var mutableRecording = recording
            mutableRecording.waveformSamples = generatedSamples
            try? mutableRecording.saveWaveform(generatedSamples)
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
