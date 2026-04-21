import SwiftUI

// Algorithm sub-editors for the profile draft flow. Each embeds shared `SettingInputSection`s
// bound directly to the DraftEditorStateModel's `preferences` — pure bindings, no side effects.

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
                    selectedVerboseHint: verboseHintBinding("Autosens Max"),
                    units: state.units,
                    type: .decimal("autosensMax"),
                    label: String(localized: "Autosens Max"),
                    miniHint: String(localized: "Upper bound on the autosens ratio (reduces insulin resistance scaling)."),
                    verboseHint: Text("Default 1.2. Caps how aggressive autosens can be."),
                    isChanged: state.isChanged(\.autosensMax),
                    onReset: { state.resetField(\.autosensMax) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.autosensMin,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Autosens Min"),
                    units: state.units,
                    type: .decimal("autosensMin"),
                    label: String(localized: "Autosens Min"),
                    miniHint: String(localized: "Lower bound on the autosens ratio (reduces sensitivity scaling)."),
                    verboseHint: Text("Default 0.7."),
                    isChanged: state.isChanged(\.autosensMin),
                    onReset: { state.resetField(\.autosensMin) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.rewindResetsAutosens,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Rewind Resets Autosens"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Rewind Resets Autosens"),
                    miniHint: String(localized: "Pump rewinds reset the autosens ratio to 1."),
                    verboseHint: Text("Default ON."),
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
                    selectedVerboseHint: verboseHintBinding("High Temp Target Raises Sensitivity"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "High Temp Target Raises Sensitivity"),
                    miniHint: String(localized: "Manual temp target above 100 mg/dL increases sensitivity."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.highTemptargetRaisesSensitivity),
                    onReset: { state.resetField(\.highTemptargetRaisesSensitivity) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.lowTemptargetLowersSensitivity,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Low Temp Target Lowers Sensitivity"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Low Temp Target Lowers Sensitivity"),
                    miniHint: String(localized: "Manual temp target below 100 mg/dL reduces sensitivity."),
                    verboseHint: Text("Default OFF. Requires Autosens Max > 1."),
                    isChanged: state.isChanged(\.lowTemptargetLowersSensitivity),
                    onReset: { state.resetField(\.lowTemptargetLowersSensitivity) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.sensitivityRaisesTarget,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Sensitivity Raises Target"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Sensitivity Raises Target"),
                    miniHint: String(localized: "Automatically raise target when autosens < 1."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.sensitivityRaisesTarget),
                    onReset: { state.resetField(\.sensitivityRaisesTarget) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.resistanceLowersTarget,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Resistance Lowers Target"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Resistance Lowers Target"),
                    miniHint: String(localized: "Automatically lower target when autosens > 1."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.resistanceLowersTarget),
                    onReset: { state.resetField(\.resistanceLowersTarget) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.halfBasalExerciseTarget,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Half Basal Exercise Target"),
                    units: state.units,
                    type: .decimal("halfBasalExerciseTarget"),
                    label: String(localized: "Half Basal Exercise Target"),
                    miniHint: String(localized: "Target at which basal is scaled to 50 %."),
                    verboseHint: Text("Default 160 mg/dL."),
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
                    selectedVerboseHint: verboseHintBinding("Enable SMB Always"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Enable SMB Always"),
                    miniHint: String(localized: "Deliver SMBs regardless of COB or target."),
                    verboseHint: Text("Default ON."),
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
                        selectedVerboseHint: verboseHintBinding("Enable SMB With COB"),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "Enable SMB With COB"),
                        miniHint: String(localized: "Deliver SMBs when carbs are on board."),
                        verboseHint: Text("Default ON."),
                        isChanged: state.isChanged(\.enableSMBWithCOB),
                        onReset: { state.resetField(\.enableSMBWithCOB) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.enableSMBWithTemptarget,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Enable SMB With Temp Target"),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "Enable SMB With Temp Target"),
                        miniHint: String(localized: "Deliver SMBs with a low temp target active."),
                        verboseHint: Text("Default ON."),
                        isChanged: state.isChanged(\.enableSMBWithTemptarget),
                        onReset: { state.resetField(\.enableSMBWithTemptarget) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.enableSMBAfterCarbs,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Enable SMB After Carbs"),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "Enable SMB After Carbs"),
                        miniHint: String(localized: "Deliver SMBs for 6 h after carbs."),
                        verboseHint: Text("Default ON."),
                        isChanged: state.isChanged(\.enableSMBAfterCarbs),
                        onReset: { state.resetField(\.enableSMBAfterCarbs) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.enableSMB_high_bg_target,
                        booleanValue: $state.preferences.enableSMB_high_bg,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Enable SMB With High Glucose"),
                        units: state.units,
                        type: .conditionalDecimal("enableSMB_high_bg_target"),
                        label: String(localized: "Enable SMB With High Glucose"),
                        conditionalLabel: String(localized: "High Glucose Target"),
                        miniHint: String(localized: "Allow SMB when glucose is above the High Glucose Target."),
                        verboseHint: Text("Default OFF."),
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
                    selectedVerboseHint: verboseHintBinding("Allow SMB With High Temp Target"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Allow SMB With High Temp Target"),
                    miniHint: String(localized: "Allow SMBs even if a high temp target is set."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.allowSMBWithHighTemptarget),
                    onReset: { state.resetField(\.allowSMBWithHighTemptarget) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.enableUAM,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Enable UAM"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Enable UAM"),
                    miniHint: String(localized: "Unannounced meal detection for aggressive dosing."),
                    verboseHint: Text("Default ON."),
                    isChanged: state.isChanged(\.enableUAM),
                    onReset: { state.resetField(\.enableUAM) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.maxSMBBasalMinutes,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Max SMB Basal Minutes"),
                    units: state.units,
                    type: .decimal("maxSMBBasalMinutes"),
                    label: String(localized: "Max SMB Basal Minutes"),
                    miniHint: String(localized: "Largest SMB expressed as minutes of basal."),
                    verboseHint: Text("Default 30 min."),
                    isChanged: state.isChanged(\.maxSMBBasalMinutes),
                    onReset: { state.resetField(\.maxSMBBasalMinutes) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.maxUAMSMBBasalMinutes,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Max UAM SMB Basal Minutes"),
                    units: state.units,
                    type: .decimal("maxUAMSMBBasalMinutes"),
                    label: String(localized: "Max UAM SMB Basal Minutes"),
                    miniHint: String(localized: "Largest UAM-driven SMB expressed as minutes of basal."),
                    verboseHint: Text("Default 30 min."),
                    isChanged: state.isChanged(\.maxUAMSMBBasalMinutes),
                    onReset: { state.resetField(\.maxUAMSMBBasalMinutes) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.smbInterval,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("SMB Interval"),
                    units: state.units,
                    type: .decimal("smbInterval"),
                    label: String(localized: "SMB Interval"),
                    miniHint: String(localized: "Minimum minutes between SMBs."),
                    verboseHint: Text("Default 3 min."),
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
                    selectedVerboseHint: verboseHintBinding("Use Dynamic ISF"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Use Dynamic ISF"),
                    miniHint: String(localized: "Enable logarithmic or sigmoid dynamic ISF. Disables autoISF."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.useNewFormula),
                    onReset: { state.resetField(\.useNewFormula) }
                )

                // Sub-toggles are hidden when dynISF is off, matching the live DynamicSettings view.
                if state.preferences.useNewFormula {
                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.sigmoid,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Sigmoid"),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "Sigmoid"),
                        miniHint: String(localized: "Use the sigmoid dynISF formula instead of logarithmic."),
                        verboseHint: Text("Default OFF."),
                        isChanged: state.isChanged(\.sigmoid),
                        onReset: { state.resetField(\.sigmoid) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.adjustmentFactor,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Adjustment Factor"),
                        units: state.units,
                        type: .decimal("adjustmentFactor"),
                        label: String(localized: "Adjustment Factor"),
                        miniHint: String(localized: "Scales the logarithmic dynISF curve."),
                        verboseHint: Text("Default 0.8."),
                        isChanged: state.isChanged(\.adjustmentFactor),
                        onReset: { state.resetField(\.adjustmentFactor) }
                    )

                    if state.preferences.sigmoid {
                        SettingInputSection(
                            decimalValue: $state.preferences.adjustmentFactorSigmoid,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: verboseHintBinding("Sigmoid Adjustment Factor"),
                            units: state.units,
                            type: .decimal("adjustmentFactorSigmoid"),
                            label: String(localized: "Sigmoid Adjustment Factor"),
                            miniHint: String(localized: "Scales the sigmoid dynISF curve."),
                            verboseHint: Text("Default 0.5."),
                            isChanged: state.isChanged(\.adjustmentFactorSigmoid),
                            onReset: { state.resetField(\.adjustmentFactorSigmoid) }
                        )
                    }

                    SettingInputSection(
                        decimalValue: $state.preferences.weightPercentage,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Weighted Average of TDD"),
                        units: state.units,
                        type: .decimal("weightPercentage"),
                        label: String(localized: "Weighted Average of TDD"),
                        miniHint: String(localized: "Blend between 24 h TDD average and recent 2 h."),
                        verboseHint: Text("Default 0.35."),
                        isChanged: state.isChanged(\.weightPercentage),
                        onReset: { state.resetField(\.weightPercentage) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.tddAdjBasal,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("TDD Adjusts Basal"),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "TDD Adjusts Basal"),
                        miniHint: String(localized: "Scale scheduled basal based on TDD."),
                        verboseHint: Text("Default OFF."),
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
                        }
                    ),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Enable autoISF"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Enable autoISF"),
                    miniHint: String(
                        localized: "Dynamically scales ISF based on BG acceleration and duration. Disables Dynamic ISF."
                    ),
                    verboseHint: Text("Default ON."),
                    isChanged: state.isChanged(\.autoisf),
                    onReset: { state.resetField(\.autoisf) }
                )

                // autoISF sub-settings are hidden when the master toggle is off.
                if state.preferences.autoisf {
                    SettingInputSection(
                        decimalValue: $state.preferences.autoISFmax,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("autoISF Max"),
                        units: state.units,
                        type: .decimal("autoISFmax"),
                        label: String(localized: "autoISF Max"),
                        miniHint: String(localized: "Upper cap on autoISF ratio."),
                        verboseHint: Text("Default 2.0."),
                        isChanged: state.isChanged(\.autoISFmax),
                        onReset: { state.resetField(\.autoISFmax) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.autoISFmin,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("autoISF Min"),
                        units: state.units,
                        type: .decimal("autoISFmin"),
                        label: String(localized: "autoISF Min"),
                        miniHint: String(localized: "Lower cap on autoISF ratio."),
                        verboseHint: Text("Default 0.5."),
                        isChanged: state.isChanged(\.autoISFmin),
                        onReset: { state.resetField(\.autoISFmin) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.smbDeliveryRatio,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("SMB Delivery Ratio"),
                        units: state.units,
                        type: .decimal("smbDeliveryRatio"),
                        label: String(localized: "SMB Delivery Ratio"),
                        miniHint: String(localized: "Share of insulinReq delivered via SMB."),
                        verboseHint: Text("Default 0.85."),
                        isChanged: state.isChanged(\.smbDeliveryRatio),
                        onReset: { state.resetField(\.smbDeliveryRatio) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.higherISFrangeWeight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Higher ISF Range Weight"),
                        units: state.units,
                        type: .decimal("higherISFrangeWeight"),
                        label: String(localized: "Higher ISF Range Weight"),
                        miniHint: String(localized: "Weight applied when BG is above target."),
                        verboseHint: Text("Default 0.3."),
                        isChanged: state.isChanged(\.higherISFrangeWeight),
                        onReset: { state.resetField(\.higherISFrangeWeight) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.lowerISFrangeWeight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Lower ISF Range Weight"),
                        units: state.units,
                        type: .decimal("lowerISFrangeWeight"),
                        label: String(localized: "Lower ISF Range Weight"),
                        miniHint: String(localized: "Weight applied when BG is below target."),
                        verboseHint: Text("Default 0.7."),
                        isChanged: state.isChanged(\.lowerISFrangeWeight),
                        onReset: { state.resetField(\.lowerISFrangeWeight) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.enableBGacceleration,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Enable BG Acceleration"),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "Enable BG Acceleration"),
                        miniHint: String(localized: "Scale ISF by glucose acceleration."),
                        verboseHint: Text("Default ON."),
                        isChanged: state.isChanged(\.enableBGacceleration),
                        onReset: { state.resetField(\.enableBGacceleration) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.bgAccelISFweight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("BG Acceleration Weight"),
                        units: state.units,
                        type: .decimal("bgAccelISFweight"),
                        label: String(localized: "BG Acceleration Weight"),
                        miniHint: String(localized: "Weight applied when BG is accelerating up."),
                        verboseHint: Text("Default 0.15."),
                        isChanged: state.isChanged(\.bgAccelISFweight),
                        onReset: { state.resetField(\.bgAccelISFweight) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.bgBrakeISFweight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("BG Brake Weight"),
                        units: state.units,
                        type: .decimal("bgBrakeISFweight"),
                        label: String(localized: "BG Brake Weight"),
                        miniHint: String(localized: "Weight applied when BG decelerates/brakes."),
                        verboseHint: Text("Default 0.15."),
                        isChanged: state.isChanged(\.bgBrakeISFweight),
                        onReset: { state.resetField(\.bgBrakeISFweight) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.postMealISFweight,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Post-Meal ISF Weight"),
                        units: state.units,
                        type: .decimal("postMealISFweight"),
                        label: String(localized: "Post-Meal ISF Weight"),
                        miniHint: String(localized: "Weight applied during post-meal window."),
                        verboseHint: Text("Default 0.02."),
                        isChanged: state.isChanged(\.postMealISFweight),
                        onReset: { state.resetField(\.postMealISFweight) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.iobThresholdPercent,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("IOB Threshold Percent"),
                        units: state.units,
                        type: .decimal("iobThresholdPercent"),
                        label: String(localized: "IOB Threshold Percent"),
                        miniHint: String(localized: "Fraction of maxIOB for autoISF gates."),
                        verboseHint: Text("Default 1.0 (100 % of maxIOB)."),
                        isChanged: state.isChanged(\.iobThresholdPercent),
                        onReset: { state.resetField(\.iobThresholdPercent) }
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
                    selectedVerboseHint: verboseHintBinding("Use Profile CSF"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Use Profile CSF"),
                    miniHint: String(localized: "Derive carb ratio dynamically from the CSF profile."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.useProfileCSF),
                    onReset: { state.resetField(\.useProfileCSF) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.maxDailySafetyMultiplier,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Max Daily Safety Multiplier"),
                    units: state.units,
                    type: .decimal("maxDailySafetyMultiplier"),
                    label: String(localized: "Max Daily Safety Multiplier"),
                    miniHint: String(localized: "Cap on temp basal vs. max scheduled daily basal."),
                    verboseHint: Text("Default 3."),
                    isChanged: state.isChanged(\.maxDailySafetyMultiplier),
                    onReset: { state.resetField(\.maxDailySafetyMultiplier) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.currentBasalSafetyMultiplier,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Current Basal Safety Multiplier"),
                    units: state.units,
                    type: .decimal("currentBasalSafetyMultiplier"),
                    label: String(localized: "Current Basal Safety Multiplier"),
                    miniHint: String(localized: "Cap on temp basal vs. current scheduled basal."),
                    verboseHint: Text("Default 4."),
                    isChanged: state.isChanged(\.currentBasalSafetyMultiplier),
                    onReset: { state.resetField(\.currentBasalSafetyMultiplier) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.skipNeutralTemps,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Skip Neutral Temps"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Skip Neutral Temps"),
                    miniHint: String(localized: "Don't issue temp basals equal to scheduled rate."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.skipNeutralTemps),
                    onReset: { state.resetField(\.skipNeutralTemps) }
                )

                SettingInputSection(
                    decimalValue: .constant(0),
                    booleanValue: $state.preferences.unsuspendIfNoTemp,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Unsuspend If No Temp"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Unsuspend If No Temp"),
                    miniHint: String(localized: "Auto-unsuspend pump if no temp basal is running."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.unsuspendIfNoTemp),
                    onReset: { state.resetField(\.unsuspendIfNoTemp) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.min5mCarbimpact,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Min 5m Carb Impact"),
                    units: state.units,
                    type: .decimal("min5mCarbimpact"),
                    label: String(localized: "Min 5m Carb Impact"),
                    miniHint: String(localized: "Minimum assumed carb impact per 5 min (mg/dL)."),
                    verboseHint: Text("Default 8."),
                    isChanged: state.isChanged(\.min5mCarbimpact),
                    onReset: { state.resetField(\.min5mCarbimpact) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.remainingCarbsFraction,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Remaining Carbs Fraction"),
                    units: state.units,
                    type: .decimal("remainingCarbsFraction"),
                    label: String(localized: "Remaining Carbs Fraction"),
                    miniHint: String(localized: "Fraction of uncovered carbs to expect absorbing."),
                    verboseHint: Text("Default 1.0."),
                    isChanged: state.isChanged(\.remainingCarbsFraction),
                    onReset: { state.resetField(\.remainingCarbsFraction) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.remainingCarbsCap,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Remaining Carbs Cap"),
                    units: state.units,
                    type: .decimal("remainingCarbsCap"),
                    label: String(localized: "Remaining Carbs Cap"),
                    miniHint: String(localized: "Cap on uncovered carbs carried forward."),
                    verboseHint: Text("Default 90 g."),
                    isChanged: state.isChanged(\.remainingCarbsCap),
                    onReset: { state.resetField(\.remainingCarbsCap) }
                )

                SettingInputSection(
                    decimalValue: $state.preferences.noisyCGMTargetMultiplier,
                    booleanValue: .constant(false),
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: verboseHintBinding("Noisy CGM Target Multiplier"),
                    units: state.units,
                    type: .decimal("noisyCGMTargetMultiplier"),
                    label: String(localized: "Noisy CGM Target Multiplier"),
                    miniHint: String(localized: "Raise target when CGM is flagged noisy."),
                    verboseHint: Text("Default 1.3."),
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
                    selectedVerboseHint: verboseHintBinding("Enable B30"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Enable B30"),
                    miniHint: String(localized: "Eating-soon high-basal window after a small manual bolus."),
                    verboseHint: Text("Default ON."),
                    isChanged: state.isChanged(\.enableB30),
                    onReset: { state.resetField(\.enableB30) }
                )

                if state.preferences.enableB30 {
                    SettingInputSection(
                        decimalValue: $state.preferences.B30iTimeStartBolus,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("B30 Start Bolus"),
                        units: state.units,
                        type: .decimal("B30iTimeStartBolus"),
                        label: String(localized: "B30 Start Bolus"),
                        miniHint: String(localized: "Minimum manual bolus to trigger the B30 window."),
                        verboseHint: Text("Default 1 U."),
                        isChanged: state.isChanged(\.B30iTimeStartBolus),
                        onReset: { state.resetField(\.B30iTimeStartBolus) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30iTime,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("B30 Duration"),
                        units: state.units,
                        type: .decimal("B30iTime"),
                        label: String(localized: "B30 Duration"),
                        miniHint: String(localized: "How long the high-basal window runs."),
                        verboseHint: Text("Default 30 min."),
                        isChanged: state.isChanged(\.B30iTime),
                        onReset: { state.resetField(\.B30iTime) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30iTimeTarget,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("B30 Target"),
                        units: state.units,
                        type: .decimal("B30iTimeTarget"),
                        label: String(localized: "B30 Target"),
                        miniHint: String(localized: "Target glucose below which B30 activates."),
                        verboseHint: Text("Default 90 mg/dL."),
                        isChanged: state.isChanged(\.B30iTimeTarget),
                        onReset: { state.resetField(\.B30iTimeTarget) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30upperLimit,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("B30 Upper Limit"),
                        units: state.units,
                        type: .decimal("B30upperLimit"),
                        label: String(localized: "B30 Upper Limit"),
                        miniHint: String(localized: "Upper glucose limit cancelling B30."),
                        verboseHint: Text("Default 130 mg/dL."),
                        isChanged: state.isChanged(\.B30upperLimit),
                        onReset: { state.resetField(\.B30upperLimit) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30upperDelta,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("B30 Upper Delta"),
                        units: state.units,
                        type: .decimal("B30upperDelta"),
                        label: String(localized: "B30 Upper Delta"),
                        miniHint: String(localized: "Delta that cancels B30 (rising BG)."),
                        verboseHint: Text("Default 8 mg/dL."),
                        isChanged: state.isChanged(\.B30upperDelta),
                        onReset: { state.resetField(\.B30upperDelta) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.B30basalFactor,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("B30 Basal Factor"),
                        units: state.units,
                        type: .decimal("B30basalFactor"),
                        label: String(localized: "B30 Basal Factor"),
                        miniHint: String(localized: "Multiplier applied to basal during B30 window."),
                        verboseHint: Text("Default 5×."),
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
                    selectedVerboseHint: verboseHintBinding("Keto Protect"),
                    units: state.units,
                    type: .boolean,
                    label: String(localized: "Keto Protect"),
                    miniHint: String(localized: "Maintain a minimum basal to avoid ketoacidosis."),
                    verboseHint: Text("Default OFF."),
                    isChanged: state.isChanged(\.ketoProtect),
                    onReset: { state.resetField(\.ketoProtect) }
                )

                if state.preferences.ketoProtect {
                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.variableKetoProtect,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Variable Keto Protect"),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "Variable Keto Protect"),
                        miniHint: String(localized: "Scale the protective basal with the scheduled basal rate."),
                        verboseHint: Text("Default OFF."),
                        isChanged: state.isChanged(\.variableKetoProtect),
                        onReset: { state.resetField(\.variableKetoProtect) }
                    )

                    SettingInputSection(
                        decimalValue: $state.preferences.ketoProtectBasalPercent,
                        booleanValue: .constant(false),
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Keto Protect Basal Percent"),
                        units: state.units,
                        type: .decimal("ketoProtectBasalPercent"),
                        label: String(localized: "Keto Protect Basal Percent"),
                        miniHint: String(localized: "Percent of scheduled basal used as floor."),
                        verboseHint: Text("Default 20 %."),
                        isChanged: state.isChanged(\.ketoProtectBasalPercent),
                        onReset: { state.resetField(\.ketoProtectBasalPercent) }
                    )

                    SettingInputSection(
                        decimalValue: .constant(0),
                        booleanValue: $state.preferences.ketoProtectAbsolut,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: verboseHintBinding("Keto Protect Absolute"),
                        units: state.units,
                        type: .boolean,
                        label: String(localized: "Keto Protect Absolute"),
                        miniHint: String(localized: "Use a fixed U/hr floor instead of a percentage."),
                        verboseHint: Text("Default OFF."),
                        isChanged: state.isChanged(\.ketoProtectAbsolut),
                        onReset: { state.resetField(\.ketoProtectAbsolut) }
                    )

                    if state.preferences.ketoProtectAbsolut {
                        SettingInputSection(
                            decimalValue: $state.preferences.ketoProtectBasalAbsolut,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: verboseHintBinding("Keto Protect Absolute Basal"),
                            units: state.units,
                            type: .decimal("ketoProtectBasalAbsolut"),
                            label: String(localized: "Keto Protect Absolute Basal"),
                            miniHint: String(localized: "Minimum basal rate used as floor."),
                            verboseHint: Text("Default 0.1 U/hr."),
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
