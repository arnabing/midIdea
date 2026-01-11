import SwiftUI

struct ContentView: View {
    // Simple state to toggle between views for testing
    @State private var useCartoonMode = true
    
    var body: some View {
        ZStack {
            if useCartoonMode {
                TalkboyCartoonView()
            } else {
                TalkboyRealisticView()
            }
            
            // Temporary Toggle Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { useCartoonMode.toggle() }) {
                        Text(useCartoonMode ? "Switch to Realistic" : "Switch to Cartoon")
                            .font(.caption)
                            .padding(8)
                            .background(.thinMaterial)
                            .cornerRadius(8)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RecordingStore())
        .environmentObject(AudioService())
}
