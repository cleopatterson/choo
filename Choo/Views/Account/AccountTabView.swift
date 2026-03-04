import SwiftUI

struct AccountTabView: View {
    @Bindable var viewModel: AuthViewModel

    @State private var showSignOutConfirmation = false
    @State private var showAddMember = false
    @State private var newMemberName = ""
    @State private var newMemberType: FamilyMember.MemberType = .person
    @State private var editingDependent: FamilyMember?
    @State private var editDepName = ""
    @State private var editDepType: FamilyMember.MemberType = .person
    @State private var editDepEmoji = ""
    @State private var notifEventCreated = true
    @State private var notifEventUpdated = true
    @State private var notifEventDeleted = true
    @State private var notifShoppingChanges = true

    var body: some View {
        NavigationStack {
            List {
                // Family Photo
                Section {
                    HStack {
                        Spacer()
                        Image("FamilyPhoto")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2.5))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Profile Section
                Section("Profile") {
                    if let profile = viewModel.userProfile {
                        LabeledContent("Name", value: profile.displayName)
                        LabeledContent("Email", value: profile.email)
                        LabeledContent("Role", value: profile.role.rawValue.capitalized)
                    }
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                // Family Section
                if let family = viewModel.firestoreService.currentFamily {
                    Section("Family") {
                        LabeledContent("Family Name", value: family.name)
                            .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invite Code")
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(family.inviteCode)
                                    .font(.title2.monospaced().bold())
                                    .foregroundStyle(Color.chooPurple)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = family.inviteCode
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                            }
                            if family.isInviteCodeExpired {
                                Text("Expired")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("Expires \(family.inviteCodeExpiresAt.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.thinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.chooPurple.opacity(0.3), lineWidth: 1)
                                )
                        )

                        if viewModel.userProfile?.role == .admin {
                            Button("Regenerate Invite Code") {
                                Task { await viewModel.regenerateInviteCode() }
                            }
                            .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                        }
                    }

                    // App Members Section
                    Section("App Members (\(viewModel.firestoreService.familyMembers.count))") {
                        ForEach(viewModel.firestoreService.familyMembers) { member in
                            HStack(spacing: 12) {
                                MemberAvatarView(name: member.displayName, uid: member.id ?? "", size: 36)
                                VStack(alignment: .leading) {
                                    Text(member.displayName)
                                        .font(.body)
                                    Text(member.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if member.role == .admin {
                                    Image(systemName: "crown.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))

                    // Family Members (dependents) Section
                    Section {
                        ForEach(viewModel.firestoreService.dependents) { dep in
                            HStack(spacing: 12) {
                                MemberAvatarView(name: dep.displayName, uid: dep.id ?? "", emoji: dep.emoji, size: 36)
                                VStack(alignment: .leading) {
                                    Text(dep.displayName)
                                        .font(.body)
                                    Text(dep.type == .pet ? "Pet" : "Family Member")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: dep.type == .pet ? "pawprint.fill" : "person.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editDepName = dep.displayName
                                editDepType = dep.type
                                editDepEmoji = dep.emoji ?? ""
                                editingDependent = dep
                            }
                        }
                        .onDelete { indices in
                            guard let familyId = viewModel.userProfile?.familyId else { return }
                            let deps = viewModel.firestoreService.dependents
                            for index in indices {
                                if let depId = deps[index].id {
                                    Task {
                                        do {
                                            try await viewModel.firestoreService.deleteDependent(
                                                familyId: familyId,
                                                dependentId: depId
                                            )
                                        } catch {
                                            viewModel.errorMessage = error.localizedDescription
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            newMemberName = ""
                            newMemberType = .person
                            showAddMember = true
                        } label: {
                            Label("Add Family Member", systemImage: "plus.circle")
                        }
                    } header: {
                        Text("Family Members (\(viewModel.firestoreService.dependents.count))")
                    } footer: {
                        Text("Add family members who don't use the app (kids, pets, etc.)")
                    }
                    .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                }

                // Notifications
                Section("Notifications") {
                    Toggle("New Events", isOn: $notifEventCreated)
                    Toggle("Event Changes", isOn: $notifEventUpdated)
                    Toggle("Event Deletions", isOn: $notifEventDeleted)
                    Toggle("Shopping List Changes", isOn: $notifShoppingChanges)
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))
                .tint(Color.chooPurple)
                .onChange(of: notifEventCreated) { saveNotificationPreferences() }
                .onChange(of: notifEventUpdated) { saveNotificationPreferences() }
                .onChange(of: notifEventDeleted) { saveNotificationPreferences() }
                .onChange(of: notifShoppingChanges) { saveNotificationPreferences() }

                // Sign Out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                            Spacer()
                        }
                    }
                }
                .listRowBackground(Rectangle().fill(.ultraThinMaterial))
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .chooBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.system(.headline, design: .serif))
                }
            }
            .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showAddMember) {
                addMemberSheet
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $editingDependent) { dep in
                editDependentSheet(for: dep)
                    .presentationBackground(.ultraThinMaterial)
            }
            .onAppear { loadNotificationPreferences() }
        }
    }

    // MARK: - Notification Preferences

    private func loadNotificationPreferences() {
        let prefs = viewModel.userProfile?.notificationPreferences
        notifEventCreated = prefs?.isEventCreatedEnabled ?? true
        notifEventUpdated = prefs?.isEventUpdatedEnabled ?? true
        notifEventDeleted = prefs?.isEventDeletedEnabled ?? true
        notifShoppingChanges = prefs?.isShoppingChangesEnabled ?? true
    }

    private func saveNotificationPreferences() {
        guard let uid = viewModel.authService.currentUser?.uid else { return }
        let prefs = NotificationPreferences(
            eventCreated: notifEventCreated,
            eventUpdated: notifEventUpdated,
            eventDeleted: notifEventDeleted,
            shoppingChanges: notifShoppingChanges
        )
        viewModel.userProfile?.notificationPreferences = prefs
        Task {
            try? await PushNotificationService.shared.updatePreferences(prefs, uid: uid)
        }
    }

    // MARK: - Add Member Sheet

    private var addMemberSheet: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $newMemberName)

                Picker("Type", selection: $newMemberType) {
                    Label("Person", systemImage: "person.fill")
                        .tag(FamilyMember.MemberType.person)
                    Label("Pet", systemImage: "pawprint.fill")
                        .tag(FamilyMember.MemberType.pet)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddMember = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let familyId = viewModel.userProfile?.familyId else { return }
                        let name = newMemberName
                        let type = newMemberType
                        let addedBy = viewModel.userProfile?.displayName ?? "Unknown"
                        showAddMember = false
                        Task {
                            do {
                                try await viewModel.firestoreService.addDependent(
                                    familyId: familyId,
                                    name: name,
                                    type: type,
                                    addedBy: addedBy
                                )
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(newMemberName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.height(250)])
    }

    // MARK: - Edit Dependent Sheet

    private static let memberEmojis = [
        "", "😎", "😊", "🤓", "😜", "🥳", "🤩", "😈",
        "🦸", "🧙", "🥷", "👑", "🤖", "👽",
        "🎮", "⚽", "🏀", "🎯", "🛹", "🏄", "🎨", "🎵",
        "📚", "🌟", "🔥", "⚡", "💎", "🚀",
        "🦄", "🐶", "🐱", "🐰", "🐾", "🦊", "🐸", "🐻",
        "🦁", "🐼", "🐨", "🦋", "🐢", "🦖"
    ]

    private func editDependentSheet(for dep: FamilyMember) -> some View {
        NavigationStack {
            Form {
                TextField("Name", text: $editDepName)

                Picker("Type", selection: $editDepType) {
                    Label("Person", systemImage: "person.fill")
                        .tag(FamilyMember.MemberType.person)
                    Label("Pet", systemImage: "pawprint.fill")
                        .tag(FamilyMember.MemberType.pet)
                }

                Section("Avatar Emoji") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(Self.memberEmojis, id: \.self) { emoji in
                            Button {
                                editDepEmoji = emoji
                            } label: {
                                if emoji.isEmpty {
                                    Image(systemName: "xmark.circle")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, height: 36)
                                } else {
                                    Text(emoji)
                                        .font(.title2)
                                        .frame(width: 36, height: 36)
                                }
                            }
                            .buttonStyle(.plain)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(editDepEmoji == emoji ? Color.chooPurple.opacity(0.3) : .clear)
                            )
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        guard let familyId = viewModel.userProfile?.familyId,
                              let depId = dep.id else { return }
                        editingDependent = nil
                        Task {
                            do {
                                try await viewModel.firestoreService.deleteDependent(
                                    familyId: familyId,
                                    dependentId: depId
                                )
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete")
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editingDependent = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let familyId = viewModel.userProfile?.familyId,
                              let depId = dep.id else { return }
                        let name = editDepName
                        let type = editDepType
                        let emoji = editDepEmoji.isEmpty ? nil : editDepEmoji
                        editingDependent = nil
                        Task {
                            do {
                                try await viewModel.firestoreService.updateDependent(
                                    familyId: familyId,
                                    dependentId: depId,
                                    displayName: name,
                                    type: type,
                                    emoji: emoji
                                )
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(editDepName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
