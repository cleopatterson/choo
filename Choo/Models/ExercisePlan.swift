import Foundation
import FirebaseFirestore

struct ExerciseSlotAssignment: Codable, Hashable {
    var sessionTypeId: String
    var sessionTypeName: String
    var categoryName: String
    var categoryEmoji: String
    var categoryColorHex: String
    var durationMinutes: Int?
    var estimatedCalories: Int?
    var intensity: String?
}

struct ExercisePlan: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var weekStart: Date
    var slots: [String: ExerciseSlotAssignment]
    var restDays: [Int]

    static func docId(for weekStart: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return "week_\(f.string(from: weekStart))"
    }
}

enum TimeSlot: String, Codable, CaseIterable {
    case morning, lunch, arvo

    var label: String {
        switch self {
        case .morning: "Morning"
        case .lunch: "Lunch"
        case .arvo: "Arvo"
        }
    }

    var emoji: String {
        switch self {
        case .morning: "☀️"
        case .lunch: "🌤️"
        case .arvo: "🌅"
        }
    }
}
