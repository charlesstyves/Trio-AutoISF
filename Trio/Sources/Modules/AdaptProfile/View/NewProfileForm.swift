import SwiftUI

extension AdaptProfile {
    /// Step 1 of new-profile creation: name + therapy percentage.
    ///
    /// On "Next" the percentage is applied (basal floored to pump-supported rates, ISF and CR
    /// quantized to picker steps) and the parent transitions to the draft editor hub. Saving
    /// happens from the hub, not here.
    struct NewProfileForm: View {
        @Bindable var state: StateModel
        let onCancel: () -> Void
        let onNext: () -> Void

        @State private var shouldDisplayHint: Bool = false
        @State private var hintDetent = PresentationDetent.large
        @State private var selectedVerboseHint: AnyView?
        @State private var hintLabel: String?
        @State private var booleanPlaceholder = false

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                nameSection
                percentSection
                nextSection
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Add Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }

        private var nameSection: some View {
            Section {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Profile name", text: $state.draft.name)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                }
            }
            .listRowBackground(Color.chart)
        }

        private var percentSection: some View {
            SettingInputSection(
                decimalValue: $state.draft.adjustPercent,
                booleanValue: $booleanPlaceholder,
                shouldDisplayHint: $shouldDisplayHint,
                selectedVerboseHint: Binding(
                    get: { selectedVerboseHint },
                    set: {
                        selectedVerboseHint = $0.map { AnyView($0) }
                        hintLabel = String(localized: "Adjust Therapy")
                    }
                ),
                units: .mgdL,
                type: .decimal("therapyAdjustment"),
                label: String(localized: "Adjust Therapy"),
                miniHint: String(
                    localized: "100 % keeps current values. Higher % = more insulin: basal goes up, ISF and CR go down."
                ),
                verboseHint:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Default: 100 %").bold()
                    Text(
                        "A single percentage adjusts all therapy values proportionally, the same way an override does."
                    )
                    Text("• Basal rate scales up with the percentage (× p / 100).")
                    Text("• Insulin Sensitivity (ISF) scales down (× 100 / p) — the algorithm will deliver more insulin.")
                    Text("• Carb Ratio (CR) scales down (× 100 / p) — more insulin per carb.")
                    Text(
                        "Adjusted basal rates are rounded down to the nearest pump-supported rate. ISF is rounded to 1 mg/dL steps, CR to 0.1 g/U."
                    )
                },
                headerText: String(localized: "Therapy Adjustment")
            )
        }

        private var nextSection: some View {
            Section {
                Button {
                    state.applyPercentagesToDraft()
                    onNext()
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(!canProceed)
                .frame(maxWidth: .infinity, alignment: .center)
                .tint(.white)
            } footer: {
                Text("Review the pre-filled therapy and algorithm values on the next screen, then save.")
            }
            .listRowBackground(!canProceed ? Color(.systemGray4) : Color(.systemBlue))
        }

        private var canProceed: Bool {
            !state.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
