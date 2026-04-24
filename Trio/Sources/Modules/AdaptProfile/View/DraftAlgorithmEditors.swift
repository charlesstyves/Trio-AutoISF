import SwiftUI

extension AdaptProfile {
    // MARK: - Autosens

    struct DraftAutosensEditor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var shouldDisplayHint = false
        @State private var hintLabel: String?
        @State private var selectedVerboseHint: AnyView?
        @State private var hintDetent = PresentationDetent.large

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: $state.preferences.autosensMax,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.autosensMaxLabel),
                    units: state.units,
                    type: .decimal("autosensMax"),
                    label: AlgorithmSettingHints.autosensMaxLabel,
                    miniHint: AlgorithmSettingHints.autosensMaxMini,
                    verboseHint: AlgorithmSettingHints.autosensMaxVerbose(),
                    isChanged: state.isChanged(\.autosensMax),
                    onReset: { state.resetField(\.autosensMax) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.autosensMin,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.autosensMinLabel),
                    units: state.units,
                    type: .decimal("autosensMin"),
                    label: AlgorithmSettingHints.autosensMinLabel,
                    miniHint: AlgorithmSettingHints.autosensMinMini,
                    verboseHint: AlgorithmSettingHints.autosensMinVerbose(),
                    isChanged: state.isChanged(\.autosensMin),
                    onReset: { state.resetField(\.autosensMin) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.rewindResetsAutosens,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.rewindResetsAutosensLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.rewindResetsAutosensLabel,
                    miniHint: AlgorithmSettingHints.rewindResetsAutosensMini,
                    verboseHint: AlgorithmSettingHints.rewindResetsAutosensVerbose(),
                    isChanged: state.isChanged(\.rewindResetsAutosens),
                    onReset: { state.resetField(\.rewindResetsAutosens) }
                )
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Autosens")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $shouldDisplayHint) { hintSheet }
        }

        private var hintSheet: some View {
            SettingInputHintView(
                hintDetent: $hintDetent,
                shouldDisplayHint: $shouldDisplayHint,
                hintLabel: hintLabel ?? "",
                hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                sheetTitle: String(localized: "Help")
            )
        }

        private func verboseHintBinding(_ label: String) -> Binding<(any View)?> {
            Binding(
                get: { selectedVerboseHint },
                set: { newValue in
                    selectedVerboseHint = newValue.map { AnyView($0) }
                    hintLabel = label
                }
            )
        }
    }

    // MARK: - Target Behavior

    struct DraftTargetBehaviorEditor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var shouldDisplayHint = false
        @State private var hintLabel: String?
        @State private var selectedVerboseHint: AnyView?
        @State private var hintDetent = PresentationDetent.large

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.highTemptargetRaisesSensitivity,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.highTempTargetRaisesSensitivityLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.highTempTargetRaisesSensitivityLabel,
                    miniHint: AlgorithmSettingHints.highTempTargetRaisesSensitivityMini(units: state.units),
                    verboseHint: AlgorithmSettingHints.highTempTargetRaisesSensitivityVerbose(units: state.units),
                    isChanged: state.isChanged(\.highTemptargetRaisesSensitivity),
                    onReset: { state.resetField(\.highTemptargetRaisesSensitivity) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.lowTemptargetLowersSensitivity,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.lowTempTargetLowersSensitivityLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.lowTempTargetLowersSensitivityLabel,
                    miniHint: AlgorithmSettingHints.lowTempTargetLowersSensitivityMini(units: state.units),
                    verboseHint: AlgorithmSettingHints.lowTempTargetLowersSensitivityVerbose(units: state.units),
                    isChanged: state.isChanged(\.lowTemptargetLowersSensitivity),
                    onReset: { state.resetField(\.lowTemptargetLowersSensitivity) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.sensitivityRaisesTarget,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.sensitivityRaisesTargetLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.sensitivityRaisesTargetLabel,
                    miniHint: AlgorithmSettingHints.sensitivityRaisesTargetMini,
                    verboseHint: AlgorithmSettingHints.sensitivityRaisesTargetVerbose(),
                    isChanged: state.isChanged(\.sensitivityRaisesTarget),
                    onReset: { state.resetField(\.sensitivityRaisesTarget) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.resistanceLowersTarget,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.resistanceLowersTargetLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.resistanceLowersTargetLabel,
                    miniHint: AlgorithmSettingHints.resistanceLowersTargetMini,
                    verboseHint: AlgorithmSettingHints.resistanceLowersTargetVerbose(),
                    isChanged: state.isChanged(\.resistanceLowersTarget),
                    onReset: { state.resetField(\.resistanceLowersTarget) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.halfBasalExerciseTarget,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.halfBasalExerciseTargetLabel),
                    units: state.units,
                    type: .decimal("halfBasalExerciseTarget"),
                    label: AlgorithmSettingHints.halfBasalExerciseTargetLabel,
                    miniHint: AlgorithmSettingHints.halfBasalExerciseTargetMini,
                    verboseHint: AlgorithmSettingHints.halfBasalExerciseTargetVerbose(units: state.units),
                    isChanged: state.isChanged(\.halfBasalExerciseTarget),
                    onReset: { state.resetField(\.halfBasalExerciseTarget) }
                )
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Target Behavior")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $shouldDisplayHint) { hintSheet }
        }

        private var hintSheet: some View {
            SettingInputHintView(
                hintDetent: $hintDetent,
                shouldDisplayHint: $shouldDisplayHint,
                hintLabel: hintLabel ?? "",
                hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                sheetTitle: String(localized: "Help")
            )
        }

        private func verboseHintBinding(_ label: String) -> Binding<(any View)?> {
            Binding(
                get: { selectedVerboseHint },
                set: { newValue in
                    selectedVerboseHint = newValue.map { AnyView($0) }
                    hintLabel = label
                }
            )
        }
    }

    // MARK: - SMB

    struct DraftSMBEditor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var shouldDisplayHint = false
        @State private var hintLabel: String?
        @State private var selectedVerboseHint: AnyView?
        @State private var hintDetent = PresentationDetent.large

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.enableSMBAlways,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableSMBAlwaysLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.enableSMBAlwaysLabel,
                    miniHint: AlgorithmSettingHints.enableSMBAlwaysMini,
                    verboseHint: AlgorithmSettingHints.enableSMBAlwaysVerbose(),
                    isChanged: state.isChanged(\.enableSMBAlways),
                    onReset: { state.resetField(\.enableSMBAlways) }
                )

                // Mirror the live SMBSettings behavior: conditional toggles are HIDDEN (not
                // greyed out) when SMB Always is on, since "Always" supersedes them all.
                if !state.preferences.enableSMBAlways {
                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.enableSMBWithCOB,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableSMBWithCOBLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.enableSMBWithCOBLabel,
                        miniHint: AlgorithmSettingHints.enableSMBWithCOBMini,
                        verboseHint: AlgorithmSettingHints.enableSMBWithCOBVerbose(),
                        isChanged: state.isChanged(\.enableSMBWithCOB),
                        onReset: { state.resetField(\.enableSMBWithCOB) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.enableSMBWithTemptarget,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableSMBWithTemptargetLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.enableSMBWithTemptargetLabel,
                        miniHint: AlgorithmSettingHints.enableSMBWithTemptargetMini(units: state.units),
                        verboseHint: AlgorithmSettingHints.enableSMBWithTemptargetVerbose(units: state.units),
                        isChanged: state.isChanged(\.enableSMBWithTemptarget),
                        onReset: { state.resetField(\.enableSMBWithTemptarget) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.enableSMBAfterCarbs,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableSMBAfterCarbsLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.enableSMBAfterCarbsLabel,
                        miniHint: AlgorithmSettingHints.enableSMBAfterCarbsMini,
                        verboseHint: AlgorithmSettingHints.enableSMBAfterCarbsVerbose(),
                        isChanged: state.isChanged(\.enableSMBAfterCarbs),
                        onReset: { state.resetField(\.enableSMBAfterCarbs) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.enableSMB_high_bg_target,
                        booleanValue: $state.preferences.enableSMB_high_bg,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableSMBWithHighGlucoseLabel),
                        units: state.units,
                        type: .conditionalDecimal("enableSMB_high_bg_target"),
                        label: AlgorithmSettingHints.enableSMBWithHighGlucoseLabel,
                        conditionalLabel: AlgorithmSettingHints.enableSMBWithHighGlucoseConditionalLabel,
                        miniHint: AlgorithmSettingHints.enableSMBWithHighGlucoseMini,
                        verboseHint: AlgorithmSettingHints.enableSMBWithHighGlucoseVerbose(),
                        isChanged: state.isChanged(\.enableSMB_high_bg)
                            || state.isChanged(\.enableSMB_high_bg_target),
                        onReset: {
                            state.resetField(\.enableSMB_high_bg)
                            state.resetField(\.enableSMB_high_bg_target)
                        }
                    )
                }

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.allowSMBWithHighTemptarget,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.allowSMBWithHighTemptargetLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.allowSMBWithHighTemptargetLabel,
                    miniHint: AlgorithmSettingHints.allowSMBWithHighTemptargetMini(units: state.units),
                    verboseHint: AlgorithmSettingHints.allowSMBWithHighTemptargetVerbose(units: state.units),
                    isChanged: state.isChanged(\.allowSMBWithHighTemptarget),
                    onReset: { state.resetField(\.allowSMBWithHighTemptarget) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.enableUAM,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableUAMLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.enableUAMLabel,
                    miniHint: AlgorithmSettingHints.enableUAMMini,
                    verboseHint: AlgorithmSettingHints.enableUAMVerbose(),
                    isChanged: state.isChanged(\.enableUAM),
                    onReset: { state.resetField(\.enableUAM) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.maxSMBBasalMinutes,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.maxSMBBasalMinutesLabel),
                    units: state.units,
                    type: .decimal("maxSMBBasalMinutes"),
                    label: AlgorithmSettingHints.maxSMBBasalMinutesLabel,
                    miniHint: AlgorithmSettingHints.maxSMBBasalMinutesMini,
                    verboseHint: AlgorithmSettingHints.maxSMBBasalMinutesVerbose(),
                    isChanged: state.isChanged(\.maxSMBBasalMinutes),
                    onReset: { state.resetField(\.maxSMBBasalMinutes) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.smbThresholdRatio,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.smbThresholdRatioLabel),
                    units: state.units,
                    type: .decimal("smbThresholdRatio"),
                    label: AlgorithmSettingHints.smbThresholdRatioLabel,
                    miniHint: AlgorithmSettingHints.smbThresholdRatioMini,
                    verboseHint: AlgorithmSettingHints.smbThresholdRatioVerbose(),
                    isChanged: state.isChanged(\.smbThresholdRatio),
                    onReset: { state.resetField(\.smbThresholdRatio) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.maxUAMSMBBasalMinutes,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.maxUAMBasalMinutesLabel),
                    units: state.units,
                    type: .decimal("maxUAMSMBBasalMinutes"),
                    label: AlgorithmSettingHints.maxUAMBasalMinutesLabel,
                    miniHint: AlgorithmSettingHints.maxUAMBasalMinutesMini,
                    verboseHint: AlgorithmSettingHints.maxUAMBasalMinutesVerbose(),
                    isChanged: state.isChanged(\.maxUAMSMBBasalMinutes),
                    onReset: { state.resetField(\.maxUAMSMBBasalMinutes) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.smbInterval,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.smbIntervalLabel),
                    units: state.units,
                    type: .decimal("smbInterval"),
                    label: AlgorithmSettingHints.smbIntervalLabel,
                    miniHint: AlgorithmSettingHints.smbIntervalMini,
                    verboseHint: AlgorithmSettingHints.smbIntervalVerbose(),
                    isChanged: state.isChanged(\.smbInterval),
                    onReset: { state.resetField(\.smbInterval) }
                )
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Super Micro Bolus (SMB)")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $shouldDisplayHint) { hintSheet }
        }

        private var hintSheet: some View {
            SettingInputHintView(
                hintDetent: $hintDetent,
                shouldDisplayHint: $shouldDisplayHint,
                hintLabel: hintLabel ?? "",
                hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                sheetTitle: String(localized: "Help")
            )
        }

        private func verboseHintBinding(_ label: String) -> Binding<(any View)?> {
            Binding(
                get: { selectedVerboseHint },
                set: { newValue in
                    selectedVerboseHint = newValue.map { AnyView($0) }
                    hintLabel = label
                }
            )
        }
    }

    // MARK: - Dynamic ISF

    struct DraftDynamicISFEditor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var shouldDisplayHint = false
        @State private var hintLabel: String?
        @State private var selectedVerboseHint: AnyView?
        @State private var hintDetent = PresentationDetent.large

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: Binding(
                        get: { state.preferences.useNewFormula },
                        set: { newValue in
                            state.preferences.useNewFormula = newValue
                            // dynISF and autoISF are mutually exclusive: enabling one disables
                            // the other.
                            if newValue { state.preferences.autoisf = false }
                        }
                    ),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.useDynamicISFLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.useDynamicISFLabel,
                    miniHint: AlgorithmSettingHints.useDynamicISFMini,
                    verboseHint: AlgorithmSettingHints.dynamicISFVerbose(),
                    isChanged: state.isChanged(\.useNewFormula),
                    onReset: { state.resetField(\.useNewFormula) }
                )

                // Sub-toggles are hidden when dynISF is off, matching the live DynamicSettings view.
                if state.preferences.useNewFormula {
                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.sigmoid,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.sigmoidLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.sigmoidLabel,
                        miniHint: AlgorithmSettingHints.sigmoidMini,
                        verboseHint: AlgorithmSettingHints.dynamicISFVerbose(),
                        isChanged: state.isChanged(\.sigmoid),
                        onReset: { state.resetField(\.sigmoid) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.adjustmentFactor,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.adjustmentFactorLabel),
                        units: state.units,
                        type: .decimal("adjustmentFactor"),
                        label: AlgorithmSettingHints.adjustmentFactorLabel,
                        miniHint: AlgorithmSettingHints.adjustmentFactorMini,
                        verboseHint: AlgorithmSettingHints.adjustmentFactorVerbose(),
                        isChanged: state.isChanged(\.adjustmentFactor),
                        onReset: { state.resetField(\.adjustmentFactor) }
                    )

                    if state.preferences.sigmoid {
                        SettingInputSection(
                            decimalValue: $state.preferences.adjustmentFactorSigmoid,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.adjustmentFactorSigmoidLabel),
                            units: state.units,
                            type: .decimal("adjustmentFactorSigmoid"),
                            label: AlgorithmSettingHints.adjustmentFactorSigmoidLabel,
                            miniHint: AlgorithmSettingHints.adjustmentFactorSigmoidMini,
                            verboseHint: AlgorithmSettingHints.adjustmentFactorSigmoidVerbose(),
                            isChanged: state.isChanged(\.adjustmentFactorSigmoid),
                            onReset: { state.resetField(\.adjustmentFactorSigmoid) }
                        )
                    }

                    SettingInputSection(
                        decimalValue: $state.preferences.weightPercentage,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.weightPercentageLabel),
                        units: state.units,
                        type: .decimal("weightPercentage"),
                        label: AlgorithmSettingHints.weightPercentageLabel,
                        miniHint: AlgorithmSettingHints.weightPercentageMini,
                        verboseHint: AlgorithmSettingHints.weightPercentageVerbose(),
                        isChanged: state.isChanged(\.weightPercentage),
                        onReset: { state.resetField(\.weightPercentage) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.tddAdjBasal,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.tddAdjBasalLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.tddAdjBasalLabel,
                        miniHint: AlgorithmSettingHints.tddAdjBasalMini,
                        verboseHint: AlgorithmSettingHints.tddAdjBasalVerbose(),
                        isChanged: state.isChanged(\.tddAdjBasal),
                        onReset: { state.resetField(\.tddAdjBasal) }
                    )
                }
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Dynamic Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $shouldDisplayHint) { hintSheet }
        }

        private var hintSheet: some View {
            SettingInputHintView(
                hintDetent: $hintDetent,
                shouldDisplayHint: $shouldDisplayHint,
                hintLabel: hintLabel ?? "",
                hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                sheetTitle: String(localized: "Help")
            )
        }

        private func verboseHintBinding(_ label: String) -> Binding<(any View)?> {
            Binding(
                get: { selectedVerboseHint },
                set: { newValue in
                    selectedVerboseHint = newValue.map { AnyView($0) }
                    hintLabel = label
                }
            )
        }
    }

    // MARK: - autoISF

    struct DraftAutoISFEditor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var shouldDisplayHint = false
        @State private var hintLabel: String?
        @State private var selectedVerboseHint: AnyView?
        @State private var hintDetent = PresentationDetent.large

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: Binding(
                        get: { state.preferences.autoisf },
                        set: { newValue in
                            state.preferences.autoisf = newValue
                            // dynISF and autoISF are mutually exclusive: enabling one disables
                            // the other.
                            if newValue { state.preferences.useNewFormula = false }
                            // When autoISF is off, autosens must be on — oref relies on at least
                            // one of autosens / autoISF to scale ISF dynamically.
                            if !newValue { state.preferences.enableAutosens = true }
                        }
                    ),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.activateAutoISFLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.activateAutoISFLabel,
                    miniHint: AlgorithmSettingHints.activateAutoISFMini,
                    verboseHint: AlgorithmSettingHints.activateAutoISFVerbose(),
                    isChanged: state.isChanged(\.autoisf),
                    onReset: { state.resetField(\.autoisf) }
                )

                // autoISF sub-settings are hidden when the master toggle is off.
                if state.preferences.autoisf {
                    SettingInputSection(
                        decimalValue: $state.preferences.iobThresholdPercent,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.iobThresholdPercentLabel),
                        units: state.units,
                        type: .decimal("iobThresholdPercent"),
                        label: AlgorithmSettingHints.iobThresholdPercentLabel,
                        miniHint: AlgorithmSettingHints.iobThresholdPercentMini,
                        verboseHint: AlgorithmSettingHints.iobThresholdPercentVerbose(),
                        isChanged: state.isChanged(\.iobThresholdPercent),
                        onReset: { state.resetField(\.iobThresholdPercent) }
                    )

                    // MARK: SMB Delivery Ratios group

                    // Placed near the top because users adjust these often per profile.

                    SettingInputSection(
                        decimalValue: $state.preferences.smbDeliveryRatio,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.smbDeliveryRatioFixedHintLabel),
                        units: state.units,
                        type: .decimal("smbDeliveryRatio"),
                        label: AlgorithmSettingHints.smbDeliveryRatioFixedLabel,
                        miniHint: AlgorithmSettingHints.smbDeliveryRatioFixedMini,
                        verboseHint: AlgorithmSettingHints.smbDeliveryRatioFixedVerbose(),
                        headerText: String(localized: "SMB Delivery Ratios"),
                        isChanged: state.isChanged(\.smbDeliveryRatio),
                        onReset: { state.resetField(\.smbDeliveryRatio) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.smbDeliveryRatioBGrange,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.smbDeliveryRatioBGrangeLabel),
                        units: state.units,
                        type: .decimal("smbDeliveryRatioBGrange"),
                        label: AlgorithmSettingHints.smbDeliveryRatioBGrangeLabel,
                        miniHint: AlgorithmSettingHints.smbDeliveryRatioBGrangeMini(units: state.units),
                        verboseHint: AlgorithmSettingHints.smbDeliveryRatioBGrangeVerbose(units: state.units),
                        isChanged: state.isChanged(\.smbDeliveryRatioBGrange),
                        onReset: { state.resetField(\.smbDeliveryRatioBGrange) }
                    )

                    // Mirror live AutoISF Settings: min/max only appear when the range is non-zero.
                    if state.preferences.smbDeliveryRatioBGrange != 0 {
                        SettingInputSection(
                            decimalValue: $state.preferences.smbDeliveryRatioMin,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.smbDeliveryRatioMinLabel),
                            units: state.units,
                            type: .decimal("smbDeliveryRatioMin"),
                            label: AlgorithmSettingHints.smbDeliveryRatioMinLabel,
                            miniHint: AlgorithmSettingHints.smbDeliveryRatioMinMini,
                            verboseHint: AlgorithmSettingHints.smbDeliveryRatioMinVerbose(),
                            isChanged: state.isChanged(\.smbDeliveryRatioMin),
                            onReset: { state.resetField(\.smbDeliveryRatioMin) }
                        )

                        SettingInputSection(
                            decimalValue: $state.preferences.smbDeliveryRatioMax,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.smbDeliveryRatioMaxLabel),
                            units: state.units,
                            type: .decimal("smbDeliveryRatioMax"),
                            label: AlgorithmSettingHints.smbDeliveryRatioMaxLabel,
                            miniHint: AlgorithmSettingHints.smbDeliveryRatioMaxMini,
                            verboseHint: AlgorithmSettingHints.smbDeliveryRatioMaxVerbose(),
                            isChanged: state.isChanged(\.smbDeliveryRatioMax),
                            onReset: { state.resetField(\.smbDeliveryRatioMax) }
                        )
                    }

                    SettingInputSection(
                        decimalValue: $state.preferences.smbMaxRangeExtension,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.smbMaxRangeExtensionLabel),
                        units: state.units,
                        type: .decimal("smbMaxRangeExtension"),
                        label: AlgorithmSettingHints.smbMaxRangeExtensionLabel,
                        miniHint: AlgorithmSettingHints.smbMaxRangeExtensionMini,
                        verboseHint: AlgorithmSettingHints.smbMaxRangeExtensionVerbose(),
                        isChanged: state.isChanged(\.smbMaxRangeExtension),
                        onReset: { state.resetField(\.smbMaxRangeExtension) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.enableAutosens,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableAutosensAutoISFLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.enableAutosensAutoISFLabel,
                        miniHint: AlgorithmSettingHints.enableAutosensAutoISFMini,
                        verboseHint: AlgorithmSettingHints.enableAutosensAutoISFVerbose(),
                        isChanged: state.isChanged(\.enableAutosens),
                        onReset: { state.resetField(\.enableAutosens) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.autoISFmax,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.autoISFmaxLabel),
                        units: state.units,
                        type: .decimal("autoISFmax"),
                        label: AlgorithmSettingHints.autoISFmaxLabel,
                        miniHint: AlgorithmSettingHints.autoISFmaxMini,
                        verboseHint: AlgorithmSettingHints.autoISFmaxVerbose(),
                        isChanged: state.isChanged(\.autoISFmax),
                        onReset: { state.resetField(\.autoISFmax) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.autoISFmin,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.autoISFminLabel),
                        units: state.units,
                        type: .decimal("autoISFmin"),
                        label: AlgorithmSettingHints.autoISFminLabel,
                        miniHint: AlgorithmSettingHints.autoISFminMini,
                        verboseHint: AlgorithmSettingHints.autoISFminVerbose(),
                        isChanged: state.isChanged(\.autoISFmin),
                        onReset: { state.resetField(\.autoISFmin) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.higherISFrangeWeight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.higherISFrangeWeightLabel),
                        units: state.units,
                        type: .decimal("higherISFrangeWeight"),
                        label: AlgorithmSettingHints.higherISFrangeWeightLabel,
                        miniHint: AlgorithmSettingHints.higherISFrangeWeightMini,
                        verboseHint: AlgorithmSettingHints.higherISFrangeWeightVerbose(),
                        isChanged: state.isChanged(\.higherISFrangeWeight),
                        onReset: { state.resetField(\.higherISFrangeWeight) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.lowerISFrangeWeight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.lowerISFrangeWeightLabel),
                        units: state.units,
                        type: .decimal("lowerISFrangeWeight"),
                        label: AlgorithmSettingHints.lowerISFrangeWeightLabel,
                        miniHint: AlgorithmSettingHints.lowerISFrangeWeightMini,
                        verboseHint: AlgorithmSettingHints.lowerISFrangeWeightVerbose(),
                        isChanged: state.isChanged(\.lowerISFrangeWeight),
                        onReset: { state.resetField(\.lowerISFrangeWeight) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.enableBGacceleration,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableBGaccelerationLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.enableBGaccelerationLabel,
                        miniHint: AlgorithmSettingHints.enableBGaccelerationMini,
                        verboseHint: AlgorithmSettingHints.enableBGaccelerationVerbose(),
                        isChanged: state.isChanged(\.enableBGacceleration),
                        onReset: { state.resetField(\.enableBGacceleration) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.bgAccelISFweight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.bgAccelISFweightLabel),
                        units: state.units,
                        type: .decimal("bgAccelISFweight"),
                        label: AlgorithmSettingHints.bgAccelISFweightLabel,
                        miniHint: AlgorithmSettingHints.bgAccelISFweightMini,
                        verboseHint: AlgorithmSettingHints.bgAccelISFweightVerbose(),
                        isChanged: state.isChanged(\.bgAccelISFweight),
                        onReset: { state.resetField(\.bgAccelISFweight) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.bgBrakeISFweight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.bgBrakeISFweightLabel),
                        units: state.units,
                        type: .decimal("bgBrakeISFweight"),
                        label: AlgorithmSettingHints.bgBrakeISFweightLabel,
                        miniHint: AlgorithmSettingHints.bgBrakeISFweightMini,
                        verboseHint: AlgorithmSettingHints.bgBrakeISFweightVerbose(),
                        isChanged: state.isChanged(\.bgBrakeISFweight),
                        onReset: { state.resetField(\.bgBrakeISFweight) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.postMealISFweight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.postMealISFweightLabel),
                        units: state.units,
                        type: .decimal("postMealISFweight"),
                        label: AlgorithmSettingHints.postMealISFweightLabel,
                        miniHint: AlgorithmSettingHints.postMealISFweightMini,
                        verboseHint: AlgorithmSettingHints.postMealISFweightVerbose(),
                        isChanged: state.isChanged(\.postMealISFweight),
                        onReset: { state.resetField(\.postMealISFweight) }
                    )
                } // if state.preferences.autoisf
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("autoISF")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $shouldDisplayHint) { hintSheet }
        }

        private var hintSheet: some View {
            SettingInputHintView(
                hintDetent: $hintDetent,
                shouldDisplayHint: $shouldDisplayHint,
                hintLabel: hintLabel ?? "",
                hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                sheetTitle: String(localized: "Help")
            )
        }

        private func verboseHintBinding(_ label: String) -> Binding<(any View)?> {
            Binding(
                get: { selectedVerboseHint },
                set: { newValue in
                    selectedVerboseHint = newValue.map { AnyView($0) }
                    hintLabel = label
                }
            )
        }
    }

    // MARK: - Additionals (Advanced)

    struct DraftAdvancedEditor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var shouldDisplayHint = false
        @State private var hintLabel: String?
        @State private var selectedVerboseHint: AnyView?
        @State private var hintDetent = PresentationDetent.large

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.useProfileCSF,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.useProfileCSFLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.useProfileCSFLabel,
                    miniHint: AlgorithmSettingHints.useProfileCSFMini,
                    verboseHint: AlgorithmSettingHints.useProfileCSFVerbose(),
                    isChanged: state.isChanged(\.useProfileCSF),
                    onReset: { state.resetField(\.useProfileCSF) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.maxDailySafetyMultiplier,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.maxDailySafetyMultiplierLabel),
                    units: state.units,
                    type: .decimal("maxDailySafetyMultiplier"),
                    label: AlgorithmSettingHints.maxDailySafetyMultiplierLabel,
                    miniHint: AlgorithmSettingHints.maxDailySafetyMultiplierMini,
                    verboseHint: AlgorithmSettingHints.maxDailySafetyMultiplierVerbose(),
                    isChanged: state.isChanged(\.maxDailySafetyMultiplier),
                    onReset: { state.resetField(\.maxDailySafetyMultiplier) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.currentBasalSafetyMultiplier,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.currentBasalSafetyMultiplierLabel),
                    units: state.units,
                    type: .decimal("currentBasalSafetyMultiplier"),
                    label: AlgorithmSettingHints.currentBasalSafetyMultiplierLabel,
                    miniHint: AlgorithmSettingHints.currentBasalSafetyMultiplierMini,
                    verboseHint: AlgorithmSettingHints.currentBasalSafetyMultiplierVerbose(),
                    isChanged: state.isChanged(\.currentBasalSafetyMultiplier),
                    onReset: { state.resetField(\.currentBasalSafetyMultiplier) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.skipNeutralTemps,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.skipNeutralTempsLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.skipNeutralTempsLabel,
                    miniHint: AlgorithmSettingHints.skipNeutralTempsMini,
                    verboseHint: AlgorithmSettingHints.skipNeutralTempsVerbose(),
                    isChanged: state.isChanged(\.skipNeutralTemps),
                    onReset: { state.resetField(\.skipNeutralTemps) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.unsuspendIfNoTemp,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.unsuspendIfNoTempLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.unsuspendIfNoTempLabel,
                    miniHint: AlgorithmSettingHints.unsuspendIfNoTempMini,
                    verboseHint: AlgorithmSettingHints.unsuspendIfNoTempVerbose(),
                    isChanged: state.isChanged(\.unsuspendIfNoTemp),
                    onReset: { state.resetField(\.unsuspendIfNoTemp) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.min5mCarbimpact,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.min5mCarbimpactLabel),
                    units: state.units,
                    type: .decimal("min5mCarbimpact"),
                    label: AlgorithmSettingHints.min5mCarbimpactLabel,
                    miniHint: AlgorithmSettingHints.min5mCarbimpactMini,
                    verboseHint: AlgorithmSettingHints.min5mCarbimpactVerbose(units: state.units),
                    isChanged: state.isChanged(\.min5mCarbimpact),
                    onReset: { state.resetField(\.min5mCarbimpact) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.remainingCarbsFraction,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.remainingCarbsFractionLabel),
                    units: state.units,
                    type: .decimal("remainingCarbsFraction"),
                    label: AlgorithmSettingHints.remainingCarbsFractionLabel,
                    miniHint: AlgorithmSettingHints.remainingCarbsFractionMini,
                    verboseHint: AlgorithmSettingHints.remainingCarbsFractionVerbose(),
                    isChanged: state.isChanged(\.remainingCarbsFraction),
                    onReset: { state.resetField(\.remainingCarbsFraction) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.remainingCarbsCap,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.remainingCarbsCapLabel),
                    units: state.units,
                    type: .decimal("remainingCarbsCap"),
                    label: AlgorithmSettingHints.remainingCarbsCapLabel,
                    miniHint: AlgorithmSettingHints.remainingCarbsCapMini,
                    verboseHint: AlgorithmSettingHints.remainingCarbsCapVerbose(),
                    isChanged: state.isChanged(\.remainingCarbsCap),
                    onReset: { state.resetField(\.remainingCarbsCap) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.noisyCGMTargetMultiplier,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.noisyCGMTargetMultiplierHintLabel),
                    units: state.units,
                    type: .decimal("noisyCGMTargetMultiplier"),
                    label: AlgorithmSettingHints.noisyCGMTargetMultiplierLabel,
                    miniHint: AlgorithmSettingHints.noisyCGMTargetMultiplierMini,
                    verboseHint: AlgorithmSettingHints.noisyCGMTargetMultiplierVerbose(),
                    isChanged: state.isChanged(\.noisyCGMTargetMultiplier),
                    onReset: { state.resetField(\.noisyCGMTargetMultiplier) }
                )
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Additionals")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $shouldDisplayHint) { hintSheet }
        }

        private var hintSheet: some View {
            SettingInputHintView(
                hintDetent: $hintDetent,
                shouldDisplayHint: $shouldDisplayHint,
                hintLabel: hintLabel ?? "",
                hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                sheetTitle: String(localized: "Help")
            )
        }

        private func verboseHintBinding(_ label: String) -> Binding<(any View)?> {
            Binding(
                get: { selectedVerboseHint },
                set: { newValue in
                    selectedVerboseHint = newValue.map { AnyView($0) }
                    hintLabel = label
                }
            )
        }
    }

    // MARK: - AIMI B30

    struct DraftB30Editor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var shouldDisplayHint = false
        @State private var hintLabel: String?
        @State private var selectedVerboseHint: AnyView?
        @State private var hintDetent = PresentationDetent.large

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.enableB30,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.enableB30Label),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.enableB30Label,
                    miniHint: AlgorithmSettingHints.enableB30Mini,
                    verboseHint: AlgorithmSettingHints.enableB30Verbose(),
                    isChanged: state.isChanged(\.enableB30),
                    onReset: { state.resetField(\.enableB30) }
                )

                if state.preferences.enableB30 {
                    SettingInputSection(
                        decimalValue: $state.preferences.B30iTimeStartBolus,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.b30iTimeStartBolusLabel),
                        units: state.units,
                        type: .decimal("B30iTimeStartBolus"),
                        label: AlgorithmSettingHints.b30iTimeStartBolusLabel,
                        miniHint: AlgorithmSettingHints.b30iTimeStartBolusMini,
                        verboseHint: AlgorithmSettingHints.b30iTimeStartBolusVerbose(),
                        isChanged: state.isChanged(\.B30iTimeStartBolus),
                        onReset: { state.resetField(\.B30iTimeStartBolus) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30iTime,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.b30iTimeLabel),
                        units: state.units,
                        type: .decimal("B30iTime"),
                        label: AlgorithmSettingHints.b30iTimeLabel,
                        miniHint: AlgorithmSettingHints.b30iTimeMini,
                        verboseHint: AlgorithmSettingHints.b30iTimeVerbose(),
                        isChanged: state.isChanged(\.B30iTime),
                        onReset: { state.resetField(\.B30iTime) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30iTimeTarget,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.b30iTimeTargetLabel),
                        units: state.units,
                        type: .decimal("B30iTimeTarget"),
                        label: AlgorithmSettingHints.b30iTimeTargetLabel,
                        miniHint: AlgorithmSettingHints.b30iTimeTargetMini,
                        verboseHint: AlgorithmSettingHints.b30iTimeTargetVerbose(units: state.units),
                        isChanged: state.isChanged(\.B30iTimeTarget),
                        onReset: { state.resetField(\.B30iTimeTarget) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30upperLimit,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.b30upperLimitLabel),
                        units: state.units,
                        type: .decimal("B30upperLimit"),
                        label: AlgorithmSettingHints.b30upperLimitLabel,
                        miniHint: AlgorithmSettingHints.b30upperLimitMini(units: state.units),
                        verboseHint: AlgorithmSettingHints.b30upperLimitVerbose(units: state.units),
                        isChanged: state.isChanged(\.B30upperLimit),
                        onReset: { state.resetField(\.B30upperLimit) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30upperDelta,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.b30upperDeltaLabel),
                        units: state.units,
                        type: .decimal("B30upperDelta"),
                        label: AlgorithmSettingHints.b30upperDeltaLabel,
                        miniHint: AlgorithmSettingHints.b30upperDeltaMini(units: state.units),
                        verboseHint: AlgorithmSettingHints.b30upperDeltaVerbose(units: state.units),
                        isChanged: state.isChanged(\.B30upperDelta),
                        onReset: { state.resetField(\.B30upperDelta) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30basalFactor,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.b30basalFactorLabel),
                        units: state.units,
                        type: .decimal("B30basalFactor"),
                        label: AlgorithmSettingHints.b30basalFactorLabel,
                        miniHint: AlgorithmSettingHints.b30basalFactorMini,
                        verboseHint: AlgorithmSettingHints.b30basalFactorVerbose(),
                        isChanged: state.isChanged(\.B30basalFactor),
                        onReset: { state.resetField(\.B30basalFactor) }
                    )
                }
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("AIMI B30")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $shouldDisplayHint) { hintSheet }
        }

        private var hintSheet: some View {
            SettingInputHintView(
                hintDetent: $hintDetent,
                shouldDisplayHint: $shouldDisplayHint,
                hintLabel: hintLabel ?? "",
                hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                sheetTitle: String(localized: "Help")
            )
        }

        private func verboseHintBinding(_ label: String) -> Binding<(any View)?> {
            Binding(
                get: { selectedVerboseHint },
                set: { newValue in
                    selectedVerboseHint = newValue.map { AnyView($0) }
                    hintLabel = label
                }
            )
        }
    }

    // MARK: - Keto Protection

    struct DraftKetoProtectEditor: View {
        @Bindable var state: DraftEditorStateModel
        @State private var shouldDisplayHint = false
        @State private var hintLabel: String?
        @State private var selectedVerboseHint: AnyView?
        @State private var hintDetent = PresentationDetent.large

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.ketoProtect,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.ketoProtectLabel),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.ketoProtectLabel,
                    miniHint: AlgorithmSettingHints.ketoProtectMini,
                    verboseHint: AlgorithmSettingHints.ketoProtectVerbose(),
                    isChanged: state.isChanged(\.ketoProtect),
                    onReset: { state.resetField(\.ketoProtect) }
                )

                if state.preferences.ketoProtect {
                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.variableKetoProtect,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.variableKetoProtectLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.variableKetoProtectLabel,
                        miniHint: AlgorithmSettingHints.variableKetoProtectMini,
                        verboseHint: AlgorithmSettingHints.variableKetoProtectVerbose(),
                        isChanged: state.isChanged(\.variableKetoProtect),
                        onReset: { state.resetField(\.variableKetoProtect) }
                    )

                    // Settings hides the percent field when Absolute is on; mirror that here.
                    if !state.preferences.ketoProtectAbsolut {
                        SettingInputSection(
                            decimalValue: $state.preferences.ketoProtectBasalPercent,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.ketoProtectBasalPercentLabel),
                            units: state.units,
                            type: .decimal("ketoProtectBasalPercent"),
                            label: AlgorithmSettingHints.ketoProtectBasalPercentLabel,
                            miniHint: AlgorithmSettingHints.ketoProtectBasalPercentMini,
                            verboseHint: AlgorithmSettingHints.ketoProtectBasalPercentVerbose(),
                            isChanged: state.isChanged(\.ketoProtectBasalPercent),
                            onReset: { state.resetField(\.ketoProtectBasalPercent) }
                        )
                    }

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.ketoProtectAbsolut,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.ketoProtectAbsolutLabel),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.ketoProtectAbsolutLabel,
                        miniHint: AlgorithmSettingHints.ketoProtectAbsolutMini,
                        verboseHint: AlgorithmSettingHints.ketoProtectAbsolutVerbose(),
                        isChanged: state.isChanged(\.ketoProtectAbsolut),
                        onReset: { state.resetField(\.ketoProtectAbsolut) }
                    )

                    if state.preferences.ketoProtectAbsolut {
                        SettingInputSection(
                            decimalValue: $state.preferences.ketoProtectBasalAbsolut,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: verboseHintBinding(AlgorithmSettingHints.ketoProtectBasalAbsolutLabel),
                            units: state.units,
                            type: .decimal("ketoProtectBasalAbsolut"),
                            label: AlgorithmSettingHints.ketoProtectBasalAbsolutLabel,
                            miniHint: AlgorithmSettingHints.ketoProtectBasalAbsolutMini,
                            verboseHint: AlgorithmSettingHints.ketoProtectBasalAbsolutVerbose(),
                            isChanged: state.isChanged(\.ketoProtectBasalAbsolut),
                            onReset: { state.resetField(\.ketoProtectBasalAbsolut) }
                        )
                    }
                }
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Keto Protection")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $shouldDisplayHint) { hintSheet }
        }

        private var hintSheet: some View {
            SettingInputHintView(
                hintDetent: $hintDetent,
                shouldDisplayHint: $shouldDisplayHint,
                hintLabel: hintLabel ?? "",
                hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                sheetTitle: String(localized: "Help")
            )
        }

        private func verboseHintBinding(_ label: String) -> Binding<(any View)?> {
            Binding(
                get: { selectedVerboseHint },
                set: { newValue in
                    selectedVerboseHint = newValue.map { AnyView($0) }
                    hintLabel = label
                }
            )
        }
    }
}
