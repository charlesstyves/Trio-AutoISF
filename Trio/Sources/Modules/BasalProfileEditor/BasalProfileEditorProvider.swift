import Combine
import Foundation
import LoopKit

extension BasalProfileEditor {
    final class Provider: BaseProvider, BasalProfileEditorProvider {
        @Injected() var settingsManager: SettingsManager!

        private let processQueue = DispatchQueue(label: "BasalProfileEditorProvider.processQueue")

        var profile: [BasalProfileEntry] {
            scope.basalProfile
        }

        var supportedBasalRates: [Decimal]? {
            deviceManager.pumpManager?.supportedBasalRates.map { Decimal($0) }
        }

        func saveProfile(_ profile: [BasalProfileEntry]) -> AnyPublisher<Void, Error> {
            guard let pump = deviceManager?.pumpManager else {
                debugPrint("\(DebuggingIdentifiers.failed) No pump found; cannot save basal profile!")
                return Fail(error: NSError()).eraseToAnyPublisher()
            }

            let syncValues = profile.map {
                RepeatingScheduleValue(
                    startTime: TimeInterval($0.minutes * 60),
                    value: Double($0.rate) / Double(settingsManager.settings.insulinConcentration)
                )
            }

            return Future { promise in
                pump.syncBasalRateSchedule(items: syncValues) { result in
                    switch result {
                    case .success:
                        self.scope.basalProfile = profile
                        promise(.success(()))
                    case let .failure(error):
                        promise(.failure(error))
                    }
                }
            }.eraseToAnyPublisher()
        }
    }
}
