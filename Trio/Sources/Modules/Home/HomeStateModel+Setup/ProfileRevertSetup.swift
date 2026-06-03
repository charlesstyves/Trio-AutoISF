import CoreData
import Foundation

extension Home.StateModel {
    /// Reverts the currently-active timed AdaptProfile to its `previousProfileID`.
    /// Under the anchor rule (see AdaptProfileProvider.activate) `previousProfileID`
    /// always points at the last indefinite profile — i.e. the basal schedule already
    /// on the pump. We pass `skipPumpSync: true` so activate doesn't issue a redundant
    /// write of the same schedule the pump already holds.
    @MainActor func revertActiveProfile() async {
        guard let resolver = resolver else { return }
        let context = CoreDataStack.shared.newTaskContext()
        let previousID: UUID? = await context.perform {
            let req = ProfileStored.fetch(.activeProfile, fetchLimit: 1)
            return (try? context.fetch(req).first)?.previousProfileID
        }
        guard let previousID = previousID else { return }

        let provider = AdaptProfile.Provider(resolver: resolver)
        _ = await provider.activate(
            id: previousID,
            durationMinutes: nil,
            confirmedPumpSync: true,
            skipPumpSync: true
        )
    }
}
