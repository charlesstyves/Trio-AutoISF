import SwiftUI

extension ProfileScheduler {
    /// New-schedule picker: single-screen form with sections for Repeat / At / Profile / Duration,
    /// plus a live preview sentence. Custom repeat rules open a detail screen.
    struct NewScheduleView: View {
        @Bindable var state: StateModel
        let onDismiss: () -> Void

        @State private var showCustomRepeat = false
        @State private var durationMode: DurationMode = .hours
        @State private var durationHours: Int = 6
        @State private var durationMinutes: Int = 0
        @State private var onceDate: Date = nextHour()

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        enum DurationMode: String, CaseIterable, Identifiable {
            case hours = "Timed"
            case untilNext = "Until next change"
            var id: String { rawValue }
        }

        var body: some View {
            NavigationView {
                List {
                    previewSection
                    repeatSection
                    if !isOnce {
                        atSection
                    }
                    profileSection
                    durationSection
                }
                .listSectionSpacing(10)
                .scrollContentBackground(.hidden)
                .background(appState.trioBackgroundColor(for: colorScheme))
                .navigationTitle("New Schedule")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", action: onDismiss)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            commitDuration()
                            Task {
                                if await state.saveDraft() { onDismiss() }
                            }
                        }
                        .disabled(state.draft.validationError != nil)
                    }
                }
                .navigationDestination(isPresented: $showCustomRepeat) {
                    CustomRepeatView(state: state, onceDate: $onceDate)
                }
            }
        }

        // MARK: - Preview

        private var previewSection: some View {
            Section {
                Text(previewSentence)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.vertical, 4)
            } header: {
                Text("Summary")
            } footer: {
                if let err = state.draft.validationError {
                    Text(err).foregroundColor(.orange)
                }
            }
            .listRowBackground(Color.chart)
        }

        private var previewSentence: String {
            let rule = ProfileScheduleSummary.repeatText(state.draft.repeatRule)
            let times = ProfileScheduleSummary.timesText(state.draft.firesAt, for: state.draft.repeatRule)
            let profile = state.draft.profileID == nil ? "(pick a profile)" : state.draft.profileName
            let dur = ProfileScheduleSummary.durationText(previewDuration)
            let head = times.isEmpty ? rule : "\(rule) \(times)"
            return "\(head), activate \(profile) \(dur)."
        }

        private var previewDuration: ProfileSchedule.Duration {
            switch durationMode {
            case .hours:
                let total = durationHours * 60 + durationMinutes
                return .hours(max(1, total / 60))
            case .untilNext:
                return .untilNext
            }
        }

        private func commitDuration() {
            state.draft.duration = previewDuration
            if case .once = state.draft.repeatRule {
                state.draft.repeatRule = .once(onceDate)
            }
        }

        // MARK: - Repeat

        private var repeatSection: some View {
            Section {
                ForEach(RepeatPreset.allCases, id: \.self) { preset in
                    Button {
                        state.draft.repeatRule = preset.rule
                    } label: {
                        HStack {
                            Text(preset.title).foregroundColor(.primary)
                            Spacer()
                            if preset.matches(state.draft.repeatRule) {
                                Image(systemName: "checkmark").foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                Button {
                    showCustomRepeat = true
                } label: {
                    HStack {
                        Text("Custom…").foregroundColor(.primary)
                        Spacer()
                        if isCustom { Image(systemName: "checkmark").foregroundColor(.accentColor) }
                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Repeat")
            }
            .listRowBackground(Color.chart)
        }

        private var isCustom: Bool {
            !RepeatPreset.allCases.contains { $0.matches(state.draft.repeatRule) }
        }

        private var isOnce: Bool {
            if case .once = state.draft.repeatRule { return true }
            return false
        }

        // MARK: - At (time picker, 15-min increments)

        private var atSection: some View {
            Section {
                ForEach(Array(state.draft.firesAt.enumerated()), id: \.offset) { idx, _ in
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { dateFromTime(state.draft.firesAt[idx]) },
                            set: { state.draft.firesAt[idx] = timeFromDate($0) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                }
                if state.draft.firesAt.count < 2 {
                    Button {
                        state.draft.firesAt.append(.init(hour: 20, minute: 0))
                    } label: {
                        Label("Add a second time", systemImage: "plus.circle")
                    }
                }
                if state.draft.firesAt.count > 1 {
                    Button(role: .destructive) {
                        state.draft.firesAt.removeLast()
                    } label: {
                        Label("Remove second time", systemImage: "minus.circle")
                    }
                }
            } header: {
                Text("At")
            } footer: {
                Text("Schedules fire in 15-minute increments.")
            }
            .listRowBackground(Color.chart)
        }

        // MARK: - Profile

        private var profileSection: some View {
            Section {
                if state.availableProfiles.isEmpty {
                    Text("No profiles — create one first.")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Profile", selection: Binding(
                        get: { state.draft.profileID ?? UUID() },
                        set: { id in
                            state.draft.profileID = id
                            state.draft.profileName = state.availableProfiles
                                .first(where: { $0.id == id })?.name ?? ""
                        }
                    )) {
                        ForEach(state.availableProfiles) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                }
            } header: {
                Text("Profile")
            }
            .listRowBackground(Color.chart)
        }

        // MARK: - Duration

        private var durationSection: some View {
            Section {
                Picker("Mode", selection: $durationMode) {
                    ForEach(DurationMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if durationMode == .hours {
                    HStack {
                        Picker("Hours", selection: $durationHours) {
                            ForEach(0 ..< 25) { Text("\($0) hr").tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Minutes", selection: $durationMinutes) {
                            ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) {
                                Text("\($0) min").tag($0)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                }
            } header: {
                Text("Duration")
            } footer: {
                Text(
                    durationMode == .untilNext
                        ?
                        "Runs until another schedule changes profile, or until the profile is changed manually. Indefinite activations write the basal to pump."
                        : "Timed activations do not touch the pump; the algorithm compensates via temp basals."
                )
            }
            .listRowBackground(Color.chart)
        }

        // MARK: - Helpers

        private func dateFromTime(_ t: ProfileSchedule.TimeOfDay) -> Date {
            var comp = DateComponents()
            comp.hour = t.hour
            comp.minute = t.minute
            return Calendar.current.date(from: comp) ?? Date()
        }

        private func timeFromDate(_ d: Date) -> ProfileSchedule.TimeOfDay {
            let comp = Calendar.current.dateComponents([.hour, .minute], from: d)
            let minute = roundToFifteen(comp.minute ?? 0)
            return .init(hour: comp.hour ?? 0, minute: minute)
        }

        private func roundToFifteen(_ m: Int) -> Int {
            let rounded = Int((Double(m) / 15).rounded()) * 15
            return min(max(rounded, 0), 45)
        }

        private static func nextHour() -> Date {
            Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        }
    }

    // MARK: - Presets

    enum RepeatPreset: CaseIterable {
        case daily
        case weekdays
        case weekends

        var title: String {
            switch self {
            case .daily: return "Every day"
            case .weekdays: return "Every weekday"
            case .weekends: return "Every weekend"
            }
        }

        var rule: ProfileSchedule.Repeat {
            switch self {
            case .daily: return .weekdays(Set(ProfileSchedule.Weekday.allCases))
            case .weekdays: return .weekdays([.monday, .tuesday, .wednesday, .thursday, .friday])
            case .weekends: return .weekdays([.saturday, .sunday])
            }
        }

        func matches(_ r: ProfileSchedule.Repeat) -> Bool {
            guard case let .weekdays(set) = r, case let .weekdays(mine) = rule else { return false }
            return set == mine
        }
    }
}
