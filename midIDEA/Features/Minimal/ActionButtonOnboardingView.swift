import SwiftUI

/// Onboarding view that guides users to set up the Action Button for quick recording.
struct ActionButtonOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenActionButtonOnboarding") private var hasSeenOnboarding = false

    @State private var currentStep = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "hand.tap.fill",
            title: "Quick Recording",
            description: "Start recording instantly using the Action Button on the side of your iPhone.",
            instruction: nil,
            action: nil
        ),
        OnboardingStep(
            icon: "square.grid.2x2.fill",
            title: "Open Shortcuts App",
            description: "First, open the Shortcuts app to sync midIDEA's actions with your device. Search for 'midIDEA' to verify it appears.",
            instruction: "This registers the shortcuts",
            action: .openShortcuts
        ),
        OnboardingStep(
            icon: "gearshape.fill",
            title: "Configure Action Button",
            description: "Go to Settings → Action Button, then scroll down and tap 'Shortcut'.",
            instruction: "Settings → Action Button → Shortcut",
            action: .openSettings
        ),
        OnboardingStep(
            icon: "magnifyingglass",
            title: "Find midIDEA",
            description: "Search for 'midIDEA' or 'Record' and select 'Record Voice Note'.",
            instruction: "Search: midIDEA",
            action: nil
        ),
        OnboardingStep(
            icon: "checkmark.circle.fill",
            title: "You're All Set!",
            description: "Press and hold the Action Button anytime to start recording - even from your lock screen.",
            instruction: nil,
            action: nil
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hex: "1C1C1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Capsule()
                                .fill(index <= currentStep ? Color.white : Color.white.opacity(0.2))
                                .frame(height: 4)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    Spacer()

                    // Step content
                    let step = steps[currentStep]

                    VStack(spacing: 32) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 120, height: 120)

                            Image(systemName: step.icon)
                                .font(.system(size: 48))
                                .foregroundColor(.white)
                        }

                        // Title
                        Text(step.title)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        // Description
                        Text(step.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        // Instruction highlight (if present)
                        if let instruction = step.instruction {
                            Text(instruction)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.15))
                                )
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Troubleshooting tip
                    if currentStep == 3 {
                        VStack(spacing: 8) {
                            Text("Not seeing midIDEA?")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                            Text("Try deleting and reinstalling the app, then run it once before checking Shortcuts.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                    }

                    // Buttons
                    VStack(spacing: 16) {
                        // Primary button
                        Button(action: handlePrimaryAction) {
                            Text(primaryButtonText)
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(14)
                        }

                        // Secondary button (skip or open settings)
                        if currentStep < steps.count - 1 {
                            Button(action: handleSkip) {
                                Text("Skip")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: handleDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.title2)
                    }
                }
            }
        }
        .interactiveDismissDisabled(currentStep == 0 && !hasSeenOnboarding)
    }

    private var primaryButtonText: String {
        switch steps[currentStep].action {
        case .openShortcuts:
            return "Open Shortcuts"
        case .openSettings:
            return "Open Settings"
        case nil:
            return currentStep == steps.count - 1 ? "Done" : "Continue"
        }
    }

    private func handlePrimaryAction() {
        let step = steps[currentStep]

        switch step.action {
        case .openShortcuts:
            // Open Shortcuts app
            if let url = URL(string: "shortcuts://") {
                UIApplication.shared.open(url)
            }
            withAnimation {
                currentStep += 1
            }
        case .openSettings:
            // Open Settings
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            withAnimation {
                currentStep += 1
            }
        case nil:
            if currentStep < steps.count - 1 {
                withAnimation {
                    currentStep += 1
                }
            } else {
                handleDismiss()
            }
        }
    }

    private func handleSkip() {
        handleDismiss()
    }

    private func handleDismiss() {
        hasSeenOnboarding = true
        dismiss()
    }
}

// MARK: - Onboarding Step Model

private enum OnboardingAction {
    case openShortcuts
    case openSettings
}

private struct OnboardingStep {
    let icon: String
    let title: String
    let description: String
    let instruction: String?
    let action: OnboardingAction?
}

#Preview {
    ActionButtonOnboardingView()
}
