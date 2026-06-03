import Foundation

extension TargetsEditor {
    final class Provider: BaseProvider, TargetsEditorProvider {
        var profile: BGTargets {
            var retrieved = scope.bgTargets

            // migrate existing mmol/L Trio users from mmol/L settings to pure mg/dl settings
            if retrieved.units == .mmolL || retrieved.userPreferredUnits == .mmolL {
                let converted = retrieved.targets.map { target in
                    BGTargetEntry(
                        low: storage.parseSettingIfMmolL(value: target.low),
                        high: storage.parseSettingIfMmolL(value: target.high),
                        start: target.start,
                        offset: target.offset
                    )
                }
                retrieved = BGTargets(units: .mgdL, userPreferredUnits: .mgdL, targets: converted)
                saveProfile(retrieved)
            }

            return retrieved
        }

        func saveProfile(_ profile: BGTargets) {
            scope.bgTargets = profile
        }
    }
}
