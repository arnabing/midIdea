import SwiftUI

struct TalkboyKeybedView: View {
    let isRecording: Bool
    let isPlaying: Bool
    let onRewind: () -> Void
    let onPlay: () -> Void
    let onStop: () -> Void
    let onFastForward: () -> Void
    let onRecord: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TalkboyKey(label: "REW", glyph: .rewind, action: onRewind)
                .frame(maxWidth: .infinity)
            TalkboyKey(label: "PLAY", glyph: .play, action: onPlay, isActive: isPlaying)
                .frame(maxWidth: .infinity)
            TalkboyKey(label: "STOP", glyph: .stop, action: onStop)
                .frame(maxWidth: .infinity)
            TalkboyKey(label: "FF", glyph: .fastForward, action: onFastForward)
                .frame(maxWidth: .infinity)
            TalkboyKey(label: "REC", glyph: .none, action: onRecord, isRecord: true, isActive: isRecording)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

private struct TalkboyKey: View {
    enum Glyph { case rewind, play, stop, fastForward, none }

    let label: String
    let glyph: Glyph
    let action: () -> Void
    var isRecord: Bool = false
    var isActive: Bool = false

    @State private var pressed = false

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.black.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .allowsTightening(true)

            Button(action: {
                HapticService.shared.playButtonPress()
                action()
            }) {
                ZStack {
                    // Button base with gradient
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: isRecord
                                    ? (pressed ? [Color(hex: "8B0000"), Color(hex: "600000")] : [Color(hex: "CC0000"), Color(hex: "A00000"), Color(hex: "800000")])
                                    : (pressed ? [Color(hex: "0C0C0E"), Color(hex: "151517")] : [Color(hex: "2C2C2E"), Color(hex: "1A1A1C"), Color(hex: "0C0C0E")]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(pressed ? 0.15 : 0.55), radius: pressed ? 1 : 4, x: 0, y: pressed ? 1 : 3)

                    // 3D bevel effect stroke
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(pressed ? 0.05 : 0.15),
                                    Color.clear,
                                    Color.black.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )

                    // Inner highlight at top edge
                    if !pressed {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.12), Color.clear, Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1
                            )
                            .padding(2)
                    }

                    if !isRecord {
                        keyGlyph
                            .foregroundColor(.white.opacity(0.95))
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                    }

                    // Active state glow (recording or playing)
                    if isActive {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isRecord ? Color.red : Color.green, lineWidth: 2)
                            .modifier(PulsingModifier())
                    }

                    // Pulsing red dot for Record button when recording
                    if isRecord && isActive {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .modifier(PulsingModifier())
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .scaleEffect(pressed ? 0.96 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: pressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
        }
    }

    @ViewBuilder
    private var keyGlyph: some View {
        switch glyph {
        case .rewind:
            TalkboyGlyph.rewind
                .frame(width: 28, height: 18)
        case .play:
            TalkboyGlyph.play
                .frame(width: 24, height: 18)
        case .stop:
            TalkboyGlyph.stop
                .frame(width: 16, height: 16)
        case .fastForward:
            TalkboyGlyph.fastForward
                .frame(width: 28, height: 18)
        case .none:
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 10, height: 10)
                .opacity(0.0)
        }
    }
}

private enum TalkboyGlyph {
    static var play: some View {
        Triangle()
            .fill(Color.white)
            .rotationEffect(.degrees(90))
    }

    static var rewind: some View {
        HStack(spacing: 3) {
            Triangle().fill(Color.white).rotationEffect(.degrees(-90))
            Triangle().fill(Color.white).rotationEffect(.degrees(-90))
        }
    }

    static var fastForward: some View {
        HStack(spacing: 3) {
            Triangle().fill(Color.white).rotationEffect(.degrees(90))
            Triangle().fill(Color.white).rotationEffect(.degrees(90))
        }
    }

    static var stop: some View {
        Rectangle().fill(Color.white)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    ZStack {
        Color(hex: "D8D9DD")
        TalkboyKeybedView(
            isRecording: true,
            isPlaying: false,
            onRewind: {}, onPlay: {}, onStop: {}, onFastForward: {}, onRecord: {}
        )
        .padding()
    }
}

