import Foundation

struct Holiday {
    let name: String
    let date: Date
}

struct SchoolHolidayPeriod {
    let name: String
    let startDate: Date
    let endDate: Date
}

enum NSWHolidays {
    private static let cal = Calendar.current

    private static func d(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Public Holidays

    static let publicHolidays: [Holiday] = [
        // 2025
        Holiday(name: "New Year's Day", date: d(2025, 1, 1)),
        Holiday(name: "Australia Day", date: d(2025, 1, 27)),
        Holiday(name: "Good Friday", date: d(2025, 4, 18)),
        Holiday(name: "Easter Saturday", date: d(2025, 4, 19)),
        Holiday(name: "Easter Sunday", date: d(2025, 4, 20)),
        Holiday(name: "Easter Monday", date: d(2025, 4, 21)),
        Holiday(name: "Anzac Day", date: d(2025, 4, 25)),
        Holiday(name: "King's Birthday", date: d(2025, 6, 9)),
        Holiday(name: "Bank Holiday", date: d(2025, 8, 4)),
        Holiday(name: "Labour Day", date: d(2025, 10, 6)),
        Holiday(name: "Christmas Day", date: d(2025, 12, 25)),
        Holiday(name: "Boxing Day", date: d(2025, 12, 26)),

        // 2026
        Holiday(name: "New Year's Day", date: d(2026, 1, 1)),
        Holiday(name: "Australia Day", date: d(2026, 1, 26)),
        Holiday(name: "Good Friday", date: d(2026, 4, 3)),
        Holiday(name: "Easter Saturday", date: d(2026, 4, 4)),
        Holiday(name: "Easter Sunday", date: d(2026, 4, 5)),
        Holiday(name: "Easter Monday", date: d(2026, 4, 6)),
        Holiday(name: "Anzac Day", date: d(2026, 4, 25)),
        Holiday(name: "King's Birthday", date: d(2026, 6, 8)),
        Holiday(name: "Bank Holiday", date: d(2026, 8, 3)),
        Holiday(name: "Labour Day", date: d(2026, 10, 5)),
        Holiday(name: "Christmas Day", date: d(2026, 12, 25)),
        Holiday(name: "Boxing Day (observed)", date: d(2026, 12, 28)),

        // 2027
        Holiday(name: "New Year's Day", date: d(2027, 1, 1)),
        Holiday(name: "Australia Day", date: d(2027, 1, 26)),
        Holiday(name: "Good Friday", date: d(2027, 3, 26)),
        Holiday(name: "Easter Saturday", date: d(2027, 3, 27)),
        Holiday(name: "Easter Sunday", date: d(2027, 3, 28)),
        Holiday(name: "Easter Monday", date: d(2027, 3, 29)),
        Holiday(name: "Anzac Day", date: d(2027, 4, 25)),
        Holiday(name: "King's Birthday", date: d(2027, 6, 14)),
        Holiday(name: "Bank Holiday", date: d(2027, 8, 2)),
        Holiday(name: "Labour Day", date: d(2027, 10, 4)),
        Holiday(name: "Christmas Day (observed)", date: d(2027, 12, 27)),
        Holiday(name: "Boxing Day (observed)", date: d(2027, 12, 28)),
    ]

    // MARK: - School Holidays (NSW)

    static let schoolHolidayPeriods: [SchoolHolidayPeriod] = [
        // 2025
        SchoolHolidayPeriod(name: "Summer Holidays", startDate: d(2025, 1, 1), endDate: d(2025, 1, 30)),
        SchoolHolidayPeriod(name: "Autumn Holidays", startDate: d(2025, 4, 14), endDate: d(2025, 4, 25)),
        SchoolHolidayPeriod(name: "Winter Holidays", startDate: d(2025, 7, 7), endDate: d(2025, 7, 18)),
        SchoolHolidayPeriod(name: "Spring Holidays", startDate: d(2025, 9, 29), endDate: d(2025, 10, 10)),
        SchoolHolidayPeriod(name: "Summer Holidays", startDate: d(2025, 12, 22), endDate: d(2026, 1, 28)),

        // 2026
        SchoolHolidayPeriod(name: "Autumn Holidays", startDate: d(2026, 4, 13), endDate: d(2026, 4, 24)),
        SchoolHolidayPeriod(name: "Winter Holidays", startDate: d(2026, 7, 6), endDate: d(2026, 7, 17)),
        SchoolHolidayPeriod(name: "Spring Holidays", startDate: d(2026, 9, 28), endDate: d(2026, 10, 9)),
        SchoolHolidayPeriod(name: "Summer Holidays", startDate: d(2026, 12, 21), endDate: d(2027, 1, 27)),

        // 2027
        SchoolHolidayPeriod(name: "Autumn Holidays", startDate: d(2027, 4, 12), endDate: d(2027, 4, 23)),
        SchoolHolidayPeriod(name: "Winter Holidays", startDate: d(2027, 7, 5), endDate: d(2027, 7, 16)),
        SchoolHolidayPeriod(name: "Spring Holidays", startDate: d(2027, 9, 27), endDate: d(2027, 10, 8)),
        SchoolHolidayPeriod(name: "Summer Holidays", startDate: d(2027, 12, 21), endDate: d(2028, 1, 27)),
    ]

    // MARK: - Lookup dictionaries (built once, O(1) per query)

    private static let holidaysByDay: [Date: Holiday] = {
        var dict: [Date: Holiday] = [:]
        for h in publicHolidays {
            dict[cal.startOfDay(for: h.date)] = h
        }
        return dict
    }()

    private static let schoolHolidaysByDay: [Date: SchoolHolidayPeriod] = {
        var dict: [Date: SchoolHolidayPeriod] = [:]
        for period in schoolHolidayPeriods {
            var current = cal.startOfDay(for: period.startDate)
            let end = cal.startOfDay(for: period.endDate)
            while current <= end {
                dict[current] = period
                guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }
        return dict
    }()

    // MARK: - Lookups

    static func publicHoliday(on date: Date) -> Holiday? {
        holidaysByDay[cal.startOfDay(for: date)]
    }

    static func schoolHolidayPeriod(on date: Date) -> SchoolHolidayPeriod? {
        schoolHolidaysByDay[cal.startOfDay(for: date)]
    }
}
