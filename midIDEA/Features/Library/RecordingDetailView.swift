import SwiftUI
import UIKit

// MARK: - Share Sheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Configure for iPad popover if needed
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = .zero
            popover.permittedArrowDirections = []
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Recording Detail View

struct RecordingDetailView: View {
    let recording: Recording

    @EnvironmentObject var recordingStore: RecordingStore
    @EnvironmentObject var audioService: AudioService
    @Environment(\.dismiss) private var dismiss

    @State private var playbackRate: Float = 1.0
    @State private var showCopiedToast = false
    @State private var isRetranscribing = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var aiSummary: String?
    @State private var aiKeyPoints: [String] = []
    @State private var isGeneratingSummary = false
    @State private var aiError: String?

    @Namespace private var glassNamespace
    @AppStorage("visualizerColorMode") private var colorModeRaw: String = VisualizerColorMode.lavaLamp.rawValue

    private var colorMode: VisualizerColorMode {
        VisualizerColorMode(rawValue: colorModeRaw) ?? .lavaLamp
    }

    var body: some View {
        ZStack {
            // Layer 1: Deep gradient base
            backgroundGradient

            // Layer 2: Liquid Audio Visualizer (same as recorder)
            LiquidAudioVisualizer(
                audioLevel: audioService.isPlaying ? -30 : -60,  // Subtle movement
                isRecording: false,
                isIdle: !audioService.isPlaying,
                colorMode: colorMode
            )

            // Layer 3: Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Top spacing for close button
                    Spacer()
                        .frame(height: 60)

                    // Recording info header
                    recordingHeader
                        .padding(.horizontal, 24)

                    // Playback controls card
                    playbackCard
                        .padding(.horizontal, 20)

                    // Transcript card
                    transcriptCard
                        .padding(.horizontal, 20)

                    // AI Summary card (if available or can generate)
                    if recording.transcriptionStatus == .completed && recording.transcript != nil {
                        aiSummaryCard
                            .padding(.horizontal, 20)
                    }

                    // Bottom padding
                    Spacer()
                        .frame(height: 40)
                }
            }

            // Top bar overlay
            VStack {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                Spacer()
            }

            // Toast overlay
            if showCopiedToast {
                VStack {
                    Spacer()
                    copiedToast
                        .padding(.bottom, 40)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .animation(.easeInOut(duration: 0.3), value: showCopiedToast)
        .onAppear {
            // Load stored AI insights from recording
            if let storedSummary = recording.aiSummary {
                aiSummary = storedSummary
            }
            if let storedPoints = recording.aiKeyPoints {
                aiKeyPoints = storedPoints
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "050508"),
                Color(hex: "0A0A12"),
                Color(hex: "0F0F1A"),
                Color(hex: "0A0A12"),
                Color(hex: "050508")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: {
                audioService.stop()
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .glassEffectID("close", in: glassNamespace)

            Spacer()

            // Share menu
            Menu {
                Button(action: shareRecording) {
                    Label("Share Audio", systemImage: "square.and.arrow.up")
                }

                if recording.transcript != nil {
                    Button(action: shareTranscript) {
                        Label("Share Transcript", systemImage: "doc.text")
                    }
                }

                Divider()

                Button(role: .destructive, action: deleteRecording) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .glassEffectID("menu", in: glassNamespace)
        }
    }

    // MARK: - Recording Header

    private var recordingHeader: some View {
        VStack(spacing: 8) {
            Text(recording.displayTitle)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(recording.durationFormatted)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 16)
    }

    // MARK: - Playback Card

    private var playbackCard: some View {
        VStack(spacing: 20) {
            progressSection
            controlsSection
            speedSection
        }
        .padding(24)
        .glassEffect()
        .glassEffectID("playback", in: glassNamespace)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            progressBar
            timeLabels
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 6)

                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: progressWidth(in: geo.size.width), height: 6)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let progress = value.location.x / geo.size.width
                        let clampedProgress = min(max(progress, 0), 1)
                        let newTime = TimeInterval(clampedProgress) * audioService.duration
                        audioService.seek(to: newTime)
                    }
            )
        }
        .frame(height: 6)
    }

    private var timeLabels: some View {
        HStack {
            Text(formatTime(audioService.currentTime))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(formatTime(recording.duration))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var controlsSection: some View {
        HStack(spacing: 32) {
            skipBackButton
            playPauseButton
            skipForwardButton
        }
    }

    private var skipBackButton: some View {
        Button(action: { audioService.skipBackward() }) {
            Image(systemName: "gobackward.10")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(audioService.isPlaying ? 0.9 : 0.4))
        }
        .disabled(!audioService.isPlaying)
    }

    private var playPauseButton: some View {
        Button(action: togglePlayback) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 72, height: 72)

                Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(hex: "0A0A12"))
                    .offset(x: audioService.isPlaying ? 0 : 2)
            }
        }
        .buttonStyle(.plain)
        .shadow(color: .white.opacity(0.3), radius: 12)
    }

    private var skipForwardButton: some View {
        Button(action: { audioService.skipForward() }) {
            Image(systemName: "goforward.10")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(audioService.isPlaying ? 0.9 : 0.4))
        }
        .disabled(!audioService.isPlaying)
    }

    private var speedSection: some View {
        HStack(spacing: 12) {
            speedButton(0.5)
            speedButton(1.0)
            speedButton(1.5)
            speedButton(2.0)
        }
    }

    private func speedButton(_ speed: Double) -> some View {
        let isSelected = playbackRate == Float(speed)
        let label = speed == 1.0 || speed == 2.0 ? "\(Int(speed))x" : String(format: "%.1fx", speed)

        return Button(action: {
            playbackRate = Float(speed)
            audioService.setPlaybackRate(Float(speed))
            HapticService.shared.playButtonPress()
        }) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .frame(width: 48, height: 32)
                .background(
                    Capsule().fill(isSelected ? .white.opacity(0.2) : .clear)
                )
        }
    }

    // MARK: - Transcript Card

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Transcript")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                if recording.transcriptionStatus == .completed && recording.transcript != nil {
                    Button(action: copyTranscript) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if recording.transcriptionStatus == .failed || recording.transcriptionStatus == .pending {
                    Button(action: retranscribe) {
                        Image(systemName: isRetranscribing ? "hourglass" : "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .disabled(isRetranscribing)
                }
            }

            // Content
            transcriptContent
        }
        .padding(24)
        .glassEffect()
        .glassEffectID("transcript", in: glassNamespace)
    }

    @ViewBuilder
    private var transcriptContent: some View {
        switch recording.transcriptionStatus {
        case .pending:
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14))
                Text("Transcription pending...")
                    .font(.system(size: 15, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.5))

        case .inProgress:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.8)
                Text("Transcribing...")
                    .font(.system(size: 15, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.5))

        case .completed:
            if let transcript = recording.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(6)
                    .textSelection(.enabled)
            } else {
                Text("No speech detected")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .italic()
            }

        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14))
                Text("Transcription failed. Tap to retry.")
                    .font(.system(size: 15, design: .rounded))
            }
            .foregroundColor(.orange.opacity(0.9))
        }
    }

    // MARK: - AI Summary Card

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                Text("Apple Intelligence")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                Spacer()

                if aiSummary == nil && !isGeneratingSummary && aiError == nil {
                    Button(action: generateSummary) {
                        Text("Summarize")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.white.opacity(0.15)))
                    }
                }
            }
            .foregroundStyle(.white.opacity(0.9))

            // Content
            if isGeneratingSummary {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                    Text("Analyzing with Apple Intelligence...")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            } else if let error = aiError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 14))
                    Text(error)
                        .font(.system(size: 14, design: .rounded))
                }
                .foregroundColor(.orange.opacity(0.9))

                Button(action: generateSummary) {
                    Text("Try Again")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 4)
            } else if let summary = aiSummary {
                // Summary
                Text(summary)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(5)

                // Key Points
                if !aiKeyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Points")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)

                        ForEach(aiKeyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(.white.opacity(0.5))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)

                                Text(point)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        }
                    }
                }
            } else {
                Text("Get a quick summary and key points using on-device AI")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(24)
        .glassEffect()
        .glassEffectID("summary", in: glassNamespace)
    }

    // MARK: - Toast

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
            Text("Copied to clipboard")
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glassEffect()
    }

    // MARK: - Helpers

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard audioService.duration > 0 else { return 0 }
        let progress = audioService.currentTime / audioService.duration
        return totalWidth * CGFloat(progress)
    }

    // MARK: - Actions

    private func togglePlayback() {
        if audioService.isPlaying {
            audioService.pause()
        } else {
            do {
                try audioService.play(url: recording.audioURL, rate: playbackRate)
            } catch {
                print("Playback failed: \(error)")
            }
        }
        HapticService.shared.playButtonPress()
    }

    private func copyTranscript() {
        guard let transcript = recording.transcript else { return }
        UIPasteboard.general.string = transcript
        showCopiedToast = true
        HapticService.shared.playSaveSuccess()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedToast = false
        }
    }

    private func shareRecording() {
        let wasPlaying = audioService.isPlaying
        if wasPlaying {
            audioService.pause()
        }
        shareItems = [recording.audioURL]
        showingShareSheet = true
    }

    private func shareTranscript() {
        guard let transcript = recording.transcript else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let textToShare = """
        Recording from \(dateFormatter.string(from: recording.createdAt))
        Duration: \(recording.durationFormatted)

        \(transcript)
        """

        shareItems = [textToShare]
        showingShareSheet = true
    }

    private func deleteRecording() {
        audioService.stop()
        recordingStore.deleteRecording(recording)
        dismiss()
    }

    private func retranscribe() {
        isRetranscribing = true

        var updatedRecording = recording
        updatedRecording.transcriptionStatus = .inProgress
        recordingStore.updateRecording(updatedRecording)

        Task {
            do {
                let transcript = try await TranscriptionService.shared.transcribe(audioURL: recording.audioURL)
                updatedRecording.transcript = transcript
                updatedRecording.transcriptionStatus = .completed

                // Auto-generate AI insights
                if AIService.shared.isAvailable && !transcript.isEmpty {
                    if let insights = try? await AIService.shared.generateInsights(transcript) {
                        updatedRecording.aiSummary = insights.summary
                        updatedRecording.aiKeyPoints = insights.keyPoints
                        await MainActor.run {
                            aiSummary = insights.summary
                            aiKeyPoints = insights.keyPoints
                        }
                    }
                }
            } catch {
                updatedRecording.transcriptionStatus = .failed
            }
            recordingStore.updateRecording(updatedRecording)
            isRetranscribing = false
        }
    }

    private func generateSummary() {
        guard let transcript = recording.transcript else { return }
        isGeneratingSummary = true
        aiError = nil

        Task {
            do {
                let insights = try await AIService.shared.generateInsights(transcript)
                await MainActor.run {
                    aiSummary = insights.summary
                    aiKeyPoints = insights.keyPoints
                    isGeneratingSummary = false

                    // Save to recording for persistence
                    var updated = recording
                    updated.aiSummary = insights.summary
                    updated.aiKeyPoints = insights.keyPoints
                    recordingStore.updateRecording(updated)
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                    isGeneratingSummary = false
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    RecordingDetailView(
        recording: Recording(
            audioFileName: "test.m4a",
            transcript: "This is a sample transcript of the recording. It contains the full text of what was spoken during the voice note.",
            transcriptionStatus: .completed
        )
    )
    .environmentObject(RecordingStore())
    .environmentObject(AudioService())
}
