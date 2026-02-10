import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.wallboardBlue)
                    Text("WallBoard")
                        .font(.largeTitle.bold())
                    Text("Family organizer")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn() }
                }
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

                if let error = viewModel.errorMessage {
                    ErrorBannerView(message: error) {
                        viewModel.errorMessage = nil
                    }
                }

                Button(action: signIn) {
                    Group {
                        if viewModel.isBusy {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                }
                .buttonStyle(.borderedProminent)
                .tint(.wallboardBlue)
                .disabled(!isFormValid || viewModel.isBusy)
                .padding(.horizontal)

                NavigationLink {
                    SignUpView(viewModel: viewModel)
                } label: {
                    Text("Don't have an account? **Sign Up**")
                        .font(.subheadline)
                }

                Spacer()
            }
        }
    }

    private var isFormValid: Bool {
        email.trimmed.isValidEmail && password.isValidPassword
    }

    private func signIn() {
        guard isFormValid else { return }
        Task {
            await viewModel.signIn(email: email.trimmed, password: password)
        }
    }
}
