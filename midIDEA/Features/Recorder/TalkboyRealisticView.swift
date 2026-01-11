import SwiftUI

struct TalkboyRealisticView: View {
    @EnvironmentObject var audioService: AudioService
    @EnvironmentObject var recordingStore: RecordingStore

    @State private var showingLibrary = false
    @State private var volume: Float = 1.0
    @State private var playbackSpeed: Float = 1.0
    @State private var showPermissionAlert = false
    @State private var currentRecordingURL: URL?
    @State private var showAlignmentOverlay = false
    @State private var showCalibrationPanel = false

    @StateObject private var layout = TalkboyLayoutModel()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Screen background
                LinearGradient(
                    colors: [Color(hex: "D8D9DD"), Color(hex: "BFC0C4")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Layout Constants
                let keybedHeight: CGFloat = 84
                
                let maxWidth = geometry.size.width
                let maxHeight = geometry.size.height
                
                let isLandscape = maxWidth > maxHeight
                
                // Dynamic Sizing Logic
                // We want to maximize the faceplate size 's', subject to:
                // 1. s <= maxHeight - keybedHeight
                // 2. Total Width <= maxWidth (in Landscape)
                
                let s_heightLimit = maxHeight - keybedHeight
                
                // Width calculation with even wider body (75% wider than content)
                let bodyMultiplier: CGFloat = 1.75
                
                // Total Width = Left Attachment + Body
                // Left Attachment W = (s + K) * 0.45
                // Body W = s * bodyMultiplier
                // Total W = 0.45s + 0.45K + 1.75s = 2.2s + 0.45K
                
                // s_widthLimit = (MaxWidth - 0.45K) / 2.2
                
                let s_widthLimit = (maxWidth - (keybedHeight * 0.45)) / 2.2
                
                // If portrait, we just fit width
                let s_portrait = maxWidth * 0.85 
                
                let faceplateSize: CGFloat = isLandscape 
                    ? min(s_heightLimit, s_widthLimit)
                    : min(s_heightLimit, s_portrait)
                
                let calculatedTotalHeight = faceplateSize + keybedHeight
                let contentWidth = faceplateSize
                let bodyWidth = contentWidth * bodyMultiplier // 75% wider body
                
                HStack(spacing: -2) { // Negative spacing for seamless merge
                    // LEFT: Speaker Attachment
                    if isLandscape {
                        TalkboyLeftAttachmentView(
                            height: calculatedTotalHeight,
                            action: { showingLibrary = true }
                        )
                        .transition(.move(edge: .leading))
                        .zIndex(1)
                    } else {
                        Spacer()
                    }

                    // CENTER: Main Talkboy Unit
                    ZStack {
                        // Metallic Body Chassis (Wider than content)
                        TalkboyBodyView()
                            .frame(width: bodyWidth, height: calculatedTotalHeight)
                        
                        // Content: Keybed + Faceplate (Centered, fixed width)
                        VStack(spacing: 0) {
                            // Keybed
                            TalkboyKeybedView(
                                isRecording: audioService.isRecording,
                                isPlaying: audioService.isPlaying,
                                onRewind: { audioService.skipBackward() },
                                onPlay: handlePlay,
                                onStop: handleStop,
                                onFastForward: { audioService.skipForward() },
                                onRecord: handleRecord
                            )
                            .frame(width: contentWidth, height: keybedHeight)
                            .padding(.top, 4) // Slight inset from top chassis edge

                            // Faceplate
                            ZStack {
                                GeometryReader { innerGeo in
                                    let fw = innerGeo.size.width
                                    let fh = innerGeo.size.height
                                    ZStack {
                                        TalkboyFaceplateView(
                                            volume: $volume,
                                            playbackSpeed: $playbackSpeed
                                        )

                                        TapeReelView(
                                            isAnimating: audioService.isRecording || audioService.isPlaying,
                                            isRecording: audioService.isRecording
                                        )
                                        .frame(width: min(fw, fh) * 0.42, height: min(fw, fh) * 0.42)
                                        .position(x: fw * 0.72, y: fh * 0.40)
                                    }
                                }
                            }
                            .frame(width: contentWidth, height: faceplateSize)
                        }
                    }
                    .frame(width: bodyWidth, height: calculatedTotalHeight)
                    .zIndex(2) // Body on top of attachments margins
                    
                    // RIGHT: Removed Mic
                    if isLandscape {
                        Spacer()
                    } else {
                        Spacer()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                #if DEBUG
                if showCalibrationPanel {
                    TalkboyCalibrationPanel(layout: layout)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(10)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                #endif
                
                // Invisible gesture layer
                Color.clear
                    .contentShape(Rectangle())
                    #if DEBUG
                    .highPriorityGesture(
                        TapGesture(count: 4).onEnded {
                            withAnimation { showCalibrationPanel.toggle() }
                        }
                    )
                    #endif
            }
        }
        .ignoresSafeArea()
        .onChange(of: volume) { _, newValue in audioService.setVolume(newValue) }
        .onChange(of: playbackSpeed) { _, newValue in audioService.setPlaybackRate(newValue) }
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
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromIntent)) { _ in handleRecord() }
        .onReceive(NotificationCenter.default.publisher(for: .toggleRecordingFromIntent)) { _ in
            if audioService.isRecording { handleStop() } else { handleRecord() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .stopRecordingFromIntent)) { _ in handleStop() }
        .onAppear { audioService.setupAudioSession() }
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height < -50 { showingLibrary = true }
            }
        )
    }

    // MARK: - Actions
    private func handleRecord() {
        Task {
            let granted = await audioService.requestMicrophonePermission()
            if granted {
                do { currentRecordingURL = try audioService.startRecording() }
                catch { print("Failed to start recording: \(error)") }
            } else { showPermissionAlert = true }
        }
    }

    private func handleStop() {
        if audioService.isRecording {
            guard let result = audioService.stopRecording() else { return }
            let recording = Recording(audioFileName: result.url.lastPathComponent, transcriptionStatus: .pending)
            var mutableRecording = recording
            mutableRecording.duration = result.duration
            recordingStore.addRecording(mutableRecording)
            Task { await transcribeRecording(mutableRecording) }
        } else if audioService.isPlaying {
            audioService.stop()
        }
    }

    private func handlePlay() {
        if audioService.isPlaying { audioService.pause() }
        else if let recording = recordingStore.recordings.first {
            do { try audioService.play(url: recording.audioURL, rate: playbackSpeed) }
            catch { print("Failed to play: \(error)") }
        }
    }

    private func transcribeRecording(_ recording: Recording) async {
        var updated = recording
        updated.transcriptionStatus = .inProgress
        recordingStore.updateRecording(updated)
        do {
            let transcript = try await TranscriptionService.shared.transcribe(audioURL: recording.audioURL)
            updated.transcript = transcript
            updated.transcriptionStatus = .completed
        } catch {
            updated.transcriptionStatus = .failed
        }
        recordingStore.updateRecording(updated)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    TalkboyRealisticView()
        .environmentObject(AudioService())
        .environmentObject(RecordingStore())
}
