import Foundation
import EventKit

extension Notification.Name {
    static let chooNavigateToDate = Notification.Name("chooNavigateToDate")
}

@Observable
final class CalendarViewModel {
    let firestoreService: FirestoreService
    let deviceCalendarService: DeviceCalendarService
    let familyId: String
    let displayName: String
    let currentUserUID: String

    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var showingMonthPicker = false
    var showingEventForm = false
    var showingCalendarSources = false
    var selectedEvent: FamilyEvent?
    var errorMessage: String?
    var hiddenMemberIds: Set<String> = []
    var hideBills = false
    var showHistory = false

    private let hiddenMembersKey = "hiddenCalendarMemberIDs"
    private let hideBillsKey = "hideCalendarBills"
    private let showHistoryKey = "showCalendarHistory"

    @ObservationIgnored private var _cachedVisibleDays: [Date] = []
    @ObservationIgnored private var _cacheKey: String = ""
    @ObservationIgnored private var _cachedEventsByDay: [Date: [FamilyEvent]] = [:]
    @ObservationIgnored private var _eventsCacheKey: String = ""
    @ObservationIgnored private var _cachedAllMembers: [AnyFamilyMember] = []
    @ObservationIgnored private var _membersCacheKey: String = ""

    init(firestoreService: FirestoreService, deviceCalendarService: DeviceCalendarService, familyId: String, displayName: String, currentUserUID: String) {
        self.firestoreService = firestoreService
        self.deviceCalendarService = deviceCalendarService
        self.familyId = familyId
        self.displayName = displayName
        self.currentUserUID = currentUserUID
        firestoreService.listenToEvents(familyId: familyId)
        loadHiddenMembers()
        hideBills = UserDefaults.standard.bool(forKey: hideBillsKey)
        showHistory = UserDefaults.standard.bool(forKey: showHistoryKey)
    }

    // MARK: - Member Filter

    func isMemberVisible(_ memberId: String) -> Bool {
        !hiddenMemberIds.contains(memberId)
    }

    func toggleMemberVisibility(_ memberId: String) {
        if hiddenMemberIds.contains(memberId) {
            hiddenMemberIds.remove(memberId)
        } else {
            hiddenMemberIds.insert(memberId)
        }
        _eventsCacheKey = "" // invalidate events cache
        saveHiddenMembers()
    }

    private func loadHiddenMembers() {
        if let ids = UserDefaults.standard.stringArray(forKey: hiddenMembersKey) {
            hiddenMemberIds = Set(ids)
        }
    }

    private func saveHiddenMembers() {
        UserDefaults.standard.set(Array(hiddenMemberIds), forKey: hiddenMembersKey)
    }

    func toggleBillsVisibility() {
        hideBills.toggle()
        _eventsCacheKey = "" // invalidate events cache
        UserDefaults.standard.set(hideBills, forKey: hideBillsKey)
    }

    func toggleHistory() {
        showHistory.toggle()
        _cacheKey = "" // invalidate visible days cache
        UserDefaults.standard.set(showHistory, forKey: showHistoryKey)
    }

    /// Filtered events for a day — respects member visibility and bill filter.
    func filteredEvents(for day: Date) -> [FamilyEvent] {
        let dayEvents = events(for: day)
        return dayEvents.filter { event in
            if hideBills && event.isBill == true { return false }
            if hiddenMemberIds.isEmpty { return true }
            let attendees = event.attendeeUIDs ?? []
            if attendees.isEmpty { return true } // show unassigned events always
            return attendees.contains { !hiddenMemberIds.contains($0) }
        }
    }

    var familyMembers: [UserProfile] {
        firestoreService.familyMembers
    }

    /// All family members (app users + dependents like kids/pets) for attendee selection.
    var allMembers: [AnyFamilyMember] {
        let depDetail = firestoreService.dependents.map { "\($0.id ?? ""):\($0.emoji ?? "")" }.joined(separator: ",")
        let key = "\(firestoreService.familyMembers.count)-\(firestoreService.dependents.count)-\(depDetail)"
        if key == _membersCacheKey && !_cachedAllMembers.isEmpty {
            return _cachedAllMembers
        }
        let users = firestoreService.familyMembers.compactMap { m -> AnyFamilyMember? in
            guard let id = m.id else { return nil }
            return AnyFamilyMember(id: id, displayName: m.displayName, isAppUser: true)
        }
        let deps = firestoreService.dependents.compactMap { d -> AnyFamilyMember? in
            guard let id = d.id else { return nil }
            return AnyFamilyMember(id: id, displayName: d.displayName, isAppUser: false, emoji: d.emoji)
        }
        _cachedAllMembers = users + deps
        _membersCacheKey = key
        return _cachedAllMembers
    }

    /// Cheap scalar fingerprint — incremented by FirestoreService on every snapshot change.
    var eventsFingerprint: Int {
        firestoreService.eventsVersion
    }

    /// Days to show: today, 1st of each month, days with events/device events.
    /// Public holidays and school holidays appear as labels on existing days, not as standalone rows.
    var visibleDays: [Date] {
        // Cache key uses cacheVersion (an int) instead of computing eventDays for the key
        let calendar = Calendar.current
        let year = calendar.component(.year, from: selectedDate)
        let key = "\(year)-\(firestoreService.eventsVersion)-\(deviceCalendarService.cacheVersion)-\(showHistory)"

        if key == _cacheKey && !_cachedVisibleDays.isEmpty {
            return _cachedVisibleDays
        }

        guard let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else { return [] }

        var daysSet = Set<Date>()

        // Always include today
        let today = calendar.startOfDay(for: Date())
        if today >= startOfYear && today <= endOfYear {
            daysSet.insert(today)
        }

        // 1st of every month — ensures month banners always appear
        for month in 1...12 {
            if let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                daysSet.insert(firstOfMonth)
            }
        }

        // All days with user events this year (including recurrence expansion)
        for event in firestoreService.events {
            if event.isTodo == true {
                // Todos: add start date, due date, and today if overdue
                let start = calendar.startOfDay(for: event.startDate)
                if start >= startOfYear && start <= endOfYear { daysSet.insert(start) }
                let due = calendar.startOfDay(for: event.endDate)
                if due != start && due >= startOfYear && due <= endOfYear { daysSet.insert(due) }
                if event.isCompleted != true && event.urgencyState == .overdue {
                    daysSet.insert(today)
                }
            } else if event.recurrence != nil {
                enumerateRecurrences(of: event, from: startOfYear, through: endOfYear, into: &daysSet)
            } else {
                let day = calendar.startOfDay(for: event.startDate)
                if day >= startOfYear && day <= endOfYear { daysSet.insert(day) }
                // For all-day multi-day events, add each day in the span
                if event.isAllDay == true {
                    let spanEnd = calendar.startOfDay(for: event.endDate)
                    var current = day
                    while current <= spanEnd && current <= endOfYear {
                        if current >= startOfYear { daysSet.insert(current) }
                        guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
                        current = next
                    }
                }
            }
        }

        // Days with enabled device calendar events (only computed on cache miss)
        let deviceDays = deviceCalendarService.eventDays(in: year)
        daysSet.formUnion(deviceDays)

        var result = daysSet.sorted()

        // When history is hidden, only show today and future
        if !showHistory {
            result = result.filter { $0 >= today }
        }

        _cachedVisibleDays = result
        _cacheKey = key
        return result
    }

    /// Enumerate occurrences of a recurring event within a date range, inserting into the set.
    private func enumerateRecurrences(of event: FamilyEvent, from rangeStart: Date, through rangeEnd: Date, into daysSet: inout Set<Date>) {
        let calendar = Calendar.current
        guard let freq = event.recurrence else { return }

        let anchor = calendar.startOfDay(for: event.startDate)
        let effectiveEnd: Date
        if let recEnd = event.recurrenceEndDate {
            effectiveEnd = min(calendar.startOfDay(for: recEnd), rangeEnd)
        } else {
            effectiveEnd = rangeEnd
        }

        let spanDays: Int
        if event.isAllDay == true {
            spanDays = max(0, calendar.dateComponents([.day], from: anchor, to: calendar.startOfDay(for: event.endDate)).day ?? 0)
        } else {
            spanDays = 0
        }

        // Fast-forward: start from rangeStart or anchor, whichever is later
        var current = anchor
        if current < rangeStart {
            switch freq {
            case .daily:
                current = rangeStart
            case .weekly:
                let daysDiff = calendar.dateComponents([.day], from: anchor, to: rangeStart).day ?? 0
                let periods = daysDiff / 7
                current = calendar.date(byAdding: .day, value: periods * 7, to: anchor) ?? rangeStart
            case .fortnightly:
                let daysDiff = calendar.dateComponents([.day], from: anchor, to: rangeStart).day ?? 0
                let periods = daysDiff / 14
                current = calendar.date(byAdding: .day, value: periods * 14, to: anchor) ?? rangeStart
            case .monthly:
                let comps = calendar.dateComponents([.month], from: anchor, to: rangeStart)
                let monthsBack = max(0, (comps.month ?? 0) - 1)
                current = calendar.date(byAdding: .month, value: monthsBack, to: anchor) ?? rangeStart
            case .yearly:
                let comps = calendar.dateComponents([.year], from: anchor, to: rangeStart)
                let yearsBack = max(0, (comps.year ?? 0) - 1)
                current = calendar.date(byAdding: .year, value: yearsBack, to: anchor) ?? rangeStart
            }
        }

        var count = 0
        let maxOccurrences = 400
        while current <= effectiveEnd && count < maxOccurrences {
            // Add occurrence days (including span)
            for offset in 0...spanDays {
                if let day = calendar.date(byAdding: .day, value: offset, to: current) {
                    if day >= rangeStart && day <= effectiveEnd {
                        daysSet.insert(day)
                    }
                }
            }

            // Advance to next occurrence
            switch freq {
            case .daily:
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            case .weekly:
                current = calendar.date(byAdding: .day, value: 7, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            case .fortnightly:
                current = calendar.date(byAdding: .day, value: 14, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            case .monthly:
                current = calendar.date(byAdding: .month, value: 1, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            case .yearly:
                current = calendar.date(byAdding: .year, value: 1, to: current) ?? effectiveEnd.addingTimeInterval(86400)
            }
            count += 1
        }
    }

    func events(for day: Date) -> [FamilyEvent] {
        let key = "\(firestoreService.eventsVersion)"
        if key != _eventsCacheKey {
            _eventsCacheKey = key
            _cachedEventsByDay = [:]
        }
        if let cached = _cachedEventsByDay[day] {
            return cached
        }
        let result = firestoreService.events.filter { $0.occursOn(day) }
        _cachedEventsByDay[day] = result
        return result
    }

    func externalEvents(for day: Date) -> [EKEvent] {
        deviceCalendarService.events(on: day)
    }

    func publicHoliday(on day: Date) -> Holiday? {
        NSWHolidays.publicHoliday(on: day)
    }

    func schoolHolidayPeriod(on day: Date) -> SchoolHolidayPeriod? {
        NSWHolidays.schoolHolidayPeriod(on: day)
    }

    /// Refresh the device calendar year cache. Call on init, year change, or calendar toggle.
    func refreshDeviceCalendarCache() {
        let year = Calendar.current.component(.year, from: selectedDate)
        deviceCalendarService.refreshCache(for: year)
        _cacheKey = "" // invalidate visible days cache
    }

    /// Next upcoming non-bill, non-todo event today, sorted by start time.
    var todayNextEvent: FamilyEvent? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let now = Date()
        let todayEvents = filteredEvents(for: today)
            .filter { $0.isBill != true && $0.isTodo != true }
            .sorted { $0.startDate < $1.startDate }

        // Find the next event that hasn't ended yet
        return todayEvents.first { event in
            if event.isAllDay == true { return true }
            return event.endDate > now
        } ?? todayEvents.first
    }

    /// Label for the hero card: "UP NEXT · THIS MORNING" etc.
    var todayNextEventLabel: String {
        guard let event = todayNextEvent else { return "TODAY" }
        if event.isAllDay == true { return "UP NEXT · TODAY" }
        let hour = Calendar.current.component(.hour, from: event.startDate)
        let period: String
        if hour < 12 {
            period = "THIS MORNING"
        } else if hour < 17 {
            period = "THIS AFTERNOON"
        } else {
            period = "TONIGHT"
        }
        return "UP NEXT · \(period)"
    }

    /// Total events today for the "+N more" pill.
    var todayEventCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return filteredEvents(for: today).filter { $0.isBill != true && $0.isTodo != true }.count
    }

    func scrollToToday() {
        selectedDate = Calendar.current.startOfDay(for: Date())
    }

    func createEvent(title: String, startDate: Date, endDate: Date, attendeeUIDs: [String], isAllDay: Bool? = nil, location: String? = nil, recurrenceFrequency: String? = nil, recurrenceEndDate: Date? = nil, reminderEnabled: Bool? = nil, isBill: Bool? = nil, amount: Double? = nil, note: String? = nil, isTodo: Bool? = nil, todoEmoji: String? = nil) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil

        do {
            try await firestoreService.createEvent(
                familyId: familyId,
                title: trimmed,
                startDate: startDate,
                endDate: endDate,
                createdBy: displayName,
                attendeeUIDs: attendeeUIDs,
                isAllDay: isAllDay,
                location: location,
                recurrenceFrequency: recurrenceFrequency,
                recurrenceEndDate: recurrenceEndDate,
                reminderEnabled: reminderEnabled,
                isBill: isBill,
                amount: amount,
                note: note,
                lastModifiedByUID: currentUserUID,
                isTodo: isTodo,
                todoEmoji: todoEmoji
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateEvent(_ event: FamilyEvent) async {
        errorMessage = nil
        var updated = event
        updated.lastModifiedByUID = currentUserUID
        do {
            try await firestoreService.updateEvent(familyId: familyId, event: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleAttendance(event: FamilyEvent, uid: String) async {
        guard let eventId = event.id else { return }
        errorMessage = nil

        var attendees = event.attendeeUIDs ?? []
        if attendees.contains(uid) {
            attendees.removeAll { $0 == uid }
        } else {
            attendees.append(uid)
        }

        do {
            try await firestoreService.updateEventAttendees(
                familyId: familyId,
                eventId: eventId,
                attendeeUIDs: attendees
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Toggle paid status for a bill. For recurring bills, toggles the specific occurrence date;
    /// for non-recurring bills, toggles isPaid.
    func toggleBillPaid(_ event: FamilyEvent, on day: Date) async {
        guard event.isBill == true else { return }
        errorMessage = nil
        var updated = event
        updated.lastModifiedByUID = currentUserUID

        if event.recurrence != nil {
            let key = FamilyEvent.occurrenceKey(for: day)
            var occurrences = updated.paidOccurrences ?? []
            if occurrences.contains(key) {
                occurrences.removeAll { $0 == key }
            } else {
                occurrences.append(key)
            }
            updated.paidOccurrences = occurrences
        } else {
            updated.isPaid = !(event.isPaid == true)
        }

        do {
            try await firestoreService.updateEvent(familyId: familyId, event: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Toggle completed status for a to-do.
    func toggleTodoCompleted(_ event: FamilyEvent) async {
        guard event.isTodo == true else { return }
        errorMessage = nil
        var updated = event
        updated.lastModifiedByUID = currentUserUID

        let wasCompleted = event.isCompleted == true
        updated.isCompleted = !wasCompleted
        updated.completedDate = wasCompleted ? nil : Date()

        do {
            try await firestoreService.updateEvent(familyId: familyId, event: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEvent(_ event: FamilyEvent) async {
        guard let eventId = event.id else { return }
        errorMessage = nil

        do {
            try await firestoreService.deleteEvent(familyId: familyId, eventId: eventId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
