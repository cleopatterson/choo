import Foundation
import FirebaseFirestore

enum RecurrenceFrequency: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case fortnightly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .fortnightly: "Fortnightly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

enum TodoUrgencyState {
    case notStarted
    case active
    case dueSoon
    case overdue
    case done
    case flexible
}

struct FamilyEvent: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var familyId: String
    var title: String
    var startDate: Date
    var endDate: Date
    var createdBy: String
    var attendeeUIDs: [String]?
    var isAllDay: Bool?
    var location: String?
    var recurrenceFrequency: String?
    var recurrenceEndDate: Date?
    var reminderEnabled: Bool?
    var isBill: Bool?
    var amount: Double?
    var isPaid: Bool?
    var paidOccurrences: [String]?
    var note: String?
    var lastModifiedByUID: String?
    var googleCalendarEventId: String?
    // To-do fields
    var isTodo: Bool?
    var isCompleted: Bool?
    var completedDate: Date?
    var todoEmoji: String?

    var recurrence: RecurrenceFrequency? {
        guard let raw = recurrenceFrequency else { return nil }
        return RecurrenceFrequency(rawValue: raw)
    }

    // MARK: - Per-occurrence paid tracking

    private static let occurrenceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func occurrenceKey(for date: Date) -> String {
        occurrenceDateFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    /// Whether this bill is paid on the given day. For recurring bills, checks paidOccurrences;
    /// falls back to isPaid for bills not yet migrated to per-occurrence tracking.
    func isPaidOn(_ day: Date) -> Bool {
        guard isBill == true else { return false }
        if recurrence != nil {
            if let occurrences = paidOccurrences {
                let key = Self.occurrenceKey(for: day)
                return occurrences.contains(key)
            }
            // No paidOccurrences yet — fall back to legacy isPaid
            return isPaid == true
        }
        return isPaid == true
    }

    // MARK: - To-do helpers

    /// Computed urgency state for to-do items.
    var urgencyState: TodoUrgencyState {
        guard isTodo == true else { return .active }
        if isCompleted == true { return .done }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // If startDate is in the future, it hasn't started yet
        let start = cal.startOfDay(for: startDate)
        if start > today { return .notStarted }

        // No due date → flexible (convention: endDate == startDate means no due date)
        guard todoHasDueDate else { return .flexible }

        // endDate is used as the due date for todos
        let due = cal.startOfDay(for: endDate)

        // Overdue: past the due date
        if due < today { return .overdue }

        // Due soon: within 2 days
        if let twoDaysBefore = cal.date(byAdding: .day, value: -2, to: due),
           today >= cal.startOfDay(for: twoDaysBefore) {
            return .dueSoon
        }

        return .active
    }

    /// Whether this to-do should appear on a given calendar day.
    /// Shows on: start date, due date, and today if overdue. Not every day.
    func todoShouldAppearOn(_ day: Date) -> Bool {
        guard isTodo == true else { return false }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        let today = cal.startOfDay(for: Date())

        // Completed todos: only show on the day they were completed, for the rest of that day
        if isCompleted == true {
            if let completed = completedDate {
                return cal.isDate(completed, inSameDayAs: day)
            }
            return false
        }

        // Show on start date
        if cal.isDate(startDate, inSameDayAs: day) { return true }

        // Show on due date (endDate)
        if !cal.isDate(startDate, inSameDayAs: endDate) && cal.isDate(endDate, inSameDayAs: day) { return true }

        // Show on today if overdue
        if dayStart == today && urgencyState == .overdue { return true }

        return false
    }

    /// Whether this to-do is relevant for a given week (for briefing cards).
    /// Shows from start date week onward until completed.
    func todoRelevantForWeek(weekStart: Date, weekEnd: Date) -> Bool {
        guard isTodo == true else { return false }
        let cal = Calendar.current

        // Completed todos are not relevant unless completed this week
        if isCompleted == true {
            if let completed = completedDate {
                let completedDay = cal.startOfDay(for: completed)
                return completedDay >= cal.startOfDay(for: weekStart) && completedDay <= cal.startOfDay(for: weekEnd)
            }
            return false
        }

        // Not started yet and start date is after this week
        let start = cal.startOfDay(for: startDate)
        let wEnd = cal.startOfDay(for: weekEnd)
        if start > wEnd { return false }

        // Active, due-soon, overdue, or flexible — it's relevant
        return true
    }

    /// Whether this to-do has a due date (endDate != startDate).
    var todoHasDueDate: Bool {
        guard isTodo == true else { return false }
        return !Calendar.current.isDate(startDate, inSameDayAs: endDate)
    }

    /// Days overdue (positive = overdue, negative/zero = not overdue).
    var daysOverdue: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let due = cal.startOfDay(for: endDate)
        return cal.dateComponents([.day], from: due, to: today).day ?? 0
    }

    /// Whether this event occurs on a given calendar day, accounting for all-day spans and recurrence.
    func occursOn(_ day: Date) -> Bool {
        // To-dos use their own appearance logic
        if isTodo == true { return todoShouldAppearOn(day) }

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)

        // Check recurrence end date bound
        if let recEnd = recurrenceEndDate, dayStart > cal.startOfDay(for: recEnd) {
            return false
        }

        // Non-recurring event
        guard let freq = recurrence else {
            if isAllDay == true {
                let eventStart = cal.startOfDay(for: startDate)
                let eventEnd = cal.startOfDay(for: endDate)
                return dayStart >= eventStart && dayStart <= eventEnd
            } else {
                return cal.isDate(startDate, inSameDayAs: day)
            }
        }

        // Day must be on or after anchor
        let anchorDay = cal.startOfDay(for: startDate)
        guard dayStart >= anchorDay else { return false }

        // For all-day multi-day events, check if day falls within span offset from any occurrence anchor
        let spanDays: Int
        if isAllDay == true {
            spanDays = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: cal.startOfDay(for: endDate)).day ?? 0)
        } else {
            spanDays = 0
        }

        switch freq {
        case .daily:
            return true // Every day from anchor onward (within recurrence end)
        case .weekly:
            let daysDiff = cal.dateComponents([.day], from: anchorDay, to: dayStart).day ?? 0
            let mod = daysDiff % 7
            return mod <= spanDays
        case .fortnightly:
            let daysDiff = cal.dateComponents([.day], from: anchorDay, to: dayStart).day ?? 0
            let mod = daysDiff % 14
            return mod <= spanDays
        case .monthly:
            // Use Calendar.date(byAdding:) to handle month-end clamping (e.g. 31st → 28th in Feb)
            let monthsDiff = cal.dateComponents([.month], from: anchorDay, to: dayStart).month ?? 0
            for m in max(0, monthsDiff - 1)...(monthsDiff + 1) {
                guard let occurrence = cal.date(byAdding: .month, value: m, to: anchorDay) else { continue }
                let occStart = cal.startOfDay(for: occurrence)
                if spanDays == 0 {
                    if dayStart == occStart { return true }
                } else {
                    for offset in 0...spanDays {
                        if let d = cal.date(byAdding: .day, value: offset, to: occStart), cal.startOfDay(for: d) == dayStart {
                            return true
                        }
                    }
                }
            }
            return false
        case .yearly:
            let anchorComps = cal.dateComponents([.month, .day], from: startDate)
            let dayComps = cal.dateComponents([.month, .day], from: day)
            if spanDays == 0 {
                return anchorComps.month == dayComps.month && anchorComps.day == dayComps.day
            }
            // Multi-day span: check each offset day
            for offset in 0...spanDays {
                if let d = cal.date(byAdding: .day, value: offset, to: anchorDay) {
                    let c = cal.dateComponents([.month, .day], from: d)
                    if c.month == dayComps.month && c.day == dayComps.day { return true }
                }
            }
            return false
        }
    }
}
