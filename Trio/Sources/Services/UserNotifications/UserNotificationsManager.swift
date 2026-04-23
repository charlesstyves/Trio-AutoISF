import AudioToolbox
import Combine
import CoreData
import Foundation
import LoopKit
import SwiftUI
import Swinject
import UIKit
import UserNotifications

protocol UserNotificationsManager {
    func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void)
    func requestNotificationPermissions(completion: @escaping (Bool) -> Void)
    @MainActor func applySnooze(for duration: TimeInterval) async
}

enum GlucoseSourceKey: String {
    case transmitterBattery
    case nightscoutPing
    case description
}

enum NotificationAction: String {
    static let key = "action"

    case snooze
    case pumpConfig
    case none
}

protocol BolusFailureObserver {
    func bolusDidFail()
}

protocol alertMessageNotificationObserver {
    func alertMessageNotification(_ message: MessageContent)
}

protocol pumpNotificationObserver {
    func pumpNotification(alert: AlertEntry)
    func pumpRemoveNotification()
}

// MARK: - SnoozeObserver Protocol

protocol SnoozeObserver {
    @MainActor func snoozeDidChange(_ untilDate: Date)
}

final class BaseUserNotificationsManager: NSObject, UserNotificationsManager, Injectable {
    enum Identifier: String {
        case glucoseNotification = "Trio.glucoseNotification"
        case carbsRequiredNotification = "Trio.carbsRequiredNotification"
        case noLoopFirstNotification = "Trio.noLoopFirstNotification"
        case noLoopSecondNotification = "Trio.noLoopSecondNotification"
        case bolusFailedNotification = "Trio.bolusFailedNotification"
        case pumpNotification = "Trio.pumpNotification"
        case alertMessageNotification = "Trio.alertMessageNotification"
    }

    @Injected() var alertPermissionsChecker: AlertPermissionsChecker!
    @Injected() private var settingsManager: SettingsManager!
    @Injected() private var broadcaster: Broadcaster!
    @Injected() private var glucoseStorage: GlucoseStorage!
    @Injected() private var apsManager: APSManager!
    @Injected() private var router: Router!

    @Injected(as: FetchGlucoseManager.self) private var sourceInfoProvider: SourceInfoProvider!

    @Persisted(key: "UserNotificationsManager.snoozeUntilDate") private var snoozeUntilDate: Date = .distantPast
    // The glucose notification observers below (Core Data saves and the storage publisher) can fire for the same
    // reading, so we persist the last alert token to avoid enqueueing identical high/low notifications multiple times.
    @Persisted(key: "UserNotificationsManager.lastGlucoseAlertToken") private var lastGlucoseAlertToken: String = ""

    private let notificationCenter = UNUserNotificationCenter.current()
    private var lifetime = Lifetime()

    private let viewContext = CoreDataStack.shared.persistentContainer.viewContext
    private let backgroundContext = CoreDataStack.shared.newTaskContext()

    // Queue for handling Core Data change notifications
    private let queue = DispatchQueue(label: "BaseUserNotificationsManager.queue", qos: .userInitiated)
    private var coreDataPublisher: AnyPublisher<Set<NSManagedObjectID>, Never>?
    private var subscriptions = Set<AnyCancellable>()

    let firstInterval = 20 // min
    let secondInterval = 40 // min

    /// Retained so schedule-activation notification responses can construct `AdaptProfile.Provider`
    /// on demand without an extra DI round-trip.
    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
        super.init()
        notificationCenter.delegate = self
        injectServices(resolver)

        coreDataPublisher =
            changedObjectsOnManagedObjectContextDidSavePublisher()
                .receive(on: queue)
                .share()
                .eraseToAnyPublisher()

        broadcaster.register(DeterminationObserver.self, observer: self)
        broadcaster.register(BolusFailureObserver.self, observer: self)
        broadcaster.register(pumpNotificationObserver.self, observer: self)
        broadcaster.register(alertMessageNotificationObserver.self, observer: self)
//        requestNotificationPermissionsIfNeeded()
        Task {
            await sendGlucoseNotification()
        }
        configureNotificationCategories()
        registerHandlers()
        registerSubscribers()
        subscribeOnLoop()
    }

    private func configureNotificationCategories() {
        notificationCenter.getNotificationCategories { [weak self] existingCategories in
            guard let self else { return }

            let glucoseCategory = NotificationCategoryFactory.createGlucoseCategory()
            let scheduleCategory = NotificationCategoryFactory.createScheduleActivationCategory()

            var categories = existingCategories
            categories.update(with: glucoseCategory)
            categories.update(with: scheduleCategory)
            // UNUserNotificationCenter methods should be called on main thread
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.notificationCenter.setNotificationCategories(categories)
            }
        }
    }

    private func subscribeOnLoop() {
        apsManager.lastLoopDateSubject
            .sink { [weak self] date in
                self?.scheduleMissingLoopNotifiactions(date: date)
            }
            .store(in: &lifetime)
    }

    private func registerHandlers() {
        // Due to the Batch insert this only is used for observing Deletion of Glucose entries
        coreDataPublisher?.filteredByEntityName("GlucoseStored").sink { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.sendGlucoseNotification()
            }
        }.store(in: &subscriptions)
    }

    private func registerSubscribers() {
        glucoseStorage.updatePublisher
            .receive(on: DispatchQueue.global(qos: .background))
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.sendGlucoseNotification()
                }
            }
            .store(in: &subscriptions)
    }

    private func addAppBadge(glucose: Int?) {
        guard let glucose = glucose, settingsManager.settings.glucoseBadge else {
            DispatchQueue.main.async {
                self.notificationCenter.setBadgeCount(0) { error in
                    guard let error else {
                        return
                    }
                    print(error)
                }
            }
            return
        }

        let badge: Int
        if settingsManager.settings.units == .mmolL {
            badge = Int(round(Double((glucose * 10).asMmolL)))
        } else {
            badge = glucose
        }

        DispatchQueue.main.async {
            self.notificationCenter.setBadgeCount(badge) { error in
                guard let error else {
                    return
                }
                print(error)
            }
        }
    }

    private func notifyCarbsRequired(_ carbs: Int) {
        guard Decimal(carbs) >= settingsManager.settings.carbsRequiredThreshold,
              settingsManager.settings.showCarbsRequiredBadge, settingsManager.settings.notificationsCarb else { return }

        var titles: [String] = []

        let content = UNMutableNotificationContent()

        if snoozeUntilDate > Date() {
            return
        }
        content.sound = .default

        titles.append(String(format: String(localized: "Carbs required: %d g", comment: "Carbs required"), carbs))

        content.title = titles.joined(separator: " ")
        content.body = String(
            format: String(
                localized:
                "To prevent LOW required %d g of carbs",
                comment: "To prevent LOW required %d g of carbs"
            ),
            carbs
        )
        addRequest(identifier: .carbsRequiredNotification, content: content, deleteOld: true, messageSubtype: .carb)
    }

    private func scheduleMissingLoopNotifiactions(date _: Date) {
        let title = String(localized: "Trio Not Active", comment: "Trio Not Active")
        let body = String(localized: "Last loop was more than %d min ago", comment: "Last loop was more than %d min ago")

        let firstContent = UNMutableNotificationContent()
        firstContent.title = title
        firstContent.body = String(format: body, firstInterval)
        firstContent.sound = .default

        let secondContent = UNMutableNotificationContent()
        secondContent.title = title
        secondContent.body = String(format: body, secondInterval)
        secondContent.sound = .default

        let firstTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * TimeInterval(firstInterval), repeats: false)
        let secondTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * TimeInterval(secondInterval), repeats: false)

        addRequest(
            identifier: .noLoopFirstNotification,
            content: firstContent,
            deleteOld: true,
            trigger: firstTrigger,
            messageType: .error,
            messageSubtype: .algorithm
        )
        addRequest(
            identifier: .noLoopSecondNotification,
            content: secondContent,
            deleteOld: true,
            trigger: secondTrigger,
            messageType: .error,
            messageSubtype: .algorithm
        )
    }

    private func notifyBolusFailure() {
        let title = String(localized: "Bolus failed", comment: "Bolus failed")
        let body = String(
            localized:
            "Bolus failed or inaccurate. Check pump history before repeating.",
            comment: "Bolus failed or inaccurate. Check pump history before repeating."
        )
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        addRequest(
            identifier: .noLoopFirstNotification,
            content: content,
            deleteOld: true,
            trigger: nil,
            messageType: .error,
            messageSubtype: .pump
        )
    }

    private func fetchGlucoseIDs() async throws -> [NSManagedObjectID] {
        let results = try await CoreDataStack.shared.fetchEntitiesAsync(
            ofType: GlucoseStored.self,
            onContext: backgroundContext,
            predicate: NSPredicate.predicateFor20MinAgo,
            key: "date",
            ascending: false,
            fetchLimit: 3
        )

        return try await backgroundContext.perform {
            guard let fetchedResults = results as? [GlucoseStored] else {
                throw CoreDataError.fetchError(function: #function, file: #file)
            }

            return fetchedResults.map(\.objectID)
        }
    }

    @MainActor private func sendGlucoseNotification() async {
        do {
            addAppBadge(glucose: nil)
            let glucoseIDs = try await fetchGlucoseIDs()
            let glucoseObjects = try glucoseIDs.compactMap { id in
                try viewContext.existingObject(with: id) as? GlucoseStored
            }

            if glucoseStorage.alarm == .none {
                lastGlucoseAlertToken = ""
            }

            guard let lastReading = glucoseObjects.first?.glucose,
                  let secondLastReading = glucoseObjects.dropFirst().first?.glucose,
                  let lastDirection = glucoseObjects.first?.directionEnum?.symbol else { return }

            addAppBadge(glucose: (glucoseObjects.first?.glucose).map { Int($0) })

            var titles: [String] = []
            var notificationAlarm = false
            var messageType = MessageType.info

            switch glucoseStorage.alarm {
            case .none:
                titles.append(String(localized: "Glucose", comment: "Glucose"))
            case .low:
                titles.append(String(localized: "LOWALERT!", comment: "LOWALERT!"))
                messageType = MessageType.warning
                notificationAlarm = true
            case .high:
                titles.append(String(localized: "HIGHALERT!", comment: "HIGHALERT!"))
                messageType = MessageType.warning
                notificationAlarm = true
            }

            let delta = glucoseObjects.count >= 2 ? lastReading - secondLastReading : nil
            let body = glucoseText(
                glucoseValue: Int(lastReading),
                delta: Int(delta ?? 0),
                direction: lastDirection
            ) + infoBody()

            if snoozeUntilDate > Date() {
                titles.append(String(localized: "(Snoozed)", comment: "(Snoozed)"))
                notificationAlarm = false
            } else {
                let token = alertToken(from: glucoseObjects.first)

                if token == "unknown" {
                    warning(.service, "Missing glucose token fields; skipping notification to avoid re-alerting")
                    return
                }
                if notificationAlarm, token == lastGlucoseAlertToken {
                    return
                }
                titles.append(body)
                let content = UNMutableNotificationContent()
                content.title = titles.joined(separator: " ")
                content.body = body

                if notificationAlarm {
                    content.sound = .default
                    content.userInfo[NotificationAction.key] = NotificationAction.snooze.rawValue
                    content.categoryIdentifier = NotificationCategoryIdentifier.trioAlert.rawValue
                }

                addRequest(
                    identifier: .glucoseNotification,
                    content: content,
                    deleteOld: true,
                    messageType: messageType,
                    messageSubtype: .glucose,
                    action: NotificationAction.snooze
                )
                if notificationAlarm {
                    lastGlucoseAlertToken = token
                }
            }
        } catch {
            debugPrint(
                "\(DebuggingIdentifiers.failed) \(#file) \(#function) Failed to send glucose notification with error: \(error)"
            )
        }
    }

    private func alertToken(from glucose: GlucoseStored?) -> String {
        if let id = glucose?.id?.uuidString { return id }

        if let date = glucose?.date {
            let roundedMinute = Int((date.timeIntervalSince1970 / 60).rounded())
            return "date-\(roundedMinute)"
        }

        // Stable fallback for Core Data objects:
        if let glucose, !glucose.objectID.isTemporaryID {
            return "objectID-\(glucose.objectID.uriRepresentation().absoluteString)"
        }

        // Stable “unknown” fallback: prevents repeated alarms when identifiers are missing
        return "unknown"
    }

    private func glucoseText(glucoseValue: Int, delta: Int?, direction: String?) -> String {
        let units = settingsManager.settings.units
        let glucoseText = glucoseFormatter
            .string(from: Double(
                units == .mmolL ? glucoseValue
                    .asMmolL : Decimal(glucoseValue)
            ) as NSNumber)! + " " + String(localized: "\(units.rawValue)", comment: "units")
        let directionText = direction ?? "↔︎"
        let deltaText = delta
            .map {
                self.deltaFormatter
                    .string(from: Double(
                        units == .mmolL ? $0
                            .asMmolL : Decimal($0)
                    ) as NSNumber)!
            } ?? "--"

        return glucoseText + " " + directionText + " " + deltaText
    }

    private func infoBody() -> String {
        var body = ""

        if settingsManager.settings.addSourceInfoToGlucoseNotifications,
           let info = sourceInfoProvider.sourceInfo()
        {
            // Description
            if let description = info[GlucoseSourceKey.description.rawValue] as? String {
                body.append("\n" + description)
            }

            // NS ping
            if let ping = info[GlucoseSourceKey.nightscoutPing.rawValue] as? TimeInterval {
                body.append(
                    "\n"
                        + String(
                            format: String(localized: "Nightscout ping: %d ms", comment: "Nightscout ping"),
                            Int(ping * 1000)
                        )
                )
            }

            // Transmitter battery
            if let transmitterBattery = info[GlucoseSourceKey.transmitterBattery.rawValue] as? Int {
                body.append(
                    "\n"
                        + String(
                            format: String(localized: "Transmitter: %@%%", comment: "Transmitter: %@%%"),
                            "\(transmitterBattery)"
                        )
                )
            }
        }
        return body
    }

    func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void) {
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completionHandler(settings)
            }
        }
    }

    func requestNotificationPermissions(completion: @escaping (Bool) -> Void) {
        debug(.service, "requestNotificationPermissions")
        notificationCenter.requestAuthorization(options: [.badge, .sound, .alert]) { granted, error in
            if granted {
                debug(.service, "requestNotificationPermissions was granted")
                DispatchQueue.main.async {
                    completion(granted)
                }
            } else {
                warning(.service, "requestNotificationPermissions failed", error: error)
            }
        }
    }

    @MainActor func applySnooze(for duration: TimeInterval) async {
        let untilDate = duration > 0 ? Date().addingTimeInterval(duration) : .distantPast
        snoozeUntilDate = untilDate
        lastGlucoseAlertToken = ""
        // removeGlucoseNotifications() is safe to call here since we're @MainActor
        removeGlucoseNotifications()

        // Notify observers that snooze was applied
        broadcaster.notify(SnoozeObserver.self, on: .main) { (observer: SnoozeObserver) in
            observer.snoozeDidChange(untilDate)
        }
    }

    private func addRequest(
        identifier: Identifier,
        content: UNMutableNotificationContent,
        deleteOld: Bool = false,
        trigger: UNNotificationTrigger? = nil,
        messageType: MessageType = MessageType.other,
        messageSubtype: MessageSubtype = MessageSubtype.misc,
        action: NotificationAction = NotificationAction.none
    ) {
        let messageCont = MessageContent(
            content: content.body,
            type: messageType,
            subtype: messageSubtype,
            title: content.title,
            useAPN: false,
            trigger: trigger,
            action: action
        )
        var alertIdentifier = identifier.rawValue
        alertIdentifier = identifier == .pumpNotification ? alertIdentifier + content
            .title : (identifier == .alertMessageNotification ? alertIdentifier + content.body : alertIdentifier)
        if deleteOld {
            DispatchQueue.main.async {
                self.notificationCenter.removeDeliveredNotifications(withIdentifiers: [alertIdentifier])
                self.notificationCenter.removePendingNotificationRequests(withIdentifiers: [alertIdentifier])
            }
        }
        if alertPermissionsChecker.notificationsDisabled {
            router.alertMessage.send(messageCont)
            return
        }
        guard router.allowNotify(messageCont, settingsManager.settings) else { return }

        let request = UNNotificationRequest(identifier: alertIdentifier, content: content, trigger: trigger)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.notificationCenter.add(request) { error in
                if let error = error {
                    warning(.service, "Unable to addNotificationRequest", error: error)
                    return
                }

                debug(.service, "Sending \(identifier) notification for \(request.content.title)")
            }
        }
    }

    private var glucoseFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        if settingsManager.settings.units == .mmolL {
            formatter.minimumFractionDigits = 1
            formatter.maximumFractionDigits = 1
        }
        formatter.roundingMode = .halfUp
        return formatter
    }

    private var deltaFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter
    }
}

extension BaseUserNotificationsManager: alertMessageNotificationObserver {
    func alertMessageNotification(_ message: MessageContent) {
        let content = UNMutableNotificationContent()
        var identifier: Identifier = .alertMessageNotification

        if message.title == "" {
            switch message.type {
            case .info:
                content.title = String(localized: "Info", comment: "Info title")
            case .warning:
                content.title = String(localized: "Warning", comment: "Warning title")
            case .error:
                content.title = String(localized: "Error", comment: "Error title")
            default:
                content.title = message.title
            }
        } else {
            content.title = message.title
        }
        switch message.subtype {
        case .pump:
            if message.type == .info || message.type == .error {
                identifier = Identifier.alertMessageNotification
            } else {
                identifier = .pumpNotification
            }
        case .carb:
            identifier = .carbsRequiredNotification
        case .glucose:
            identifier = .glucoseNotification
        case .algorithm:
            if message.trigger != nil {
                identifier = message.content.contains(String(firstInterval)) ? Identifier.noLoopFirstNotification : Identifier
                    .noLoopSecondNotification
            } else {
                identifier = Identifier.alertMessageNotification
            }
        default:
            identifier = .alertMessageNotification
        }
        switch message.action {
        case .snooze:
            content.userInfo[NotificationAction.key] = NotificationAction.snooze.rawValue
        case .pumpConfig:
            content.userInfo[NotificationAction.key] = NotificationAction.pumpConfig.rawValue
        default: break
        }

        content.body = String(localized: "\(message.content)", comment: "Info message")
        content.sound = .default
        addRequest(
            identifier: identifier,
            content: content,
            deleteOld: true,
            trigger: message.trigger,
            messageType: message.type,
            messageSubtype: message.subtype,
            action: message.action
        )
    }
}

extension BaseUserNotificationsManager: pumpNotificationObserver {
    func pumpNotification(alert: AlertEntry) {
        let content = UNMutableNotificationContent()
        let alertUp = alert.alertIdentifier.uppercased()
        let typeMessage: MessageType
        if alertUp.contains("FAULT") || alertUp.contains("ERROR") {
            content.userInfo[NotificationAction.key] = NotificationAction.pumpConfig.rawValue
            typeMessage = .error
        } else {
            typeMessage = .warning
            guard settingsManager.settings.notificationsPump else { return }
        }
        content.title = alert.contentTitle ?? "Unknown"
        content.body = alert.contentBody ?? "Unknown"
        content.sound = .default
        addRequest(
            identifier: .pumpNotification,
            content: content,
            deleteOld: true,
            trigger: nil,
            messageType: typeMessage,
            messageSubtype: .pump,
            action: .pumpConfig
        )
    }

    func pumpRemoveNotification() {
        let identifier: Identifier = .pumpNotification
        DispatchQueue.main.async {
            self.notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier.rawValue])
            self.notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier.rawValue])
        }
    }

    /// Removes all glucose notifications (delivered and pending).
    /// Must be called from the main thread. Safe to call from @MainActor contexts.
    @MainActor private func removeGlucoseNotifications() {
        let identifier = Identifier.glucoseNotification.rawValue
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

extension BaseUserNotificationsManager: DeterminationObserver {
    func determinationDidUpdate(_ determination: Determination) {
        guard let carndRequired = determination.carbsReq else { return }
        notifyCarbsRequired(Int(carndRequired))
    }
}

extension BaseUserNotificationsManager: BolusFailureObserver {
    func bolusDidFail() {
        notifyBolusFailure()
    }
}

extension BaseUserNotificationsManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound, .list])
    }

    /// UNUserNotificationCenterDelegate method called when user interacts with a notification.
    /// This can be called off the main thread, so we ensure all work happens on @MainActor.
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        debug(
            .service,
            "NotificationResponse: actionIdentifier=\(response.actionIdentifier) category=\(response.notification.request.content.categoryIdentifier)"
        )

        // Handle quick snooze actions (from notification action buttons)
        if let quickAction = NotificationResponseAction(rawValue: response.actionIdentifier) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.applySnooze(for: quickAction.duration)
            }
            return
        }

        // Handle schedule-activation actions (indefinite schedule fires via PR 5 Flow B).
        if response.notification.request.content.categoryIdentifier
            == NotificationCategoryIdentifier.scheduleActivation.rawValue
        {
            if let scheduleAction = ScheduleNotificationAction(rawValue: response.actionIdentifier) {
                handleScheduleActivationResponse(action: scheduleAction, notification: response.notification)
            } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                // User tapped the notification body — open an in-app dialog so they can pick
                // Save to pump / Skip without having to long-press the notification.
                handleScheduleActivationDefaultTap(notification: response.notification)
            }
            return
        }

        // Handle other notification actions (e.g., tapping notification body)
        guard let actionRaw = response.notification.request.content.userInfo[NotificationAction.key] as? String,
              let action = NotificationAction(rawValue: actionRaw)
        else { return }

        // Ensure UI operations happen on main thread using Task for consistency
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            switch action {
            case .snooze:
                self.router.mainModalScreen.send(.snooze)
            case .pumpConfig:
                let messageCont = MessageContent(
                    content: response.notification.request.content.body,
                    type: MessageType.other,
                    subtype: .pump,
                    useAPN: false,
                    action: .pumpConfig
                )
                self.router.alertMessage.send(messageCont)
            default: break
            }
        }
    }

    /// Responds to user interaction on a scheduled-activation notification.
    /// - `.confirm` → navigates to AdaptProfile and broadcasts `didConfirmScheduleActivation` so
    ///   the root view can present the pump-save confirmation pre-filled for the target profile.
    /// - `.skip` → marks the occurrence as fired on `ProfileScheduleStored` without activation,
    ///   so the firer's next sweep doesn't re-post the notification.
    private func handleScheduleActivationResponse(
        action: ScheduleNotificationAction,
        notification: UNNotification
    ) {
        let info = notification.request.content.userInfo
        guard
            let scheduleRaw = info[ScheduleNotificationUserInfoKey.scheduleID] as? String,
            let scheduleID = UUID(uuidString: scheduleRaw),
            let profileRaw = info[ScheduleNotificationUserInfoKey.profileID] as? String,
            let profileID = UUID(uuidString: profileRaw),
            let occurrenceEpoch = info[ScheduleNotificationUserInfoKey.occurrenceEpoch] as? Double
        else {
            debug(.service, "Schedule notification payload malformed; ignoring")
            return
        }
        let occurrence = Date(timeIntervalSince1970: occurrenceEpoch)

        debug(.service, "ScheduledActivation: response action=\(action.rawValue) schedule=\(scheduleID)")
        switch action {
        case .confirm:
            runScheduledActivation(
                scheduleID: scheduleID,
                profileID: profileID,
                occurrence: occurrence
            )
        case .skip:
            markScheduleOccurrenceSkipped(scheduleID: scheduleID, occurrence: occurrence)
        }
    }

    /// Default-tap on the notification body (no explicit action button chosen). Navigates to
    /// AdaptProfile and broadcasts the request so RootView can present a Save-to-pump / Skip
    /// dialog. This is distinct from the explicit `.confirm` / `.skip` action buttons, which run
    /// directly without an in-app prompt.
    private func handleScheduleActivationDefaultTap(notification: UNNotification) {
        let info = notification.request.content.userInfo
        guard
            let scheduleRaw = info[ScheduleNotificationUserInfoKey.scheduleID] as? String,
            let scheduleID = UUID(uuidString: scheduleRaw),
            let profileRaw = info[ScheduleNotificationUserInfoKey.profileID] as? String,
            let profileID = UUID(uuidString: profileRaw),
            let occurrenceEpoch = info[ScheduleNotificationUserInfoKey.occurrenceEpoch] as? Double
        else {
            debug(.service, "ScheduledActivation default-tap: malformed payload")
            return
        }
        let occurrence = Date(timeIntervalSince1970: occurrenceEpoch)
        debug(.service, "ScheduledActivation: default-tap routing to AdaptProfile for schedule=\(scheduleID)")
        // Stash the request first so AdaptProfile.StateModel picks it up regardless of whether
        // it's already alive (Foundation notification path) or about to spin up (drain on
        // subscribe). Navigate afterwards so the new RootView sees the mailbox populated.
        ScheduledActivationMailbox.enqueue(
            scheduleID: scheduleID,
            profileID: profileID,
            occurrence: occurrence
        )
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.router.mainModalScreen.send(.adaptProfile)
            Foundation.NotificationCenter.default.post(
                name: .didTapScheduleNotification,
                object: nil,
                userInfo: [
                    ScheduleNotificationUserInfoKey.scheduleID: scheduleID,
                    ScheduleNotificationUserInfoKey.profileID: profileID,
                    ScheduleNotificationUserInfoKey.occurrenceEpoch: occurrenceEpoch
                ]
            )
        }
    }

    /// Performs the indefinite activation directly from the notification-action tap. The
    /// notification body already explained what "Save to pump" does, so we don't need a second
    /// in-app confirmation — tapping the action IS the confirmation. Clears the schedule's
    /// `pendingOccurrence` either way so the firer moves on.
    private func runScheduledActivation(scheduleID: UUID, profileID: UUID, occurrence: Date) {
        debug(.service, "ScheduledActivation: confirm received for schedule=\(scheduleID) profile=\(profileID)")
        Task { @MainActor [weak self] in
            guard let self else { return }
            let provider = AdaptProfile.Provider(resolver: self.resolver)
            await provider.markScheduleActivated(scheduleID: scheduleID, occurrence: occurrence)
            debug(.service, "ScheduledActivation: markScheduleActivated done")
            let outcome = await provider.activate(
                id: profileID,
                durationMinutes: nil,
                confirmedPumpSync: true
            )
            debug(.service, "ScheduledActivation: activate outcome=\(outcome)")
            Foundation.NotificationCenter.default.post(
                name: .didUpdateProfileSchedules,
                object: nil
            )
        }
    }

    /// Stamps `lastFiredAt = occurrence` and clears `pendingOccurrence` so the firer's next sweep
    /// treats the occurrence as handled and moves on to the next one. Runs on a background context;
    /// the `didUpdateProfileSchedules` broadcast refreshes open schedule lists.
    private func markScheduleOccurrenceSkipped(scheduleID: UUID, occurrence: Date) {
        let context = CoreDataStack.shared.newTaskContext()
        context.perform {
            let request = ProfileScheduleStored.fetch(.scheduleByID(scheduleID), fetchLimit: 1)
            guard let row = (try? context.fetch(request))?.first else { return }
            row.lastFiredAt = occurrence
            row.pendingOccurrence = nil
            try? context.save()
            Task { @MainActor in
                Foundation.NotificationCenter.default.post(
                    name: .didUpdateProfileSchedules,
                    object: nil
                )
            }
        }
    }
}
