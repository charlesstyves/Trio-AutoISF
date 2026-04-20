import Foundation

struct TrioCustomOrefVariables: JSON, Equatable {
    var average_total_data: Decimal
    var currentTDD: Decimal
    var weightedAverage: Decimal
    var past2hoursAverage: Decimal
    var date: Date
    var overridePercentage: Decimal
    var useOverride: Bool
    var duration: Decimal
    var unlimited: Bool
    var overrideTarget: Decimal
    var smbIsOff: Bool
    var advancedSettings: Bool
    var isfAndCr: Bool
    var isf: Bool
    var cr: Bool
    var smbIsScheduledOff: Bool
    var start: Decimal
    var end: Decimal
    var smbMinutes: Decimal
    var uamMinutes: Decimal
    // AutoISF profile injection overrides (nil = use profile default)
    var overrideAutoISFmin: Decimal?
    var overrideAutoISFmax: Decimal?
    var overrideAutoISFhourlyChange: Decimal?
    var overrideHigherISFrangeWeight: Decimal?
    var overrideLowerISFrangeWeight: Decimal?
    var overridePostMealISFweight: Decimal?
    var overrideBgAccelISFweight: Decimal?
    var overrideBgBrakeISFweight: Decimal?
    var overrideIobThresholdPercent: Decimal?
    var overrideSmbDeliveryRatioBGrange: Decimal?
    var overrideSmbDeliveryRatioMin: Decimal?
    var overrideSmbDeliveryRatioMax: Decimal?
    var overrideEnableBGacceleration: Bool?

    init(
        average_total_data: Decimal,
        weightedAverage: Decimal,
        currentTDD: Decimal,
        past2hoursAverage: Decimal,
        date: Date,
        overridePercentage: Decimal,
        useOverride: Bool,
        duration: Decimal,
        unlimited: Bool,
        overrideTarget: Decimal,
        smbIsOff: Bool,
        advancedSettings: Bool,
        isfAndCr: Bool,
        isf: Bool,
        cr: Bool,
        smbIsScheduledOff: Bool,
        start: Decimal,
        end: Decimal,
        smbMinutes: Decimal,
        uamMinutes: Decimal,
        overrideAutoISFmin: Decimal? = nil,
        overrideAutoISFmax: Decimal? = nil,
        overrideAutoISFhourlyChange: Decimal? = nil,
        overrideHigherISFrangeWeight: Decimal? = nil,
        overrideLowerISFrangeWeight: Decimal? = nil,
        overridePostMealISFweight: Decimal? = nil,
        overrideBgAccelISFweight: Decimal? = nil,
        overrideBgBrakeISFweight: Decimal? = nil,
        overrideIobThresholdPercent: Decimal? = nil,
        overrideSmbDeliveryRatioBGrange: Decimal? = nil,
        overrideSmbDeliveryRatioMin: Decimal? = nil,
        overrideSmbDeliveryRatioMax: Decimal? = nil,
        overrideEnableBGacceleration: Bool? = nil
    ) {
        self.average_total_data = average_total_data
        self.weightedAverage = weightedAverage
        self.currentTDD = currentTDD
        self.past2hoursAverage = past2hoursAverage
        self.date = date
        self.overridePercentage = overridePercentage
        self.useOverride = useOverride
        self.duration = duration
        self.unlimited = unlimited
        self.overrideTarget = overrideTarget
        self.smbIsOff = smbIsOff
        self.advancedSettings = advancedSettings
        self.isfAndCr = isfAndCr
        self.isf = isf
        self.cr = cr
        self.smbIsScheduledOff = smbIsScheduledOff
        self.start = start
        self.end = end
        self.smbMinutes = smbMinutes
        self.uamMinutes = uamMinutes
        self.overrideAutoISFmin = overrideAutoISFmin
        self.overrideAutoISFmax = overrideAutoISFmax
        self.overrideAutoISFhourlyChange = overrideAutoISFhourlyChange
        self.overrideHigherISFrangeWeight = overrideHigherISFrangeWeight
        self.overrideLowerISFrangeWeight = overrideLowerISFrangeWeight
        self.overridePostMealISFweight = overridePostMealISFweight
        self.overrideBgAccelISFweight = overrideBgAccelISFweight
        self.overrideBgBrakeISFweight = overrideBgBrakeISFweight
        self.overrideIobThresholdPercent = overrideIobThresholdPercent
        self.overrideSmbDeliveryRatioBGrange = overrideSmbDeliveryRatioBGrange
        self.overrideSmbDeliveryRatioMin = overrideSmbDeliveryRatioMin
        self.overrideSmbDeliveryRatioMax = overrideSmbDeliveryRatioMax
        self.overrideEnableBGacceleration = overrideEnableBGacceleration
    }
}

extension TrioCustomOrefVariables {
    private enum CodingKeys: String, CodingKey {
        case average_total_data
        case weightedAverage
        case currentTDD
        case past2hoursAverage
        case date
        case overridePercentage
        case useOverride
        case duration
        case unlimited
        case overrideTarget
        case smbIsOff
        case advancedSettings
        case isfAndCr
        case isf
        case cr
        case smbIsScheduledOff
        case start
        case end
        case smbMinutes
        case uamMinutes
        case overrideAutoISFmin
        case overrideAutoISFmax
        case overrideAutoISFhourlyChange
        case overrideHigherISFrangeWeight
        case overrideLowerISFrangeWeight
        case overridePostMealISFweight
        case overrideBgAccelISFweight
        case overrideBgBrakeISFweight
        case overrideIobThresholdPercent
        case overrideSmbDeliveryRatioBGrange
        case overrideSmbDeliveryRatioMin
        case overrideSmbDeliveryRatioMax
        case overrideEnableBGacceleration
    }
}
