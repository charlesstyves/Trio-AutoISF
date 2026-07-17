import SlideButton
import SwiftUI

extension AdaptProfile {
    /// Sheet presented when the user taps a non-active profile row. Requires the user to
    /// explicitly choose a duration (no default) and slide to activate — mirrors the OmniBLE
    /// "Slide to Insert Cannula" deliberate-acceptance pattern.
    struct ActivateProfileView: View {
        let profile: AdaptProfileListItem
        @Bindable var state: StateModel
        let onDismiss: () -> Void

        @State private var indefinite: Bool = false
        @State private var durationHours: Int = 0
        @State private var durationMinutes: Int = 0
        @State private var displayPickerDuration: Bool = false
        @State private var showPumpConfirm = false
        @State private var errorMessage: String?
        @State private var isActivating = false

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        var body: some View {
            NavigationView {
                List {
                    nameSection
                    durationSection
                    slideSection
                }
                .listSectionSpacing(10)
                .scrollContentBackground(.hidden)
                .background(appState.trioBackgroundColor(for: colorScheme))
                .navigationTitle("Activate Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", action: onDismiss)
                    }
                }
                .alert("Save basal to pump?", isPresented: $showPumpConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Save to pump") {
                        Task { await performActivation(confirmedPumpSync: true) }
                    }
                } message: {
                    Text(
                        "An indefinite activation updates the pump's scheduled basal to match this profile. The pump's basal schedule will be overwritten."
                    )
                }
                .alert(
                    "Activation failed",
                    isPresented: Binding(
                        get: { errorMessage != nil },
                        set: { if !$0 { errorMessage = nil } }
                    )
                ) {
                    Button("OK") { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
            }
        }

        // MARK: - Sections

        private var nameSection: some View {
            Section {
                HStack {
                    Text("Profile")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(profile.name).bold()
                }
            }
            .listRowBackground(Color.chart)
        }

        private var durationSection: some View {
            Section {
                Toggle(isOn: $indefinite) {
                    Text("Enable Indefinitely")
                }
                .onChange(of: indefinite) { _, newValue in
                    if newValue {
                        displayPickerDuration = false
                    }
                }

                if !indefinite {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatHoursAndMinutes(hours: durationHours, minutes: durationMinutes))
                            .foregroundColor(!displayPickerDuration ? .primary : .accentColor)
                            .onTapGesture {
                                displayPickerDuration.toggle()
                            }
                    }

                    if displayPickerDuration {
                        HStack {
                            Picker("Hours", selection: $durationHours) {
                                ForEach(0 ..< 25) { hour in
                                    Text("\(hour) hr").tag(hour)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(maxWidth: .infinity)

                            Picker("Minutes", selection: $durationMinutes) {
                                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { minute in
                                    Text("\(minute) min").tag(minute)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(maxWidth: .infinity)
                        }
                        .listRowSeparator(.hidden, edges: .top)
                    }
                }
            } header: {
                Text("Duration")
            } footer: {
                Text(
                    "Indefinite activations push the basal schedule to the pump. Timed activations (up to 24 h) keep the pump untouched — the algorithm compensates via temp basals, same as overrides — and auto-revert when they expire."
                )
            }
            .listRowBackground(Color.chart)
        }

        private func formatHoursAndMinutes(hours: Int, minutes: Int) -> String {
            if hours == 0, minutes == 0 {
                return String(
                    localized: "Tap to set",
                    comment: "Placeholder on activation duration row when the user hasn't chosen hours or minutes yet"
                )
            }
            if hours ==
                0 { return String(localized: "\(minutes) min", comment: "Activation duration row — duration in minutes only") }
            if minutes ==
                0 { return String(localized: "\(hours) hr", comment: "Activation duration row — duration in whole hours") }
            return String(
                localized: "\(hours) hr \(minutes) min",
                comment: "Activation duration row — duration in hours and minutes"
            )
        }

        private var slideSection: some View {
            Section {
                SlideButton(
                    styling: .init(textShimmers: canActivate),
                    action: {
                        await performActivation(confirmedPumpSync: false)
                    }
                ) {
                    Text(slideLabel)
                }
                .disabled(!canActivate || isActivating)
            } footer: {
                if !canActivate {
                    Text("Enable Indefinitely or set a duration greater than zero.")
                        .foregroundColor(.secondary)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        }

        private var totalMinutes: Int { durationHours * 60 + durationMinutes }

        private var canActivate: Bool {
            indefinite || totalMinutes > 0
        }

        private var slideLabel: String {
            if indefinite { return String(
                localized: "Slide to activate indefinitely",
                comment: "Slide-to-confirm button label when user chose indefinite activation"
            ) }
            if totalMinutes > 0 {
                return String(
                    localized: "Slide to activate for \(formatHoursAndMinutes(hours: durationHours, minutes: durationMinutes))",
                    comment: "Slide-to-confirm button label — the interpolated value is a formatted duration like '3 hr 15 min'"
                )
            }
            return String(
                localized: "Choose a duration first",
                comment: "Slide-to-confirm button label shown (disabled) when no duration is set and indefinite is off"
            )
        }

        // MARK: - Activation driver

        private func performActivation(confirmedPumpSync: Bool) async {
            isActivating = true
            let minutesArg: Int? = indefinite ? nil : totalMinutes
            let outcome = await state.activate(
                id: profile.id,
                durationMinutes: minutesArg,
                confirmedPumpSync: confirmedPumpSync
            )
            isActivating = false
            switch outcome {
            case .success:
                onDismiss()
            case .needsPumpConfirm:
                showPumpConfirm = true
            case let .pumpSyncFailed(msg):
                errorMessage = msg
            case let .failed(msg):
                errorMessage = msg
            }
        }
    }
}
