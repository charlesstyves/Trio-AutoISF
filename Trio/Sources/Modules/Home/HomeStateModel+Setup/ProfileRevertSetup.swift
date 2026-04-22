import CoreData
import Foundation

extension Home.StateModel {
    /// Reverts the currently-active timed AdaptProfile to its `previousProfileID`.
    /// Timed activations keep the pump untouched, so reverting to an indefinite
    /// predecessor typically skips pump sync (basal already matches).
    @MainActor func revertActiveProfile() async {
        guard let resolver = resolver else { return }
        let context = CoreDataStack.shared.newTaskContext()
        let previousID: UUID? = await context.perform {
            let req = ProfileStored.fetch(.activeProfile, fetchLimit: 1)
            return (try? context.fetch(req).first)?.previousProfileID
        }
        guard let previousID = previousID else { return }

        let provider = AdaptProfile.Provider(resolver: resolver)
        _ = await provider.activate(id: previousID, durationHours: nil, confirmedPumpSync: true)
    }
}
