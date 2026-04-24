import SwiftUI

extension AdaptProfile {
    /// Step 1 of new-profile creation: name + therapy percentage.
    ///
    /// On "Next" the percentage is applied (basal floored to pump-supported rates, ISF and CR
    /// quantized to picker steps) and the parent transitions to the draft editor hub. Saving
    /// happens from the hub, not here.
    struct AddProfileForm: View {
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
            .sheet(isPresented: $shouldDisplayHint) {
                SettingInputHintView(
                    hintDetent: $hintDetent,
                    shouldDisplayHint: $shouldDisplayHint,
                    hintLabel: hintLabel ?? "",
                    hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                    sheetTitle: String(localized: "Help", comment: "Help sheet title")
                )
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
                        hintLabel = String(
                            localized: "Adjust current Therapy Setting",
                            comment: "Hint mini-label shown when tapping info on the therapy-adjustment percentage row of Add Profile form"
                        )
                    }
                ),
                units: .mgdL,
                type: .decimal("therapyAdjustment"),
                label: String(
                    localized: "Adjust current Therapy Settings",
                    comment: "Row label on Add Profile form for the percentage that rescales Basal/ISF/CR"
                ),
                miniHint: String(
                    localized: "Values >100% = less sensitive, more insulin nedded, Basal Rates profile is lifted, ISF and CR profiles decrease. 100% preserves current Therapy Settings.",
                    comment: "Mini-hint beneath the therapy-adjustment percentage row on Add Profile form"
                ),
                verboseHint:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Default: 100 %").bold()
                    Text(
                        "This percentage rescales the three therapy profiles — Basal Rate, Insulin Sensitivity (ISF) and Carb Ratio (CR) — in one step. It's the same mechanism an override uses, baked into the profile so every loop cycle sees the adjusted values."
                    )
                    Text(
                        "Keep at 100 % if you want the new profile to share the active profile's therapy values and only differ in algorithm toggles or BG targets."
                    )
                    Text(
                        ">100 % = more insulin overall (less sensitive). Basal rises, ISF drops, CR drops."
                    )
                    Text(
                        "<100 % = less insulin (more sensitive). Basal drops, ISF rises, CR rises."
                    )
                    Text(
                        "Adjusted basal rates are rounded down to the nearest pump-supported rate. ISF is rounded to 1 mg/dL steps, CR to 0.1 g/U. You can fine-tune each value manually in the editor after tapping Next."
                    )
                },
                headerText: String(
                    localized: "Therapy Adjustment",
                    comment: "Section header for the therapy-adjustment percentage on Add Profile form"
                )
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
