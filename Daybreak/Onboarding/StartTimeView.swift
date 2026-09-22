import SwiftUI

/// S3: the daily start time. Saving registers the schedule and finishes onboarding.
struct StartTimeView: View {
    @Environment(AppModel.self) private var model
    @State private var date = TimeOfDay.defaultStart.date(on: .now) ?? .now
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("When should the shield start?")
                .font(.title2.bold())
            Text("Every day, until you've reflected.")
                .foregroundStyle(.secondary)
            DatePicker("Start time", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(date, format: .dateTime.hour().minute()) → 11:59 PM")
                    .font(.headline)
                Text("\(appsPhrase(model.selectedCount)) stay shielded until today's reflection is approved. Unlocked time carries to the next morning.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            Spacer(minLength: 0)
            Button(action: save) {
                Text("Start the schedule")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .navigationTitle("Start time")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        do {
            try model.saveStartTime(TimeOfDay(date))
            model.completeOnboarding()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
