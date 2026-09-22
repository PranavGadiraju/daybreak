import FamilyControls
import SwiftUI

/// S2: the system picker. Daybreak only ever sees opaque tokens, so the count is all it can show.
struct PickAppsView: View {
    @Environment(AppModel.self) private var model
    let onContinue: () -> Void
    @State private var selection = FamilyActivitySelection()

    private var count: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private var canContinue: Bool {
        #if targetEnvironment(simulator)
        true // The Simulator's picker lists few or no apps; let the flow continue so the UI can be exercised.
        #else
        count > 0
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            FamilyActivityPicker(selection: $selection)
            VStack(spacing: 10) {
                Text(count == 0 ? "Pick at least one app, category, or website." : "Categories and websites count too.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    model.saveSelection(selection)
                    onContinue()
                } label: {
                    Text(count == 0 ? "Continue" : "Continue · \(count) selected")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canContinue)
            }
            .padding(20)
            .background(.bar)
        }
        .navigationTitle("Choose apps")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { selection = model.selection }
    }
}
