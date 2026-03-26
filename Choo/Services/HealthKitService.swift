import Foundation
import HealthKit

@Observable
final class HealthKitService {
    static let shared = HealthKitService()

    var isAuthorized = false
    var weekAverageSteps: Int = 0
    var weekTotalCalories: Int = 0
    var weekExerciseMinutes: Int = 0
    var todayActiveCalories: Int = 0
    var weekWorkouts: [HKWorkout] = []

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var lastFetchDate: Date?

    private init() {}

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    private var readTypes: Set<HKObjectType> {
        Set([
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKObjectType.workoutType(),
        ])
    }

    func requestAuthorization() async {
        guard Self.isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // Check actual status — requestAuthorization doesn't throw on denial
            isAuthorized = store.authorizationStatus(for: HKQuantityType(.stepCount)) != .notDetermined
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Fetch (once per app launch)

    func fetchIfNeeded() {
        if let last = lastFetchDate, Calendar.current.isDateInToday(last) { return }
        guard Self.isAvailable, isAuthorized else { return }
        lastFetchDate = Date()

        fetchWeekSteps()
        fetchWeekCalories()
        fetchWeekExerciseMinutes()
        fetchTodayActiveCalories()
        fetchWeekWorkouts()
    }

    // MARK: - Week Stats

    private var weekInterval: DateInterval {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), duration: 0)
    }

    private var daysElapsedThisWeek: Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: weekInterval.start, to: Date()).day ?? 0
        return max(days + 1, 1)
    }

    private func fetchWeekSteps() {
        let type = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: weekInterval.start, end: weekInterval.end)

        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            guard let self else { return }
            let total = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            let avg = Int(total) / self.daysElapsedThisWeek
            Task { @MainActor in
                self.weekAverageSteps = avg
            }
        }
        store.execute(query)
    }

    private func fetchWeekCalories() {
        let type = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: weekInterval.start, end: weekInterval.end)

        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let cals = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            Task { @MainActor in
                self?.weekTotalCalories = Int(cals)
            }
        }
        store.execute(query)
    }

    private func fetchWeekExerciseMinutes() {
        let type = HKQuantityType(.appleExerciseTime)
        let predicate = HKQuery.predicateForSamples(withStart: weekInterval.start, end: weekInterval.end)

        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let mins = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
            Task { @MainActor in
                self?.weekExerciseMinutes = Int(mins)
            }
        }
        store.execute(query)
    }

    private func fetchTodayActiveCalories() {
        let type = HKQuantityType(.activeEnergyBurned)
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let cals = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            Task { @MainActor in
                self?.todayActiveCalories = Int(cals)
            }
        }
        store.execute(query)
    }

    private func fetchWeekWorkouts() {
        let predicate = HKQuery.predicateForSamples(withStart: weekInterval.start, end: weekInterval.end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { [weak self] _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            Task { @MainActor in
                self?.weekWorkouts = workouts
            }
        }
        store.execute(query)
    }

    // MARK: - Helpers

    func todayWorkouts() -> [HKWorkout] {
        let cal = Calendar.current
        return weekWorkouts.filter { cal.isDateInToday($0.startDate) }
    }
}

// MARK: - Workout Activity Type Names

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: "Run"
        case .walking: "Walk"
        case .cycling: "Cycle"
        case .swimming: "Swim"
        case .yoga: "Yoga"
        case .pilates: "Pilates"
        case .functionalStrengthTraining: "Strength"
        case .traditionalStrengthTraining: "Weights"
        case .highIntensityIntervalTraining: "HIIT"
        case .coreTraining: "Core"
        case .flexibility: "Stretch"
        case .dance: "Dance"
        case .cooldown: "Cooldown"
        case .elliptical: "Elliptical"
        case .rowing: "Rowing"
        case .stairClimbing: "Stairs"
        case .hiking: "Hike"
        case .mixedCardio: "Cardio"
        default: "Workout"
        }
    }
}
