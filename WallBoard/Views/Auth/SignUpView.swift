import SwiftUI

struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, email, password
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Create Account")
                    .font(.largeTitle.bold())
                Text("Join your family on WallBoard")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 16) {
                TextField("Display Name", text: $name)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                SecureField("Password (6+ characters)", text: $password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { signUp() }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                ErrorBannerView(message: error) {
                    viewModel.errorMessage = nil
                }
            }

            Button(action: signUp) {
                Group {
                    if viewModel.isBusy {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign Up")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 22)
            }
            .buttonStyle(.borderedProminent)
            .tint(.wallboardBlue)
            .disabled(!isFormValid || viewModel.isBusy)
            .padding(.horizontal)

            Spacer()
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isFormValid: Bool {
        !name.trimmed.isEmpty && email.trimmed.isValidEmail && password.isValidPassword
    }

    private func signUp() {
        guard isFormValid else { return }
        Task {
            await viewModel.signUp(name: name.trimmed, email: email.trimmed, password: password)
        }
    }
}
