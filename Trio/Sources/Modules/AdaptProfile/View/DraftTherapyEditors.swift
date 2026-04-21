import SwiftUI

// Thin wrappers around the shared `TherapySettingEditorView` for each therapy schedule in the
// draft flow. Bindings write straight into the draft state model — no side effects.

extension AdaptProfile {
    struct DraftBasalEditor: View {
        @Bindable var state: DraftEditorStateModel

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            TherapySettingEditorView(
                items: $state.basalItems,
                unit: .unitPerHour,
                timeOptions: state.timeValues,
                valueOptions: state.basalRateValues
            )
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Basal Rates")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    struct DraftISFEditor: View {
        @Bindable var state: DraftEditorStateModel

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            TherapySettingEditorView(
                items: $state.isfItems,
                unit: state.units == .mmolL ? .mmolLPerUnit : .mgdLPerUnit,
                timeOptions: state.timeValues,
                valueOptions: state.isfRateValues
            )
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Insulin Sensitivity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    struct DraftCREditor: View {
        @Bindable var state: DraftEditorStateModel

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            TherapySettingEditorView(
                items: $state.crItems,
                unit: .gramPerUnit,
                timeOptions: state.timeValues,
                valueOptions: state.crRateValues
            )
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Carb Ratio")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    struct DraftTargetEditor: View {
        @Bindable var state: DraftEditorStateModel

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            TherapySettingEditorView(
                items: $state.targetItems,
                unit: state.units == .mmolL ? .mmolL : .mgdL,
                timeOptions: state.timeValues,
                valueOptions: state.targetRateValues
            )
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Glucose Targets")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
