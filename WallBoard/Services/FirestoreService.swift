import Foundation
import FirebaseFirestore

@Observable
final class FirestoreService {
    private let db = Firestore.firestore()

    private var familyListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?

    var currentFamily: Family?
    var familyMembers: [UserProfile] = []

    deinit {
        familyListener?.remove()
        membersListener?.remove()
    }

    // MARK: - Invite Code Generation

    static func generateInviteCode() -> String {
        // No ambiguous chars: 0/O, 1/I/L removed
        let chars = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: - User Profile

    func createUserProfile(_ profile: UserProfile, uid: String) async throws {
        try db.collection("users").document(uid).setData(from: profile)
    }

    func getUserProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        return try? snapshot.data(as: UserProfile.self)
    }

    func updateUserFamilyId(uid: String, familyId: String, role: UserRole) async throws {
        try await db.collection("users").document(uid).updateData([
            "familyId": familyId,
            "role": role.rawValue
        ])
    }

    // MARK: - Family CRUD

    func createFamily(name: String, adminUID: String) async throws -> String {
        let inviteCode = Self.generateInviteCode()
        let family = Family(
            name: name,
            adminUID: adminUID,
            memberUIDs: [adminUID],
            inviteCode: inviteCode,
            inviteCodeExpiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60)
        )
        let docRef = try db.collection("families").addDocument(from: family)
        return docRef.documentID
    }

    func lookupFamilyByInviteCode(_ code: String) async throws -> Family? {
        let snapshot = try await db.collection("families")
            .whereField("inviteCode", isEqualTo: code.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        return try doc.data(as: Family.self)
    }

    func joinFamily(familyId: String, uid: String) async throws {
        try await db.collection("families").document(familyId).updateData([
            "memberUIDs": FieldValue.arrayUnion([uid])
        ])
    }

    func regenerateInviteCode(familyId: String) async throws -> String {
        let newCode = Self.generateInviteCode()
        let newExpiry = Date().addingTimeInterval(7 * 24 * 60 * 60)
        try await db.collection("families").document(familyId).updateData([
            "inviteCode": newCode,
            "inviteCodeExpiresAt": Timestamp(date: newExpiry)
        ])
        return newCode
    }

    // MARK: - Real-time Listeners

    func listenToFamily(familyId: String) {
        familyListener?.remove()
        familyListener = db.collection("families").document(familyId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else { return }
                self?.currentFamily = try? snapshot.data(as: Family.self)

                if let memberUIDs = self?.currentFamily?.memberUIDs {
                    self?.listenToMembers(uids: memberUIDs)
                }
            }
    }

    private func listenToMembers(uids: [String]) {
        membersListener?.remove()
        guard !uids.isEmpty else {
            familyMembers = []
            return
        }
        membersListener = db.collection("users")
            .whereField(FieldPath.documentID(), in: uids)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else { return }
                self?.familyMembers = snapshot.documents.compactMap {
                    try? $0.data(as: UserProfile.self)
                }
            }
    }

    func stopListening() {
        familyListener?.remove()
        membersListener?.remove()
        familyListener = nil
        membersListener = nil
        currentFamily = nil
        familyMembers = []
    }
}
