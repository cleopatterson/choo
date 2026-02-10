import SwiftUI
import FirebaseCore

@main
struct WallBoardApp: App {
    private var authService: AuthService
    private var firestoreService: FirestoreService

    init() {
        FirebaseApp.configure()
        authService = AuthService()
        firestoreService = FirestoreService()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: AuthViewModel(
                    authService: authService,
                    firestoreService: firestoreService
                )
            )
        }
    }
}
