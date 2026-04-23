import SwiftUI

extension ProfileScheduler {
    /// New-schedule picker. Sections in order: Profile → Repeat → Time → Duration, plus a live
    /// preview sentence. Repeat presets collapse into a single dropdown; Custom pushes to a
    /// sub-screen for weekday / monthly / once selection.
    struct NewScheduleView: View {
        @Bindable var state: StateModel
        let onDismiss: () -> Void

        @State private var showCustomRepeat = false
        @State private var durationMode: DurationMode = .hours
        @State private var durationHours: Int = 6
        @State private var durationMinutes: Int = 0
        @State private var onceDate: Date = nextHour()

        @State private var showTimePicker = false
        @State private var showDurationPicker = false
        @State private var selectedPreset: RepeatPreset = .daily

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        enum DurationMode: String, CaseIterable, Identifiable {
            case hours = "Timed"
            case untilNext = "Until next change"
            var id: String { rawValue }
        }

        var body: some View {
            NavigationStack {
                List {
                    previewSection
                    profileSection
                    repeatSection
                    if !isOnce {
                        timeSection
                    }
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
                .onAppear {
                    syncPresetFromDraft()
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

        // MARK: - Profile

        private var profileSection: some View {
            Section {
                if state.availableProfiles.isEmpty {
                    Text("No profiles — create one first.")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Profile", selection: Binding(
                        get: { state.draft.profileID ?? state.availableProfiles.first?.id ?? UUID() },
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
                    .pickerStyle(.menu)
                }
            } header: {
                Text("Profile")
            }
            .listRowBackground(Color.chart)
        }

        // MARK: - Repeat (dropdown + Custom row)

        private var repeatSection: some View {
            Section {
                Picker("Repeat", selection: $selectedPreset) {
                    ForEach(RepeatPreset.allCases, id: \.self) { p in
                        Text(p.title).tag(p)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPreset) { _, new in
                    state.draft.repeatRule = new.rule
                }

                Button {
                    showCustomRepeat = true
                } label: {
                    HStack {
                        Text("Custom…").foregroundColor(.primary)
                        Spacer()
                        if isCustom {
                            Text(ProfileScheduleSummary.repeatText(state.draft.repeatRule))
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
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

        private func syncPresetFromDraft() {
            // If draft is in a blank/initial state, default to the selected preset so the summary
            // sentence makes sense from the first render.
            if case let .weekdays(set) = state.draft.repeatRule, set.isEmpty {
                state.draft.repeatRule = selectedPreset.rule
                return
            }
            if let match = RepeatPreset.allCases.first(where: { $0.matches(state.draft.repeatRule) }) {
                selectedPreset = match
            }
        }

        // MARK: - Time (collapsible, 15-min UIDatePicker)

        private var timeSection: some View {
            Section {
                HStack {
                    Text("At")
                    Spacer()
                    Text(timeLabel)
                        .foregroundColor(showTimePicker ? .accentColor : .primary)
                        .onTapGesture { showTimePicker.toggle() }
                }
                if showTimePicker {
                    CustomTimeOnlyPicker(
                        selection: Binding(
                            get: { dateFromTime(state.draft.firesAt.first ?? .init(hour: 8, minute: 0)) },
                            set: { state.draft.firesAt = [timeFromDate($0)] }
                        ),
                        // TODO: restore to 15 after live-testing firing. 1-min for fast test cycles.
                        minuteInterval: 1
                    )
                    .frame(height: 160)
                }
            } header: {
                Text("Time")
            }
            .listRowBackground(Color.chart)
        }

        private var timeLabel: String {
            guard let t = state.draft.firesAt.first else { return "Tap to set" }
            return String(format: "%02d:%02d", t.hour, t.minute)
        }

        // MARK: - Duration (collapsible wheels, 5-min)

        private var durationSection: some View {
            Section {
                Picker("Mode", selection: $durationMode) {
                    ForEach(DurationMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if durationMode == .hours {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formatHM(hours: durationHours, minutes: durationMinutes))
                            .foregroundColor(showDurationPicker ? .accentColor : .primary)
                            .onTapGesture { showDurationPicker.toggle() }
                    }
                    if showDurationPicker {
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
                }
            } header: {
                Text("Duration")
            } footer: {
                Text(
                    durationMode == .untilNext
                        ?
                        "Runs until another schedule changes the profile, or until changed manually. Indefinite activations write the basal to pump."
                        : "Timed activations do not touch the pump; the algorithm compensates via temp basals."
                )
            }
            .listRowBackground(Color.chart)
        }

        private func formatHM(hours: Int, minutes: Int) -> String {
            if hours == 0, minutes == 0 { return "Tap to set" }
            if minutes == 0 { return "\(hours) hr" }
            if hours == 0 { return "\(minutes) min" }
            return "\(hours) hr \(minutes) min"
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
            return .init(hour: comp.hour ?? 0, minute: comp.minute ?? 0)
        }

        private static func nextHour() -> Date {
            Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        }
    }

    // MARK: - Presets

    enum RepeatPreset: CaseIterable, Hashable {
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

/// Time-of-day UIDatePicker wrapper (no date component, fixed minute interval). Mirrors
/// `CustomDateTimePicker` but `.time` mode and no `maximumDate` — schedules are future-facing.
struct CustomTimeOnlyPicker: UIViewRepresentable {
    @Binding var selection: Date
    var minuteInterval: Int

    class Coordinator: NSObject {
        var parent: CustomTimeOnlyPicker
        init(_ parent: CustomTimeOnlyPicker) { self.parent = parent }
        @objc func dateChanged(_ sender: UIDatePicker) { parent.selection = sender.date }
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.minuteInterval = minuteInterval
        picker.preferredDatePickerStyle = .wheels
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context _: Context) {
        uiView.date = selection
        uiView.minuteInterval = minuteInterval
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }
}
