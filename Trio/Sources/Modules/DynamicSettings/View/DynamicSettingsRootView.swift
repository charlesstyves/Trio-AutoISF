import SwiftUI
import Swinject

extension DynamicSettings {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State private var shouldDisplayHint: Bool = false
        @State private var showDynamicISFHint: Bool = false
        @State var hintDetent = PresentationDetent.large
        @State var selectedVerboseHint: AnyView?
        @State var hintLabel: String?
        @State private var decimalPlaceholder: Decimal = 0.0
        @State private var booleanPlaceholder: Bool = false

        private var conversionFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1

            return formatter
        }

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter
        }

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
            } else { formatter.maximumFractionDigits = 0 }
            formatter.roundingMode = .halfUp
            return formatter
        }

        var body: some View {
            List {
                Section(
                    header: Text("Dynamic Insulin Sensitivity"),
                    content: {
                        VStack(alignment: .leading) {
                            Picker(
                                selection: $state.dynamicSensitivityType,
                                label: Text("Dynamic ISF").multilineTextAlignment(.leading)
                            ) {
                                ForEach(DynamicSensitivityType.allCases) { selection in
                                    Text(selection.displayName).tag(selection)
                                }
                            }
                            .disabled(!state.hasValidTDD)
                            .padding(.top)

                            HStack(alignment: .center) {
                                let miniHintText = state.hasValidTDD ?
                                    String(
                                        localized: "Dynamically adjust insulin sensitivity using Dynamic Ratio rather than Autosens Ratio.",
                                        comment: "Mini-hint under Dynamic ISF picker on Dynamic Settings when enough TDD data exists"
                                    ) :
                                    String(
                                        localized: "Trio does not have enough closed-loop data to enable Dynamic ISF. This data collection can take up to 7 days.",
                                        comment: "Mini-hint under Dynamic ISF picker on Dynamic Settings when TDD data is insufficient (requires up to 7 days of closed-loop runs)"
                                    )
                                let miniHintTextColorForDisabled: Color = colorScheme == .dark ? .orange :
                                    .accentColor
                                let miniHintTextColor: Color = state.hasValidTDD ? .secondary : miniHintTextColorForDisabled

                                Text(miniHintText)
                                    .font(.footnote)
                                    .foregroundColor(miniHintTextColor)
                                    .lineLimit(nil)

                                Spacer()
                                Button(
                                    action: { showDynamicISFHint = true },
                                    label: {
                                        HStack {
                                            Image(systemName: "questionmark.circle")
                                        }
                                    }
                                )
                                .buttonStyle(BorderlessButtonStyle())
                                .sheet(isPresented: $showDynamicISFHint) {
                                    SettingInputHintView(
                                        hintDetent: $hintDetent,
                                        shouldDisplayHint: $showDynamicISFHint,
                                        hintLabel: AlgorithmSettingHints.dynamicISFLabel,
                                        hintText: AlgorithmSettingHints.dynamicISFVerbose(),
                                        sheetTitle: String(localized: "Help", comment: "Help sheet title")
                                    )
                                }
                            }.padding(.top)
                        }.padding(.bottom)
                    }
                ).listRowBackground(Color.chart)

                if state.dynamicSensitivityType != .disabled {
                    if state.dynamicSensitivityType == .logarithmic {
                        SettingInputSection(
                            decimalValue: $state.adjustmentFactor,
                            booleanValue: $booleanPlaceholder,
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.adjustmentFactorLabel
                                }
                            ),
                            // TODO?: include conditional links to Desmos logarithmic graphs based on which .glucose setting is used
                            units: state.units,
                            type: .decimal("adjustmentFactor"),
                            label: AlgorithmSettingHints.adjustmentFactorLabel,
                            miniHint: AlgorithmSettingHints.adjustmentFactorMini,
                            verboseHint: AlgorithmSettingHints.adjustmentFactorVerbose()
                        )

                        SettingInputSection(
                            decimalValue: $state.weightPercentage,
                            booleanValue: $booleanPlaceholder,
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.weightPercentageLabel
                                }
                            ),
                            units: state.units,
                            type: .decimal("weightPercentage"),
                            label: AlgorithmSettingHints.weightPercentageLabel,
                            miniHint: AlgorithmSettingHints.weightPercentageMini,
                            verboseHint: AlgorithmSettingHints.weightPercentageVerbose()
                        )
                    } else {
                        SettingInputSection(
                            decimalValue: $state.adjustmentFactorSigmoid,
                            booleanValue: $booleanPlaceholder,
                            shouldDisplayHint: $shouldDisplayHint,
                            selectedVerboseHint: Binding(
                                get: { selectedVerboseHint },
                                set: {
                                    selectedVerboseHint = $0.map { AnyView($0) }
                                    hintLabel = AlgorithmSettingHints.adjustmentFactorSigmoidLabel
                                }
                            ),
                            units: state.units,
                            type: .decimal("adjustmentFactorSigmoid"),
                            label: AlgorithmSettingHints.adjustmentFactorSigmoidLabel,
                            miniHint: AlgorithmSettingHints.adjustmentFactorSigmoidMini,
                            verboseHint: AlgorithmSettingHints.adjustmentFactorSigmoidVerbose()
                        )
                    }

                    SettingInputSection(
                        decimalValue: $decimalPlaceholder,
                        booleanValue: $state.tddAdjBasal,
                        shouldDisplayHint: $shouldDisplayHint,
                        selectedVerboseHint: Binding(
                            get: { selectedVerboseHint },
                            set: {
                                selectedVerboseHint = $0.map { AnyView($0) }
                                hintLabel = AlgorithmSettingHints.tddAdjBasalLabel
                            }
                        ),
                        units: state.units,
                        type: .boolean,
                        label: AlgorithmSettingHints.tddAdjBasalLabel,
                        miniHint: AlgorithmSettingHints.tddAdjBasalMini,
                        verboseHint: AlgorithmSettingHints.tddAdjBasalVerbose(),
                        headerText: String(
                            localized: "Dynamic-dependent Features",
                            comment: "Section header on Dynamic Settings grouping features that depend on Dynamic ISF being enabled (e.g. TDD basal adjustment)"
                        )
                    )
                }
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
            .navigationBarTitle("Dynamic Settings")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}
