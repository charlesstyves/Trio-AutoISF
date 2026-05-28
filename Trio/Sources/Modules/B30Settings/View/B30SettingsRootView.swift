import SwiftUI
import Swinject

extension B30Settings {
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
        @Environment(AppState.self) var appState

        var body: some View {
            List {
                Section(
                    header: Text("Enable"),
                    content: {
                        SettingInputSection(
                            decimalValue: .constant(0),
                            booleanValue: $state.enableB30,
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.enableB30Label
                                }
                            ),
                            units: state.units,
                            type: .boolean,
                            label: AlgorithmSettingHints.enableB30Label,
                            miniHint: AlgorithmSettingHints.enableB30Mini,
                            verboseHint: AlgorithmSettingHints.enableB30Verbose()
                        )
                    }
                )
                if state.enableB30 {
                    Section(header: Text("B30 Settings")) {
                        SettingInputSection(
                            decimalValue: $state.B30iTimeTarget,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.b30iTimeTargetLabel
                                }
                            ),
                            units: state.units,
                            type: .decimal("B30iTimeTarget"),
                            label: AlgorithmSettingHints.b30iTimeTargetLabel,
                            miniHint: AlgorithmSettingHints.b30iTimeTargetMini,
                            verboseHint: AlgorithmSettingHints.b30iTimeTargetVerbose(units: state.units)
                        )
                        SettingInputSection(
                            decimalValue: $state.B30iTimeStartBolus,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.b30iTimeStartBolusLabel
                                }
                            ),
                            units: state.units,
                            type: .decimal("B30iTimeStartBolus"),
                            label: AlgorithmSettingHints.b30iTimeStartBolusLabel,
                            miniHint: AlgorithmSettingHints.b30iTimeStartBolusMini,
                            verboseHint: AlgorithmSettingHints.b30iTimeStartBolusVerbose()
                        )
                        SettingInputSection(
                            decimalValue: $state.B30iTime,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.b30iTimeLabel
                                }
                            ),
                            units: state.units,
                            type: .decimal("B30iTime"),
                            label: AlgorithmSettingHints.b30iTimeLabel,
                            miniHint: AlgorithmSettingHints.b30iTimeMini,
                            verboseHint: AlgorithmSettingHints.b30iTimeVerbose()
                        )
                        SettingInputSection(
                            decimalValue: $state.B30basalFactor,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.b30basalFactorLabel
                                }
                            ),
                            units: state.units,
                            type: .decimal("B30basalFactor"),
                            label: AlgorithmSettingHints.b30basalFactorLabel,
                            miniHint: AlgorithmSettingHints.b30basalFactorMini,
                            verboseHint: AlgorithmSettingHints.b30basalFactorVerbose()
                        )
                        SettingInputSection(
                            decimalValue: $state.B30upperLimit,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.b30upperLimitLabel
                                }
                            ),
                            units: state.units,
                            type: .decimal("B30upperLimit"),
                            label: AlgorithmSettingHints.b30upperLimitLabel,
                            miniHint: AlgorithmSettingHints.b30upperLimitMini(units: state.units),
                            verboseHint: AlgorithmSettingHints.b30upperLimitVerbose(units: state.units)
                        )
                        SettingInputSection(
                            decimalValue: $state.B30upperDelta,
                            booleanValue: .constant(false),
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.b30upperDeltaLabel
                                }
                            ),
                            units: state.units,
                            type: .decimal("B30upperDelta"),
                            label: AlgorithmSettingHints.b30upperDeltaLabel,
                            miniHint: AlgorithmSettingHints.b30upperDeltaMini(units: state.units),
                            verboseHint: AlgorithmSettingHints.b30upperDeltaVerbose(units: state.units)
                        )
                    }
                } else {
                    VStack(alignment: .leading) {
                        Text(
                            "Enables an increased basal rate after an EatingSoon TT and a manual bolus to saturate the infusion site with insulin to increase insulin absorption for SMB's following a meal with no carb counting."
                        )
                        BulletList(
                            listItems: [
                                "needs an EatingSoon TempTarget (TT) with a specific GlucoseTarget",
                                "in order to activate B30 a minimum manual Bolus needs to be given",
                                "you can specify how long B30 run and how high it is",
                                "while B30 TBR runs no SMB's will be enacted",
                                "once activated you can stop the B30 TBR and allowing SMB's by just cancelling the TT"
                            ],
                            listItemSpacing: 10
                        )
                        Text(
                            "Initiating B30 can be done by Apple Shortcuts\nhttps://tinyurl.com/aimiB30shortcut\n"
                        )
                    }
                }
            }
            .sheet(isPresented: $shouldDisplayHint) {
                SettingInputHintView(
                    hintDetent: $hintDetent,
                    shouldDisplayHint: $shouldDisplayHint,
                    hintLabel: hintLabel ?? "",
                    hintText: selectedVerboseHint ?? AnyView(EmptyView()),
                    sheetTitle: "Help"
                )
            }
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .onAppear(perform: configureView)
            .navigationTitle("AIMI B30 Settings")
            .navigationBarTitleDisplayMode(.automatic)
            .settingsHighlightScroll()
        }
    }
}
