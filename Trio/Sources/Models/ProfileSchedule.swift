import Foundation

/// Value types backing `ProfileScheduleStored`. Kept deliberately small — the scheduler supports
/// weekday-based repeats, day-of-month repeats, and one-off dates. Anchor-relative intervals
/// ("every N days from anchor") are intentionally out of scope; see the design discussion for
/// why — users compose rhythms via weekday chips instead.
enum ProfileSchedule {}

extension ProfileSchedule {
    /// Day of week. Raw value matches `Calendar.Component.weekday` on the Gregorian calendar:
    /// Sunday = 1 … Saturday = 7. Using the same integer space avoids mapping at the
    /// `Calendar.nextDate(matching:)` boundary.
    enum Weekday: Int, Codable, CaseIterable, Hashable, Sendable {
        case sunday = 1
        case monday
        case tuesday
        case wednesday
        case thursday
        case friday
        case saturday
    }

    /// Wall-clock time of day, in 15-minute increments per UX spec. No seconds, no time zone —
    /// schedules fire in the user's current calendar.
    struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
        var hour: Int // 0...23
        var minute: Int // 0, 15, 30, 45

        static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
            (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
        }
    }

    /// How a schedule recurs. Three cases cover every UX requirement; "every N days from anchor"
    /// is deliberately omitted.
    enum Repeat: Codable, Hashable, Sendable {
        /// Fires on each selected weekday. Empty set = never fires (treated as disabled).
        case weekdays(Set<Weekday>)

        /// Fires on each selected day-of-month (1…31). Days that don't exist in a given month
        /// (e.g. 31 in February) are skipped silently for that month.
        case monthlyDays(Set<Int>)

        /// Single firing on the given date. Past dates return nil from `nextFire`.
        case once(Date)
    }

    /// How long an activation lasts after the schedule fires.
    enum Duration: Codable, Hashable, Sendable {
        /// Timed activation expressed in minutes. Algorithm compensates via temp basals; pump
        /// is not touched.
        case minutes(Int)

        /// Indefinite activation. Target profile becomes the new baseline and is written to pump.
        /// Requires user interaction at fire time (see `requiresPumpInteraction`).
        case indefinite

        /// Runs until the next scheduled change. UI collapses this with `.indefinite` — both read
        /// "until next change" — but storage distinguishes the two because `.untilNext` never
        /// writes to pump.
        case untilNext

        /// True if firing this duration must involve a user-confirmed pump write.
        var requiresPumpInteraction: Bool {
            self == .indefinite
        }
    }
}
