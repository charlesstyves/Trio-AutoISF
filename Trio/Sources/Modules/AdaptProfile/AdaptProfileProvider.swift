import CoreData
import Foundation

extension AdaptProfile {
    final class Provider: BaseProvider, AdaptProfileProvider {
        private let coreDataStack = CoreDataStack.shared

        func fetchAll() async -> [AdaptProfileListItem] {
            let context = coreDataStack.newTaskContext()
            return await context.perform {
                let request: NSFetchRequest<ProfileStored> = ProfileStored.fetchRequest()
                request.sortDescriptors = [
                    NSSortDescriptor(key: "orderPosition", ascending: true),
                    NSSortDescriptor(key: "createdAt", ascending: false)
                ]
                do {
                    let rows = try context.fetch(request)
                    return rows.compactMap { profile -> AdaptProfileListItem? in
                        guard let id = profile.id else { return nil }
                        return AdaptProfileListItem(
                            id: id,
                            name: profile.name ?? "Unnamed",
                            createdAt: profile.createdAt ?? .distantPast,
                            isActive: profile.isActive,
                            expiresAt: profile.expiresAt,
                            orderPosition: profile.orderPosition
                        )
                    }
                } catch {
                    debug(.coreData, "AdaptProfileProvider.fetchAll failed: \(error)")
                    return []
                }
            }
        }

        func applyOrdering(_ orderedIDs: [UUID]) async {
            let context = coreDataStack.newTaskContext()
            await context.perform {
                do {
                    let request: NSFetchRequest<ProfileStored> = ProfileStored.fetchRequest()
                    request.predicate = NSPredicate(format: "id IN %@", orderedIDs)
                    let rows = try context.fetch(request)
                    let byID = Dictionary(uniqueKeysWithValues: rows.compactMap { row -> (UUID, ProfileStored)? in
                        guard let id = row.id else { return nil }
                        return (id, row)
                    })
                    for (index, id) in orderedIDs.enumerated() {
                        byID[id]?.orderPosition = Int16(index + 1)
                    }
                    if context.hasChanges {
                        try context.save()
                    }
                } catch {
                    debug(.coreData, "AdaptProfileProvider.applyOrdering failed: \(error)")
                }
            }
        }

        func rename(id: UUID, to newName: String) async {
            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let context = coreDataStack.newTaskContext()
            await context.perform {
                do {
                    let request = ProfileStored.fetch(.profileByID(id), fetchLimit: 1)
                    guard let profile = try context.fetch(request).first else { return }
                    profile.name = trimmed
                    try context.save()
                } catch {
                    debug(.coreData, "AdaptProfileProvider.rename failed: \(error)")
                }
            }
        }

        func delete(id: UUID) async {
            let context = coreDataStack.newTaskContext()
            await context.perform {
                do {
                    let request = ProfileStored.fetch(.profileByID(id), fetchLimit: 1)
                    guard let profile = try context.fetch(request).first else { return }
                    if profile.isActive {
                        debug(.coreData, "AdaptProfileProvider.delete: refusing to delete active profile")
                        return
                    }
                    context.delete(profile)
                    try context.save()
                } catch {
                    debug(.coreData, "AdaptProfileProvider.delete failed: \(error)")
                }
            }
        }

        var supportedBasalRates: [Decimal]? {
            deviceManager.pumpManager?.supportedBasalRates.map { Decimal($0) }
        }

        func saveNewProfile(name: String, preferences: Preferences, therapy: TherapyBundle) async -> UUID? {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let context = coreDataStack.newTaskContext()
            return await context.perform { () -> UUID? in
                do {
                    let request: NSFetchRequest<ProfileStored> = ProfileStored.fetchRequest()
                    request.sortDescriptors = [NSSortDescriptor(key: "orderPosition", ascending: false)]
                    request.fetchLimit = 1
                    let maxOrder = (try? context.fetch(request).first?.orderPosition) ?? 0

                    let newID = UUID()
                    let profile = ProfileStored(context: context)
                    profile.id = newID
                    profile.name = trimmed
                    profile.createdAt = Date()
                    profile.isActive = false
                    profile.activatedAt = nil
                    profile.expiresAt = nil
                    profile.previousProfileID = nil
                    profile.orderPosition = maxOrder + 1
                    profile.preferences = preferences
                    profile.therapy = therapy
                    try context.save()
                    return newID
                } catch {
                    debug(.coreData, "AdaptProfileProvider.saveNewProfile failed: \(error)")
                    return nil
                }
            }
        }
    }
}
