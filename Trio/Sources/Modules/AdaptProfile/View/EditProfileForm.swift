import SwiftUI

extension AdaptProfile {
    /// Edit sheet opened from the swipe action. For now it supports rename only; activation and
    /// deeper profile editing are attached in later steps.
    struct EditProfileForm: View {
        @Bindable var state: StateModel
        let item: AdaptProfileListItem
        let onDismiss: () -> Void

        @State private var nameText: String
        @State private var isSaving = false

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        init(state: StateModel, item: AdaptProfileListItem, onDismiss: @escaping () -> Void) {
            self.state = state
            self.item = item
            self.onDismiss = onDismiss
            _nameText = State(initialValue: item.name)
        }

        var body: some View {
            NavigationView {
                List {
                    Section {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("Profile name", text: $nameText)
                                .multilineTextAlignment(.trailing)
                                .textInputAutocapitalization(.words)
                        }
                    }
                    .listRowBackground(Color.chart)

                    saveSection
                }
                .listSectionSpacing(10)
                .scrollContentBackground(.hidden)
                .background(appState.trioBackgroundColor(for: colorScheme))
                .navigationTitle("Edit Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", action: onDismiss)
                    }
                }
            }
        }

        private var saveSection: some View {
            let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasChanges = trimmed != item.name
            let invalid = trimmed.isEmpty || !hasChanges || isSaving

            return Section {
                Button {
                    isSaving = true
                    state.rename(item, to: trimmed)
                    onDismiss()
                } label: {
                    Text("Save")
                }
                .disabled(invalid)
                .frame(maxWidth: .infinity, alignment: .center)
                .tint(.white)
            }
            .listRowBackground(invalid ? Color(.systemGray4) : Color(.systemBlue))
        }
    }
}
