//
//  RecordingWidgetLiveActivity.swift
//  RecordingWidget
//
//  Created by Arnab on 1/13/26.
//

import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

// RecordingActivityAttributes is defined in RecordingActivityAttributes.swift
// This file is shared between the main app and widget extension

// MARK: - Live Activity Widget

struct RecordingWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock screen/banner UI
            LockScreenRecordingView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.8))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view regions
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(mode: context.state.mode, title: context.state.title)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(
                        elapsedTime: context.state.elapsedTime,
                        totalDuration: context.state.totalDuration,
                        mode: context.state.mode
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    let progress: Double? = context.state.mode == .playback && context.state.totalDuration != nil
                        ? context.state.elapsedTime / context.state.totalDuration!
                        : nil
                    ExpandedCenterView(audioLevel: context.state.audioLevel, mode: context.state.mode, progress: progress)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(mode: context.state.mode)
                }
            } compactLeading: {
                CompactLeadingView(mode: context.state.mode)
            } compactTrailing: {
                CompactTrailingView(
                    elapsedTime: context.state.elapsedTime,
                    totalDuration: context.state.totalDuration,
                    mode: context.state.mode
                )
            } minimal: {
                MinimalView(mode: context.state.mode)
            }
            .keylineTint(context.state.mode == .recording ? Color.red : Color.blue)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenRecordingView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Mode indicator
            if context.state.mode == .recording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .shadow(color: .red.opacity(0.6), radius: 4)

                    Text("REC")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)

                    if let title = context.state.title {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Duration / Progress
            if context.state.mode == .playback, let total = context.state.totalDuration {
                Text("\(formatDuration(context.state.elapsedTime)) / \(formatDuration(total))")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Text(formatDuration(context.state.elapsedTime))
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Waveform
            SimpleWaveformView(level: context.state.audioLevel, mode: context.state.mode)
                .frame(width: 32, height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Compact Views (Pills)

private struct CompactLeadingView: View {
    let mode: ActivityMode

    var body: some View {
        if mode == .recording {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 16, height: 16)

                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
            }
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.blue)
        }
    }
}

private struct CompactTrailingView: View {
    let elapsedTime: TimeInterval
    let totalDuration: TimeInterval?
    let mode: ActivityMode

    var body: some View {
        if mode == .playback, totalDuration != nil {
            // Show progress as percentage or compact time
            Text(formatDuration(elapsedTime))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.blue)
                .monospacedDigit()
        } else {
            Text(formatDuration(elapsedTime))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct MinimalView: View {
    let mode: ActivityMode

    var body: some View {
        if mode == .recording {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 14, height: 14)

                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Expanded Views

private struct ExpandedLeadingView: View {
    let mode: ActivityMode
    let title: String?

    var body: some View {
        HStack(spacing: 6) {
            if mode == .recording {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 16, height: 16)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                }

                Text("Recording")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            } else {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)

                Text(title ?? "Playing")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
    }
}

private struct ExpandedTrailingView: View {
    let elapsedTime: TimeInterval
    let totalDuration: TimeInterval?
    let mode: ActivityMode

    var body: some View {
        if mode == .playback, let total = totalDuration {
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatDuration(elapsedTime))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text("of \(formatDuration(total))")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        } else {
            Text(formatDuration(elapsedTime))
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()
        }
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct ExpandedCenterView: View {
    let audioLevel: Float
    let mode: ActivityMode
    let progress: Double?  // 0-1 for playback

    var body: some View {
        if mode == .playback, let progress = progress {
            // Progress bar for playback
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geo.size.width * progress, height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 24)
        } else {
            ExpandedWaveformView(level: audioLevel, mode: mode)
                .frame(height: 24)
        }
    }
}

private struct ExpandedBottomView: View {
    let mode: ActivityMode

    var body: some View {
        if mode == .recording {
            Button(intent: StopRecordingIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Stop Recording")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.red)
                )
            }
            .buttonStyle(.plain)
        } else {
            Text("Tap for playback controls")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Waveform Views

private struct SimpleWaveformView: View {
    let level: Float
    var mode: ActivityMode = .recording
    private let barCount = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(mode == .recording ? Color.white.opacity(0.6) : Color.blue.opacity(0.6))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        let position = CGFloat(index) / CGFloat(barCount - 1)
        let curve = sin(position * .pi)
        let levelMultiplier = CGFloat(max(0.2, level))
        return baseHeight + (maxHeight - baseHeight) * curve * levelMultiplier
    }
}

private struct ExpandedWaveformView: View {
    let level: Float
    var mode: ActivityMode = .recording
    private let barCount = 12

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: 3, height: barHeight(for: index, maxHeight: geo.size.height))
                }
            }
        }
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 6
        let position = CGFloat(index) / CGFloat(barCount - 1)
        let wave1 = sin(position * .pi * 2)
        let wave2 = sin(position * .pi)
        let levelMultiplier = CGFloat(max(0.3, level))
        let combinedWave = (wave1 * 0.3 + wave2 * 0.7) * levelMultiplier
        return baseHeight + (maxHeight - baseHeight) * CGFloat(abs(combinedWave))
    }

    private func barColor(for index: Int) -> Color {
        if mode == .playback {
            return Color.blue.opacity(0.7 + Double(index) / Double(barCount) * 0.3)
        }
        let position = CGFloat(index) / CGFloat(barCount - 1)
        return Color(hue: 0.55 + position * 0.1, saturation: 0.7, brightness: 0.9)
    }
}

// MARK: - Preview

#Preview("Recording", as: .content, using: RecordingActivityAttributes(startTime: Date(), mode: .recording)) {
    RecordingWidgetLiveActivity()
} contentStates: {
    RecordingActivityAttributes.ContentState(elapsedTime: 65, isActive: true, audioLevel: 0.6, mode: .recording, totalDuration: nil, title: nil)
    RecordingActivityAttributes.ContentState(elapsedTime: 120, isActive: true, audioLevel: 0.3, mode: .recording, totalDuration: nil, title: nil)
}

#Preview("Playback", as: .content, using: RecordingActivityAttributes(startTime: Date(), mode: .playback)) {
    RecordingWidgetLiveActivity()
} contentStates: {
    RecordingActivityAttributes.ContentState(elapsedTime: 45, isActive: true, audioLevel: 0.5, mode: .playback, totalDuration: 180, title: "Morning Ideas")
    RecordingActivityAttributes.ContentState(elapsedTime: 120, isActive: true, audioLevel: 0.7, mode: .playback, totalDuration: 180, title: "Morning Ideas")
}
