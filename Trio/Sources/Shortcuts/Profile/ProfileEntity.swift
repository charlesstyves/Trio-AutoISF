import AppIntents
import Foundation

/// Shortcuts-facing representation of a stored profile.
struct ProfileEntity: AppEntity, Identifiable {
    static var defaultQuery = ProfileEntityQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Profile"
}

struct ProfileEntityQuery: EntityQuery {
    func entities(for identifiers: [ProfileEntity.ID]) async throws -> [ProfileEntity] {
        await ProfileIntentRequest().fetchProfiles(ids: identifiers)
    }

    func suggestedEntities() async throws -> [ProfileEntity] {
        await ProfileIntentRequest().fetchAllProfiles()
    }
}
