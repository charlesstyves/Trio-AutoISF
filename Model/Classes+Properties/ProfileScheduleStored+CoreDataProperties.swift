import CoreData
import Foundation

public extension ProfileScheduleStored {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ProfileScheduleStored> {
        NSFetchRequest<ProfileScheduleStored>(entityName: "ProfileScheduleStored")
    }

    @NSManaged var createdAt: Date?
    @NSManaged var durationJSON: Data?
    @NSManaged var enabled: Bool
    @NSManaged var firesAtJSON: Data?
    @NSManaged var id: UUID?
    @NSManaged var lastFiredAt: Date?
    @NSManaged var name: String?
    @NSManaged var orderPosition: Int16
    @NSManaged var pendingOccurrence: Date?
    @NSManaged var profileID: UUID?
    @NSManaged var repeatRuleJSON: Data?
}

extension ProfileScheduleStored: Identifiable {}
