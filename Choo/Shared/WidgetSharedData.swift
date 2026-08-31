import Foundation

// Shared between the main app and the ChooWidget extension.
// Add this file's target membership to BOTH targets in Xcode.

enum WidgetSharedConstants {
    static let appGroupID = "group.com.tonywall.wallboard"
    static let snapshotFilename = "widget-upcoming.json"
    static let widgetKind = "ChooUpcomingWidget"
}

struct WidgetUpcomingItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable { case event, bill, todo }

    var id: String
    var title: String
    var date: Date
    var isAllDay: Bool
    var kind: Kind
    var emoji: String?
    var amount: Double?
    var location: String?
}

struct WidgetUpcomingSnapshot: Codable {
    var generatedAt: Date
    var items: [WidgetUpcomingItem]
}

enum WidgetSharedStore {
    private static func fileURL() -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetSharedConstants.appGroupID
        ) else { return nil }
        return container.appendingPathComponent(WidgetSharedConstants.snapshotFilename)
    }

    static func save(_ snapshot: WidgetUpcomingSnapshot) {
        guard let url = fileURL() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load() -> WidgetUpcomingSnapshot? {
        guard let url = fileURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetUpcomingSnapshot.self, from: data)
    }
}
