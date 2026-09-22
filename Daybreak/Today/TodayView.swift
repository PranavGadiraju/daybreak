import SwiftUI

/// S4 / S6: one status card, one primary action, and today's goals once they exist.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var isReflecting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    PhaseCard(phase: model.phase, selectedCount: model.selectedCount, approvedAt: model.todayEntry?.approvedAt)
                    primaryAction
                    if let entry = model.todayEntry {
                        GoalsCard(title: "Today's goals", goals: entry.goals)
                    } else if let last = model.journal.entries.first {
                        LastEntryCard(entry: last)
                    }
                    if model.streak > 0 {
                        Text("Streak · \(model.streak) \(model.streak == 1 ? "day" : "days")")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                    }
                    SimulatorNote(gateway: model.gateway)
                }
                .padding(20)
            }
            .navigationTitle("Today")
            .fullScreenCover(isPresented: $isReflecting) { ReflectView() }
            .task { await keepFresh() }
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch model.phase {
        case .shielded:
            Button {
                isReflecting = true
            } label: {
                Label("Write today's goals", systemImage: "pencil.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .beforeStart:
            Button {
                isReflecting = true
            } label: {
                Text("Reflect early")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        case .cleared:
            EmptyView()
        case .off:
            Text("Turn the schedule on in Settings to start shielding.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    /// Re-evaluate the phase while the screen is visible so the card flips at the start time without a relaunch.
    private func keepFresh() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            model.refresh()
        }
    }
}

struct PhaseCard: View {
    let phase: ShieldPhase
    let selectedCount: Int
    let approvedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(headline)
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.35)))
        .accessibilityElement(children: .combine)
    }

    private var tint: Color {
        switch phase {
        case .off: .gray
        case .beforeStart: .blue
        case .shielded: .indigo
        case .cleared: .green
        }
    }

    private var eyebrow: String {
        switch phase {
        case .off:
            "Schedule off"
        case .beforeStart(let startsAt):
            "Shield starts at \(startsAt.formatted(date: .omitted, time: .shortened))"
        case .shielded(let since):
            "Shielded since \(since.formatted(date: .omitted, time: .shortened))"
        case .cleared:
            approvedAt.map { "Approved \($0.formatted(date: .omitted, time: .shortened))" } ?? "Cleared for today"
        }
    }

    private var headline: String {
        switch phase {
        case .off:
            "Nothing is shielded"
        case .beforeStart(let startsAt):
            "Starts \(startsAt.formatted(.relative(presentation: .numeric)))"
        case .shielded:
            selectedCount == 1 ? "1 app is waiting on you" : "\(selectedCount) apps are waiting on you"
        case .cleared:
            "Unlocked for today"
        }
    }

    private var detail: String {
        switch phase {
        case .off:
            "Turn the schedule on in Settings to shield \(appsPhrase(selectedCount)) each morning."
        case .beforeStart:
            "\(appsPhrase(selectedCount)) will be shielded until you've written today's goals."
        case .shielded:
            "Write today's goals to unlock them for the day."
        case .cleared(let resumesAt):
            "The shield returns \(resumesAt.formatted(.relative(presentation: .named))) at \(resumesAt.formatted(date: .omitted, time: .shortened))."
        }
    }
}

struct GoalsCard: View {
    let title: String
    let goals: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            ForEach(Array(goals.enumerated()), id: \.offset) { index, goal in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 16, alignment: .trailing)
                    Text(goal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LastEntryCard: View {
    let entry: ReflectionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last time").font(.headline)
            Text("\(entry.approvedAt, format: .dateTime.weekday(.wide).day().month()) · \(entry.goals.count) goals · \(TextMetrics.wordCount(entry.reflection)) words")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Only appears in the Simulator, where the mock gateway stands in for Screen Time.
struct SimulatorNote: View {
    let gateway: any ScreenTimeGateway

    var body: some View {
        if let mock = gateway as? MockScreenTimeGateway {
            Label(
                mock.isShieldActive
                    ? "Simulator: the shield would be on right now."
                    : "Simulator: nothing is really shielded. Run on a device for the real gate.",
                systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
