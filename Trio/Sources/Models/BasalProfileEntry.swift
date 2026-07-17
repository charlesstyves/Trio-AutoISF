import Foundation

struct BasalProfileEntry: JSON, Equatable {
    let start: String
    let minutes: Int
    let rate: Decimal
}

protocol BasalProfileObserver {
    func basalProfileDidChange(_ basalProfile: [BasalProfileEntry])
}

extension BasalProfileEntry {
    private enum CodingKeys: String, CodingKey {
        case start
        case minutes
        case rate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = try container.decode(String.self, forKey: .start)
        let minutes = try container.decode(Int.self, forKey: .minutes)
        let rate = try container.decode(Double.self, forKey: .rate).decimal ?? .zero

        self = BasalProfileEntry(start: start, minutes: minutes, rate: rate)
    }
}

extension Array where Element == BasalProfileEntry {
    /// Calculate total daily basal rate in units per day
    var totalDailyBasal: Decimal {
        var total: Decimal = 0
        for (i, entry) in enumerated() {
            let nextMinutes = i + 1 < count ? self[i + 1].minutes : 24 * 60
            let hours = Decimal(nextMinutes - entry.minutes) / 60
            total += entry.rate * hours
        }
        return total
    }
}
