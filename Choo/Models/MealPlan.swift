import Foundation
import FirebaseFirestore

struct MealAssignment: Codable, Hashable {
    var recipeId: String
    var recipeName: String   // denormalized for display
    var recipeIcon: String   // denormalized for display

    /// Ticked off on the shopping tab once its ingredients are in the trolley.
    /// Optional so picks saved before the change still decode.
    var isChecked: Bool?
}

struct MealPlan: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var weekStart: Date                          // Monday of the week
    var assignments: [String: MealAssignment]    // legacy: "0"..."6" (Mon=0...Sun=6)

    /// This week's meals, with no night attached. The set you shop for.
    /// Optional so weeks written before the change still decode.
    var picks: [MealAssignment]?

    private static let docIdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Deterministic document ID: "week_2026-02-16"
    static func docId(for weekStart: Date) -> String {
        "week_\(docIdFormatter.string(from: weekStart))"
    }
}
