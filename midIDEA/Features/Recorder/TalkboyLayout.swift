import SwiftUI

/// Centralizes proportional layout knobs.
@MainActor
final class TalkboyLayoutModel: ObservableObject {
    // Canvas - Adjusted for portrait-friendly vertical layout (Boxier)
    @Published var canvasHeightRatio: CGFloat = 0.85
    @Published var canvasAspect: CGFloat = 0.82 // width:height - Closer to square/portrait
    @Published var overlayOpacity: Double = 0.251

    // Faceplate insets
    @Published var faceplateHorizontalPaddingRatio: CGFloat = 0.055
    @Published var faceplateTopPaddingRatio: CGFloat = 0.040
    @Published var faceplateBottomPaddingRatio: CGFloat = 0.060
    
    // Internal element ratios can remain if needed by subviews, or cleaned up.
    @Published var reelSizeRatio: CGFloat = 0.567
    @Published var reelCenterXRatio: CGFloat = 0.815
    @Published var reelCenterYRatio: CGFloat = 0.464
}

/// DEBUG-only slider panel to tune TalkboyLayoutModel live.
struct TalkboyCalibrationPanel: View {
    @ObservedObject var layout: TalkboyLayoutModel

    var body: some View {
        TalkboyCalibrationSheet(layout: layout)
    }
}

/// A bottom sheet version of the calibration panel so the Talkboy stays visible.
private struct TalkboyCalibrationSheet: View {
    @ObservedObject var layout: TalkboyLayoutModel

    @State private var sheetHeightRatio: CGFloat = 0.38
    @State private var dragStartRatio: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let fullH = geo.size.height
            let minRatio: CGFloat = 0.22
            let maxRatio: CGFloat = 0.70
            let sheetH = fullH * sheetHeightRatio

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 46, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                HStack(spacing: 10) {
                    Text("Talkboy Calibration (DEBUG)")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Button("Copy") {
                        UIPasteboard.general.string = layout.exportText()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.16)))
                }
                .padding(.horizontal, 14)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        sliderDouble("Overlay opacity", $layout.overlayOpacity, 0.10...0.45)

                        Divider().opacity(0.35)

                        slider("Canvas height", $layout.canvasHeightRatio, 0.5...1.0)
                        slider("Canvas aspect", $layout.canvasAspect, 0.5...2.0)

                        Text("Tip: triple-tap toggles reference overlay; four-tap toggles this panel.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .frame(height: sheetH)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.60))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .foregroundColor(.white)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .gesture(
                DragGesture()
                    .onChanged { g in
                        if dragStartRatio == nil { dragStartRatio = sheetHeightRatio }
                        let start = dragStartRatio ?? sheetHeightRatio
                        let delta = g.translation.height / fullH
                        sheetHeightRatio = min(max(start - delta, minRatio), maxRatio)
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                    }
            )
        }
    }

    private func slider(_ title: String, _ value: Binding<CGFloat>, _ range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    Spacer()
                Text(String(format: "%.3f", value.wrappedValue))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .opacity(0.9)
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = CGFloat($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound)
            )
        }
    }

    private func sliderDouble(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .opacity(0.9)
            }
            Slider(value: value, in: range)
        }
    }
}

private extension TalkboyLayoutModel {
    func exportText() -> String {
        """
        overlayOpacity=\(String(format: "%.3f", overlayOpacity))
        canvasHeightRatio=\(String(format: "%.3f", canvasHeightRatio))
        canvasAspect=\(String(format: "%.3f", canvasAspect))
        """
    }
}
