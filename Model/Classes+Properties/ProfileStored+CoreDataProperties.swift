import CoreData
import Foundation

public extension ProfileStored {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ProfileStored> {
        NSFetchRequest<ProfileStored>(entityName: "ProfileStored")
    }

    @NSManaged var activatedAt: Date?
    @NSManaged var createdAt: Date?
    @NSManaged var expiresAt: Date?
    @NSManaged var id: UUID?
    @NSManaged var isActive: Bool
    @NSManaged var name: String?
    @NSManaged var orderPosition: Int16
    @NSManaged var preferencesJSON: Data?
    @NSManaged var previousProfileID: UUID?
    @NSManaged var therapyJSON: Data?
}

extension ProfileStored: Identifiable {}
