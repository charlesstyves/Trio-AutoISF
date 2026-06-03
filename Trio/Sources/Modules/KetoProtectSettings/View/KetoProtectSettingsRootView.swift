import SwiftUI
import Swinject

extension KetoProtectSettings {
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
                            booleanValue: $state.ketoProtect,
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.ketoProtectLabel
                                }
                            ),
                            units: state.units,
                            type: .boolean,
                            label: AlgorithmSettingHints.ketoProtectLabel,
                            miniHint: AlgorithmSettingHints.ketoProtectMini,
                            verboseHint: AlgorithmSettingHints.ketoProtectVerbose()
                        )
                    }
                )
                if state.ketoProtect {
                    Section(
                        header: Text("Strategy Definition"),
                        content: {
                            SettingInputSection(
                                decimalValue: .constant(0),
                                booleanValue: $state.variableKetoProtect,
                                shouldDisplayHint: $shouldDisplayHint,
                                selectedVerboseHint: Binding(
                                    get: { selectedVerboseHint },
                                    set: {
                                        selectedVerboseHint = $0.map { AnyView($0) }
                                        hintLabel = AlgorithmSettingHints.variableKetoProtectLabel
                                    }
                                ),
                                units: state.units,
                                type: .boolean,
                                label: AlgorithmSettingHints.variableKetoProtectLabel,
                                miniHint: AlgorithmSettingHints.variableKetoProtectMini,
                                verboseHint: AlgorithmSettingHints.variableKetoProtectVerbose()
                            )
                        }
                    )
                    if state.variableKetoProtect {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(
                                "To understand the Variable Keto Protection Strategy, read up on IOB and active Insulin (activity):"
                            )

                            SwiftUI.Link(
                                "OpenAPS on IOB and Activity calculations",
                                destination: URL(
                                    string: "https://openaps.readthedocs.io/en/latest/docs/While%20You%20Wait%20For%20Gear/understanding-insulin-on-board-calculations.html?highlight=final%20note#understanding-insulin-on-board-iob-calculations"
                                )!
                            )
                            .accentColor(.blue)
                        }
                        .multilineTextAlignment(.leading)
                    }

                    Section(
                        header: Text("Settings for protective TBR"),
                        content: {
                            if !state.ketoProtectAbsolut {
                                SettingInputSection(
                                    decimalValue: $state.ketoProtectBasalPercent,
                                    booleanValue: .constant(false),
                                    shouldDisplayHint: $shouldDisplayHint,
                                    selectedVerboseHint: Binding(
                                        get: { selectedVerboseHint },
                                        set: {
                                            selectedVerboseHint = $0.map { AnyView($0) }
                                            hintLabel = AlgorithmSettingHints.ketoProtectBasalPercentLabel
                                        }
                                    ),
                                    units: state.units,
                                    type: .decimal("ketoProtectBasalPercent"),
                                    label: AlgorithmSettingHints.ketoProtectBasalPercentLabel,
                                    miniHint: AlgorithmSettingHints.ketoProtectBasalPercentMini,
                                    verboseHint: AlgorithmSettingHints.ketoProtectBasalPercentVerbose()
                                )
                            }
                            SettingInputSection(
                                decimalValue: .constant(0),
                                booleanValue: $state.ketoProtectAbsolut,
                                shouldDisplayHint: $shouldDisplayHint,
                                selectedVerboseHint: Binding(
                                    get: { selectedVerboseHint },
                                    set: {
                                        selectedVerboseHint = $0.map { AnyView($0) }
                                        hintLabel = AlgorithmSettingHints.ketoProtectAbsolutLabel
                                    }
                                ),
                                units: state.units,
                                type: .boolean,
                                label: AlgorithmSettingHints.ketoProtectAbsolutLabel,
                                miniHint: AlgorithmSettingHints.ketoProtectAbsolutMini,
                                verboseHint: AlgorithmSettingHints.ketoProtectAbsolutVerbose()
                            )
                            if state.ketoProtectAbsolut {
                                SettingInputSection(
                                    decimalValue: $state.ketoProtectBasalAbsolut,
                                    booleanValue: .constant(false),
                                    shouldDisplayHint: $shouldDisplayHint,
                                    selectedVerboseHint: Binding(
                                        get: { selectedVerboseHint },
                                        set: {
                                            selectedVerboseHint = $0.map { AnyView($0) }
                                            hintLabel = AlgorithmSettingHints.ketoProtectBasalAbsolutLabel
                                        }
                                    ),
                                    units: state.units,
                                    type: .decimal("ketoProtectBasalAbsolut"),
                                    label: AlgorithmSettingHints.ketoProtectBasalAbsolutLabel,
                                    miniHint: AlgorithmSettingHints.ketoProtectBasalAbsolutMini,
                                    verboseHint: AlgorithmSettingHints.ketoProtectBasalAbsolutVerbose()
                                )
                            }
                        }
                    )

                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(
                            "Ketoacidosis protection applies a small safety Temp Basal Rate continuously or under specific conditions (Variable Strategy) to reduce ketoacidosis risk."
                        )
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom)

                        Text(
                            "To understand the Variable Keto Protection Strategy, read up on IOB and active Insulin (activity):"
                        )
                        SwiftUI.Link(
                            "OpenAPS documentation",
                            destination: URL(
                                string: "https://openaps.readthedocs.io/en/latest/docs/While%20You%20Wait%20For%20Gear/understanding-insulin-on-board-calculations.html?highlight=final%20note#understanding-insulin-on-board-iob-calculations"
                            )!
                        )
                        .accentColor(.blue)
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
            .navigationTitle("KetoProtect Settings")
            .navigationBarTitleDisplayMode(.automatic)
            .settingsHighlightScroll()
        }
    }
}
