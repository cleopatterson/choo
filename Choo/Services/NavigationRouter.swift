import Foundation

@MainActor
@Observable
final class NavigationRouter {
    static let shared = NavigationRouter()

    var pendingEventDate: Date?

    private init() {}

    func navigateToEvent(date: Date) {
        pendingEventDate = date
    }

    func consumePendingNavigation() -> Date? {
        guard let date = pendingEventDate else { return nil }
        pendingEventDate = nil
        return date
    }
}
