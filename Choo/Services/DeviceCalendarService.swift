import EventKit
import SwiftUI

@Observable
final class DeviceCalendarService {
    private let store = EKEventStore()
    private let enabledKey = "enabledDeviceCalendarIDs"

    var authorizationStatus: EKAuthorizationStatus = .notDetermined
    var availableCalendars: [EKCalendar] = []
    var enabledCalendarIDs: Set<String> = []

    // Year-level event cache — avoids per-day EKEventStore disk queries
    @ObservationIgnored private var _cachedEventsByDay: [Date: [EKEvent]] = [:]
    @ObservationIgnored private var _cachedYear: Int = 0
    @ObservationIgnored private(set) var cacheVersion: Int = 0

    init() {
        loadEnabledIDs()
        refreshStatus()
    }

    // MARK: - Authorization

    func refreshStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if authorizationStatus == .fullAccess {
            reloadCalendars()
        }
    }

    func requestAccess() async {
        do {
            let granted = try await store.requestFullAccessToEvents()
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted {
                    reloadCalendars()
                }
            }
        } catch {
            await MainActor.run {
                authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            }
        }
    }

    // MARK: - Calendars

    func reloadCalendars() {
        availableCalendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func isEnabled(_ calendar: EKCalendar) -> Bool {
        enabledCalendarIDs.contains(calendar.calendarIdentifier)
    }

    func toggle(_ calendar: EKCalendar) {
        let id = calendar.calendarIdentifier
        if enabledCalendarIDs.contains(id) {
            enabledCalendarIDs.remove(id)
        } else {
            enabledCalendarIDs.insert(id)
        }
        saveEnabledIDs()
        // Invalidate year cache so events reflect the new calendar selection
        if _cachedYear != 0 {
            refreshCache(for: _cachedYear)
        }
    }

    // MARK: - Year-level cache

    /// Pre-fetch all events for the given year into a per-day dictionary.
    /// Call this when year changes, calendars change, or on a store notification.
    func refreshCache(for year: Int) {
        let cal = Calendar.current
        guard authorizationStatus == .fullAccess,
              let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else {
            _cachedEventsByDay = [:]
            _cachedYear = year
            cacheVersion += 1
            return
        }

        let calendars = availableCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else {
            _cachedEventsByDay = [:]
            _cachedYear = year
            cacheVersion += 1
            return
        }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let ekEvents = store.events(matching: predicate)

        var dict: [Date: [EKEvent]] = [:]
        for event in ekEvents {
            var current = cal.startOfDay(for: event.startDate)
            let eventEnd = cal.startOfDay(for: event.endDate)
            while current <= eventEnd {
                dict[current, default: []].append(event)
                guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        }

        _cachedEventsByDay = dict
        _cachedYear = year
        cacheVersion += 1
    }

    // MARK: - Events (cached)

    /// Raw EKEventStore query — only used for non-cached ranges (e.g. briefing).
    func events(from start: Date, to end: Date) -> [EKEvent] {
        guard authorizationStatus == .fullAccess else { return [] }
        let calendars = availableCalendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
    }

    /// O(1) cached lookup for a single day.
    func events(on day: Date) -> [EKEvent] {
        let start = Calendar.current.startOfDay(for: day)
        return _cachedEventsByDay[start] ?? []
    }

    /// All dates in the cached year that have enabled external calendar events.
    func eventDays(in year: Int) -> Set<Date> {
        if year != _cachedYear {
            refreshCache(for: year)
        }
        return Set(_cachedEventsByDay.keys)
    }

    // MARK: - Persistence

    private func loadEnabledIDs() {
        if let ids = UserDefaults.standard.stringArray(forKey: enabledKey) {
            enabledCalendarIDs = Set(ids)
        }
    }

    private func saveEnabledIDs() {
        UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: enabledKey)
    }
}
