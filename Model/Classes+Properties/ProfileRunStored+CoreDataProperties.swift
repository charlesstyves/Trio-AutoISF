import CoreData
import Foundation

public extension ProfileRunStored {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ProfileRunStored> {
        NSFetchRequest<ProfileRunStored>(entityName: "ProfileRunStored")
    }

    @NSManaged var endDate: Date?
    @NSManaged var id: UUID?
    @NSManaged var isUploadedToNS: Bool
    @NSManaged var name: String?
    @NSManaged var startDate: Date?
    @NSManaged var profile: ProfileStored?
}

extension ProfileRunStored: Identifiable {}
