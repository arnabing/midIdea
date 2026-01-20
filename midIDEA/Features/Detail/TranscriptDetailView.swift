import SwiftUI

/// Full-screen transcript view with summary card and floating glass controls
struct TranscriptDetailView: View {
    let recording: Recording

    @EnvironmentObject var audioService: AudioService
    @State private var showCopiedToast = false

    var body: some View {
        ZStack {
            // Light background
            Color(.systemGray6)
                .ignoresSafeArea()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Top spacing for navigation bar
                    Spacer()
                        .frame(height: 16)

                    // Summary card (if available)
                    if let summary = recording.summary, !summary.isEmpty {
                        SummaryCard(summary: summary)
                            .padding(.horizontal, 16)
                    }

                    // Transcript content (no container)
                    transcriptContent
                        .padding(.horizontal, 16)

                    // Bottom spacing for media player
                    Spacer()
                        .frame(height: 130)
                }
            }
            .scrollIndicators(.hidden)

            // Bottom media player only
            VStack {
                Spacer()

                MediaPlayerBar(recording: recording)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .navigationTitle(recording.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: copyTranscript) {
                        Label("Copy Transcript", systemImage: "doc.on.doc")
                    }
                    Button(action: {}) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive, action: {}) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Transcript Content (No Container)

    @ViewBuilder
    private var transcriptContent: some View {
        switch recording.transcriptionStatus {
        case .completed:
            if let transcript = recording.transcript, !transcript.isEmpty {
                Text(transcript)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(6)
                    .textSelection(.enabled)
            } else {
                emptyTranscriptView
            }

        case .inProgress:
            HStack(spacing: 12) {
                ProgressView()
                Text("Transcribing...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

        case .failed:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Transcription failed")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)

        case .pending:
            VStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Waiting to transcribe")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private var emptyTranscriptView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No transcript available")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Toast

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Copied to clipboard")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect()
        .padding(.top, 60)
    }

    // MARK: - Actions

    private func copyTranscript() {
        guard let transcript = recording.transcript, !transcript.isEmpty else { return }
        UIPasteboard.general.string = transcript

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCopiedToast = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showCopiedToast = false
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let summary: String
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.purple)

                    Text("Summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Content
            if isExpanded {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect()
    }
}

#Preview {
    TranscriptDetailView(
        recording: {
            var r = Recording(duration: 125, audioFileName: "test.m4a")
            r.transcript = "I have a dream that one day this nation will rise up and live out the true meaning of its creed: We hold these truths to be self-evident, that all men are created equal.\n\nI have a dream that one day on the red hills of Georgia, the sons of former slaves and the sons of former slave owners will be able to sit down together at the table of brotherhood."
            r.summary = "Martin Luther King Jr.'s iconic speech about racial equality and the dream of a united America where people are judged by character, not skin color."
            r.transcriptionStatus = .completed
            return r
        }()
    )
    .environmentObject(AudioService())
}
