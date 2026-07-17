import Foundation

extension ISFEditor {
    final class Provider: BaseProvider, ISFEditorProvider {
        var profile: InsulinSensitivities {
            var retrieved = scope.sensitivities

            // migrate existing mmol/L Trio users from mmol/L settings to pure mg/dl settings
            if retrieved.units == .mmolL || retrieved.userPreferredUnits == .mmolL {
                let converted = retrieved.sensitivities.map { isf in
                    InsulinSensitivityEntry(
                        sensitivity: storage.parseSettingIfMmolL(value: isf.sensitivity),
                        offset: isf.offset,
                        start: isf.start
                    )
                }
                retrieved = InsulinSensitivities(
                    units: .mgdL,
                    userPreferredUnits: .mgdL,
                    sensitivities: converted
                )
                saveProfile(retrieved)
            }

            return retrieved
        }

        func saveProfile(_ profile: InsulinSensitivities) {
            scope.sensitivities = profile
        }
    }
}
