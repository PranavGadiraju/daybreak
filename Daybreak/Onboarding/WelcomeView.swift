import SwiftUI
import UIKit

/// S1: explains the three steps and asks for Screen Time access.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    let onContinue: () -> Void
    @State private var isRequesting = false

    private var isDenied: Bool { model.authorization == .denied }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: "sunrise.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Daybreak")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("Pick the apps that pull at you. From a time you choose, they stay shielded until you've written today's goals.")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                StepCard(number: 1, title: "Allow Screen Time", detail: "iOS enforces the shield, not this app.")
                StepCard(number: 2, title: "Pick apps", detail: "Daybreak only receives anonymous tokens.")
                StepCard(number: 3, title: "Choose a start time", detail: "Default 7:00 AM, every day.")
            }
            Spacer(minLength: 0)
            if isDenied {
                Text("Screen Time access was declined, so nothing can be shielded yet. Allow it in Settings, then try again.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button(action: continueTapped) {
                Group {
                    if isRequesting {
                        ProgressView()
                    } else {
                        Text(buttonTitle)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRequesting)
            if isDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url)
                    .frame(maxWidth: .infinity)
            }
            Text("Nothing leaves your phone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var buttonTitle: String {
        switch model.authorization {
        case .approved: "Continue"
        case .denied: "Try again"
        case .notDetermined: "Allow Screen Time access"
        }
    }

    private func continueTapped() {
        if model.authorization == .approved {
            onContinue()
            return
        }
        isRequesting = true
        Task {
            await model.requestAuthorization()
            isRequesting = false
            if model.authorization == .approved {
                onContinue()
            }
        }
    }
}

private struct StepCard: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
