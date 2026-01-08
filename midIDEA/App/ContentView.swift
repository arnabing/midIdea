import SwiftUI

struct ContentView: View {
    @State private var showingLibrary = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color("BackgroundTop"), Color("BackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                // Main cassette recorder view
                RecorderView()

                // Swipe up indicator for library
                VStack(spacing: 4) {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Recordings")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                .onTapGesture {
                    showingLibrary = true
                }
            }
        }
        .sheet(isPresented: $showingLibrary) {
            LibraryView()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -50 {
                        showingLibrary = true
                    }
                }
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(RecordingStore())
        .environmentObject(AudioService())
}
