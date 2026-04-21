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
                    NSSortDescriptor(key: "isActive", ascending: false),
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
                            expiresAt: profile.expiresAt
                        )
                    }
                } catch {
                    debug(.coreData, "AdaptProfileProvider.fetchAll failed: \(error)")
                    return []
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
                    let newID = UUID()
                    let profile = ProfileStored(context: context)
                    profile.id = newID
                    profile.name = trimmed
                    profile.createdAt = Date()
                    profile.isActive = false
                    profile.activatedAt = nil
                    profile.expiresAt = nil
                    profile.previousProfileID = nil
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
