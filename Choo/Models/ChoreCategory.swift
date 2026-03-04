import Foundation
import FirebaseFirestore

enum ChoreEffort: String, CaseIterable, Identifiable, Codable {
    case easy, medium, big

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .big: "Big"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: "Quick task"
        case .medium: "Some effort"
        case .big: "Major job"
        }
    }
}

struct ChoreType: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String
    var durationMinutes: Int?

    var durationDisplay: String? {
        guard let mins = durationMinutes, mins > 0 else { return nil }
        if mins >= 60 {
            let hrs = mins / 60
            let rem = mins % 60
            return rem > 0 ? "\(hrs)hr \(rem)min" : "\(hrs)hr"
        }
        return "\(mins) min"
    }
}

struct ChoreCategory: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var emoji: String
    var colorHex: String
    var sortOrder: Int
    var isDefault: Bool
    var choreTypes: [ChoreType]

    static let defaults: [ChoreCategory] = [
        ChoreCategory(
            name: "Outdoor", emoji: "\u{1F33F}", colorHex: "#00b894", sortOrder: 0, isDefault: true,
            choreTypes: [
                ChoreType(id: UUID().uuidString, name: "Take bins out", description: "Wheelie bins to kerb", durationMinutes: 10),
                ChoreType(id: UUID().uuidString, name: "Mow front & back lawn", description: "Full mow cycle", durationMinutes: 60),
                ChoreType(id: UUID().uuidString, name: "Clear gutters", description: "Remove leaves & debris", durationMinutes: 45),
                ChoreType(id: UUID().uuidString, name: "Sweep driveway", description: "Sweep & tidy up", durationMinutes: 20),
            ]
        ),
        ChoreCategory(
            name: "Cleaning", emoji: "\u{1F9F9}", colorHex: "#74b9ff", sortOrder: 1, isDefault: true,
            choreTypes: [
                ChoreType(id: UUID().uuidString, name: "Vacuum all rooms", description: "Full house vacuum", durationMinutes: 45),
                ChoreType(id: UUID().uuidString, name: "Clean bathrooms", description: "Scrub & sanitise", durationMinutes: 40),
                ChoreType(id: UUID().uuidString, name: "Fold & put away laundry", description: "Folding & wardrobe sort", durationMinutes: 30),
            ]
        ),
        ChoreCategory(
            name: "Kitchen", emoji: "\u{1F373}", colorHex: "#fb923c", sortOrder: 2, isDefault: true,
            choreTypes: [
                ChoreType(id: UUID().uuidString, name: "Deep clean oven & stovetop", description: "Heavy kitchen clean", durationMinutes: 60),
                ChoreType(id: UUID().uuidString, name: "Clean out fridge", description: "Toss expired items & wipe down", durationMinutes: 30),
            ]
        ),
        ChoreCategory(
            name: "Swimming Pool", emoji: "\u{1F3CA}", colorHex: "#4ecdc4", sortOrder: 3, isDefault: true,
            choreTypes: [
                ChoreType(id: UUID().uuidString, name: "Check chlorine & pH levels", description: "Test & adjust chemicals", durationMinutes: 15),
                ChoreType(id: UUID().uuidString, name: "Skim leaves & vacuum pool", description: "Surface & floor clean", durationMinutes: 30),
            ]
        ),
    ]
}
