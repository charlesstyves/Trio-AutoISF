import SwiftUI

extension ProfileScheduler {
    /// iOS Calendar-style custom repeat editor. Segmented picker for Weekly / Monthly / Once,
    /// plus the corresponding detail control.
    struct CustomRepeatView: View {
        @Bindable var state: StateModel
        @Binding var onceDate: Date

        @State private var kind: Kind = .weekly

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        enum Kind: String, CaseIterable, Identifiable {
            case weekly = "Weekly"
            case monthly = "Monthly"
            case once = "Once"
            var id: String { rawValue }
        }

        var body: some View {
            List {
                Section {
                    Picker("Kind", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.chart)

                switch kind {
                case .weekly: weeklySection
                case .monthly: monthlySection
                case .once: onceSection
                }
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Custom Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                kind = currentKind()
            }
        }

        private func currentKind() -> Kind {
            switch state.draft.repeatRule {
            case .weekdays: return .weekly
            case .monthlyDays: return .monthly
            case .once: return .once
            }
        }

        // MARK: - Weekly

        private var weeklySection: some View {
            Section {
                let binding = Binding<Set<ProfileSchedule.Weekday>>(
                    get: {
                        if case let .weekdays(s) = state.draft.repeatRule { return s }
                        return []
                    },
                    set: { state.draft.repeatRule = .weekdays($0) }
                )
                HStack(spacing: 6) {
                    ForEach(orderedWeekdays, id: \.self) { day in
                        WeekdayChip(day: day, isOn: binding.wrappedValue.contains(day)) {
                            var s = binding.wrappedValue
                            if s.contains(day) { s.remove(day) } else { s.insert(day) }
                            binding.wrappedValue = s
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } header: {
                Text("Weekdays")
            } footer: {
                Text("Pick any combination. Example: M/W/F fires three times a week.")
            }
            .listRowBackground(Color.chart)
        }

        private var orderedWeekdays: [ProfileSchedule.Weekday] {
            [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        }

        // MARK: - Monthly

        private var monthlySection: some View {
            Section {
                let binding = Binding<Set<Int>>(
                    get: {
                        if case let .monthlyDays(s) = state.draft.repeatRule { return s }
                        return []
                    },
                    set: { state.draft.repeatRule = .monthlyDays($0) }
                )
                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(1 ... 31, id: \.self) { day in
                        MonthDayCell(day: day, isOn: binding.wrappedValue.contains(day)) {
                            var s = binding.wrappedValue
                            if s.contains(day) { s.remove(day) } else { s.insert(day) }
                            binding.wrappedValue = s
                        }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text("Days of month")
            } footer: {
                Text("Days that don't exist in a given month (e.g. 31 in February) are skipped.")
            }
            .listRowBackground(Color.chart)
        }

        // MARK: - Once

        private var onceSection: some View {
            Section {
                DatePicker(
                    "Date & time",
                    selection: Binding(
                        get: { onceDate },
                        set: { new in
                            onceDate = new
                            state.draft.repeatRule = .once(new)
                        }
                    ),
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
            } header: {
                Text("One-off")
            } footer: {
                Text("Fires once at the chosen date and time, then the schedule is removed.")
            }
            .listRowBackground(Color.chart)
        }
    }

    struct WeekdayChip: View {
        let day: ProfileSchedule.Weekday
        let isOn: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                Text(ProfileScheduleSummary.shortName(day).prefix(1))
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(isOn ? Color.accentColor : Color.clear)
                    )
                    .overlay(
                        Circle().strokeBorder(isOn ? Color.accentColor : Color.secondary, lineWidth: 1)
                    )
                    .foregroundColor(isOn ? .white : .primary)
            }
            .buttonStyle(.plain)
        }
    }

    struct MonthDayCell: View {
        let day: Int
        let isOn: Bool
        let toggle: () -> Void

        var body: some View {
            Button(action: toggle) {
                Text("\(day)")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 6).fill(isOn ? Color.accentColor : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isOn ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .foregroundColor(isOn ? .white : .primary)
            }
            .buttonStyle(.plain)
        }
    }
}
