import Foundation
import FirebaseFirestore

enum ExerciseIntensity: String, CaseIterable, Identifiable, Codable {
    case light, moderate, high, peak

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .moderate: "Moderate"
        case .high: "High"
        case .peak: "Peak"
        }
    }

    var subtitle: String {
        switch self {
        case .light: "Recovery, gentle"
        case .moderate: "Steady effort"
        case .high: "Intense, challenging"
        case .peak: "All-out effort"
        }
    }
}

struct SessionType: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var description: String
    var durationMinutes: Int?
    var estimatedCalories: Int?
    var intensity: String?

    var intensityEnum: ExerciseIntensity? {
        guard let raw = intensity else { return nil }
        return ExerciseIntensity(rawValue: raw)
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

// MARK: - Day Load (exercise intensity)

enum DayLoad: String {
    case light, moderate, high, peak

    var displayName: String {
        switch self {
        case .light: "Light"
        case .moderate: "Moderate"
        case .high: "High"
        case .peak: "Peak"
        }
    }

    static func from(totalCalories: Int) -> DayLoad {
        switch totalCalories {
        case ..<200: return .light
        case 200..<350: return .moderate
        case 350..<550: return .high
        default: return .peak
        }
    }
}

struct ExerciseCategory: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var emoji: String
    var colorHex: String
    var sortOrder: Int
    var isDefault: Bool
    var sessionTypes: [SessionType]

    static let defaults: [ExerciseCategory] = [
        ExerciseCategory(
            name: "Yoga", emoji: "🧘", colorHex: "#4ecdc4", sortOrder: 0, isDefault: true,
            sessionTypes: [
                SessionType(id: UUID().uuidString, name: "Yin Yoga", description: "Deep stretches · Recovery", durationMinutes: 45, estimatedCalories: 120, intensity: "light"),
                SessionType(id: UUID().uuidString, name: "Power Yoga", description: "Strength flow · Intense", durationMinutes: 60, estimatedCalories: 250, intensity: "high"),
                SessionType(id: UUID().uuidString, name: "Flow", description: "Vinyasa flow · Balanced", durationMinutes: 45, estimatedCalories: 180, intensity: "moderate"),
            ]
        ),
        ExerciseCategory(
            name: "Run", emoji: "🏃", colorHex: "#f39c12", sortOrder: 1, isDefault: true,
            sessionTypes: [
                SessionType(id: UUID().uuidString, name: "Easy Run", description: "Conversational pace", durationMinutes: 30, estimatedCalories: 280, intensity: "moderate"),
                SessionType(id: UUID().uuidString, name: "Interval Training", description: "Speed work · High intensity", durationMinutes: 40, estimatedCalories: 450, intensity: "peak"),
                SessionType(id: UUID().uuidString, name: "Long Run", description: "Endurance · Steady pace", durationMinutes: 60, estimatedCalories: 550, intensity: "high"),
            ]
        ),
        ExerciseCategory(
            name: "Swim", emoji: "🏊", colorHex: "#74b9ff", sortOrder: 2, isDefault: true,
            sessionTypes: [
                SessionType(id: UUID().uuidString, name: "Laps", description: "Pool laps · Cardio", durationMinutes: 30, estimatedCalories: 300, intensity: "moderate"),
                SessionType(id: UUID().uuidString, name: "Open Water", description: "Ocean or lake", durationMinutes: 45, estimatedCalories: 400, intensity: "high"),
                SessionType(id: UUID().uuidString, name: "Drills", description: "Technique focus", durationMinutes: 30, estimatedCalories: 250, intensity: "moderate"),
            ]
        ),
        ExerciseCategory(
            name: "Weights", emoji: "🏋️", colorHex: "#ff6b6b", sortOrder: 3, isDefault: true,
            sessionTypes: [
                SessionType(id: UUID().uuidString, name: "Upper Body", description: "Chest, back, arms", durationMinutes: 45, estimatedCalories: 250, intensity: "high"),
                SessionType(id: UUID().uuidString, name: "Lower Body", description: "Legs, glutes", durationMinutes: 45, estimatedCalories: 280, intensity: "high"),
                SessionType(id: UUID().uuidString, name: "Full Body", description: "All major groups", durationMinutes: 60, estimatedCalories: 350, intensity: "high"),
            ]
        ),
        ExerciseCategory(
            name: "Pilates", emoji: "🤸", colorHex: "#e84393", sortOrder: 4, isDefault: true,
            sessionTypes: [
                SessionType(id: UUID().uuidString, name: "Mat Pilates", description: "Core & flexibility", durationMinutes: 45, estimatedCalories: 150, intensity: "light"),
                SessionType(id: UUID().uuidString, name: "Reformer", description: "Machine-based", durationMinutes: 50, estimatedCalories: 200, intensity: "moderate"),
            ]
        ),
    ]
}
