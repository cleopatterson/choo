import SwiftUI

struct ContentView: View {
    @State var viewModel: AuthViewModel

    var body: some View {
        Group {
            switch viewModel.authFlowState {
            case .loading:
                LoadingView()
            case .login:
                LoginView(viewModel: viewModel)
            case .signUp:
                SignUpView(viewModel: viewModel)
            case .familySetup:
                FamilySetupView(viewModel: viewModel)
            case .ready:
                MainTabView(viewModel: viewModel)
            }
        }
        .animation(.default, value: viewModel.authFlowState)
        .onChange(of: viewModel.authService.currentUser?.uid) {
            Task { await viewModel.resolveAuthState() }
        }
        .onChange(of: viewModel.authService.isLoading) {
            Task { await viewModel.resolveAuthState() }
        }
    }
}
