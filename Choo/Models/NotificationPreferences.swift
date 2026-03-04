import Foundation

struct NotificationPreferences: Codable {
    var eventCreated: Bool?
    var eventUpdated: Bool?
    var eventDeleted: Bool?
    var shoppingChanges: Bool?

    /// nil = enabled (opt-out model, no migration needed for existing users)
    var isEventCreatedEnabled: Bool { eventCreated ?? true }
    var isEventUpdatedEnabled: Bool { eventUpdated ?? true }
    var isEventDeletedEnabled: Bool { eventDeleted ?? true }
    var isShoppingChangesEnabled: Bool { shoppingChanges ?? true }
}
