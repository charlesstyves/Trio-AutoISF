import SwiftUI
import Swinject

extension AdaptProfile {
    struct RootView: BaseView {
        let resolver: Resolver
        @State var state = StateModel()
        @State private var showNewProfile = false
        @State private var draftEditorState: DraftEditorStateModel?
        @State private var selectedProfile: AdaptProfileListItem?
        @State private var isConfirmDeletePresented = false
        @State private var showEditSheet = false

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        private static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f
        }()

        private var activeItem: AdaptProfileListItem? {
            state.items.first(where: { $0.isActive })
        }

        private var inactiveItems: [AdaptProfileListItem] {
            state.items.filter { !$0.isActive }
        }

        var body: some View {
            List {
                if let active = activeItem {
                    currentActiveProfile(active)
                }

                if inactiveItems.isEmpty, !state.isLoading {
                    defaultText
                } else {
                    profilesSection
                }
            }
            .listSectionSpacing(10)
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await state.refresh() }
            .onAppear(perform: configureView)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        state.startNewDraft()
                        showNewProfile = true
                    }, label: {
                        HStack {
                            Text("Add Profile")
                            Image(systemName: "plus")
                        }
                    })
                }
            }
            .sheet(isPresented: $showNewProfile, onDismiss: { draftEditorState = nil }) {
                newProfileSheet
            }
            .sheet(isPresented: $showEditSheet, onDismiss: { selectedProfile = nil }) {
                if let profile = selectedProfile {
                    EditProfileForm(
                        state: state,
                        item: profile,
                        onDismiss: { showEditSheet = false }
                    )
                }
            }
        }

        private var newProfileSheet: some View {
            NavigationStack {
                NewProfileForm(
                    state: state,
                    onCancel: { showNewProfile = false },
                    onNext: {
                        draftEditorState = DraftEditorStateModel(
                            provider: state.provider,
                            insulinConcentration: state.settingsManager.settings.insulinConcentration,
                            units: state.settingsManager.settings.units,
                            sourceProfileName: activeItem?.name ?? String(localized: "Current"),
                            from: state.draft
                        )
                    }
                )
                .navigationDestination(isPresented: Binding(
                    get: { draftEditorState != nil },
                    set: { if !$0 { draftEditorState = nil } }
                )) {
                    if let draftState = draftEditorState {
                        DraftEditorRootView(
                            state: draftState,
                            onCancel: { showNewProfile = false },
                            onSaved: {
                                showNewProfile = false
                                Task { await state.refresh() }
                            }
                        )
                    }
                }
            }
        }

        private var defaultText: some View {
            Section {} header: {
                Text("Add a Profile by tapping 'Add Profile +' in the top right-hand corner of the screen.")
                    .textCase(nil)
                    .foregroundStyle(.secondary)
            }
        }

        private func currentActiveProfile(_ item: AdaptProfileListItem) -> some View {
            Section {
                HStack {
                    Text("\(item.name) is active")
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Color.primary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedProfile = item
                    showEditSheet = true
                }
            }
            .listRowBackground(Color.tabBar.opacity(0.8))
        }

        private var profilesSection: some View {
            Section {
                ForEach(inactiveItems) { item in
                    profileRow(for: item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            swipeActions(for: item)
                        }
                }
                .onMove(perform: state.reorderInactive)
                .confirmationDialog(
                    "Delete the Profile \"\(selectedProfile?.name ?? "")\"?",
                    isPresented: $isConfirmDeletePresented,
                    titleVisibility: .visible
                ) {
                    if let itemToDelete = selectedProfile {
                        Button("Delete", role: .destructive) {
                            state.delete(itemToDelete)
                            selectedProfile = nil
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        selectedProfile = nil
                    }
                }
                .listRowBackground(Color.chart)
            } header: {
                Text("Profiles")
            } footer: {
                HStack {
                    Image(systemName: "hand.draw.fill").foregroundStyle(.primary)
                    Text("Swipe left to rename or delete a profile. Hold, drag and drop to reorder.")
                }
            }
        }

        @ViewBuilder private func swipeActions(for item: AdaptProfileListItem) -> some View {
            Button(role: .none) {
                selectedProfile = item
                isConfirmDeletePresented = true
            } label: {
                Label("Delete", systemImage: "trash.fill")
                    .tint(.red)
            }
            Button {
                selectedProfile = item
                showEditSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
                    .tint(.blue)
            }
        }

        private func profileRow(for item: AdaptProfileListItem) -> some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name)
                        Spacer()
                    }
                    HStack(spacing: 5) {
                        ForEach(labels(for: item), id: \.self) { label in
                            Text(label)
                            if label != labels(for: item).last {
                                Divider().frame(width: 1, height: 14)
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 2)
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
                Image(systemName: "line.3.horizontal")
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
            }
        }

        private func labels(for item: AdaptProfileListItem) -> [String] {
            var out: [String] = []
            out.append("Created \(Self.dateFormatter.string(from: item.createdAt))")
            if let expiresAt = item.expiresAt {
                out.append("Expires \(Self.dateFormatter.string(from: expiresAt))")
            }
            return out
        }
    }
}
