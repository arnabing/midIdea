//
//  RecordingWidgetBundle.swift
//  RecordingWidget
//
//  Created by Arnab on 1/13/26.
//

import WidgetKit
import SwiftUI

@main
struct RecordingWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Only include the Live Activity for Dynamic Island
        RecordingWidgetLiveActivity()
    }
}
