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
