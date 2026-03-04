import Foundation
import FirebaseFirestore

struct ChoreAssignee: Identifiable, Hashable {
    let id: String
    let displayName: String
    let emoji: String
    let colorHex: String

    static let family = ChoreAssignee(
        id: "family",
        displayName: "Family",
        emoji: "\u{1F3E0}",
        colorHex: "#f97066"
    )

    /// Rotating palette for dynamic members.
    static let palette = ["#4ecdc4", "#a78bfa", "#fbbf24", "#fb923c", "#74b9ff", "#e84393"]
}

struct ChoreSlotAssignment: Codable, Hashable {
    var choreTypeId: String
    var choreTypeName: String
    var categoryName: String
    var categoryEmoji: String
    var categoryColorHex: String
    var durationMinutes: Int?
    var assignedTo: String
    var isCompleted: Bool = false
}

struct ChoresPlan: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var weekStart: Date
    var slots: [String: ChoreSlotAssignment]

    static func docId(for weekStart: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return "week_\(f.string(from: weekStart))"
    }
}
