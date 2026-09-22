import SwiftUI

enum OnboardingStep: Hashable {
    case pickApps
    case startTime
}

/// S1 → S2 → S3. Finishing S3 marks onboarding complete and RootView switches to the tabs.
struct OnboardingFlow: View {
    @State private var path: [OnboardingStep] = []

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(.pickApps) }
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .pickApps:
                        PickAppsView { path.append(.startTime) }
                    case .startTime:
                        StartTimeView()
                    }
                }
        }
    }
}
