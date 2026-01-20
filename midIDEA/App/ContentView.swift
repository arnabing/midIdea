import SwiftUI

struct ContentView: View {
    var body: some View {
        MainContainerView()
            .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
        .environmentObject(RecordingStore())
        .environmentObject(AudioService())
}
