import SwiftUI
import UIKit

/// Native iOS share sheet wrapper for sharing audio and transcripts
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let applicationActivities: [UIActivity]?

    init(items: [Any], applicationActivities: [UIActivity]? = nil) {
        self.items = items
        self.applicationActivities = applicationActivities
        DebugLogger.log("ShareSheet initialized with \(items.count) item(s)", category: .sharing, level: .info)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: applicationActivities
        )

        // Configure for iPad popover if needed
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        // Log completion
        controller.completionWithItemsHandler = { activityType, completed, _, error in
            if let error = error {
                DebugLogger.logError("Share sheet failed", error: error)
            } else if completed {
                DebugLogger.log("Share completed via: \(activityType?.rawValue ?? "unknown")", category: .sharing, level: .info)
            } else {
                DebugLogger.log("Share cancelled", category: .sharing, level: .debug)
            }
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
