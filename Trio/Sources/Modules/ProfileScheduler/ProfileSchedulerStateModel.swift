import Foundation
import Observation
import SwiftUI

extension ProfileScheduler {
    @Observable final class StateModel: BaseStateModel<Provider> {
        var schedules: [ProfileScheduleListItem] = []
        var availableProfiles: [ProfilePickerChoice] = []
        var isLoading: Bool = false

        var draft = ProfileScheduleDraft()

        override func subscribe() {
            Task { await refresh() }
            Foundation.NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleSchedulesUpdated),
                name: .didUpdateProfileSchedules,
                object: nil
            )
        }

        @objc private func handleSchedulesUpdated() {
            Task { @MainActor in await refresh() }
        }

        @MainActor func refresh() async {
            isLoading = true
            async let schedulesTask = provider.fetchAllSchedules()
            async let profilesTask = provider.fetchProfiles()
            schedules = await schedulesTask
            availableProfiles = await profilesTask
            isLoading = false
        }

        @MainActor func startNewDraft() {
            draft = ProfileScheduleDraft()
            // Default to a one-off schedule an hour from now — simplest case, no configuration
            // beyond picking a date+time.
            let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            draft.repeatRule = .once(nextHour)
            // Pre-select the currently active profile as a sensible default.
            if let active = availableProfiles.first(where: { $0.isActive }) {
                draft.profileID = active.id
                draft.profileName = active.name
            }
        }

        @MainActor func saveDraft() async -> Bool {
            guard draft.validationError == nil else { return false }
            let id = await provider.saveNewSchedule(draft)
            if id != nil { await refresh() }
            return id != nil
        }

        func toggleEnabled(_ item: ProfileScheduleListItem) {
            Task {
                await provider.setEnabled(id: item.id, enabled: !item.enabled)
                await refresh()
            }
        }

        func delete(_ item: ProfileScheduleListItem) {
            Task {
                await provider.deleteSchedule(id: item.id)
                await refresh()
            }
        }
    }
}
