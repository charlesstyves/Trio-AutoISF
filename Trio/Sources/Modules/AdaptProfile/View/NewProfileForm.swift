import SwiftUI

extension AdaptProfile {
    /// Step 1 of new-profile creation: name + therapy percentage adjustments.
    /// On "Review", populates the draft's adjusted values and navigates to the basal review.
    struct NewProfileForm: View {
        @Bindable var state: StateModel
        let onCancel: () -> Void
        let onReview: () -> Void

        var body: some View {
            Form {
                Section {
                    TextField("Profile name", text: $state.draft.name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    Text("A new snapshot of the currently active profile will be created.")
                }

                Section {
                    percentStepper(title: "Insulin Sensitivity (ISF)", value: $state.draft.isfPercent)
                    percentStepper(title: "Basal Rate", value: $state.draft.basalPercent)
                    percentStepper(title: "Carb Ratio (CR)", value: $state.draft.crPercent)
                } header: {
                    Text("Therapy percentage")
                } footer: {
                    Text("100% keeps the current value. Higher percentage = more aggressive (more insulin).")
                }
            }
            .navigationTitle("New profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Review", action: onReview)
                        .disabled(!canProceed)
                }
            }
        }

        private var canProceed: Bool {
            !state.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        private func percentStepper(title: String, value: Binding<Decimal>) -> some View {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue.formatted(.number.precision(.fractionLength(0)))) %")
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                Stepper("", value: value, in: 50 ... 200, step: 5)
                    .labelsHidden()
            }
        }
    }
}
