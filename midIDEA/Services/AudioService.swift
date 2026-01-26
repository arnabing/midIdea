import AVFoundation
import Combine

@MainActor
class AudioService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var duration: TimeInterval = 0

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var meteringTimer: Timer?
    private var playbackTimer: Timer?
    private var currentRecordingURL: URL?

    // MARK: - Silence Detection

    private var silenceStartTime: Date?
    private let silenceThreshold: Float = -45.0  // dB level considered silence
    var silenceDuration: TimeInterval = 15.0     // Seconds of silence before auto-stop
    var onSilenceAutoStop: (() -> Void)?         // Callback when silence triggers stop

    // MARK: - Constants

    static let maxRecordingDuration: TimeInterval = 30 * 60 // 30 minutes

    // MARK: - Permissions

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Recording

    func startRecording() throws -> URL {
        let fileName = "\(UUID().uuidString).m4a"
        let url = Recording.recordingsDirectory.appendingPathComponent(fileName)
        currentRecordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.delegate = self
        audioRecorder?.record()

        isRecording = true
        currentTime = 0
        silenceStartTime = nil  // Reset silence detection

        startMeteringTimer()
        playRecordStartSound()

        // Start Live Activity for Dynamic Island
        LiveActivityManager.shared.startRecordingActivity()

        return url
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        let duration = recorder.currentTime
        recorder.stop()

        stopMeteringTimer()
        isRecording = false
        audioLevel = 0

        playRecordStopSound()

        // End Live Activity
        LiveActivityManager.shared.endRecordingActivity()

        if let url = currentRecordingURL {
            return (url, duration)
        }
        return nil
    }

    func cancelRecording() {
        guard isRecording else { return }

        audioRecorder?.stop()
        stopMeteringTimer()
        isRecording = false
        audioLevel = 0

        // End Live Activity
        LiveActivityManager.shared.endRecordingActivity()

        // Delete the cancelled recording file
        if let url = currentRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentRecordingURL = nil
    }

    // MARK: - Playback

    func play(url: URL, rate: Float = 1.0) throws {
        stop()

        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.enableRate = true
        audioPlayer?.rate = rate
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()

        duration = audioPlayer?.duration ?? 0
        isPlaying = true

        startPlaybackTimer()
        playTapeStartSound()
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }

    func resume() {
        audioPlayer?.play()
        isPlaying = true
        startPlaybackTimer()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        stopPlaybackTimer()
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func setPlaybackRate(_ rate: Float) {
        audioPlayer?.rate = rate
    }

    func setVolume(_ volume: Float) {
        audioPlayer?.volume = volume
    }

    func skipForward(_ seconds: TimeInterval = 10) {
        guard let player = audioPlayer else { return }
        let newTime = min(player.currentTime + seconds, player.duration)
        seek(to: newTime)
    }

    func skipBackward(_ seconds: TimeInterval = 10) {
        guard let player = audioPlayer else { return }
        let newTime = max(player.currentTime - seconds, 0)
        seek(to: newTime)
    }

    // MARK: - Sound Effects

    private func playRecordStartSound() {
        // TODO: Play tape motor start sound
        HapticService.shared.playRecordStart()
    }

    private func playRecordStopSound() {
        // TODO: Play tape motor stop sound
        HapticService.shared.playRecordStop()
    }

    private func playTapeStartSound() {
        // TODO: Play tape playback start sound
    }

    // MARK: - Timers

    private func startMeteringTimer() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetering()
            }
        }
    }

    private func stopMeteringTimer() {
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func updateMetering() {
        guard let recorder = audioRecorder, isRecording else { return }
        recorder.updateMeters()
        audioLevel = recorder.averagePower(forChannel: 0)
        currentTime = recorder.currentTime

        // Update Live Activity with audio level
        LiveActivityManager.shared.setAudioLevel(audioLevel)

        // Check for stop request from Dynamic Island widget
        checkForWidgetStopRequest()

        // Check max duration
        if currentTime >= Self.maxRecordingDuration {
            _ = stopRecording()
        }

        // Silence detection
        if audioLevel < silenceThreshold {
            // Audio is below threshold (silence)
            if silenceStartTime == nil {
                silenceStartTime = Date()
            } else if let startTime = silenceStartTime,
                      Date().timeIntervalSince(startTime) >= silenceDuration {
                // Silence duration exceeded - trigger auto-stop
                silenceStartTime = nil
                onSilenceAutoStop?()
            }
        } else {
            // Sound detected - reset silence timer
            silenceStartTime = nil
        }
    }

    private func startPlaybackTimer() {
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePlayback()
            }
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func updatePlayback() {
        guard let player = audioPlayer, isPlaying else { return }
        currentTime = player.currentTime
    }

    // MARK: - Widget Communication

    /// Check if the Dynamic Island widget requested to stop recording
    private func checkForWidgetStopRequest() {
        let defaults = UserDefaults(suiteName: "group.com.mididea.shared")
        if defaults?.bool(forKey: "stopRecordingRequested") == true {
            // Clear the flag first
            defaults?.removeObject(forKey: "stopRecordingRequested")
            defaults?.synchronize()

            // Stop the recording
            _ = stopRecording()
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            isRecording = false
            stopMeteringTimer()
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
            currentTime = 0
            stopPlaybackTimer()
        }
    }
}
