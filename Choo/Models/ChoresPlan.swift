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
        colorHex: "#C88EA7"
    )

    static let palette = ["#4ecdc4", "#a78bfa", "#fbbf24", "#fb923c", "#74b9ff", "#e84393"]
}

struct ChoreAssignments: Codable {
    var assignments: [String: String]
    var dayPlan: [String: Int]?
}
