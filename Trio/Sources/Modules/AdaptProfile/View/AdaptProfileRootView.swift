import SwiftUI
import Swinject

extension AdaptProfile {
    struct RootView: BaseView {
        let resolver: Resolver
        @State var state = StateModel()
        @State private var renameTarget: AdaptProfileListItem?
        @State private var renameText: String = ""

        @Environment(AppState.self) var appState

        private static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f
        }()

        var body: some View {
            List {
                if state.items.isEmpty, !state.isLoading {
                    Section {
                        Text("No profiles yet.")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section {
                        ForEach(state.items) { item in
                            row(for: item)
                        }
                    } header: {
                        Text("Profiles")
                    }
                }
            }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await state.refresh() }
            .onAppear(perform: configureView)
            .sheet(item: $renameTarget) { item in
                renameSheet(for: item)
            }
        }

        private func row(for item: AdaptProfileListItem) -> some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.headline)
                        if item.isActive {
                            Text("Active")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        Text("Created \(item.createdAt, formatter: Self.dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let expiresAt = item.expiresAt {
                            Text("Expires \(expiresAt, formatter: Self.dateFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if !item.isActive {
                    Button(role: .destructive) {
                        state.delete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                Button {
                    renameText = item.name
                    renameTarget = item
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.blue)
            }
        }

        private func renameSheet(for item: AdaptProfileListItem) -> some View {
            NavigationStack {
                Form {
                    Section {
                        TextField("Profile name", text: $renameText)
                    }
                }
                .navigationTitle("Rename profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { renameTarget = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            state.rename(item, to: renameText)
                            renameTarget = nil
                        }
                        .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
