import SwiftUI
import Swinject

extension ProfileScheduler {
    struct RootView: BaseView {
        let resolver: Resolver
        @State var state = StateModel()
        @State private var showNewSchedule = false
        @State private var selectedForDelete: ProfileScheduleListItem?
        @State private var isConfirmDeletePresented = false

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        private static let nextFireFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEE, dd.MM. HH:mm"
            return f
        }()

        var body: some View {
            List {
                if state.schedules.isEmpty, !state.isLoading {
                    emptyState
                } else {
                    schedulesSection
                }
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Schedules")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await state.refresh() }
            .onAppear(perform: configureView)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        state.startNewDraft()
                        showNewSchedule = true
                    }, label: {
                        HStack {
                            Text("Add Schedule")
                            Image(systemName: "plus")
                        }
                    })
                }
            }
            .sheet(isPresented: $showNewSchedule) {
                NewScheduleView(state: state, onDismiss: { showNewSchedule = false })
            }
        }

        private var emptyState: some View {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No schedules yet")
                        .font(.headline)
                    Text("Tap + to schedule an automatic profile switch.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
            .listRowBackground(Color.clear)
        }

        private var schedulesSection: some View {
            Section {
                ForEach(state.schedules) { item in
                    row(for: item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                selectedForDelete = item
                                isConfirmDeletePresented = true
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                                    .tint(.red)
                            }
                            Button {
                                state.toggleEnabled(item)
                            } label: {
                                if item.enabled {
                                    Label("Disable", systemImage: "pause.circle.fill")
                                        .tint(.blue)
                                } else {
                                    Label("Enable", systemImage: "play.circle.fill")
                                        .tint(.blue)
                                }
                            }
                        }
                }
                .confirmationDialog(
                    "Delete this schedule?",
                    isPresented: $isConfirmDeletePresented,
                    titleVisibility: .visible
                ) {
                    if let target = selectedForDelete {
                        Button("Delete", role: .destructive) {
                            state.delete(target)
                            selectedForDelete = nil
                        }
                    }
                    Button("Cancel", role: .cancel) { selectedForDelete = nil }
                }
                .listRowBackground(Color.chart)
            } header: {
                Text("Active schedules")
            } footer: {
                HStack {
                    Image(systemName: "hand.draw.fill").foregroundStyle(.primary)
                    Text(
                        "Swipe left to enable, disable, or delete. Enabled schedules are sorted by next fire; disabled ones sink to the bottom."
                    )
                }
            }
        }

        @ViewBuilder private func row(for item: ProfileScheduleListItem) -> some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline(for: item))
                        .font(.body)
                        .foregroundColor(item.enabled ? .primary : .secondary)
                    Text(subline(for: item))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    if let next = item.nextFire {
                        Text(Self.nextFireFormatter.string(from: next))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if !item.enabled {
                        Text("Disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }

        private func headline(for item: ProfileScheduleListItem) -> String {
            let repeatText = ProfileScheduleSummary.repeatText(item.repeatRule)
            let timeText = ProfileScheduleSummary.timesText(item.firesAt, for: item.repeatRule)
            if timeText.isEmpty { return repeatText }
            return "\(repeatText) • \(timeText)"
        }

        private func subline(for item: ProfileScheduleListItem) -> String {
            let profile = item.profileName
            let dur = ProfileScheduleSummary.durationText(item.duration)
            return "\(profile) • \(dur)"
        }
    }
}

/// One-line summary helpers used by the list row + preview sentence in the picker.
enum ProfileScheduleSummary {
    static func repeatText(_ rule: ProfileSchedule.Repeat) -> String {
        switch rule {
        case let .weekdays(days):
            if days.count == 7 { return "Every day" }
            if days == [.monday, .tuesday, .wednesday, .thursday, .friday] { return "Weekdays" }
            if days == [.saturday, .sunday] { return "Weekends" }
            if days.isEmpty { return "No days selected" }
            let sorted = days.sorted { $0.rawValue < $1.rawValue }
            return "Weekly on " + sorted.map(shortName(_:)).joined(separator: ", ")
        case let .monthlyDays(days):
            if days.isEmpty { return "No days selected" }
            let sorted = days.sorted()
            return "Monthly on \(sorted.map(String.init).joined(separator: ", "))"
        case let .once(date):
            let f = DateFormatter()
            f.dateFormat = "EEE, dd.MM.yyyy HH:mm"
            return "Once on \(f.string(from: date))"
        }
    }

    static func timesText(_ times: [ProfileSchedule.TimeOfDay], for rule: ProfileSchedule.Repeat) -> String {
        if case .once = rule { return "" }
        if times.isEmpty { return "" }
        return "at " + times.map { String(format: "%02d:%02d", $0.hour, $0.minute) }.joined(separator: " & ")
    }

    static func durationText(_ duration: ProfileSchedule.Duration) -> String {
        switch duration {
        case let .minutes(m):
            let h = m / 60
            let mm = m % 60
            if h == 0 { return "for \(mm) min" }
            if mm == 0 { return "for \(h) h" }
            return "for \(h) h \(mm) min"
        case .indefinite,
             .untilNext:
            return "until next change"
        }
    }

    /// Locale-aware 3-letter weekday abbreviation (e.g. "Mon" / "Mo." / "月").
    static func shortName(_ w: ProfileSchedule.Weekday) -> String {
        let symbols = shortStandaloneWeekdaySymbols
        let index = w.rawValue - 1 // Calendar.weekday: Sunday=1
        return index >= 0 && index < symbols.count ? symbols[index] : "?"
    }

    /// Locale-aware single-letter weekday for chip buttons (e.g. "M" / "L" / "月").
    static func singleLetter(_ w: ProfileSchedule.Weekday) -> String {
        let symbols = veryShortStandaloneWeekdaySymbols
        let index = w.rawValue - 1
        return index >= 0 && index < symbols.count ? symbols[index] : "?"
    }

    private static var shortStandaloneWeekdaySymbols: [String] {
        let f = DateFormatter()
        f.locale = .current
        return f.shortStandaloneWeekdaySymbols ?? []
    }

    private static var veryShortStandaloneWeekdaySymbols: [String] {
        let f = DateFormatter()
        f.locale = .current
        return f.veryShortStandaloneWeekdaySymbols ?? []
    }
}
