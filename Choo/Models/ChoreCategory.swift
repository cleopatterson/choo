import Foundation
import FirebaseFirestore

enum ChoreFrequency: String, CaseIterable, Identifiable, Codable {
    case weekly, monthly, quarterly, biannual, yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .biannual: "Every 6 months"
        case .yearly: "Yearly"
        }
    }

    var days: Int {
        switch self {
        case .weekly: 7
        case .monthly: 30
        case .quarterly: 90
        case .biannual: 180
        case .yearly: 365
        }
    }

    var sortOrder: Int {
        switch self {
        case .weekly: 0
        case .monthly: 1
        case .quarterly: 2
        case .biannual: 3
        case .yearly: 4
        }
    }

    var emoji: String {
        switch self {
        case .weekly: "\u{1F4C5}"
        case .monthly: "\u{1F5D3}\u{FE0F}"
        case .quarterly: "\u{1F9F9}"
        case .biannual: "\u{2728}"
        case .yearly: "\u{1F3E0}"
        }
    }

    var colorHex: String {
        switch self {
        case .weekly: "#C88EA7"
        case .monthly: "#a78bfa"
        case .quarterly: "#fb923c"
        case .biannual: "#4ecdc4"
        case .yearly: "#74b9ff"
        }
    }
}

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
    var frequency: ChoreFrequency?

    var effectiveFrequency: ChoreFrequency {
        frequency ?? .weekly
    }

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
                ChoreType(id: "chore-outdoor-bins", name: "Take bins out", description: "Wheelie bins to kerb", durationMinutes: 10, frequency: .weekly),
                ChoreType(id: "chore-outdoor-mow", name: "Mow front & back lawn", description: "Full mow cycle", durationMinutes: 60, frequency: .weekly),
                ChoreType(id: "chore-outdoor-sweep-driveway", name: "Sweep driveway", description: "Sweep & tidy up", durationMinutes: 20, frequency: .monthly),
                ChoreType(id: "chore-outdoor-gutters", name: "Clear gutters", description: "Remove leaves & debris", durationMinutes: 45, frequency: .yearly),
                ChoreType(id: "chore-outdoor-furniture-deck", name: "Clean outdoor furniture & deck", description: "Wipe down, oil if needed", durationMinutes: 45, frequency: .quarterly),
                ChoreType(id: "chore-outdoor-pressure-clean", name: "Pressure clean paths & outside", description: "Paths, driveway, walls", durationMinutes: 90, frequency: .yearly),
            ]
        ),
        ChoreCategory(
            name: "Cleaning", emoji: "\u{1F9F9}", colorHex: "#74b9ff", sortOrder: 1, isDefault: true,
            choreTypes: [
                ChoreType(id: "chore-clean-vacuum", name: "Vacuum floors & furniture", description: "Full house vacuum", durationMinutes: 45, frequency: .weekly),
                ChoreType(id: "chore-clean-mop", name: "Mop floors", description: "Hard floors throughout", durationMinutes: 30, frequency: .weekly),
                ChoreType(id: "chore-clean-bathrooms", name: "Clean all bathroom surfaces", description: "Scrub & sanitise", durationMinutes: 40, frequency: .weekly),
                ChoreType(id: "chore-clean-mirrors", name: "Clean mirrors", description: "Streak-free shine", durationMinutes: 15, frequency: .weekly),
                ChoreType(id: "chore-clean-dust", name: "Dust furniture", description: "All surfaces & shelves", durationMinutes: 20, frequency: .weekly),
                ChoreType(id: "chore-clean-bedding", name: "Change bedding", description: "Strip, wash & remake beds", durationMinutes: 30, frequency: .weekly),
                ChoreType(id: "chore-clean-laundry", name: "Fold & put away laundry", description: "Folding & wardrobe sort", durationMinutes: 30, frequency: .weekly),
                ChoreType(id: "chore-clean-blinds", name: "Dust blinds", description: "All window blinds", durationMinutes: 20, frequency: .monthly),
                ChoreType(id: "chore-clean-vents", name: "Clean vents", description: "Air vents & returns", durationMinutes: 20, frequency: .monthly),
                ChoreType(id: "chore-clean-lights", name: "Clean & dust lights", description: "Light fittings & shades", durationMinutes: 20, frequency: .monthly),
                ChoreType(id: "chore-clean-mattress", name: "Vacuum mattress", description: "Both sides, freshen up", durationMinutes: 20, frequency: .quarterly),
                ChoreType(id: "chore-clean-pillows-quilt", name: "Wash pillows & quilt", description: "Machine or dry clean", durationMinutes: 30, frequency: .quarterly),
                ChoreType(id: "chore-clean-under-furniture", name: "Vacuum under furniture", description: "Move sofas, beds, etc.", durationMinutes: 30, frequency: .quarterly),
                ChoreType(id: "chore-clean-shower-curtain", name: "Clean shower curtain", description: "Wash or replace", durationMinutes: 15, frequency: .quarterly),
                ChoreType(id: "chore-clean-windows", name: "Clean windows", description: "Inside & out", durationMinutes: 60, frequency: .yearly),
                ChoreType(id: "chore-clean-carpet-upholstery", name: "Deep clean carpet & upholstery", description: "Steam or shampoo", durationMinutes: 120, frequency: .yearly),
                ChoreType(id: "chore-clean-curtains-blinds", name: "Clean curtains & blinds", description: "Wash or vacuum all", durationMinutes: 45, frequency: .yearly),
                ChoreType(id: "chore-clean-dryer-vents", name: "Clean dryer & vents", description: "Lint trap & duct", durationMinutes: 30, frequency: .yearly),
            ]
        ),
        ChoreCategory(
            name: "Kitchen", emoji: "\u{1F373}", colorHex: "#fb923c", sortOrder: 2, isDefault: true,
            choreTypes: [
                ChoreType(id: "chore-kitchen-appliances", name: "Wipe kitchen appliances", description: "Toaster, kettle, etc.", durationMinutes: 15, frequency: .weekly),
                ChoreType(id: "chore-kitchen-microwave", name: "Clean inside microwave", description: "Steam & wipe", durationMinutes: 10, frequency: .weekly),
                ChoreType(id: "chore-kitchen-fridge", name: "Clean out fridge & toss old food", description: "Shelves & drawers", durationMinutes: 30, frequency: .weekly),
                ChoreType(id: "chore-kitchen-dishwasher", name: "Clean dishwasher", description: "Filter, seals & cycle", durationMinutes: 20, frequency: .monthly),
                ChoreType(id: "chore-kitchen-washing-machine", name: "Clean washing machine", description: "Drum clean cycle & seals", durationMinutes: 20, frequency: .monthly),
                ChoreType(id: "chore-kitchen-vacuum-cleaner", name: "Empty vacuum cleaner", description: "Bin, filter & brushes", durationMinutes: 10, frequency: .monthly),
                ChoreType(id: "chore-kitchen-oven", name: "Deep clean oven & stovetop", description: "Heavy degreasing", durationMinutes: 60, frequency: .quarterly),
                ChoreType(id: "chore-kitchen-coffee-machine", name: "Descale coffee machine", description: "Run descale cycle", durationMinutes: 30, frequency: .quarterly),
                ChoreType(id: "chore-kitchen-rangehood", name: "Clean rangehood", description: "Filters & exterior", durationMinutes: 30, frequency: .quarterly),
                ChoreType(id: "chore-kitchen-deep-fridge", name: "Deep clean inside fridge", description: "Remove all, scrub shelves", durationMinutes: 45, frequency: .quarterly),
                ChoreType(id: "chore-kitchen-freezer", name: "Clean out freezer", description: "Defrost & wipe down", durationMinutes: 45, frequency: .quarterly),
            ]
        ),
        ChoreCategory(
            name: "Swimming Pool", emoji: "\u{1F3CA}", colorHex: "#4ecdc4", sortOrder: 3, isDefault: true,
            choreTypes: [
                ChoreType(id: "chore-pool-chemicals", name: "Check chlorine & pH levels", description: "Test & adjust chemicals", durationMinutes: 15, frequency: .weekly),
                ChoreType(id: "chore-pool-skim-vacuum", name: "Skim leaves & vacuum pool", description: "Surface & floor clean", durationMinutes: 30, frequency: .weekly),
            ]
        ),
    ]
}
