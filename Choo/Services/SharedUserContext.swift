import Foundation

enum SharedUserContext {
    private static let suiteName = "group.com.tonywall.wallboard"

    private enum Key {
        static let uid = "shared_uid"
        static let familyId = "shared_familyId"
        static let displayName = "shared_displayName"
        static let defaultShoppingListId = "shared_defaultShoppingListId"
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static var uid: String? { defaults?.string(forKey: Key.uid) }
    static var familyId: String? { defaults?.string(forKey: Key.familyId) }
    static var displayName: String? { defaults?.string(forKey: Key.displayName) }
    static var defaultShoppingListId: String? { defaults?.string(forKey: Key.defaultShoppingListId) }

    static var isLoggedIn: Bool {
        uid != nil && familyId != nil
    }

    static func save(uid: String, familyId: String, displayName: String) {
        let d = defaults
        d?.set(uid, forKey: Key.uid)
        d?.set(familyId, forKey: Key.familyId)
        d?.set(displayName, forKey: Key.displayName)
    }

    static func saveDefaultListId(_ listId: String) {
        defaults?.set(listId, forKey: Key.defaultShoppingListId)
    }

    static func clear() {
        let d = defaults
        d?.removeObject(forKey: Key.uid)
        d?.removeObject(forKey: Key.familyId)
        d?.removeObject(forKey: Key.displayName)
        d?.removeObject(forKey: Key.defaultShoppingListId)
    }
}
