import SwiftUI

struct AccountTabView: View {
    @Bindable var viewModel: AuthViewModel

    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section("Profile") {
                    if let profile = viewModel.userProfile {
                        LabeledContent("Name", value: profile.displayName)
                        LabeledContent("Email", value: profile.email)
                        LabeledContent("Role", value: profile.role.rawValue.capitalized)
                    }
                }

                // Family Section
                if let family = viewModel.firestoreService.currentFamily {
                    Section("Family") {
                        LabeledContent("Family Name", value: family.name)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invite Code")
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(family.inviteCode)
                                    .font(.title2.monospaced().bold())
                                    .foregroundStyle(Color.wallboardBlue)
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

                        if viewModel.userProfile?.role == .admin {
                            Button("Regenerate Invite Code") {
                                Task { await viewModel.regenerateInviteCode() }
                            }
                        }
                    }

                    // Members Section
                    Section("Members (\(viewModel.firestoreService.familyMembers.count))") {
                        ForEach(viewModel.firestoreService.familyMembers) { member in
                            HStack {
                                Image(systemName: member.role == .admin ? "crown.fill" : "person.fill")
                                    .foregroundStyle(member.role == .admin ? .orange : .secondary)
                                VStack(alignment: .leading) {
                                    Text(member.displayName)
                                        .font(.body)
                                    Text(member.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

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
            }
            .navigationTitle("Account")
            .confirmationDialog("Sign Out?", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    viewModel.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}
