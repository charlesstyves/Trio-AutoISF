import CoreData
import Foundation
import LoopKit

extension AdaptProfile {
    final class Provider: BaseProvider, AdaptProfileProvider {
        @Injected() private var apsManager: APSManager!
        @Injected() private var settingsManager: SettingsManager!
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
                    // Build a lookup of id → (name, preferences, bgTargets) so each row can
                    // reference its source profile without triggering repeated fetches.
                    struct SourceSnapshot {
                        let name: String
                        let preferences: Preferences?
                        let bgTargets: BGTargets?
                    }
                    let byID: [UUID: SourceSnapshot] = rows.reduce(into: [:]) { dict, p in
                        guard let id = p.id else { return }
                        dict[id] = SourceSnapshot(
                            name: p.name ?? "Unnamed",
                            preferences: p.preferences,
                            bgTargets: p.therapy?.bgTargets
                        )
                    }

                    return rows.compactMap { profile -> AdaptProfileListItem? in
                        guard let id = profile.id else { return nil }
                        let source = profile.sourceProfileID.flatMap { byID[$0] }
                        let profilePrefs = profile.preferences
                        let profileTargets = profile.therapy?.bgTargets

                        let prefsChanged: Bool = {
                            guard let source = source, let sp = source.preferences else { return false }
                            return profilePrefs != sp
                        }()
                        let targetsChanged: Bool = {
                            guard let source = source, let st = source.bgTargets else { return false }
                            return profileTargets?.targets != st.targets
                        }()

                        let applied = profile.appliedPercent?.decimalValue ?? 100
                        return AdaptProfileListItem(
                            id: id,
                            name: profile.name ?? "Unnamed",
                            createdAt: profile.createdAt ?? .distantPast,
                            isActive: profile.isActive,
                            expiresAt: profile.expiresAt,
                            orderPosition: profile.orderPosition,
                            sourceProfileName: source?.name,
                            appliedPercent: applied,
                            preferencesChangedFromSource: prefsChanged,
                            targetsChangedFromSource: targetsChanged,
                            previousProfileID: profile.previousProfileID
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

        func activate(id: UUID, durationMinutes: Int?, confirmedPumpSync: Bool) async -> ActivationOutcome {
            let context = coreDataStack.newTaskContext()
            context.name = "AdaptProfileActivateContext"
            context.transactionAuthor = "AdaptProfileActivate"

            // Step 1: load target profile's decoded snapshot + active-profile metadata (all on the
            // context queue — we don't carry the NSManagedObject outside).
            let loaded: (
                preferences: Preferences,
                therapy: TherapyBundle,
                oldActiveID: UUID?,
                oldAnchorID: UUID?
            )? = await context.perform { () -> (Preferences, TherapyBundle, UUID?, UUID?)? in
                let req = ProfileStored.fetch(.profileByID(id), fetchLimit: 1)
                guard let target = try? context.fetch(req).first,
                      let prefs = target.preferences,
                      let therapy = target.therapy
                else {
                    return nil
                }
                let activeReq = ProfileStored.fetch(.activeProfile, fetchLimit: 1)
                let oldActive = try? context.fetch(activeReq).first
                return (prefs, therapy, oldActive?.id, oldActive?.previousProfileID)
            }

            guard let loaded = loaded else {
                return .failed(String(localized: "Profile not found."))
            }

            // Step 2: pump-sync decision. Only indefinite activations that would change the basal
            // schedule require a pump write; timed activations keep the pump schedule untouched.
            let isIndefinite = (durationMinutes == nil)
            let basalDiffers = scope.basalProfile != loaded.therapy.basalProfile
            let needsPumpSync = isIndefinite && basalDiffers

            if needsPumpSync, !confirmedPumpSync {
                return .needsPumpConfirm
            }

            // Step 3: pump sync (indefinite + basal changed + user confirmed).
            if needsPumpSync {
                guard let pump = deviceManager?.pumpManager else {
                    return .pumpSyncFailed(String(localized: "No pump manager available."))
                }
                let concentration = settingsManager.settings.insulinConcentration
                let syncValues = loaded.therapy.basalProfile.map {
                    RepeatingScheduleValue(
                        startTime: TimeInterval($0.minutes * 60),
                        value: Double($0.rate) / Double(concentration)
                    )
                }
                do {
                    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                        pump.syncBasalRateSchedule(items: syncValues) { result in
                            switch result {
                            case .success: cont.resume()
                            case let .failure(error): cont.resume(throwing: error)
                            }
                        }
                    }
                } catch {
                    return .pumpSyncFailed(error.localizedDescription)
                }
            }

            // Step 4: flip Core Data on the VIEW context so SwiftUI `@FetchRequest` consumers
            // (Home's active-profile banner) pick up the change immediately. A background
            // context save would require a subsequent merge — viewContext has
            // `automaticallyMergesChangesFromParent = false` so @FetchRequest would stay stale
            // until persistent-history notifications caught up, which is why the Home banner
            // showed the previous profile until the next loop tick.
            let viewContext = coreDataStack.persistentContainer.viewContext
            let flipped: Bool = await viewContext.perform { () -> Bool in
                do {
                    let activeReq = ProfileStored.fetch(.activeProfile)
                    let actives = try viewContext.fetch(activeReq)
                    for p in actives where p.id != id {
                        p.isActive = false
                        p.activatedAt = nil
                        p.expiresAt = nil
                    }
                    let targetReq = ProfileStored.fetch(.profileByID(id), fetchLimit: 1)
                    guard let target = try viewContext.fetch(targetReq).first else { return false }
                    target.isActive = true
                    target.activatedAt = Date()
                    target.expiresAt = durationMinutes.map { Date().addingTimeInterval(TimeInterval($0) * 60) }
                    // Anchor rule: indefinite activations clear previousProfileID (this profile
                    // is now the pump baseline). Timed activations inherit the outgoing profile's
                    // anchor, or fall back to the outgoing profile's id if it didn't have one.
                    // This guarantees reverting/stopping any temp always returns to the profile
                    // whose basal is on the pump — chains of temps can't sneak unfamiliar basal
                    // onto the pump.
                    if isIndefinite {
                        target.previousProfileID = nil
                    } else {
                        target.previousProfileID = loaded.oldAnchorID ?? loaded.oldActiveID
                    }
                    try viewContext.save()
                    return true
                } catch {
                    debug(.coreData, "AdaptProfileProvider.activate CoreData flip failed: \(error)")
                    return false
                }
            }

            guard flipped else {
                return .failed(String(localized: "Failed to update profile state."))
            }

            // Step 5: write live settings. Order: preferences first, then therapy. The mirror will
            // re-write the same data into the now-active profile — harmless no-op.
            scope.preferences = loaded.preferences
            scope.basalProfile = loaded.therapy.basalProfile
            scope.sensitivities = loaded.therapy.sensitivities
            scope.carbRatios = loaded.therapy.carbRatios
            scope.bgTargets = loaded.therapy.bgTargets

            // Step 6: trigger a loop iteration so the algorithm picks up the new profile.
            do {
                try await apsManager.determineBasalSync()
            } catch {
                debug(.default, "AdaptProfileProvider.activate loop trigger failed: \(error)")
                // non-fatal — activation itself succeeded
            }

            return .success
        }

        func updateProfile(
            id: UUID,
            name: String,
            preferences: Preferences,
            therapy: TherapyBundle
        ) async -> Bool {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            let context = coreDataStack.newTaskContext()
            context.name = "AdaptProfileUpdateContext"
            return await context.perform {
                do {
                    let req = ProfileStored.fetch(.profileByID(id), fetchLimit: 1)
                    guard let profile = try context.fetch(req).first else { return false }
                    profile.name = trimmed
                    profile.preferences = preferences
                    profile.therapy = therapy
                    try context.save()
                    return true
                } catch {
                    debug(.coreData, "AdaptProfileProvider.updateProfile failed: \(error)")
                    return false
                }
            }
        }

        func loadProfileContent(id: UUID) async -> LoadedProfileContent? {
            let context = coreDataStack.newTaskContext()
            return await context.perform { () -> LoadedProfileContent? in
                let req = ProfileStored.fetch(.profileByID(id), fetchLimit: 1)
                guard let profile = try? context.fetch(req).first,
                      let profileID = profile.id,
                      let prefs = profile.preferences,
                      let therapy = profile.therapy
                else { return nil }

                var sourceName: String?
                if let sourceID = profile.sourceProfileID {
                    let srcReq = ProfileStored.fetch(.profileByID(sourceID), fetchLimit: 1)
                    sourceName = (try? context.fetch(srcReq).first)?.name
                }

                return LoadedProfileContent(
                    id: profileID,
                    name: profile.name ?? "",
                    preferences: prefs,
                    therapy: therapy,
                    sourceProfileID: profile.sourceProfileID,
                    sourceProfileName: sourceName,
                    appliedPercent: profile.appliedPercent?.decimalValue ?? 100
                )
            }
        }

        func saveNewProfile(
            name: String,
            preferences: Preferences,
            therapy: TherapyBundle,
            sourceProfileID: UUID?,
            appliedPercent: Decimal
        ) async -> UUID? {
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
                    profile.sourceProfileID = sourceProfileID
                    profile.appliedPercent = NSDecimalNumber(decimal: appliedPercent)
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
