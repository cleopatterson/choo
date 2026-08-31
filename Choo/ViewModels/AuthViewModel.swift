import Foundation
import FirebaseAuth

enum AuthFlowState: Equatable {
    case loading
    case login
    case signUp
    case familySetup
    case ready
}

/// The last signed-in session, cached so a cold start can render the app
/// immediately and refresh behind the scenes instead of showing a loading screen.
private struct CachedSession: Codable {
    let uid: String
    let email: String
    let displayName: String
    let familyId: String
    let roleRaw: String

    private static let key = "cachedAuthSession"

    static func load() -> CachedSession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedSession.self, from: data)
    }

    static func save(uid: String, profile: UserProfile) {
        guard let familyId = profile.familyId else { return }
        let session = CachedSession(uid: uid, email: profile.email, displayName: profile.displayName, familyId: familyId, roleRaw: profile.role.rawValue)
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    var profile: UserProfile {
        UserProfile(
            id: uid,
            email: email,
            displayName: displayName,
            familyId: familyId,
            role: UserRole(rawValue: roleRaw) ?? .member,
            fcmTokens: nil,
            notificationPreferences: nil
        )
    }
}

@MainActor
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
    /// Cold starts go straight to the app from the cached session (no loading
    /// screen) and the profile refreshes silently once auth confirms.
    func resolveAuthState() async {
        guard !authService.isLoading else {
            // Auth restore is in flight (fires within a frame). Trust the cached
            // session so the agenda renders immediately from Firestore's disk cache.
            if authFlowState == .loading, let cached = CachedSession.load() {
                userProfile = cached.profile
                firestoreService.listenToFamily(familyId: cached.familyId)
                authFlowState = .ready
            }
            return
        }

        guard let user = authService.currentUser else {
            authFlowState = .login
            firestoreService.stopListening()
            userProfile = nil
            CachedSession.clear()
            return
        }

        do {
            if let profile = try await firestoreService.getUserProfile(uid: user.uid) {
                userProfile = profile
                if let familyId = profile.familyId {
                    firestoreService.listenToFamily(familyId: familyId)
                    CachedSession.save(uid: user.uid, profile: profile)
                    authFlowState = .ready
                } else {
                    CachedSession.clear()
                    authFlowState = .familySetup
                }
            } else {
                // User exists in Auth but no Firestore profile — needs family setup
                CachedSession.clear()
                authFlowState = .familySetup
            }
        } catch {
            // Offline or transient failure: stay on the cached session rather
            // than bouncing to a login screen.
            guard authFlowState != .ready else { return }
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
            CachedSession.clear()
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
