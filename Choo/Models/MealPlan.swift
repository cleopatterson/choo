import Foundation
import FirebaseFirestore

struct MealAssignment: Codable, Hashable {
    var recipeId: String
    var recipeName: String   // denormalized for display
    var recipeIcon: String   // denormalized for display

}

struct MealPlan: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var weekStart: Date                          // Monday of the week
    var assignments: [String: MealAssignment]    // "0"..."6" (Mon=0...Sun=6)

    /// Deterministic document ID: "week_2026-02-16"
    static func docId(for weekStart: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "week_\(formatter.string(from: weekStart))"
    }
}
