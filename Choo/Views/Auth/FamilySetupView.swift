import SwiftUI

struct FamilySetupView: View {
    @Bindable var viewModel: AuthViewModel

    @State private var familyName = ""
    @State private var inviteCode = ""
    @State private var mode: SetupMode = .choose

    private enum SetupMode {
        case choose, create, join
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(Color.chooPurple)
                    Text("Family Setup")
                        .font(.largeTitle.bold())
                    Text("Create a new family or join an existing one")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let error = viewModel.errorMessage {
                    ErrorBannerView(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                switch mode {
                case .choose:
                    chooseView
                case .create:
                    createView
                case .join:
                    joinView
                }

                Spacer()
            }
            .padding(.horizontal)
            .chooBackground()
        }
    }

    // MARK: - Choose Mode

    private var chooseView: some View {
        VStack(spacing: 16) {
            Button {
                mode = .create
            } label: {
                Label("Create a Family", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
            }
            .buttonStyle(.borderedProminent)
            .tint(.chooPurple)
            .shadow(color: .chooPurple.opacity(0.4), radius: 12, y: 4)

            Button {
                mode = .join
            } label: {
                Label("Join with Invite Code", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
            }
            .buttonStyle(.bordered)
            .tint(.chooPurple)
        }
    }

    // MARK: - Create Family

    private var createView: some View {
        VStack(spacing: 16) {
            TextField("Family Name", text: $familyName)
                .glassField()

            Button(action: createFamily) {
                Group {
                    if viewModel.isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create Family")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 22)
            }
            .buttonStyle(.borderedProminent)
            .tint(.chooPurple)
            .shadow(color: .chooPurple.opacity(0.4), radius: 12, y: 4)
            .disabled(familyName.trimmed.isEmpty || viewModel.isBusy)

            Button("Back") { mode = .choose }
                .font(.subheadline)
        }
    }

    // MARK: - Join Family

    private var joinView: some View {
        VStack(spacing: 16) {
            TextField("Invite Code", text: $inviteCode)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .glassField()

            Button(action: joinFamily) {
                Group {
                    if viewModel.isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text("Join Family")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 22)
            }
            .buttonStyle(.borderedProminent)
            .tint(.chooPurple)
            .shadow(color: .chooPurple.opacity(0.4), radius: 12, y: 4)
            .disabled(inviteCode.trimmed.count < 6 || viewModel.isBusy)

            Button("Back") { mode = .choose }
                .font(.subheadline)
        }
    }

    private func createFamily() {
        Task {
            await viewModel.createFamily(name: familyName.trimmed)
        }
    }

    private func joinFamily() {
        Task {
            await viewModel.joinFamily(inviteCode: inviteCode.trimmed)
        }
    }
}
