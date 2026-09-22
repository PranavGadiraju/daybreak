import FamilyControls
import SwiftUI

/// S9: apps, start time, schedule, strictness.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isPickerPresented = false
    @State private var selection = FamilyActivitySelection()
    @State private var startDate = Date.now
    @State private var scheduleOn = false
    @State private var strictness: Strictness = .standard
    @State private var isConfirmingOff = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        selection = model.selection
                        isPickerPresented = true
                    } label: {
                        HStack {
                            Text("Apps")
                            Spacer()
                            Text("\(model.selectedCount) selected")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    DatePicker("Start time", selection: $startDate, displayedComponents: .hourAndMinute)
                    Toggle("Schedule", isOn: $scheduleOn)
                } header: {
                    Text("Shield")
                } footer: {
                    Text(scheduleFooter)
                }

                Section {
                    Picker("Strictness", selection: $strictness) {
                        ForEach(Strictness.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("The bar")
                } footer: {
                    Text(model.strictness.summary)
                }

                Section("About") {
                    LabeledContent("Privacy", value: "Nothing leaves this phone")
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Settings")
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            .onAppear(perform: syncFromModel)
            .onChange(of: model.isScheduleEnabled) { scheduleOn = model.isScheduleEnabled }
            .onChange(of: selection) {
                if selection != model.selection { model.saveSelection(selection) }
            }
            .onChange(of: startDate) { saveStartTime() }
            .onChange(of: scheduleOn) { scheduleToggled() }
            .onChange(of: strictness) {
                if strictness != model.strictness { model.setStrictness(strictness) }
            }
            .confirmationDialog("Turn the schedule off?", isPresented: $isConfirmingOff, titleVisibility: .visible) {
                Button("Turn off", role: .destructive) {
                    model.setScheduleEnabled(false)
                    scheduleOn = false
                }
                Button("Keep it on", role: .cancel) {}
            } message: {
                Text("The shield clears now and won't come back until you turn the schedule on again.")
            }
            .alert("Can't use that time", isPresented: isShowingError) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } })
    }

    private var scheduleFooter: String {
        if model.isScheduleEnabled {
            let start = model.startTime.date(on: .now)?.formatted(date: .omitted, time: .shortened) ?? ""
            return "Every day from \(start) until you've reflected."
        }
        return "The schedule is off. Nothing is shielded."
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    private func syncFromModel() {
        startDate = model.startTime.date(on: .now) ?? .now
        scheduleOn = model.isScheduleEnabled
        strictness = model.strictness
    }

    private func saveStartTime() {
        let time = TimeOfDay(startDate)
        guard time != model.startTime else { return }
        do {
            try model.saveStartTime(time)
        } catch {
            errorMessage = error.localizedDescription
            startDate = model.startTime.date(on: .now) ?? .now
        }
    }

    /// Turning on is immediate; turning off asks first, so the toggle snaps back until the user confirms.
    private func scheduleToggled() {
        guard scheduleOn != model.isScheduleEnabled else { return }
        if scheduleOn {
            model.setScheduleEnabled(true)
        } else {
            scheduleOn = true
            isConfirmingOff = true
        }
    }
}
