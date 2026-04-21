import SwiftUI

extension AdaptProfile {
    /// Draft editor hub shown after the user confirms the percentage-adjustment form.
    /// Pre-populated with: therapy = % adjusted + rounded, algorithm = current active profile.
    /// User can accept everything as-is ("Save") or drill into any section to tweak first.
    struct DraftEditorRootView: View {
        @Bindable var state: DraftEditorStateModel
        let onCancel: () -> Void
        let onSaved: () -> Void

        @State private var isSaving = false
        @State private var saveError = false

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        private let rateFormatter: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = 2
            f.maximumFractionDigits = 3
            return f
        }()

        var body: some View {
            List {
                nameSection
                therapySection
                algorithmSection
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

        // MARK: - Sections

        private var nameSection: some View {
            Section {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Profile name", text: $state.name)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                }
            } header: {
                Text("Name")
            } footer: {
                if state.appliedPercent != 100 {
                    Text(
                        "Therapy values have been scaled by \(state.appliedPercent.formatted(.number.precision(.fractionLength(0)))) % and rounded to picker steps. Tap any row to review or adjust."
                    )
                } else {
                    Text("Therapy and algorithm values inherit from the currently active profile. Tap any row to review or adjust.")
                }
            }
            .listRowBackground(Color.chart)
        }

        private var therapySection: some View {
            Section {
                NavigationLink {
                    DraftBasalEditor(state: state)
                } label: {
                    therapyRow(
                        title: String(localized: "Basal Rates"),
                        summary: basalSummary
                    )
                }

                NavigationLink {
                    DraftISFEditor(state: state)
                } label: {
                    therapyRow(
                        title: String(localized: "Insulin Sensitivity (ISF)"),
                        summary: isfSummary
                    )
                }

                NavigationLink {
                    DraftCREditor(state: state)
                } label: {
                    therapyRow(
                        title: String(localized: "Carb Ratio (CR)"),
                        summary: crSummary
                    )
                }

                NavigationLink {
                    DraftTargetEditor(state: state)
                } label: {
                    therapyRow(
                        title: String(localized: "Glucose Targets"),
                        summary: targetSummary
                    )
                }
            } header: {
                Text("Therapy")
            }
            .listRowBackground(Color.chart)
        }

        private var algorithmSection: some View {
            Section {
                Text("Coming in the next step. For now, algorithm settings inherit unchanged from the currently active profile.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } header: {
                Text("Algorithm")
            }
            .listRowBackground(Color.chart)
        }

        private var saveSection: some View {
            Section {
                Button {
                    Task { await save() }
                } label: {
                    Text("Save Profile")
                }
                .disabled(!canSave || isSaving)
                .frame(maxWidth: .infinity, alignment: .center)
                .tint(.white)
            }
            .listRowBackground(!canSave || isSaving ? Color(.systemGray4) : Color(.systemBlue))
        }

        private func therapyRow(title: String, summary: String) -> some View {
            HStack {
                Text(title)
                Spacer()
                Text(summary)
                    .foregroundColor(.secondary)
                    .font(.callout)
                    .lineLimit(1)
            }
        }

        // MARK: - Summaries

        private var basalSummary: String {
            guard !state.basalItems.isEmpty else { return String(localized: "None") }
            let total = state.basalItems.enumerated().reduce(Decimal(0)) { running, pair in
                let (idx, item) = pair
                let nextTime = idx + 1 < state.basalItems.count ? state.basalItems[idx + 1].time : 86_400
                let hours = Decimal((nextTime - item.time) / 3600)
                return running + item.value * hours
            }
            let totalStr = rateFormatter.string(from: total as NSDecimalNumber) ?? "\(total)"
            return "\(state.basalItems.count) · \(totalStr) U/day"
        }

        private var isfSummary: String {
            guard !state.isfItems.isEmpty else { return String(localized: "None") }
            return "\(state.isfItems.count) entries"
        }

        private var crSummary: String {
            guard !state.crItems.isEmpty else { return String(localized: "None") }
            return "\(state.crItems.count) entries"
        }

        private var targetSummary: String {
            guard !state.targetItems.isEmpty else { return String(localized: "None") }
            return "\(state.targetItems.count) entries"
        }

        private var canSave: Bool {
            !state.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !state.basalItems.isEmpty
                && !state.isfItems.isEmpty
                && !state.crItems.isEmpty
                && !state.targetItems.isEmpty
        }

        @MainActor private func save() async {
            isSaving = true
            let ok = await state.save()
            isSaving = false
            if ok {
                onSaved()
            } else {
                saveError = true
            }
        }
    }
}
