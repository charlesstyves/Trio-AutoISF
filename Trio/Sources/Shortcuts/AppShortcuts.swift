import AppIntents
import Foundation

struct AppShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] {
//        AppShortcut(
//            intent: BolusIntent(),
//            phrases: [
//                "\(.applicationName) bolus",
//                "Enacts a \(.applicationName) Bolus"
//            ],
//            shortTitle: "Enact Bolus",
//            systemImageName: "drop.circle"
//        )
        AppShortcut(
            intent: ApplyTempPresetIntent(),
            phrases: [
                "Activate \(.applicationName) temporary target ?",
                "\(.applicationName) apply a temporary target"
            ],
            shortTitle: "Activate TT",
            systemImageName: "arrow.up.circle.badge.clock"
        )
        AppShortcut(
            intent: ScheduleTempPresetIntent(),
            phrases: [
                "Schedule \(.applicationName) temporary target",
                "\(.applicationName) schedule a temporary target preset"
            ],
            shortTitle: "Schedule TT",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: ListStateIntent(),
            phrases: [
                "List \(.applicationName) state",
                "\(.applicationName) state"
            ],
            shortTitle: "List State",
            systemImageName: "list.bullet.circle"
        )
        AppShortcut(
            intent: AddCarbPresetIntent(),
            phrases: [
                "Add carbs in \(.applicationName)",
                "\(.applicationName) allows to add carbs"
            ],
            shortTitle: "Add Carbs",
            systemImageName: "fork.knife.circle"
        )
        AppShortcut(
            intent: ApplyOverridePresetIntent(),
            phrases: [
                "Activate \(.applicationName) override",
                "Activates an available \(.applicationName) override"
            ],
            shortTitle: "Activate Override",
            systemImageName: "clock.arrow.2.circlepath"
        )
        AppShortcut(
            intent: CancelOverrideIntent(),
            phrases: [
                "Cancel \(.applicationName) override",
                "Cancels an active \(.applicationName) override"
            ],
            shortTitle: "Cancel Override",
            systemImageName: "xmark.square.fill"
        )
        AppShortcut(
            intent: CancelTempPresetIntent(),
            phrases: [
                "Cancel \(.applicationName) Temp Target",
                "Cancels an active \(.applicationName) Temp Target"
            ],
            shortTitle: "Cancel TT",
            systemImageName: "xmark.square"
        )
        AppShortcut(
            intent: ApplyProfileIntent(),
            phrases: [
                "Activate \(.applicationName) profile",
                "Activates a \(.applicationName) profile for a limited time"
            ],
            shortTitle: "Activate Profile (timed)",
            systemImageName: "person.crop.circle.badge.checkmark"
        )
        AppShortcut(
            intent: ScheduleProfileOnceIntent(),
            phrases: [
                "Schedule \(.applicationName) profile",
                "Schedules a \(.applicationName) profile to activate at a chosen time for a limited duration"
            ],
            shortTitle: "Schedule Profile (timed)",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: CreateCustomTempTargetIntent(),
            phrases: [
                "Create a \(.applicationName) Temporary Target",
                "\(.applicationName) create temporary target"
            ],
            shortTitle: "Create TT",
            systemImageName: "scope"
        )
        AppShortcut(
            intent: ScheduleCustomTempTargetIntent(),
            phrases: [
                "Schedule a custom \(.applicationName) Temporary Target",
                "\(.applicationName) schedule custom temporary target"
            ],
            shortTitle: "Schedule custom TT",
            systemImageName: "calendar.badge.plus"
        )
        AppShortcut(
            intent: RestartLiveActivityIntent(),
            phrases: [
                "Restart \(.applicationName) Live Activity",
                "Restarts the Live Activity for \(.applicationName)"
            ],
            shortTitle: "Restart Live Activity",
            systemImageName: "arrow.clockwise.circle.fill"
        )
    }
}
