import SwiftUI
import AVFoundation

// MARK: - Debug Logging Helper
private func debugLog(_ message: String, category: String = "General") {
    #if DEBUG
    print("[\(category)] \(message)")
    #endif
}

struct TalkboyCartoonView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var recordingStore: RecordingStore

    @State private var showingLibrary = false
    @State private var volume: Float = 1.0
    @State private var playbackSpeed: Float = 1.0
    @State private var showPermissionAlert = false
    @State private var currentRecordingURL: URL?

    // Sample Playback State
    @State private var playingSample = false
    @State private var samplePlayer: AVAudioPlayer?

    // Button Press States
    @State private var stopPressed = false
    @State private var rewindPressed = false
    @State private var playPressed = false
    @State private var ffPressed = false
    @State private var recordPressed = false

    // Image/SVG Dimensions
    private let svgWidth: CGFloat = 400
    private let svgHeight: CGFloat = 300

    // Debug: Set to true to show touch target boundaries
    private let showDebugOverlay = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - "iOS 26 Liquid Glass" Effect
                // Simulating a futuristic, ultra-smooth blur with multiple layers
                ZStack {
                    // Deep base layer for depth
                    Color.black.opacity(0.8).ignoresSafeArea()
                    
                    // Vibrant, abstract gradient blobs for the "liquid" feel
                    GeometryReader { geo in
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 300, height: 300)
                                .blur(radius: 60)
                                .position(x: geo.size.width * 0.2, y: geo.size.height * 0.3)
                            
                            Circle()
                                .fill(Color.purple.opacity(0.3))
                                .frame(width: 400, height: 400)
                                .blur(radius: 80)
                                .position(x: geo.size.width * 0.8, y: geo.size.height * 0.7)
                            
                            Circle()
                                .fill(Color.cyan.opacity(0.2))
                                .frame(width: 250, height: 250)
                                .blur(radius: 50)
                                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                        }
                    }
                    .ignoresSafeArea()
                    
                    // The "Glass" Surface
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                }

                // Scale to fit the screen while maintaining aspect ratio
                // "Learn from dimensions" -> Use standard aspect fit logic
                // User reported 1.75 was "small", but logic suggests it should be large. 
                // Stick to 1.75 for now or adjust if we find the image has padding.
                let ratio = min(geometry.size.width / svgWidth, geometry.size.height / svgHeight)
                let scale = ratio * 1.75
                
                ZStack {
                    // 1. Image Background (Replaces Vector Layers)
                    Image("TalkboyCartoonBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: svgWidth, height: svgHeight)

                    // 2. Interactive Elements Aligned to Image Coordinates
                    // Using previous SVG coordinates as a baseline for the screenshot

                    // Cassette Reel - Spins during recording/playback
                    // Position: center of the dark circular cassette window
                    CartoonCassetteReel(isAnimating: audioService.isRecording || audioService.isPlaying)
                        .frame(width: 65, height: 65)
                        .position(x: 285, y: 168)

                    // Recording glow around cassette
                    if audioService.isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.5), lineWidth: 3)
                            .frame(width: 75, height: 75)
                            .position(x: 285, y: 168)
                            .modifier(PulsingModifier())
                    }

                    // Button Press Glow Overlays (below touch targets)
                    // Corrected positions based on debug screenshot analysis
                    Group {
                        CartoonButtonOverlay(isPressed: stopPressed, color: .white)
                            .position(x: 273, y: 65)
                        CartoonButtonOverlay(isPressed: rewindPressed, color: .green)
                            .position(x: 298, y: 65)
                        CartoonButtonOverlay(isPressed: playPressed, color: .green)
                            .position(x: 323, y: 65)
                        CartoonButtonOverlay(isPressed: ffPressed, color: .green)
                            .position(x: 348, y: 65)
                        CartoonButtonOverlay(isPressed: recordPressed, color: .red, isActive: audioService.isRecording)
                            .position(x: 378, y: 65)
                    }

                    // Invisible Touch Targets for Buttons (Top Bezel - TOP LAYER)
                    // 44x44 touch targets (Apple HIG minimum recommended)
                    Group {
                        // Stop (square icon)
                        Button(action: handleStop) {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !stopPressed {
                                        stopPressed = true
                                        HapticService.shared.playButtonPress()
                                        debugLog("Stop button pressed")
                                    }
                                }
                                .onEnded { _ in
                                    stopPressed = false
                                    debugLog("Stop button released")
                                }
                        )
                        .frame(width: 44, height: 44)
                        .position(x: 273, y: 65)

                        // Rewind (<<)
                        Button(action: {
                            audioService.skipBackward()
                            debugLog("Rewind tapped")
                        }) {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !rewindPressed {
                                        rewindPressed = true
                                        HapticService.shared.playButtonPress()
                                        debugLog("Rewind button pressed")
                                    }
                                }
                                .onEnded { _ in
                                    rewindPressed = false
                                    debugLog("Rewind button released")
                                }
                        )
                        .frame(width: 44, height: 44)
                        .position(x: 298, y: 65)

                        // Play (triangle - long press for sample)
                        Button(action: handlePlay) {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !playPressed {
                                        playPressed = true
                                        HapticService.shared.playButtonPress()
                                        debugLog("Play button pressed")
                                    }
                                }
                                .onEnded { _ in
                                    playPressed = false
                                    debugLog("Play button released")
                                }
                        )
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 1.0)
                                .onEnded { _ in
                                    playRandomSample()
                                    debugLog("Play long-press: sample triggered")
                                }
                        )
                        .frame(width: 44, height: 44)
                        .position(x: 323, y: 65)

                        // Fast Forward (>>)
                        Button(action: {
                            audioService.skipForward()
                            debugLog("Fast Forward tapped")
                        }) {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !ffPressed {
                                        ffPressed = true
                                        HapticService.shared.playButtonPress()
                                        debugLog("Fast Forward button pressed")
                                    }
                                }
                                .onEnded { _ in
                                    ffPressed = false
                                    debugLog("Fast Forward button released")
                                }
                        )
                        .frame(width: 44, height: 44)
                        .position(x: 348, y: 65)

                        // Record (red circle)
                        Button(action: handleRecord) {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !recordPressed {
                                        recordPressed = true
                                        HapticService.shared.playButtonPress()
                                        debugLog("Record button pressed")
                                    }
                                }
                                .onEnded { _ in
                                    recordPressed = false
                                    debugLog("Record button released")
                                }
                        )
                        .frame(width: 44, height: 44)
                        .position(x: 378, y: 65)
                    }

                    // DEBUG: Visual overlay to show touch target positions
                    if showDebugOverlay {
                        Group {
                            // Button touch targets (red outline) - updated coordinates
                            ForEach([(273, "Stop"), (298, "<<"), (323, "Play"), (348, ">>"), (378, "Rec")], id: \.0) { x, label in
                                Rectangle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(label)
                                            .font(.system(size: 8))
                                            .foregroundColor(.red)
                                    )
                                    .position(x: CGFloat(x), y: 65)
                            }

                            // Cassette reel position (blue circle)
                            Circle()
                                .stroke(Color.blue, lineWidth: 2)
                                .frame(width: 65, height: 65)
                                .overlay(
                                    Text("Reel")
                                        .font(.system(size: 10))
                                        .foregroundColor(.blue)
                                )
                                .position(x: 285, y: 168)

                            // Coordinate reference crosshairs at center
                            Rectangle()
                                .fill(Color.yellow.opacity(0.5))
                                .frame(width: 2, height: svgHeight)
                                .position(x: svgWidth / 2, y: svgHeight / 2)
                            Rectangle()
                                .fill(Color.yellow.opacity(0.5))
                                .frame(width: svgWidth, height: 2)
                                .position(x: svgWidth / 2, y: svgHeight / 2)
                        }
                        .allowsHitTesting(false)
                    }

                    // Sliders (Bottom)
                    CartoonSliderTouchArea(value: $volume, range: 0...1)
                        .frame(width: 40, height: 20)
                        .position(x: 165, y: 220)
                    
                    CartoonSliderTouchArea(value: $playbackSpeed, range: 0.5...2.0)
                        .frame(width: 40, height: 20)
                        .position(x: 235, y: 220)
                    
                }
                .frame(width: svgWidth, height: svgHeight)
                .scaleEffect(scale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .onChange(of: volume) { _, newValue in audioService.setVolume(newValue) }
        .onChange(of: playbackSpeed) { _, newValue in audioService.setPlaybackRate(newValue) }
        // Alerts and Sheets
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
        .sheet(isPresented: $showingLibrary) {
            LibraryView()
        }
        // Intent Listeners (Action Button integration)
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromIntent)) { _ in
            debugLog("Start recording intent received")
            HapticService.shared.playButtonPress()
            handleRecord()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleRecordingFromIntent)) { _ in
            debugLog("Toggle recording intent received - isRecording: \(audioService.isRecording)")
            HapticService.shared.playButtonPress()
            if audioService.isRecording {
                handleStop()
            } else {
                handleRecord()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromIntent)) { _ in
            debugLog("Stop recording intent received")
            HapticService.shared.playButtonPress()
            handleStop()
        }
    }
    
    // MARK: - Actions
    private func handleRecord() {
        debugLog("handleRecord() called")
        Task {
            let granted = await audioService.requestMicrophonePermission()
            debugLog("Microphone permission: \(granted ? "granted" : "denied")", category: "Recording")

            if granted {
                do {
                    currentRecordingURL = try audioService.startRecording()
                    debugLog("Recording started successfully - URL: \(currentRecordingURL?.lastPathComponent ?? "nil")", category: "Recording")
                } catch {
                    debugLog("Failed to start recording: \(error)", category: "Recording")
                }
            } else {
                showPermissionAlert = true
                debugLog("Showing microphone permission alert", category: "UI")
            }
        }
    }

    private func handleStop() {
        debugLog("handleStop() called - isRecording: \(audioService.isRecording), isPlaying: \(audioService.isPlaying)")

        if audioService.isRecording {
            guard let result = audioService.stopRecording() else {
                debugLog("stopRecording() returned nil", category: "Recording")
                return
            }

            debugLog("Recording stopped - duration: \(result.duration)s, file: \(result.url.lastPathComponent)", category: "Recording")

            let recording = Recording(audioFileName: result.url.lastPathComponent, transcriptionStatus: .pending)
            var mutableRecording = recording
            mutableRecording.duration = result.duration
            recordingStore.addRecording(mutableRecording)

            debugLog("Recording added to store - total recordings: \(recordingStore.recordings.count)", category: "Recording")

            // Auto-transcribe
            Task {
                await transcribeRecording(mutableRecording)
            }

            // Wave-like feature: Immediately show the library/content after capturing
            showingLibrary = true
            debugLog("Opening library after recording stop")
        } else if audioService.isPlaying {
            audioService.stop()
            debugLog("Playback stopped")
        } else {
            // If idle and Stop is pressed -> Eject/Open Library
            showingLibrary = true
            debugLog("Opening library (eject behavior)")
        }
    }

    private func handlePlay() {
        debugLog("handlePlay() called - isPlaying: \(audioService.isPlaying), recordings count: \(recordingStore.recordings.count)")

        if audioService.isPlaying {
            audioService.pause()
            debugLog("Playback paused")
        } else if let recording = recordingStore.recordings.first {
            do {
                try audioService.play(url: recording.audioURL, rate: playbackSpeed)
                debugLog("Playback started - file: \(recording.audioFileName), rate: \(playbackSpeed)", category: "Recording")
            } catch {
                debugLog("Failed to play recording: \(error)", category: "Recording")
            }
        } else {
            debugLog("No recordings available to play", category: "Recording")
        }
    }

    private func transcribeRecording(_ recording: Recording) async {
        debugLog("Starting transcription for: \(recording.audioFileName)", category: "Transcription")

        var updated = recording
        updated.transcriptionStatus = .inProgress
        recordingStore.updateRecording(updated)

        do {
            let transcript = try await TranscriptionService.shared.transcribe(audioURL: recording.audioURL)
            updated.transcript = transcript
            updated.transcriptionStatus = .completed
            debugLog("Transcription completed - length: \(transcript.count) chars", category: "Transcription")
        } catch {
            updated.transcriptionStatus = .failed
            debugLog("Transcription failed for \(recording.audioFileName): \(error)", category: "Transcription")
        }

        recordingStore.updateRecording(updated)
    }
    
    private func playRandomSample() {
        // Placeholder for Home Alone 2 samples
        // In a real app, these would be in the bundle
        print("Playing Home Alone sample...")
        // Logic: Pick random file from bundle, play using AVAudioPlayer
    }
}

// Helper for invisible slider touch
struct CartoonSliderTouchArea: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture().onChanged { g in
                        let clampedX = min(max(g.location.x, 0), w)
                        let t = Float(clampedX / w)
                        let rangeSpan = range.upperBound - range.lowerBound
                        value = range.lowerBound + t * rangeSpan
                    }
                )
            
            // Optional: Draw a small thumb indicator
            let rangeSpan = range.upperBound - range.lowerBound
            let normalized = CGFloat((value - range.lowerBound) / rangeSpan)
            
            Rectangle()
                .fill(Color(hex: "bac2c7"))
                .frame(width: 8, height: 12)
                .position(x: normalized * w, y: geo.size.height / 2)
                .shadow(radius: 1)
                .allowsHitTesting(false)
        }
    }
}

// Helper for button press visual feedback - Hybrid approach with visible idle state
private struct CartoonButtonOverlay: View {
    let isPressed: Bool
    let color: Color
    let isActive: Bool  // For showing active state (e.g., recording)

    init(isPressed: Bool, color: Color, isActive: Bool = false) {
        self.isPressed = isPressed
        self.color = color
        self.isActive = isActive
    }

    var body: some View {
        ZStack {
            // Always-visible subtle ring (so users know where buttons are)
            Circle()
                .stroke(color.opacity(0.4), lineWidth: 2)
                .frame(width: 32, height: 32)

            // Pressed state - bright glow
            if isPressed {
                Circle()
                    .fill(color.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .blur(radius: 4)
            }

            // Active indicator (pulsing dot for record button when recording)
            if isActive {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .opacity(isActive ? 1 : 0)
                    .modifier(PulsingModifier())
            }
        }
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .allowsHitTesting(false)
    }
}

// Preview to verify layout
#Preview {
    TalkboyCartoonView()
        .environmentObject(AudioService())
        .environmentObject(RecordingStore())
}
