import SwiftUI

extension AdaptProfile {
    /// Step 2 of new-profile creation: review adjusted therapy values. Basal rates are shown with
    /// the pump-rounded target; the user can still tweak each rate to any pump-supported value.
    /// ISF / CR / targets are display-only here (they don't need rounding).
    struct BasalReviewView: View {
        @Bindable var state: StateModel
        let onBack: () -> Void
        let onSaved: () -> Void

        @State private var isSaving = false
        @State private var saveError = false

        private let rateFormatter: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 3
            return f
        }()

        var body: some View {
            Form {
                basalSection
                isfSection
                crSection
            }
            .navigationTitle("Review profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back", action: onBack)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Save failed", isPresented: $saveError) {
                Button("OK") { saveError = false }
            } message: {
                Text("The profile couldn't be saved. Check the name and try again.")
            }
        }

        private var basalSection: some View {
            Section {
                if state.draft.basalItems.isEmpty {
                    Text("No basal entries.").foregroundColor(.secondary)
                } else {
                    ForEach(state.draft.basalItems.indices, id: \.self) { idx in
                        basalRow(idx: idx)
                    }
                }
            } header: {
                HStack {
                    Text("Basal rates")
                    Spacer()
                    Text("\(state.draft.basalPercent.formatted()) %")
                        .foregroundColor(.secondary)
                }
            } footer: {
                if state.draft.hasRoundingAdjustments {
                    Text("Some rates were rounded down to a pump-supported value.")
                        .foregroundColor(.orange)
                } else if state.draft.basalPercent != 100 {
                    Text("All adjusted rates map cleanly onto pump-supported values.")
                }
            }
        }

        private func basalRow(idx: Int) -> some View {
            let item = state.draft.basalItems[idx]
            return VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.timeLabel)
                        .font(.body.monospacedDigit())
                    Spacer()
                    Text("\(formatted(item.originalRate)) U/hr")
                        .foregroundColor(.secondary)
                        .strikethrough(item.originalRate != item.selectedRate)
                }
                HStack {
                    Text("Adjusted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if item.selectedRate != item.adjustedRate {
                        Text("\(formatted(item.adjustedRate)) →")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Picker(
                        "",
                        selection: Binding(
                            get: { state.draft.basalItems[idx].selectedRate },
                            set: { state.draft.basalItems[idx].selectedRate = $0 }
                        )
                    ) {
                        ForEach(state.draft.supportedRates, id: \.self) { rate in
                            Text("\(formatted(rate)) U/hr").tag(rate)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }
        }

        private var isfSection: some View {
            Section {
                ForEach(Array(zip(
                    state.draft.originalSensitivities.sensitivities.indices,
                    state.draft.originalSensitivities.sensitivities
                )), id: \.0) { idx, original in
                    let adjusted = state.draft.adjustedSensitivities.sensitivities[safe: idx]
                    HStack {
                        Text(original.start)
                            .font(.body.monospacedDigit())
                        Spacer()
                        Text("\(formatted(original.sensitivity)) → \(formatted(adjusted?.sensitivity ?? original.sensitivity))")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                HStack {
                    Text("Insulin Sensitivity (ISF)")
                    Spacer()
                    Text("\(state.draft.isfPercent.formatted()) %")
                        .foregroundColor(.secondary)
                }
            }
        }

        private var crSection: some View {
            Section {
                ForEach(Array(zip(
                    state.draft.originalCarbRatios.schedule.indices,
                    state.draft.originalCarbRatios.schedule
                )), id: \.0) { idx, original in
                    let adjusted = state.draft.adjustedCarbRatios.schedule[safe: idx]
                    HStack {
                        Text(original.start)
                            .font(.body.monospacedDigit())
                        Spacer()
                        Text("\(formatted(original.ratio)) → \(formatted(adjusted?.ratio ?? original.ratio)) g/U")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                HStack {
                    Text("Carb Ratio (CR)")
                    Spacer()
                    Text("\(state.draft.crPercent.formatted()) %")
                        .foregroundColor(.secondary)
                }
            }
        }

        private func formatted(_ value: Decimal) -> String {
            rateFormatter.string(from: value as NSDecimalNumber) ?? "\(value)"
        }

        @MainActor
        private func save() async {
            isSaving = true
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
