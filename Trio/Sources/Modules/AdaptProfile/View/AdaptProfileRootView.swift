import SwiftUI
import Swinject

extension AdaptProfile {
    struct RootView: BaseView {
        let resolver: Resolver
        @State var state = StateModel()
        @State private var showNewProfile = false
        @State private var showEditor = false
        @State private var draftEditorState: DraftEditorStateModel?
        @State private var selectedProfile: AdaptProfileListItem?
        @State private var isConfirmDeletePresented = false
        @State private var activationTarget: AdaptProfileListItem?

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

        /// The profile that will become active when a timed activation expires. Pinned to the top
        /// of the inactive list so the user can see (and easily switch back to) the fallback.
        private var pinnedRevertItem: AdaptProfileListItem? {
            guard let active = activeItem,
                  active.expiresAt != nil,
                  let prevID = active.previousProfileID
            else { return nil }
            return inactiveItems.first(where: { $0.id == prevID })
        }

        private var otherInactiveItems: [AdaptProfileListItem] {
            guard let pinned = pinnedRevertItem else { return inactiveItems }
            return inactiveItems.filter { $0.id != pinned.id }
        }

        var body: some View {
            List {
                if let active = activeItem {
                    currentActiveProfile(active)
                }

                if let pinned = pinnedRevertItem, let active = activeItem, let expiresAt = active.expiresAt {
                    revertToSection(pinned, activatesAt: expiresAt)
                }

                if otherInactiveItems.isEmpty, !state.isLoading, pinnedRevertItem == nil {
                    defaultText
                } else if !otherInactiveItems.isEmpty {
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
            .sheet(isPresented: $showEditor, onDismiss: { draftEditorState = nil }) {
                NavigationStack {
                    if let draftState = draftEditorState {
                        DraftEditorRootView(
                            state: draftState,
                            onSaved: {
                                showEditor = false
                                Task { await state.refresh() }
                            }
                        )
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Cancel") { showEditor = false }
                            }
                        }
                    }
                }
            }
            .sheet(item: $activationTarget) { item in
                ActivateProfileView(
                    profile: item,
                    state: state,
                    onDismiss: { activationTarget = nil }
                )
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
                            sourceProfileID: activeItem?.id,
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
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(item.name) is active")
                        Spacer()
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(Color.primary)
                    }
                    if let expiresAt = item.expiresAt {
                        HStack(spacing: 4) {
                            Text("Expires")
                            Text(expiresAt, style: .relative)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    openEditor(for: item)
                }
            }
            .listRowBackground(Color.tabBar.opacity(0.8))
        }

        private func revertToSection(_ item: AdaptProfileListItem, activatesAt: Date) -> some View {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        Text("Activates at \(activatesAt, style: .time)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    activationTarget = item
                }
            } header: {
                Text("Reverts to")
            }
            .listRowBackground(Color.chart)
        }

        private var profilesSection: some View {
            Section {
                ForEach(otherInactiveItems) { item in
                    profileRow(for: item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            swipeActions(for: item)
                        }
                }
                .onMove(perform: reorderOtherInactive)
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

        private func openEditor(for item: AdaptProfileListItem) {
            Task { @MainActor in
                guard let content = await state.provider.loadProfileContent(id: item.id) else { return }
                draftEditorState = DraftEditorStateModel(
                    provider: state.provider,
                    insulinConcentration: state.settingsManager.settings.insulinConcentration,
                    units: state.settingsManager.settings.units,
                    editing: content
                )
                showEditor = true
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
                openEditor(for: item)
            } label: {
                Label("Edit", systemImage: "pencil")
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
            .contentShape(Rectangle())
            .onTapGesture {
                activationTarget = item
            }
        }

        private func labels(for item: AdaptProfileListItem) -> [String] {
            var out: [String] = []
            if let source = item.sourceProfileName {
                let percent = item.appliedPercent.formatted(.number.precision(.fractionLength(0)))
                out.append("\(source) · \(percent) %")
            }
            switch (item.preferencesChangedFromSource, item.targetsChangedFromSource) {
            case (true, true): out.append(String(localized: "Algorithm Settings & Glucose Targets tuned"))
            case (true, false): out.append(String(localized: "Algorithm Settings tuned"))
            case (false, true): out.append(String(localized: "Glucose Targets tuned"))
            case (false, false): break
            }
            return out
        }

        /// Reorder only the non-pinned subset. Preserves the pinned revert-profile's position at
        /// the top of the inactive list when rewriting orderPositions.
        private func reorderOtherInactive(from source: IndexSet, to destination: Int) {
            var reorderedOthers = otherInactiveItems
            reorderedOthers.move(fromOffsets: source, toOffset: destination)

            var newItems: [AdaptProfileListItem] = []
            if let active = activeItem { newItems.append(active) }
            if let pinned = pinnedRevertItem { newItems.append(pinned) }
            newItems.append(contentsOf: reorderedOthers)
            state.items = newItems
            let ids = newItems.map(\.id)
            Task {
                await state.provider.applyOrdering(ids)
                await state.refresh()
            }
        }
    }
}
