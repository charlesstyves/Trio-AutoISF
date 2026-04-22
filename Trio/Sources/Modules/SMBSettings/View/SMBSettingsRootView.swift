import SwiftUI
import Swinject

extension SMBSettings {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var shouldDisplayHint: Bool = false
        @State var hintDetent = PresentationDetent.large
        @State var selectedVerboseHint: AnyView?
        @State var hintLabel: String?
        @State private var decimalPlaceholder: Decimal = 0.0
        @State private var booleanPlaceholder: Bool = false

        @Environment(\.colorScheme) var colorScheme
        @EnvironmentObject var appIcons: Icons
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                SettingInputSection(
                    decimalValue: $decimalPlaceholder,
                    booleanValue: $state.enableSMBAlways,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: Binding(
                        get: { selectedVerboseHint },
                        set: {
                            selectedVerboseHint = $0.map { AnyView($0) }
                            hintLabel = AlgorithmSettingHints.enableSMBAlwaysLabel
                        }
                    ),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.enableSMBAlwaysLabel,
                    miniHint: AlgorithmSettingHints.enableSMBAlwaysMini,
                    verboseHint: AlgorithmSettingHints.enableSMBAlwaysVerbose(),
                    headerText: String(localized: "Super-Micro-Bolus")
                )

                if !state.enableSMBAlways {
                    SettingInputSection(
                        decimalValue: $decimalPlaceholder,
                        booleanValue: $state.enableSMBWithCOB,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: Binding(
                            get: { selectedVerboseHint },
                            set: {
                                selectedVerboseHint = $0.map { AnyView($0) }
                                hintLabel = AlgorithmSettingHints.enableSMBWithCOBLabel
                            }
                        ),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.enableSMBWithCOBLabel,
                        miniHint: AlgorithmSettingHints.enableSMBWithCOBMini,
                        verboseHint: AlgorithmSettingHints.enableSMBWithCOBVerbose()
                    )

                    SettingInputSection(
                        decimalValue: $decimalPlaceholder,
                        booleanValue: $state.enableSMBWithTemptarget,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: Binding(
                            get: { selectedVerboseHint },
                            set: {
                                selectedVerboseHint = $0.map { AnyView($0) }
                                hintLabel = AlgorithmSettingHints.enableSMBWithTemptargetLabel
                            }
                        ),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.enableSMBWithTemptargetLabel,
                        miniHint: AlgorithmSettingHints.enableSMBWithTemptargetMini(units: state.units),
                        verboseHint: AlgorithmSettingHints.enableSMBWithTemptargetVerbose(units: state.units)
                    )

                    SettingInputSection(
                        decimalValue: $decimalPlaceholder,
                        booleanValue: $state.enableSMBAfterCarbs,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: Binding(
                            get: { selectedVerboseHint },
                            set: {
                                selectedVerboseHint = $0.map { AnyView($0) }
                                hintLabel = AlgorithmSettingHints.enableSMBAfterCarbsLabel
                            }
                        ),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.enableSMBAfterCarbsLabel,
                        miniHint: AlgorithmSettingHints.enableSMBAfterCarbsMini,
                        verboseHint: AlgorithmSettingHints.enableSMBAfterCarbsVerbose()
                    )

                    SettingInputSection(
                        decimalValue: $state.enableSMB_high_bg_target,
                        booleanValue: $state.enableSMB_high_bg,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: Binding(
                            get: { selectedVerboseHint },
                            set: {
                                selectedVerboseHint = $0.map { AnyView($0) }
                                hintLabel = AlgorithmSettingHints.enableSMBWithHighGlucoseLabel
                            }
                        ),
                        units: state.units,
                        type: .conditionalDecimal("enableSMB_high_bg_target"),
                        label: AlgorithmSettingHints.enableSMBWithHighGlucoseLabel,
                        conditionalLabel: AlgorithmSettingHints.enableSMBWithHighGlucoseConditionalLabel,
                        miniHint: AlgorithmSettingHints.enableSMBWithHighGlucoseMini,
                        verboseHint: AlgorithmSettingHints.enableSMBWithHighGlucoseVerbose()
                    )
                }

                SettingInputSection(
                    decimalValue: $decimalPlaceholder,
                    booleanValue: $state.allowSMBWithHighTemptarget,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: Binding(
                        get: { selectedVerboseHint },
                        set: {
                            selectedVerboseHint = $0.map { AnyView($0) }
                            hintLabel = AlgorithmSettingHints.allowSMBWithHighTemptargetLabel
                        }
                    ),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.allowSMBWithHighTemptargetLabel,
                    miniHint: AlgorithmSettingHints.allowSMBWithHighTemptargetMini(units: state.units),
                    verboseHint: AlgorithmSettingHints.allowSMBWithHighTemptargetVerbose(units: state.units)
                )

                SettingInputSection(
                    decimalValue: $decimalPlaceholder,
                    booleanValue: $state.enableUAM,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: Binding(
                        get: { selectedVerboseHint },
                        set: {
                            selectedVerboseHint = $0.map { AnyView($0) }
                            hintLabel = AlgorithmSettingHints.enableUAMLabel
                        }
                    ),
                    units: state.units,
                    type: .boolean,
                    label: AlgorithmSettingHints.enableUAMLabel,
                    miniHint: AlgorithmSettingHints.enableUAMMini,
                    verboseHint: AlgorithmSettingHints.enableUAMVerbose()
                )

                SettingInputSection(
                    decimalValue: $state.maxSMBBasalMinutes,
                    booleanValue: $booleanPlaceholder,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: Binding(
                        get: { selectedVerboseHint },
                        set: {
                            selectedVerboseHint = $0.map { AnyView($0) }
                            hintLabel = AlgorithmSettingHints.maxSMBBasalMinutesLabel
                        }
                    ),
                    units: state.units,
                    type: .decimal("maxSMBBasalMinutes"),
                    label: AlgorithmSettingHints.maxSMBBasalMinutesLabel,
                    miniHint: AlgorithmSettingHints.maxSMBBasalMinutesMini,
                    verboseHint: AlgorithmSettingHints.maxSMBBasalMinutesVerbose()
                )

                SettingInputSection(
                    decimalValue: $state.maxUAMSMBBasalMinutes,
                    booleanValue: $booleanPlaceholder,
                    shouldDisplayHint: $shouldDisplayHint,
                    selectedVerboseHint: Binding(
                        get: { selectedVerboseHint },
                        set: {
                            selectedVerboseHint = $0.map { AnyView($0) }
                            hintLabel = AlgorithmSettingHints.maxUAMBasalMinutesLabel
                        }
                    ),
                    units: state.units,
                    type: .decimal("maxUAMSMBBasalMinutes"),
                    label: AlgorithmSettingHints.maxUAMBasalMinutesLabel,
                    miniHint: AlgorithmSettingHints.maxUAMBasalMinutesMini,
                    verboseHint: AlgorithmSettingHints.maxUAMBasalMinutesVerbose()
                )

//                SettingInputSection(
//                    decimalValue: $state.maxDeltaBGthreshold,
//                    booleanValue: $booleanPlaceholder,
//                    shouldDisplayHint: $shouldDisplayHint,
//                    selectedVerboseHint: Binding(
//                        get: { selectedVerboseHint },
//                        set: {
//                            selectedVerboseHint = $0.map { AnyView($0) }
//                            hintLabel = String(
//                                localized: "Max Allowed Glucose Rise for SMB",
//                                comment: "Max Allowed Glucose Rise for SMB, formerly Max Delta-BG Threshold"
//                            )
//                        }
//                    ),
//                    units: state.units,
//                    type: .decimal("maxDeltaBGthreshold"),
//                    label: String(
//                        localized: "Max Allowed Glucose Rise for SMB",
//                        comment: "Max Allowed Glucose Rise for SMB, formerly Max Delta-BG Threshold"
//                    ),
//                    miniHint: String(localized: "Disables SMBs if last two glucose values differ by more than this percent."),
//                    verboseHint:
//                    VStack(alignment: .leading, spacing: 10) {
//                        Text("Default: 20% increase").bold()
//                        Text(
//                            "Maximum allowed positive percent change in glucose level to permit SMBs. If the difference in glucose is greater than this, Trio will only adjust Temp Basal Rate and not deliver an SMB that loop cycle."
//                        )
//                        Text(
//                            "This is a safety limitation to avoid high SMB doses when glucose is rising abnormally fast, such as after a meal or with a very jumpy CGM sensor."
//                        )
//                        Text("Note: This setting has a hard-coded cap of 40%")
//                    }
//                )
            }
            .listSectionSpacing(sectionSpacing)
            .sheet(isPresented: $shouldDisplayHint) {
                SettingInputHintView(
                    hintDetent: $hintDetent,
                    shouldDisplayHint: $shouldDisplayHint,
                    hintLabel: hintLabel ?? "",
                    hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                    sheetTitle: String(localized: "Help", comment: "Help sheet title")
                )
            }
            .scrollContentBackground(.hidden).background(appState.trioBackgroundColor(for: colorScheme))
            .onAppear(perform: configureView)
            .navigationTitle("SMB Settings")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
