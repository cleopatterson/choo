import SwiftUI
import FirebaseCore
import FirebaseMessaging
import AppIntents

@main
struct ChooApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private var authService: AuthService
    private var firestoreService: FirestoreService

    init() {
        FirebaseApp.configure()
        authService = AuthService()
        firestoreService = FirestoreService()
        NotificationService.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                viewModel: AuthViewModel(
                    authService: authService,
                    firestoreService: firestoreService
                )
            )
            .preferredColorScheme(.dark)
            .task {
                ChooShortcuts.updateAppShortcutParameters()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                processPendingShares()
            }
        }
    }

    private func processPendingShares() {
        let pending = PendingShareManager.readPendingNotes()
        guard !pending.isEmpty,
              SharedUserContext.isLoggedIn,
              let familyId = SharedUserContext.familyId,
              let displayName = SharedUserContext.displayName else { return }

        Task {
            var allSucceeded = true
            for note in pending {
                do {
                    try await firestoreService.createNote(
                        familyId: familyId,
                        title: note.title,
                        content: note.content,
                        createdBy: displayName
                    )
                } catch {
                    allSucceeded = false
                    print("Failed to create shared note '\(note.title)': \(error.localizedDescription)")
                }
            }
            // Only clear after all notes saved successfully to prevent data loss
            if allSucceeded {
                PendingShareManager.clearPendingNotes()
            }
        }
    }
}
