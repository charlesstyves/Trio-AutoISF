import SwiftUI

extension AdaptProfile {
    /// Draft editor hub shown after the user confirms the percentage-adjustment form.
    /// Pre-populated with: therapy = % adjusted + rounded, algorithm = current active profile.
    /// User can accept everything as-is ("Save") or drill into any section to tweak first.
    struct DraftEditorRootView: View {
        @Bindable var state: DraftEditorStateModel
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
            .navigationTitle(state.isEditing ? "Edit Profile" : "Add Profile")
            .navigationBarTitleDisplayMode(.inline)
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
                        title: String(localized: "Insulin Sensitivities"),
                        summary: isfSummary,
                        changed: state.isfIsChanged
                    )
                }

                NavigationLink {
                    DraftCREditor(state: state)
                } label: {
                    therapyRow(
                        title: String(localized: "Carb Ratios"),
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
            // Order and page names mirror Algorithm settings (see SettingItems.algorithmItems).
            Section {
                NavigationLink {
                    DraftAutosensEditor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "Autosens"),
                        changed: autosensChanged,
                        onReset: resetAutosens
                    )
                }
                NavigationLink {
                    DraftSMBEditor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "Super Micro Bolus (SMB)"),
                        changed: smbChanged,
                        onReset: resetSMB
                    )
                }
                NavigationLink {
                    DraftDynamicISFEditor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "Dynamic Settings"),
                        changed: dynISFChanged,
                        onReset: resetDynISF
                    )
                }
                NavigationLink {
                    DraftTargetBehaviorEditor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "Target Behavior"),
                        changed: targetBehaviorChanged,
                        onReset: resetTargetBehavior
                    )
                }
                NavigationLink {
                    DraftAdvancedEditor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "Additionals"),
                        changed: advancedChanged,
                        onReset: resetAdvanced
                    )
                }
                NavigationLink {
                    DraftAutoISFEditor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "autoISF"),
                        changed: autoISFChanged,
                        onReset: resetAutoISF
                    )
                }
                NavigationLink {
                    DraftB30Editor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "AIMI B30"),
                        changed: b30Changed,
                        onReset: resetB30
                    )
                }
                NavigationLink {
                    DraftKetoProtectEditor(state: state)
                } label: {
                    algorithmRow(
                        title: String(localized: "Keto Protection"),
                        changed: ketoChanged,
                        onReset: resetKeto
                    )
                }
            } header: {
                Text("Algorithm")
            } footer: {
                Text("Blue rows differ from the source profile. Tap the reset icon to discard a section's changes.")
            }
            .listRowBackground(Color.chart)
        }

        private func algorithmRow(title: String, changed: Bool, onReset: @escaping () -> Void) -> some View {
            HStack {
                Text(title)
                    .foregroundColor(changed ? .accentColor : .primary)
                Spacer()
                if changed {
                    Button(action: onReset) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
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

        private var advancedChanged: Bool {
            let p = state.preferences, o = state.originalPreferences
            return p.useProfileCSF != o.useProfileCSF
                || p.maxDailySafetyMultiplier != o.maxDailySafetyMultiplier
                || p.currentBasalSafetyMultiplier != o.currentBasalSafetyMultiplier
                || p.skipNeutralTemps != o.skipNeutralTemps
                || p.unsuspendIfNoTemp != o.unsuspendIfNoTemp
                || p.min5mCarbimpact != o.min5mCarbimpact
                || p.remainingCarbsFraction != o.remainingCarbsFraction
                || p.remainingCarbsCap != o.remainingCarbsCap
                || p.noisyCGMTargetMultiplier != o.noisyCGMTargetMultiplier
        }

        private var b30Changed: Bool {
            let p = state.preferences, o = state.originalPreferences
            return p.enableB30 != o.enableB30
                || p.B30iTimeStartBolus != o.B30iTimeStartBolus
                || p.B30iTime != o.B30iTime
                || p.B30iTimeTarget != o.B30iTimeTarget
                || p.B30upperLimit != o.B30upperLimit
                || p.B30upperDelta != o.B30upperDelta
                || p.B30basalFactor != o.B30basalFactor
        }

        private var ketoChanged: Bool {
            let p = state.preferences, o = state.originalPreferences
            return p.ketoProtect != o.ketoProtect
                || p.variableKetoProtect != o.variableKetoProtect
                || p.ketoProtectBasalPercent != o.ketoProtectBasalPercent
                || p.ketoProtectAbsolut != o.ketoProtectAbsolut
                || p.ketoProtectBasalAbsolut != o.ketoProtectBasalAbsolut
        }

        // MARK: - Per-section reset helpers

        private func resetAutosens() {
            state.resetField(\.autosensMin)
            state.resetField(\.autosensMax)
            state.resetField(\.rewindResetsAutosens)
        }

        private func resetTargetBehavior() {
            state.resetField(\.highTemptargetRaisesSensitivity)
            state.resetField(\.lowTemptargetLowersSensitivity)
            state.resetField(\.sensitivityRaisesTarget)
            state.resetField(\.resistanceLowersTarget)
            state.resetField(\.halfBasalExerciseTarget)
        }

        private func resetSMB() {
            state.resetField(\.enableSMBAlways)
            state.resetField(\.enableSMBWithCOB)
            state.resetField(\.enableSMBWithTemptarget)
            state.resetField(\.enableSMBAfterCarbs)
            state.resetField(\.enableSMB_high_bg)
            state.resetField(\.enableSMB_high_bg_target)
            state.resetField(\.allowSMBWithHighTemptarget)
            state.resetField(\.enableUAM)
            state.resetField(\.maxSMBBasalMinutes)
            state.resetField(\.maxUAMSMBBasalMinutes)
            state.resetField(\.smbInterval)
        }

        private func resetDynISF() {
            state.resetField(\.useNewFormula)
            state.resetField(\.sigmoid)
            state.resetField(\.adjustmentFactor)
            state.resetField(\.adjustmentFactorSigmoid)
            state.resetField(\.weightPercentage)
            state.resetField(\.tddAdjBasal)
        }

        private func resetAutoISF() {
            state.resetField(\.autoisf)
            state.resetField(\.autoISFmax)
            state.resetField(\.autoISFmin)
            state.resetField(\.smbDeliveryRatio)
            state.resetField(\.higherISFrangeWeight)
            state.resetField(\.lowerISFrangeWeight)
            state.resetField(\.enableBGacceleration)
            state.resetField(\.bgAccelISFweight)
            state.resetField(\.bgBrakeISFweight)
            state.resetField(\.postMealISFweight)
            state.resetField(\.iobThresholdPercent)
        }

        private func resetAdvanced() {
            state.resetField(\.useProfileCSF)
            state.resetField(\.maxDailySafetyMultiplier)
            state.resetField(\.currentBasalSafetyMultiplier)
            state.resetField(\.skipNeutralTemps)
            state.resetField(\.unsuspendIfNoTemp)
            state.resetField(\.min5mCarbimpact)
            state.resetField(\.remainingCarbsFraction)
            state.resetField(\.remainingCarbsCap)
            state.resetField(\.noisyCGMTargetMultiplier)
        }

        private func resetB30() {
            state.resetField(\.enableB30)
            state.resetField(\.B30iTimeStartBolus)
            state.resetField(\.B30iTime)
            state.resetField(\.B30iTimeTarget)
            state.resetField(\.B30upperLimit)
            state.resetField(\.B30upperDelta)
            state.resetField(\.B30basalFactor)
        }

        private func resetKeto() {
            state.resetField(\.ketoProtect)
            state.resetField(\.variableKetoProtect)
            state.resetField(\.ketoProtectBasalPercent)
            state.resetField(\.ketoProtectAbsolut)
            state.resetField(\.ketoProtectBasalAbsolut)
        }

        private var saveSection: some View {
            Section {
                Button {
                    Task { await save() }
                } label: {
                    Text(state.isEditing ? "Save Changes" : "Save Profile")
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
