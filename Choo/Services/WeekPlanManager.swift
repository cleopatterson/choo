import Foundation

enum AutoPlanState: Equatable {
    case idle
    case planning
    case done
    case failed(String)
}

@MainActor
@Observable
final class WeekPlanManager {
    static let shared = WeekPlanManager()

    var dinnerState: AutoPlanState = .idle
    var exerciseState: AutoPlanState = .idle
    var choresState: AutoPlanState = .idle

    @ObservationIgnored private let dinnerAutoPlanKey = "WeekPlanManager.dinner.lastWeek"
    @ObservationIgnored private let exerciseAutoPlanKey = "WeekPlanManager.exercise.lastWeek"
    @ObservationIgnored private let choresAutoPlanKey = "WeekPlanManager.chores.lastWeek"
    @ObservationIgnored private let resetVersionKey = "WeekPlanManager.resetVersion"
    @ObservationIgnored private let currentResetVersion = 4  // Bump to force reset

    func applyOneTimeResetIfNeeded() {
        let lastVersion = UserDefaults.standard.integer(forKey: resetVersionKey)
        if lastVersion < currentResetVersion {
            print("[AutoPlan] One-time reset v\(currentResetVersion) — clearing all stamps")
            reset()
            UserDefaults.standard.set(currentResetVersion, forKey: resetVersionKey)
        }
    }

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    // MARK: - Week helpers

    var thisMonday: Date {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return Date()
        }
        return calendar.startOfDay(for: interval.start)
    }

    // MARK: - Per-tab once-per-week guards

    func shouldAutoPlanDinners() -> Bool { !hasRanThisWeek(dinnerAutoPlanKey) }
    func shouldAutoPlanExercise() -> Bool { !hasRanThisWeek(exerciseAutoPlanKey) }
    func shouldAutoPlanChores() -> Bool { !hasRanThisWeek(choresAutoPlanKey) }

    func markDinnerAutoPlanDone() { stampThisWeek(dinnerAutoPlanKey) }
    func markExerciseAutoPlanDone() { stampThisWeek(exerciseAutoPlanKey) }
    func markChoresAutoPlanDone() { stampThisWeek(choresAutoPlanKey) }

    /// True if any tab still needs auto-planning this week
    func anyTabNeedsAutoPlan() -> Bool {
        shouldAutoPlanDinners() || shouldAutoPlanExercise() || shouldAutoPlanChores()
    }

    private func hasRanThisWeek(_ key: String) -> Bool {
        let mondayString = Self.dateFormatter.string(from: thisMonday)
        return UserDefaults.standard.string(forKey: key) == mondayString
    }

    private func stampThisWeek(_ key: String) {
        let mondayString = Self.dateFormatter.string(from: thisMonday)
        UserDefaults.standard.set(mondayString, forKey: key)
    }

    /// Reset all tabs so auto-plan triggers again
    func reset() {
        UserDefaults.standard.removeObject(forKey: dinnerAutoPlanKey)
        UserDefaults.standard.removeObject(forKey: exerciseAutoPlanKey)
        UserDefaults.standard.removeObject(forKey: choresAutoPlanKey)
    }

    // MARK: - Empty-plan checks

    func isMealPlanEmpty(_ plan: MealPlan?) -> Bool {
        guard let plan else { return true }
        return plan.assignments.isEmpty
    }

    func isExercisePlanEmpty(_ plan: ExercisePlan?) -> Bool {
        guard let plan else { return true }
        return plan.slots.isEmpty && plan.restDays.isEmpty
    }

    func isChoresPlanEmpty(dayPlan: [String: Int]) -> Bool {
        dayPlan.isEmpty
    }

    // MARK: - Formatters

    @ObservationIgnored
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
