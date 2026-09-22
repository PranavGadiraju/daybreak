import SwiftUI

/// S5: goals, reflection, the live checklist, and the one button that unlocks the day.
struct ReflectView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var hasTriedToSubmit = false
    @State private var errorPulse = 0

    var body: some View {
        @Bindable var model = model
        let verdict = model.verdict(for: model.draft)
        let thresholds = model.rubric.thresholds
        let isDraftEmpty = model.draft.isEmpty

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("\(model.strictness.title) bar · \(thresholds.minGoals) to \(thresholds.maxGoals) goals")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    GoalsEditor(
                        draft: $model.draft,
                        thresholds: thresholds,
                        problemRows: isDraftEmpty ? [] : verdict.problemRows)
                    ReflectionEditor(text: $model.draft.reflection, minWords: thresholds.minReflectionWords)
                    RubricChecklist(
                        verdict: verdict,
                        isDraftEmpty: isDraftEmpty,
                        showFixes: hasTriedToSubmit || !isDraftEmpty)
                    Button(action: submit) {
                        Text("Done reflecting")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(verdict.isApproved ? Color.accentColor : Color.gray)
                    .accessibilityHint(verdict.isApproved ? "Unlocks your apps for today" : "Shows what is still missing")
                }
                .padding(20)
            }
            .navigationTitle("Today's goals")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        model.persistDraft()
                        dismiss()
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.draft) { model.persistDraft() }
            .sensoryFeedback(.error, trigger: errorPulse)
        }
    }

    private func submit() {
        if model.submitReflection() {
            dismiss()
        } else {
            hasTriedToSubmit = true
            errorPulse += 1
        }
    }
}

struct GoalsEditor: View {
    @Binding var draft: ReflectionDraft
    let thresholds: RubricThresholds
    let problemRows: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goals").font(.headline)
            ForEach($draft.goals) { $goal in
                let number = (draft.goals.firstIndex { $0.id == goal.id } ?? 0) + 1
                GoalRow(
                    goal: $goal,
                    number: number,
                    hasProblem: problemRows.contains(number),
                    onRemove: draft.goals.count > thresholds.minGoals ? { remove(goal.id) } : nil)
            }
            if draft.goals.count < thresholds.maxGoals {
                Button {
                    draft.goals.append(GoalLine())
                } label: {
                    Label("Add a goal", systemImage: "plus")
                }
                .font(.subheadline)
            }
        }
    }

    private func remove(_ id: UUID) {
        draft.goals.removeAll { $0.id == id }
    }
}

struct GoalRow: View {
    @Binding var goal: GoalLine
    let number: Int
    let hasProblem: Bool
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
                .padding(.top, 2)
            TextField("Goal \(number)", text: $goal.text)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
                .accessibilityIdentifier("goal-\(number)")
            if hasProblem {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Needs attention")
            } else if !goal.text.trimmingCharacters(in: .whitespaces).isEmpty {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Looks good")
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Remove goal \(number)")
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(hasProblem ? Color.orange.opacity(0.6) : Color.clear))
    }
}

struct ReflectionEditor: View {
    @Binding var text: String
    let minWords: Int

    private var wordCount: Int { TextMetrics.wordCount(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reflection").font(.headline)
            Text("What matters most today, and why? What tends to get in the way?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .accessibilityIdentifier("reflection")
                .frame(minHeight: 150)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            Text("\(wordCount) of \(minWords) words")
                .font(.caption.monospacedDigit())
                .foregroundStyle(wordCount >= minWords ? Color.green : Color.secondary)
        }
    }
}

struct RubricChecklist: View {
    let verdict: RubricVerdict
    let isDraftEmpty: Bool
    let showFixes: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verdict.isApproved && !isDraftEmpty ? "Clears the bar" : "The bar")
                .font(.headline)
            ForEach(verdict.checks) { check in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon(for: check))
                        .foregroundStyle(color(for: check))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.title)
                        if showFixes, !check.passed, let fix = check.fix {
                            Text(fix)
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func icon(for check: RubricCheck) -> String {
        if isDraftEmpty { return "circle" }
        if check.passed { return "checkmark.circle.fill" }
        return showFixes ? "exclamationmark.circle" : "circle"
    }

    private func color(for check: RubricCheck) -> Color {
        if isDraftEmpty { return .secondary }
        if check.passed { return .green }
        return showFixes ? .orange : .secondary
    }
}
