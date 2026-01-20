import SwiftUI

/// Minimal recording interface with iOS 26 Liquid Glass aesthetic.
/// Features multi-blob visualizer with color modes and native glass morphing transitions.
struct MinimalRecorderView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var recordingStore: RecordingStore

    @Namespace private var glassNamespace

    @State private var showingRecordingsList = false
    @State private var showPermissionAlert = false
    @State private var showOnboarding = false
    @State private var currentRecordingURL: URL?
    @State private var latestTranscript: String = ""
    @State private var completedRecording: Recording?
    @State private var currentSessionId: UUID?

    @AppStorage("hasSeenActionButtonOnboarding") private var hasSeenOnboarding = false
    @AppStorage("visualizerColorMode") private var colorModeRaw: String = VisualizerColorMode.lavaLamp.rawValue

    private var colorMode: VisualizerColorMode {
        VisualizerColorMode(rawValue: colorModeRaw) ?? .lavaLamp
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Layer 1: Deep gradient base
                backgroundGradient

                // Layer 2: Full-screen Liquid Audio Visualizer
                LiquidAudioVisualizer(
                    audioLevel: audioService.audioLevel,
                    isRecording: audioService.isRecording,
                    isIdle: !audioService.isRecording && latestTranscript.isEmpty,
                    colorMode: colorMode
                )

                // Layer 3: Glass UI Controls
                GlassEffectContainer(spacing: 16) {
                    VStack(spacing: 0) {
                        // Top bar
                        topBar
                            .padding(.horizontal, 24)
                            .padding(.top, 60)

                        Spacer()

                        // Center content (transcript or prompt)
                        centerContent
                            .padding(.horizontal, 28)

                        Spacer()

                        // Recording status (when active)
                        if audioService.isRecording {
                            recordingStatus
                                .transition(.scale.combined(with: .opacity))
                        }

                        // Main record button with glass morphing (always visible)
                        recordButton
                            .padding(.bottom, 24)

                        // Bottom hint
                        bottomHint
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 16)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingRecordingsList) {
            MinimalRecordingsList()
        }
        .sheet(isPresented: $showOnboarding) {
            ActionButtonOnboardingView()
        }
        .sheet(item: $completedRecording) { recording in
            CompletedRecordingView(
                recording: recording,
                onNewRecording: {
                    handleNewRecording()
                },
                onResume: {
                    handleResume()
                },
                onDismiss: {
                    completedRecording = nil
                }
            )
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -50 {
                        showingRecordingsList = true
                    }
                }
        )
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to record voice notes.")
        }
        .onAppear {
            setupAudioService()
            loadLatestTranscript()
            checkOnboarding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromIntent)) { _ in
            handleRecord()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleRecordingFromIntent)) { _ in
            if audioService.isRecording {
                handleStop()
            } else {
                handleRecord()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromIntent)) { _ in
            handleStop()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: audioService.isRecording)
        .onChange(of: audioService.audioLevel) { _, newLevel in
            // Update Live Activity with current audio level
            if audioService.isRecording {
                LiveActivityManager.shared.setAudioLevel(newLevel)
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
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            // Recordings count badge with glass effect
            if recordingStore.recordings.count > 0 {
                Button(action: { showingRecordingsList = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(recordingStore.recordings.count)")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
                .glassEffectID("count", in: glassNamespace)
            }
        }
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 16) {
            if !audioService.isRecording && completedRecording == nil {
                // Empty/ready state
                emptyStatePrompt
            }
            // When recording: shows nothing (visualizer is the focus)
            // When completed: sheet is shown instead
        }
    }

    // MARK: - Empty State Prompt

    private var emptyStatePrompt: some View {
        VStack(spacing: 20) {
            Text("Tap to Record")
                .font(.displayMedium)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("Your voice, transcribed instantly")
                .font(.bodySecondary)
                .foregroundColor(.white.opacity(0.45))

            // Action Button hint
            Button(action: { showOnboarding = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "button.horizontal.top.press")
                        .font(.system(size: 12, weight: .medium))
                    Text("Set up Action Button")
                        .font(.captionSecondary)
                }
                .foregroundColor(.white.opacity(0.35))
            }
            .padding(.top, 8)
        }
        .padding(.top, 60)
    }

    // MARK: - Recording Status

    private var recordingStatus: some View {
        HStack(spacing: 12) {
            // Pulsing red dot
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .modifier(PulsingModifier())

            Text("REC")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.red)

            Text(formatDuration(audioService.currentTime))
                .font(.monoLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .glassEffect()
        .glassEffectID("status", in: glassNamespace)
        .padding(.bottom, 24)
    }

    // MARK: - Record Button with Glass Morphing

    private var recordButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                if audioService.isRecording {
                    handleStop()
                } else {
                    handleRecord()
                }
            }
        }) {
            ZStack {
                // Glass container
                Circle()
                    .fill(.clear)
                    .frame(width: 100, height: 100)

                // Inner button shape - morphs between circle and square
                if audioService.isRecording {
                    // Stop square
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: Color.red.opacity(0.6), radius: 16)
                } else {
                    // Record circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.red, Color.red.opacity(0.75)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 38
                            )
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: Color.red.opacity(0.5), radius: 14)
                }
            }
        }
        .buttonStyle(.glass)
        .glassEffectID("recordButton", in: glassNamespace)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: audioService.isRecording)
    }

    // MARK: - Bottom Hint

    private var bottomHint: some View {
        Group {
            if !audioService.isRecording && recordingStore.recordings.count > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Swipe up for recordings")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.35))
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Setup

    private func setupAudioService() {
        audioService.setupAudioSession()
        audioService.silenceDuration = 15.0
        audioService.onSilenceAutoStop = { [self] in
            handleStop()
        }
    }

    private func loadLatestTranscript() {
        if let latest = recordingStore.recordings.first,
           let transcript = latest.transcript {
            latestTranscript = transcript
        }
    }

    private func checkOnboarding() {
        if !hasSeenOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showOnboarding = true
            }
        }
    }

    // MARK: - Actions

    private func handleRecord() {
        Task {
            let granted = await audioService.requestMicrophonePermission()
            if granted {
                do {
                    currentRecordingURL = try audioService.startRecording()
                    HapticService.shared.playRecordStart()

                    // Start Live Activity for Dynamic Island
                    LiveActivityManager.shared.startRecordingActivity()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            } else {
                showPermissionAlert = true
            }
        }
    }

    private func handleStop() {
        guard audioService.isRecording else { return }

        // End Live Activity
        LiveActivityManager.shared.endRecordingActivity()

        guard let result = audioService.stopRecording() else { return }
        HapticService.shared.playRecordStop()

        var recording = Recording(
            audioFileName: result.url.lastPathComponent,
            transcriptionStatus: .pending,
            sessionId: currentSessionId
        )
        recording.duration = result.duration
        recordingStore.addRecording(recording)

        // Set completed recording for post-recording UI
        completedRecording = recording

        Task {
            await transcribeRecording(recording)
        }
    }

    private func handleResume() {
        // Link new recording to same session
        if currentSessionId == nil {
            currentSessionId = completedRecording?.id
        }
        completedRecording = nil
        handleRecord()
    }

    private func handleNewRecording() {
        // Fresh start - clear session
        currentSessionId = nil
        completedRecording = nil
        latestTranscript = ""
    }

    private func transcribeRecording(_ recording: Recording) async {
        var updated = recording
        updated.transcriptionStatus = .inProgress
        recordingStore.updateRecording(updated)

        do {
            let transcript = try await TranscriptionService.shared.transcribe(audioURL: recording.audioURL)
            updated.transcript = transcript
            updated.transcriptionStatus = .completed

            await MainActor.run {
                latestTranscript = transcript
                // Refresh completedRecording if it matches
                if completedRecording?.id == updated.id {
                    completedRecording = updated
                }
            }

            // Generate AI insights if available
            if AIService.shared.isAvailable && !transcript.isEmpty {
                if let insights = try? await AIService.shared.generateInsights(transcript) {
                    updated.aiSummary = insights.summary
                    updated.aiKeyPoints = insights.keyPoints

                    // Update completedRecording with AI insights
                    await MainActor.run {
                        if completedRecording?.id == updated.id {
                            completedRecording = updated
                        }
                    }
                }
            }
        } catch {
            updated.transcriptionStatus = .failed
        }

        recordingStore.updateRecording(updated)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    MinimalRecorderView()
        .environmentObject(AudioService())
        .environmentObject(RecordingStore())
}
