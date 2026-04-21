import Combine
import CoreData
import Observation
import SwiftUI

extension AdaptProfile {
    @Observable final class StateModel: BaseStateModel<Provider> {
        var items: [AdaptProfileListItem] = []
        var isLoading: Bool = false

        override func subscribe() {
            Task { await refresh() }
        }

        @MainActor
        func refresh() async {
            isLoading = true
            items = await provider.fetchAll()
            isLoading = false
        }

        func rename(_ item: AdaptProfileListItem, to newName: String) {
            Task {
                await provider.rename(id: item.id, to: newName)
                await refresh()
            }
        }

        func delete(_ item: AdaptProfileListItem) {
            Task {
                await provider.delete(id: item.id)
                await refresh()
            }
        }
    }
}
