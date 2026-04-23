import SwiftUI
import Swinject

extension AdaptProfile {
    struct RootView: BaseView {
        let resolver: Resolver
        @State var state = StateModel()
        @State private var showNewProfile = false
        @State private var draftEditorState: DraftEditorStateModel?
        @State private var editDraftState: DraftEditorStateModel?
        @State private var selectedProfile: AdaptProfileListItem?
        @State private var isConfirmDeletePresented = false
        @State private var activationTarget: AdaptProfileListItem?
        @State private var isConfirmRevertPresented = false
        @State private var showProfileHint = false
        @State private var profileHintDetent = PresentationDetent.large

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showProfileHint = true }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showProfileHint) {
                SettingInputHintView(
                    hintDetent: $profileHintDetent,
                    shouldDisplayHint: $showProfileHint,
                    hintLabel: String(localized: "About Profiles"),
                    hintText: AnyView(profileAbstractHint),
                    sheetTitle: String(localized: "Help", comment: "Help sheet title")
                )
            }
            .sheet(isPresented: $showNewProfile, onDismiss: { draftEditorState = nil }) {
                newProfileSheet
            }
            .sheet(item: $editDraftState) { draftState in
                NavigationStack {
                    DraftEditorRootView(
                        state: draftState,
                        onSaved: {
                            editDraftState = nil
                            Task { await state.refresh() }
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { editDraftState = nil }
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
            .safeAreaInset(edge: .bottom) {
                if let active = activeItem,
                   active.expiresAt != nil,
                   active.previousProfileID != nil
                {
                    stickyStopTempProfileButton
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
                        let minutesLeft = max(0, Int(expiresAt.timeIntervalSinceNow / 60))
                        Text(minutesLeft > 0 ? formatHrMin(minutesLeft) : String(localized: "Expiring"))
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
                    isConfirmRevertPresented = true
                }
            } header: {
                Text("Reverts to")
            }
            .listRowBackground(Color.chart)
        }

        private var stickyStopTempProfileButton: some View {
            ZStack {
                Rectangle()
                    .frame(width: UIScreen.main.bounds.width, height: 65)
                    .foregroundStyle(colorScheme == .dark ? Color.bgDarkerDarkBlue : Color.white)
                    .background(.thinMaterial)
                    .opacity(0.8)
                    .clipShape(Rectangle())

                Button(action: {
                    isConfirmRevertPresented = true
                }, label: {
                    Text("Stop Temp Profile")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(10)
                })
                    .frame(width: UIScreen.main.bounds.width * 0.9, height: 40, alignment: .center)
                    .background(Color(.systemRed))
                    .tint(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(5)
                    .confirmationDialog(
                        "Stop the temporary profile?",
                        isPresented: $isConfirmRevertPresented,
                        titleVisibility: .visible
                    ) {
                        if let prevID = activeItem?.previousProfileID {
                            Button("Stop", role: .destructive) {
                                Task {
                                    _ = await state.activate(
                                        id: prevID,
                                        durationMinutes: nil,
                                        confirmedPumpSync: true
                                    )
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(
                            "Restores the previous indefinite profile — the one whose basal schedule is already on the pump. No pump change needed."
                        )
                    }
            }
        }

        @ViewBuilder private var profileAbstractHint: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("What is a Profile?").bold()
                Text(
                    "A Profile is a named snapshot of your full therapy and algorithm setup — basal rate, ISF, CR, BG targets, plus every Algorithm Settings toggle. You keep one baseline profile and build alternates (sick day, exercise, menstrual cycle, travel, test modes) from it. Switching profiles swaps the entire setup in one tap."
                )

                Text("Activation modes").bold()
                Text(
                    "Indefinite: becomes your new baseline. The basal schedule is written to the pump and everything else is applied immediately."
                )
                Text(
                    "Timed (up to 24 h): applied until the duration expires, then auto-reverts to the indefinite baseline. The pump's scheduled basal is NOT changed; the algorithm compensates in-the-loop via temp basals — just like an override. This means you can safely experiment without touching the pump."
                )

                Text("Reverting").bold()
                Text(
                    "Stopping a temp profile (or waiting for it to expire) returns you to the indefinite profile whose basal is already on the pump. Revert always targets that anchor — chains of temps can never leave the pump in an unfamiliar state."
                )

                Text("Creating a new profile").bold()
                Text(
                    "Tap \"Add Profile\" to start from the currently active profile's settings. First pick a percentage to scale Basal, ISF and CR in one step, then fine-tune any individual setting in the editor that follows."
                )
            }
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
                editDraftState = DraftEditorStateModel(
                    provider: state.provider,
                    insulinConcentration: state.settingsManager.settings.insulinConcentration,
                    units: state.settingsManager.settings.units,
                    editing: content
                )
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
                out.append(source)
            }
            out += ProfileSummaryLabel.strings(
                appliedPercent: item.appliedPercent,
                dailyBasalRate: item.totalDailyBasal,
                tuning: .init(
                    preferencesTuned: item.preferencesChangedFromSource,
                    targetsTuned: item.targetsChangedFromSource
                )
            )
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
