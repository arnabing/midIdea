import SwiftUI

/// Individual recording row in the sidebar list
struct SidebarRecordingRow: View {
    let recording: Recording
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)

                // Title and metadata
                VStack(alignment: .leading, spacing: 2) {
                    Text(recording.displayTitle)
                        .font(.bodySecondary)
                        .foregroundStyle(.white.opacity(isSelected ? 1 : 0.9))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(recording.formattedDuration)
                            .font(.captionSmall)

                        Text("•")

                        Text(recording.formattedDate)
                            .font(.captionSmall)
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }

                Spacer(minLength: 8)

                // Menu button
                Menu {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .alert("Delete Recording?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This will permanently delete \"\(recording.displayTitle)\" and its transcript.")
        }
    }

    private var iconName: String {
        switch recording.transcriptionStatus {
        case .completed:
            return "doc.text.fill"
        case .inProgress:
            return "arrow.clockwise"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .pending:
            return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch recording.transcriptionStatus {
        case .completed:
            return .white.opacity(0.7)
        case .inProgress:
            return .blue
        case .failed:
            return .orange
        case .pending:
            return .white.opacity(0.5)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "050508")
            .ignoresSafeArea()

        VStack(spacing: 4) {
            SidebarRecordingRow(
                recording: Recording(duration: 125, audioFileName: "test.m4a"),
                isSelected: true,
                onSelect: {},
                onDelete: {}
            )

            SidebarRecordingRow(
                recording: Recording(duration: 3600, audioFileName: "meeting.m4a"),
                isSelected: false,
                onSelect: {},
                onDelete: {}
            )
        }
        .frame(width: 280)
    }
}
