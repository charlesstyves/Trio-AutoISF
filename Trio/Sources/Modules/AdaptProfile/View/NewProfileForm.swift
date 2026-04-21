import SwiftUI

extension AdaptProfile {
    /// Single-step new-profile creation: name + therapy percentage. On Save the draft is applied
    /// (basal floored to pump-supported rates, ISF and CR quantized to their picker step sizes)
    /// and persisted as a non-active profile. Styling mirrors `AddTempTargetForm`.
    struct NewProfileForm: View {
        @Bindable var state: StateModel
        let onCancel: () -> Void
        let onSaved: () -> Void

        @State private var isSaving = false
        @State private var saveError = false
        @State private var shouldDisplayHint: Bool = false
        @State private var hintDetent = PresentationDetent.large
        @State private var selectedVerboseHint: (any View)?
        @State private var hintLabel: String?
        @State private var booleanPlaceholder = false

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState
        @Environment(\.dismiss) var dismiss

        var body: some View {
            NavigationView {
                List {
                    nameSection
                    percentSection
                    saveSection
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
                .alert("Save failed", isPresented: $saveError) {
                    Button("OK") { saveError = false }
                } message: {
                    Text("The profile couldn't be saved. Check the name and try again.")
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

        private var saveSection: some View {
            Section {
                Button {
                    Task { await save() }
                } label: {
                    Text("Add Profile")
                }
                .disabled(!canProceed || isSaving)
                .frame(maxWidth: .infinity, alignment: .center)
                .tint(.white)
            }
            .listRowBackground(!canProceed || isSaving ? Color(.systemGray4) : Color(.systemBlue))
        }

        private var canProceed: Bool {
            !state.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        @MainActor private func save() async {
            isSaving = true
            state.applyPercentagesToDraft()
            let ok = await state.saveDraft()
            isSaving = false
            if ok {
                onSaved()
            } else {
                saveError = true
            }
        }
    }
}
