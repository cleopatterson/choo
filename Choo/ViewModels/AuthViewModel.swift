import Foundation
import FirebaseAuth

enum AuthFlowState: Equatable {
    case loading
    case login
    case signUp
    case familySetup
    case ready
}

@Observable
final class AuthViewModel {
    let authService: AuthService
    let firestoreService: FirestoreService

    var authFlowState: AuthFlowState = .loading
    var userProfile: UserProfile?
    var errorMessage: String?
    var isBusy = false

    init(authService: AuthService, firestoreService: FirestoreService) {
        self.authService = authService
        self.firestoreService = firestoreService
    }

    // MARK: - Auth State Resolution

    /// Call after auth state changes to determine the correct flow state.
    func resolveAuthState() async {
        guard !authService.isLoading else {
            authFlowState = .loading
            return
        }

        guard let user = authService.currentUser else {
            authFlowState = .login
            firestoreService.stopListening()
            userProfile = nil
            return
        }

        do {
            if let profile = try await firestoreService.getUserProfile(uid: user.uid) {
                userProfile = profile
                if let familyId = profile.familyId {
                    firestoreService.listenToFamily(familyId: familyId)
                    authFlowState = .ready
                } else {
                    authFlowState = .familySetup
                }
            } else {
                // User exists in Auth but no Firestore profile — needs family setup
                authFlowState = .familySetup
            }
        } catch {
            errorMessage = error.localizedDescription
            authFlowState = .login
        }
    }

    // MARK: - Sign Up

    func signUp(name: String, email: String, password: String) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let user = try await authService.signUp(email: email, password: password)
            let profile = UserProfile(
                email: email,
                displayName: name,
                familyId: nil,
                role: .member
            )
            try await firestoreService.createUserProfile(profile, uid: user.uid)
            userProfile = profile
            authFlowState = .familySetup
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            _ = try await authService.signIn(email: email, password: password)
            await resolveAuthState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create Family

    func createFamily(name: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            let familyId = try await firestoreService.createFamily(name: name, adminUID: uid)
            try await firestoreService.updateUserFamilyId(uid: uid, familyId: familyId, role: .admin)
            userProfile?.familyId = familyId
            userProfile?.role = .admin
            firestoreService.listenToFamily(familyId: familyId)
            authFlowState = .ready
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Join Family

    func joinFamily(inviteCode: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }

        do {
            guard let family = try await firestoreService.lookupFamilyByInviteCode(inviteCode) else {
                errorMessage = "Invalid invite code. Please check and try again."
                return
            }

            guard !family.isInviteCodeExpired else {
                errorMessage = "This invite code has expired. Ask the family admin for a new one."
                return
            }

            guard let familyId = family.id else { return }

            try await firestoreService.joinFamily(familyId: familyId, uid: uid)
            try await firestoreService.updateUserFamilyId(uid: uid, familyId: familyId, role: .member)
            userProfile?.familyId = familyId
            userProfile?.role = .member
            firestoreService.listenToFamily(familyId: familyId)
            authFlowState = .ready
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            if let uid = authService.currentUser?.uid {
                PushNotificationService.shared.removeFCMToken(uid: uid)
            }
            try authService.signOut()
            firestoreService.stopListening()
            userProfile = nil
            authFlowState = .login
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Regenerate Invite Code

    func regenerateInviteCode() async {
        guard let familyId = userProfile?.familyId else { return }
        errorMessage = nil

        do {
            _ = try await firestoreService.regenerateInviteCode(familyId: familyId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
