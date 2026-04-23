import SwiftUI
import Swinject

extension ProfileScheduler {
    struct RootView: BaseView {
        let resolver: Resolver
        @State var state = StateModel()
        @State private var showNewSchedule = false

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
                        Image(systemName: "plus")
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
                            Button(role: .destructive) {
                                state.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                state.toggleEnabled(item)
                            } label: {
                                if item.enabled {
                                    Label("Disable", systemImage: "pause.circle")
                                } else {
                                    Label("Enable", systemImage: "play.circle")
                                }
                            }
                            .tint(.orange)
                        }
                }
            } header: {
                Text("Active schedules")
            } footer: {
                Text("Swipe a row to disable or delete. Upcoming fires are shown on the Profiles screen.")
            }
            .listRowBackground(Color.chart)
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
            return sorted.map(shortName(_:)).joined(separator: " ")
        case let .monthlyDays(days):
            if days.isEmpty { return "No days selected" }
            let sorted = days.sorted()
            return "Monthly on \(sorted.map(String.init).joined(separator: ", "))"
        case let .once(date):
            let f = DateFormatter()
            f.dateFormat = "EEE, dd.MM.yyyy"
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
        case let .hours(h): return "for \(h) h"
        case .indefinite,
             .untilNext: return "until next change"
        }
    }

    static func shortName(_ w: ProfileSchedule.Weekday) -> String {
        switch w {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }
}
