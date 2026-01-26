//
//  RecordingWidgetControl.swift
//  RecordingWidget
//
//  Created by Arnab on 1/13/26.
//

import AppIntents
import SwiftUI
import WidgetKit

// Control Center widget for quick recording toggle
struct RecordingWidgetControl: ControlWidget {
    static let kind: String = "com.mididea.app.RecordingControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ToggleRecordingControlIntent()) {
                Label("Record", systemImage: "mic.fill")
            }
        }
        .displayName("Quick Record")
        .description("Start a new voice recording")
    }
}

// Simple intent to open the app for recording
struct ToggleRecordingControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Recording"
    static var description = IntentDescription("Start or stop recording")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Opening the app is handled by openAppWhenRun
        return .result()
    }
}
