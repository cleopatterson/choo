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
                    Image("FamilyPhoto")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 3))
                        .shadow(color: .chooPurple.opacity(0.4), radius: 12, y: 4)
                    Text("Choo")
                        .font(.system(.largeTitle, design: .serif).bold())
                    Text("Family organizer")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .glassField()

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { signIn() }
                        .glassField()
                }
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
                .tint(.chooPurple)
                .disabled(!isFormValid || viewModel.isBusy)
                .shadow(color: .chooPurple.opacity(0.4), radius: 12, y: 4)
                .padding(.horizontal)

                NavigationLink {
                    SignUpView(viewModel: viewModel)
                } label: {
                    Text("Don't have an account? **Sign Up**")
                        .font(.subheadline)
                }

                Spacer()
            }
            .chooBackground()
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
