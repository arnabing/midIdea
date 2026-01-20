//
//  RecordingWidgetLiveActivity.swift
//  RecordingWidget
//
//  Created by Arnab on 1/13/26.
//

import ActivityKit
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
                    ExpandedLeadingView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(elapsedTime: context.state.elapsedTime)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(audioLevel: context.state.audioLevel)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView()
                }
            } compactLeading: {
                CompactLeadingView()
            } compactTrailing: {
                CompactTrailingView(elapsedTime: context.state.elapsedTime)
            } minimal: {
                MinimalView()
            }
            .keylineTint(Color.red)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenRecordingView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: .red.opacity(0.6), radius: 4)

                Text("REC")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
            }

            Spacer()

            // Duration
            Text(formatDuration(context.state.elapsedTime))
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)

            // Waveform
            SimpleWaveformView(level: context.state.audioLevel)
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
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 16, height: 16)

            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
        }
    }
}

private struct CompactTrailingView: View {
    let elapsedTime: TimeInterval

    var body: some View {
        Text(formatDuration(elapsedTime))
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundColor(.white)
            .monospacedDigit()
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct MinimalView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 14, height: 14)

            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Expanded Views

private struct ExpandedLeadingView: View {
    var body: some View {
        HStack(spacing: 6) {
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
        }
    }
}

private struct ExpandedTrailingView: View {
    let elapsedTime: TimeInterval

    var body: some View {
        Text(formatDuration(elapsedTime))
            .font(.system(size: 28, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .monospacedDigit()
    }

    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct ExpandedCenterView: View {
    let audioLevel: Float

    var body: some View {
        ExpandedWaveformView(level: audioLevel)
            .frame(height: 24)
    }
}

private struct ExpandedBottomView: View {
    var body: some View {
        Text("Tap to open midIDEA")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
    }
}

// MARK: - Waveform Views

private struct SimpleWaveformView: View {
    let level: Float
    private let barCount = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.6))
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
        let position = CGFloat(index) / CGFloat(barCount - 1)
        return Color(hue: 0.55 + position * 0.1, saturation: 0.7, brightness: 0.9)
    }
}

// MARK: - Preview

#Preview("Notification", as: .content, using: RecordingActivityAttributes(startTime: Date())) {
    RecordingWidgetLiveActivity()
} contentStates: {
    RecordingActivityAttributes.ContentState(elapsedTime: 65, isActive: true, audioLevel: 0.6)
    RecordingActivityAttributes.ContentState(elapsedTime: 120, isActive: true, audioLevel: 0.3)
}
