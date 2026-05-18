import Combine

extension CarbRatioEditor {
    final class Provider: BaseProvider, CarbRatioEditorProvider {
        var profile: CarbRatios {
            scope.carbRatios
        }

        var isfProfile: InsulinSensitivities {
            scope.sensitivities
        }

        var csfProfile: CarbSensitivities {
            storage.retrieve(OpenAPS.Settings.carbSensitivities, as: CarbSensitivities.self)
                ?? CarbSensitivities(from: OpenAPS.defaults(for: OpenAPS.Settings.carbSensitivities))
                ?? CarbSensitivities(
                    units: .mgdL,
                    userPreferredUnits: .mgdL,
                    sensitivities: []
                )
        }

        func saveProfile(_ profile: CarbRatios) {
            scope.carbRatios = profile
        }
    }
}
