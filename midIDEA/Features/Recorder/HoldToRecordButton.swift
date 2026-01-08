import SwiftUI

struct HoldToRecordButton: View {
    @Binding var recordingState: RecordingState
    @Binding var countdownValue: Int

    let onRecordingStart: () -> Void
    let onRecordingEnd: () -> Void
    let onRecordingCancel: () -> Void

    @State private var isPressed = false
    @State private var glowAmount: CGFloat = 0
    @State private var buttonScale: CGFloat = 1.0
    @State private var countdownProgress: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var countdownTimer: Timer?

    private let buttonSize: CGFloat = 80
    private let countdownDuration: Int = 3

    var body: some View {
        ZStack {
            // Glow effect (behind button)
            if recordingState == .recording || recordingState == .countdown {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: buttonSize + glowAmount, height: buttonSize + glowAmount)
                    .blur(radius: glowAmount / 3)
            }

            // Countdown ring
            if recordingState == .countdown {
                Circle()
                    .stroke(Color.red.opacity(0.3), lineWidth: 6)
                    .frame(width: buttonSize + 30, height: buttonSize + 30)

                Circle()
                    .trim(from: 0, to: countdownProgress)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: buttonSize + 30, height: buttonSize + 30)
                    .rotationEffect(.degrees(-90))

                // Countdown number
                Text("\(countdownValue)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                    .transition(.scale.combined(with: .opacity))
            }

            // Main button
            if recordingState != .countdown {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: recordingState == .recording
                                ? [Color.red.opacity(0.9), Color.red]
                                : [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                            center: .center,
                            startRadius: 0,
                            endRadius: buttonSize / 2
                        )
                    )
                    .frame(width: buttonSize, height: buttonSize)
                    .scaleEffect(buttonScale)
                    .shadow(color: .red.opacity(recordingState == .recording ? 0.6 : 0.3),
                            radius: recordingState == .recording ? 15 : 5,
                            x: 0, y: 0)
                    .overlay(
                        // Inner circle detail
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: buttonSize - 10, height: buttonSize - 10)
                    )
                    .overlay(
                        // Recording dot or REC text
                        Group {
                            if recordingState == .recording {
                                Text("REC")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .fill(Color.white.opacity(0.9))
                                    .frame(width: 20, height: 20)
                            }
                        }
                    )
                    .offset(dragOffset)
            }

            // Cancel hint (when dragging away)
            if recordingState == .countdown && abs(dragOffset.width) > 50 {
                Text("Release to cancel")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .offset(y: buttonSize / 2 + 40)
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.1)
                .onEnded { _ in
                    startRecording()
                }
                .simultaneously(with:
                    DragGesture()
                        .onChanged { value in
                            if recordingState == .countdown {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            if recordingState == .countdown {
                                if abs(value.translation.width) > 100 || abs(value.translation.height) > 100 {
                                    cancelFromCountdown()
                                }
                                dragOffset = .zero
                            }
                        }
                )
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if recordingState == .idle {
                        withAnimation(.easeOut(duration: 0.1)) {
                            isPressed = true
                            buttonScale = 1.1
                        }
                    }
                }
                .onEnded { _ in
                    if recordingState == .recording {
                        stopRecording()
                    }
                    withAnimation(.easeOut(duration: 0.1)) {
                        isPressed = false
                        buttonScale = 1.0
                    }
                }
        )
        .onTapGesture {
            if recordingState == .countdown {
                resumeRecording()
            }
        }
    }

    // MARK: - Recording State Machine

    private func startRecording() {
        guard recordingState == .idle else { return }

        recordingState = .recording
        onRecordingStart()
        HapticService.shared.playRecordStart()

        // Start glow animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            glowAmount = 40
        }
    }

    private func stopRecording() {
        guard recordingState == .recording else { return }

        recordingState = .countdown
        countdownValue = countdownDuration
        countdownProgress = 1.0
        glowAmount = 20

        HapticService.shared.playRecordStop()

        startCountdown()
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                countdownTick()
            }
        }

        // Animate progress ring
        withAnimation(.linear(duration: Double(countdownDuration))) {
            countdownProgress = 0
        }
    }

    private func countdownTick() {
        HapticService.shared.playCountdownTick()

        if countdownValue > 1 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                countdownValue -= 1
            }
        } else {
            finalizeRecording()
        }
    }

    private func finalizeRecording() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            recordingState = .idle
            glowAmount = 0
            countdownProgress = 1.0
        }

        HapticService.shared.playSaveSuccess()
        onRecordingEnd()
    }

    private func resumeRecording() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            recordingState = .recording
            countdownProgress = 1.0
        }

        // Resume glow animation
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            glowAmount = 40
        }

        HapticService.shared.playRecordStart()
    }

    private func cancelFromCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            recordingState = .idle
            glowAmount = 0
            countdownProgress = 1.0
            dragOffset = .zero
        }

        HapticService.shared.playDiscardWarning()
        onRecordingCancel()
    }
}

#Preview {
    VStack {
        HoldToRecordButton(
            recordingState: .constant(.idle),
            countdownValue: .constant(3),
            onRecordingStart: { print("Started") },
            onRecordingEnd: { print("Ended") },
            onRecordingCancel: { print("Cancelled") }
        )
    }
    .padding(50)
}
