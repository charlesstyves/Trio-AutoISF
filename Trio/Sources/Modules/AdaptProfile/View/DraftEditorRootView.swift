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
                HStack {
                    Text("Copied from")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(state.sourceProfileName)
                        .foregroundColor(.secondary)
                }
                if state.appliedPercent != 100 {
                    HStack {
                        Text("Therapy adjustment")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(state.appliedPercent.formatted(.number.precision(.fractionLength(0)))) %")
                            .foregroundColor(.accentColor)
                    }
                }
            } header: {
                Text("Profile")
            } footer: {
                Text("Blue entries differ from the source profile. Tap any row to review or adjust.")
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
                        summary: basalSummary,
                        changed: state.basalIsChanged
                    )
                }

                NavigationLink {
                    DraftISFEditor(state: state)
                } label: {
                    therapyRow(
                        title: String(localized: "Insulin Sensitivity (ISF)"),
                        summary: isfSummary,
                        changed: state.isfIsChanged
                    )
                }

                NavigationLink {
                    DraftCREditor(state: state)
                } label: {
                    therapyRow(
                        title: String(localized: "Carb Ratio (CR)"),
                        summary: crSummary,
                        changed: state.crIsChanged
                    )
                }

                NavigationLink {
                    DraftTargetEditor(state: state)
                } label: {
                    therapyRow(
                        title: String(localized: "Glucose Targets"),
                        summary: targetSummary,
                        changed: state.targetsAreChanged
                    )
                }
            } header: {
                Text("Therapy")
            }
            .listRowBackground(Color.chart)
        }

        private var algorithmSection: some View {
            Section {
                NavigationLink {
                    DraftAutosensEditor(state: state)
                } label: {
                    algorithmRow(title: String(localized: "Autosens"), summary: autosensSummary, changed: autosensChanged)
                }
                NavigationLink {
                    DraftTargetBehaviorEditor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "Target Behavior"),
                        summary: targetBehaviorSummary,
                        changed: targetBehaviorChanged
                    )
                }
                NavigationLink {
                    DraftSMBEditor(state: state)
                } label: {
                    algorithmRow(title: String(localized: "SMB"), summary: smbSummary, changed: smbChanged)
                }
                NavigationLink {
                    DraftDynamicISFEditor(state: state)
                } label: {
                    algorithmRow(title: String(localized: "Dynamic ISF"), summary: dynISFSummary, changed: dynISFChanged)
                }
                NavigationLink {
                    DraftAutoISFEditor(state: state)
                } label: {
                    algorithmRow(title: String(localized: "autoISF"), summary: autoISFSummary, changed: autoISFChanged)
                }
            } header: {
                Text("Algorithm")
            } footer: {
                Text("Algorithm settings inherit from the source profile.")
            }
            .listRowBackground(Color.chart)
        }

        private func algorithmRow(title: String, summary: String, changed: Bool) -> some View {
            HStack {
                Text(title)
                Spacer()
                Text(summary)
                    .foregroundColor(changed ? .accentColor : .secondary)
                    .font(.callout)
                    .lineLimit(1)
            }
        }

        // MARK: - Algorithm change detection

        private var autosensChanged: Bool {
            state.preferences.autosensMin != state.originalPreferences.autosensMin
                || state.preferences.autosensMax != state.originalPreferences.autosensMax
                || state.preferences.rewindResetsAutosens != state.originalPreferences.rewindResetsAutosens
        }

        private var targetBehaviorChanged: Bool {
            state.preferences.highTemptargetRaisesSensitivity != state.originalPreferences.highTemptargetRaisesSensitivity
                || state.preferences.lowTemptargetLowersSensitivity != state.originalPreferences.lowTemptargetLowersSensitivity
                || state.preferences.sensitivityRaisesTarget != state.originalPreferences.sensitivityRaisesTarget
                || state.preferences.resistanceLowersTarget != state.originalPreferences.resistanceLowersTarget
                || state.preferences.halfBasalExerciseTarget != state.originalPreferences.halfBasalExerciseTarget
        }

        private var smbChanged: Bool {
            let p = state.preferences, o = state.originalPreferences
            return p.enableSMBAlways != o.enableSMBAlways
                || p.enableSMBWithCOB != o.enableSMBWithCOB
                || p.enableSMBWithTemptarget != o.enableSMBWithTemptarget
                || p.enableSMBAfterCarbs != o.enableSMBAfterCarbs
                || p.allowSMBWithHighTemptarget != o.allowSMBWithHighTemptarget
                || p.enableUAM != o.enableUAM
                || p.maxSMBBasalMinutes != o.maxSMBBasalMinutes
                || p.maxUAMSMBBasalMinutes != o.maxUAMSMBBasalMinutes
                || p.smbInterval != o.smbInterval
        }

        private var dynISFChanged: Bool {
            let p = state.preferences, o = state.originalPreferences
            return p.useNewFormula != o.useNewFormula
                || p.sigmoid != o.sigmoid
                || p.adjustmentFactor != o.adjustmentFactor
                || p.adjustmentFactorSigmoid != o.adjustmentFactorSigmoid
                || p.weightPercentage != o.weightPercentage
                || p.tddAdjBasal != o.tddAdjBasal
        }

        private var autoISFChanged: Bool {
            let p = state.preferences, o = state.originalPreferences
            return p.autoisf != o.autoisf
                || p.autoISFmax != o.autoISFmax
                || p.autoISFmin != o.autoISFmin
                || p.smbDeliveryRatio != o.smbDeliveryRatio
                || p.higherISFrangeWeight != o.higherISFrangeWeight
                || p.lowerISFrangeWeight != o.lowerISFrangeWeight
                || p.enableBGacceleration != o.enableBGacceleration
                || p.bgAccelISFweight != o.bgAccelISFweight
                || p.bgBrakeISFweight != o.bgBrakeISFweight
                || p.postMealISFweight != o.postMealISFweight
                || p.iobThresholdPercent != o.iobThresholdPercent
        }

        // MARK: - Algorithm summaries

        private var autosensSummary: String {
            "\(state.preferences.autosensMin.formatted())–\(state.preferences.autosensMax.formatted())"
        }

        private var targetBehaviorSummary: String {
            var flags: [String] = []
            if state.preferences.highTemptargetRaisesSensitivity { flags.append("HighTT↑") }
            if state.preferences.lowTemptargetLowersSensitivity { flags.append("LowTT↓") }
            if state.preferences.sensitivityRaisesTarget { flags.append("Sens↑T") }
            if state.preferences.resistanceLowersTarget { flags.append("Res↓T") }
            return flags.isEmpty ? String(localized: "Off") : flags.joined(separator: " ")
        }

        private var smbSummary: String {
            var parts: [String] = []
            if state.preferences.enableSMBAlways { parts.append("Always") }
            if state.preferences.enableUAM { parts.append("UAM") }
            if parts.isEmpty { parts.append(String(localized: "Off")) }
            return parts.joined(separator: " · ")
        }

        private var dynISFSummary: String {
            if !state.preferences.useNewFormula { return String(localized: "Off") }
            return state.preferences.sigmoid ? String(localized: "Sigmoid") : String(localized: "Logarithmic")
        }

        private var autoISFSummary: String {
            state.preferences.autoisf ? String(localized: "On") : String(localized: "Off")
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

        private func therapyRow(title: String, summary: String, changed: Bool) -> some View {
            HStack {
                Text(title)
                Spacer()
                Text(summary)
                    .foregroundColor(changed ? .accentColor : .secondary)
                    .font(.callout)
                    .lineLimit(1)
            }
        }

        // MARK: - Summaries

        private var basalSummary: String {
            guard !state.basalItems.isEmpty else { return String(localized: "None") }
            let total = state.basalItems.enumerated().reduce(Decimal(0)) { running, pair in
                let (idx, item) = pair
                let nextTime = idx + 1 < state.basalItems.count ? state.basalItems[idx + 1].time : 86400
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
