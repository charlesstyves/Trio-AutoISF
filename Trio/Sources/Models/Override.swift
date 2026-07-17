import Foundation

struct Override {
    let name: String
    let enabled: Bool
    let date: Date
    let duration: Decimal
    let indefinite: Bool
    let percentage: Double
    let smbIsOff: Bool
    let isPreset: Bool
    let id: String
    let overrideTarget: Bool
    let target: Decimal
    let advancedSettings: Bool
    let isfAndCr: Bool
    let isf: Bool
    let cr: Bool
    let smbIsScheduledOff: Bool
    let start: Decimal
    let end: Decimal
    let smbMinutes: Decimal
    let uamMinutes: Decimal
    // AutoISF profile injection (nil = use profile default)
    let autoISFmin: Decimal?
    let autoISFmax: Decimal?
    let autoISFhourlyChange: Decimal?
    let higherISFrangeWeight: Decimal?
    let lowerISFrangeWeight: Decimal?
    let postMealISFweight: Decimal?
    let bgAccelISFweight: Decimal?
    let bgBrakeISFweight: Decimal?
    let iobThresholdPercent: Decimal?
    let smbDeliveryRatio: Decimal?
    let smbDeliveryRatioBGrange: Decimal?
    let smbDeliveryRatioMin: Decimal?
    let smbDeliveryRatioMax: Decimal?
    let enableBGacceleration: Bool?
}
