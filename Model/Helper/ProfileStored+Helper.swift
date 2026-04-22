import CoreData
import Foundation

/// Full therapy-settings snapshot stored inside a `ProfileStored` as JSON.
struct TherapyBundle: Codable {
    var basalProfile: [BasalProfileEntry]
    var sensitivities: InsulinSensitivities
    var carbRatios: CarbRatios
    var bgTargets: BGTargets
}

extension NSPredicate {
    /// Active profile: `isActive == true`. Kept deliberately simple (same shape as
    /// `enabled == true` on Override / TempTarget) because callers such as
    /// `AdaptProfileProvider.activate` rely on this predicate to locate the
    /// outgoing profile — including ones whose timer has just elapsed — so the
    /// deactivation/anchor bookkeeping stays correct.
    ///
    /// Display-side freshness is handled by the 5-second `timerDate` tick in
    /// HomeStateModel, which (a) re-renders the chip so the countdown stays
    /// live and (b) runs `checkExpiredProfileAndAutoRevert()` to flip
    /// `isActive` / re-activate the anchor within a sweep cycle.
    static var activeProfile: NSPredicate {
        NSPredicate(format: "isActive == %@", true as NSNumber)
    }

    static func profileByID(_ id: UUID) -> NSPredicate {
        NSPredicate(format: "id == %@", id as CVarArg)
    }
}

extension ProfileStored {
    static func fetch(
        _ predicate: NSPredicate,
        ascending: Bool = false,
        fetchLimit: Int? = nil
    ) -> NSFetchRequest<ProfileStored> {
        let request = ProfileStored.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: ascending)]
        request.predicate = predicate
        if let fetchLimit = fetchLimit {
            request.fetchLimit = fetchLimit
        }
        return request
    }

    /// Decoded therapy bundle. `nil` if unset or decode fails (caller should treat as missing).
    var therapy: TherapyBundle? {
        get {
            guard let data = therapyJSON else { return nil }
            return try? JSONCoding.decoder.decode(TherapyBundle.self, from: data)
        }
        set {
            therapyJSON = newValue.flatMap { try? JSONCoding.encoder.encode($0) }
        }
    }

    /// Decoded algorithm preferences.
    var preferences: Preferences? {
        get {
            guard let data = preferencesJSON else { return nil }
            return try? JSONCoding.decoder.decode(Preferences.self, from: data)
        }
        set {
            preferencesJSON = newValue.flatMap { try? JSONCoding.encoder.encode($0) }
        }
    }
}
