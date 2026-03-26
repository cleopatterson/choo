import Foundation
import EventKit

@MainActor
@Observable
final class WeeklyBriefingViewModel {
    let firestoreService: FirestoreService
    let claudeService: ClaudeAPIService
    let weatherService: WeatherService
    let deviceCalendarService: DeviceCalendarService?
    let familyId: String

    var briefing: WeeklyBriefing?
    var nextWeekBriefing: WeeklyBriefing?
    var forecasts: [DayForecast] = []
    var headline = "Your week at a glance"
    var summary = ""
    var nextWeekHeadline = "Next week preview"
    var nextWeekSummary = ""
    var eventCounts: [Date: Int] = [:]
    var nextWeekEventCounts: [Date: Int] = [:]
    var isLoadingBriefing = false

    @ObservationIgnored private var aiEventIcons: [String: String] = [:]
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastEventHash: Int = 0
    @ObservationIgnored private var hasLoadedInitially = false
    @ObservationIgnored private let debounceDuration: UInt64 = 3_000_000_000 // 3 seconds

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    init(firestoreService: FirestoreService, claudeService: ClaudeAPIService, weatherService: WeatherService, deviceCalendarService: DeviceCalendarService? = nil, familyId: String) {
        self.firestoreService = firestoreService
        self.claudeService = claudeService
        self.weatherService = weatherService
        self.deviceCalendarService = deviceCalendarService
        self.familyId = familyId
        loadCachedBriefing()
    }

    // MARK: - Week computation

    var weekStart: Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: comps) ?? calendar.startOfDay(for: Date())
    }

    var weekEnd: Date {
        calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }

    var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var nextWeekStart: Date {
        calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    var nextWeekEnd: Date {
        calendar.date(byAdding: .day, value: 6, to: nextWeekStart) ?? nextWeekStart
    }

    var nextWeekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: nextWeekStart) }
    }

    var weekDateRange: String {
        let startDay = calendar.component(.day, from: weekStart)
        return "\(startDay)–\(Self.endDateFormatter.string(from: weekEnd))"
    }

    var nextWeekForecasts: [DayForecast] {
        let nwStart = calendar.startOfDay(for: nextWeekStart)
        let nwEnd = calendar.date(byAdding: .day, value: 7, to: nwStart) ?? nwStart
        return forecasts.filter { $0.date >= nwStart && $0.date < nwEnd }
    }

    // MARK: - Load

    func load() async {
        guard !hasLoadedInitially else { return }
        async let weatherTask: () = loadWeather()
        async let summaryTask: () = generateSummary()
        async let nextWeekTask: () = generateNextWeekSummary()
        _ = await (weatherTask, summaryTask, nextWeekTask)
        buildBriefing()
        // Record current event version so onEventsChanged doesn't re-fetch for the initial data load
        lastEventHash = firestoreService.eventsVersion
        hasLoadedInitially = true
    }

    func onEventsChanged() {
        let newHash = firestoreService.eventsVersion
        guard newHash != lastEventHash else { return }
        lastEventHash = newHash

        // Rebuild highlights/otherEvents immediately (no API call)
        buildBriefing()

        // Only debounce an AI re-fetch if the initial load has completed —
        // otherwise the initial event population triggers a redundant API call
        guard hasLoadedInitially else { return }

        // Debounce the AI summary regeneration
        debounceTask?.cancel()
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: debounceDuration)
                guard !Task.isCancelled else { return }
                claudeService.invalidateCache()
                await generateSummary()
                await generateNextWeekSummary()
                buildBriefing()
            } catch {
                // Cancelled — new debounce started
            }
        }
    }

    /// Force-refresh everything (for pull-to-refresh).
    func forceRefresh() async {
        claudeService.invalidateCache()
        async let weatherTask: () = loadWeather()
        async let summaryTask: () = generateSummary()
        async let nextWeekTask: () = generateNextWeekSummary()
        _ = await (weatherTask, summaryTask, nextWeekTask)
        buildBriefing()
    }

    // MARK: - Weather

    private func loadWeather() async {
        await weatherService.fetchForecast()
        forecasts = weatherService.forecasts
    }

    // MARK: - AI Summary

    private func generateSummary() async {
        isLoadingBriefing = true
        defer { isLoadingBriefing = false }
        let today = calendar.startOfDay(for: Date())
        let weekEvents = eventsThisWeek()
        // Only include today-and-forward events so the summary doesn't reference yesterday
        let upcomingEvents = weekEvents.filter { event in
            event.startDate >= today || event.occursOn(today) || weekDays.contains(where: { day in day >= today && event.occursOn(day) })
        }
        print("[Briefing] generateSummary called with \(upcomingEvents.count) upcoming events (of \(weekEvents.count) total)")
        var inputs = upcomingEvents.filter { $0.isTodo != true }.map { event -> EventSummaryInput in
            let dateDesc = formatEventDate(event)
            return EventSummaryInput(title: event.title, dateDescription: dateDesc)
        }

        // Add active/overdue todos as context for the AI
        let relevantTodos = firestoreService.events.filter { event in
            guard event.isTodo == true, event.isCompleted != true else { return false }
            let state = event.urgencyState
            return state == .overdue || state == .dueSoon || state == .active
        }
        for todo in relevantTodos {
            let urgency: String
            switch todo.urgencyState {
            case .overdue: urgency = "\(todo.daysOverdue) days overdue"
            case .dueSoon: urgency = "due soon"
            default: urgency = todo.todoHasDueDate ? "due \(Self.dayFormatter.string(from: todo.endDate))" : "no deadline"
            }
            inputs.append(EventSummaryInput(title: "TO-DO: \(todo.title)", dateDescription: urgency))
        }

        // Include device calendar events (birthdays, etc.)
        if let deviceCal = deviceCalendarService {
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let ekEvents = deviceCal.events(from: today, to: weekEnd)
            for ekEvent in ekEvents {
                let dateDesc = Self.dayFormatter.string(from: ekEvent.startDate)
                let suffix = ekEvent.isAllDay ? " (all day)" : " at " + Self.timeFormatter.string(from: ekEvent.startDate)
                inputs.append(EventSummaryInput(title: ekEvent.title ?? "Event", dateDescription: dateDesc + suffix))
            }
        }

        // Build a short weather summary for the AI prompt
        let weatherSummary: String? = forecasts.isEmpty ? nil : forecasts.map { forecast in
            let day = Self.dayFormatter.string(from: forecast.date)
            return "• \(day): \(forecast.shortDescription), \(Int(round(forecast.maxTemp)))°"
        }.joined(separator: "\n")

        let result = await claudeService.generateWeekSummary(events: inputs, weekStart: weekStart, weatherSummary: weatherSummary)
        print("[Briefing] Result: headline=\(result.headline), icons=\(result.eventIcons)")
        headline = result.headline
        summary = result.summary
        aiEventIcons = result.eventIcons
    }

    @ObservationIgnored private var nextWeekAiEventIcons: [String: String] = [:]

    private func generateNextWeekSummary() async {
        let nwEvents = eventsNextWeek()
        guard !nwEvents.isEmpty else {
            nextWeekHeadline = "Next week preview"
            nextWeekSummary = ""
            return
        }

        let inputs = nwEvents.map { event -> EventSummaryInput in
            let dateDesc = formatEventDate(event)
            return EventSummaryInput(title: event.title, dateDescription: dateDesc)
        }

        let nwForecasts = nextWeekForecasts
        let weatherSummary: String? = nwForecasts.isEmpty ? nil : nwForecasts.map { forecast in
            let day = Self.dayFormatter.string(from: forecast.date)
            return "• \(day): \(forecast.shortDescription), \(Int(round(forecast.maxTemp)))°"
        }.joined(separator: "\n")

        let result = await claudeService.generateWeekSummary(events: inputs, weekStart: nextWeekStart, weatherSummary: weatherSummary, weekLabel: "next week")
        nextWeekHeadline = result.headline
        nextWeekSummary = result.summary
        nextWeekAiEventIcons = result.eventIcons
    }

    // MARK: - Build briefing model

    private func buildBriefing() {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let weekEvents = eventsThisWeek()

        // Pre-compute event counts per day (used by WeekTimelineView)
        var counts: [Date: Int] = [:]
        for day in weekDays {
            let dayStart = calendar.startOfDay(for: day)
            counts[dayStart] = weekEvents.filter { $0.occursOn(dayStart) }.count
        }
        eventCounts = counts

        // Extract todos — these are handled separately in highlights and briefing
        let todoEvents = weekEvents.filter { $0.isTodo == true }
        let nonTodoEvents = weekEvents.filter { $0.isTodo != true }

        // Also include active/overdue todos from other weeks (carry-forward)
        let carryForwardTodos = firestoreService.events.filter { event in
            guard event.isTodo == true else { return false }
            // Already in this week's events
            if weekEvents.contains(where: { $0.id == event.id }) { return false }
            return event.todoRelevantForWeek(weekStart: weekStart, weekEnd: weekEnd)
        }
        let allRelevantTodos = todoEvents + carryForwardTodos

        // Split non-bill, non-todo events into highlights (fun/outings) vs others (chores/routine)
        let nonBillEvents = nonTodoEvents.filter { $0.isBill != true }
        let funEvents = nonBillEvents.filter { isHighlightEvent($0) }
        let otherNonBillEvents = nonBillEvents.filter { !isHighlightEvent($0) }

        let highlights: [WeekHighlight] = funEvents
            .prefix(8)
            .map { event in
                let day: Date
                if event.recurrence != nil,
                   let occurrenceDay = weekDays.first(where: { event.occursOn($0) }) {
                    day = calendar.startOfDay(for: occurrenceDay)
                } else {
                    day = calendar.startOfDay(for: event.startDate)
                }
                let icon = iconForEvent(event)
                return WeekHighlight(
                    eventId: event.id ?? UUID().uuidString,
                    title: event.title,
                    date: event.startDate,
                    icon: icon,
                    isPast: day < today
                )
            }

        // "Also this week" — bills + non-highlight events
        let otherEvents: [WeekHighlight] = (otherNonBillEvents + weekEvents.filter { $0.isBill == true })
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                let day: Date
                if event.recurrence != nil,
                   let occurrenceDay = weekDays.first(where: { event.occursOn($0) }) {
                    day = calendar.startOfDay(for: occurrenceDay)
                } else {
                    day = calendar.startOfDay(for: event.startDate)
                }
                let icon = iconForEvent(event)
                return WeekHighlight(
                    eventId: event.id ?? UUID().uuidString,
                    title: event.title,
                    date: event.startDate,
                    icon: icon,
                    isPast: day < today
                )
            }

        // Bills
        let bills: [BriefingBill] = nonTodoEvents
            .filter { $0.isBill == true }
            .map { event in
                let day: Date
                if event.recurrence != nil,
                   let occurrenceDay = weekDays.first(where: { event.occursOn($0) }) {
                    day = calendar.startOfDay(for: occurrenceDay)
                } else {
                    day = calendar.startOfDay(for: event.startDate)
                }
                return BriefingBill(
                    eventId: event.id ?? UUID().uuidString,
                    title: event.title,
                    date: event.startDate,
                    amount: event.amount,
                    isPast: day < today
                )
            }

        // Todos
        let todos: [BriefingTodo] = allRelevantTodos.map { event in
            let state = event.urgencyState
            let urgencyStr: String
            switch state {
            case .notStarted: urgencyStr = "notStarted"
            case .active: urgencyStr = event.todoHasDueDate ? "active" : "flexible"
            case .dueSoon: urgencyStr = "dueSoon"
            case .overdue: urgencyStr = "overdue"
            case .done: urgencyStr = "done"
            case .flexible: urgencyStr = "flexible"
            }
            return BriefingTodo(
                eventId: event.id ?? UUID().uuidString,
                title: event.title,
                emoji: event.todoEmoji ?? "✅",
                startDate: event.startDate,
                dueDate: event.todoHasDueDate ? event.endDate : nil,
                isCompleted: event.isCompleted == true,
                urgency: urgencyStr,
                daysOverdue: event.daysOverdue
            )
        }

        // Agenda — include todos that should appear on each day
        let agenda: [DayAgendaItem] = weekDays.compactMap { day in
            let dayStart = calendar.startOfDay(for: day)
            var dayEvents = weekEvents.filter { $0.occursOn(dayStart) }
            // Add carry-forward todos that appear today
            for todo in carryForwardTodos where todo.todoShouldAppearOn(dayStart) {
                if !dayEvents.contains(where: { $0.id == todo.id }) {
                    dayEvents.append(todo)
                }
            }
            guard !dayEvents.isEmpty else { return nil }

            // Sort: timed events first (by time), then bills, then todos (overdue > dueSoon > active > flexible)
            let sorted = dayEvents.sorted { a, b in
                let aOrder = a.isTodo == true ? 2 : (a.isBill == true ? 1 : 0)
                let bOrder = b.isTodo == true ? 2 : (b.isBill == true ? 1 : 0)
                if aOrder != bOrder { return aOrder < bOrder }
                if a.isTodo == true && b.isTodo == true {
                    return todoSortOrder(a) < todoSortOrder(b)
                }
                return a.startDate < b.startDate
            }

            let agendaEvents = sorted.map { event -> AgendaEvent in
                let time: String? = (event.isAllDay == true || event.isTodo == true) ? nil : Self.timeFormatter.string(from: event.startDate)
                let colorName = memberColorName(for: event)
                let urgencyStr: String? = event.isTodo == true ? {
                    let state = event.urgencyState
                    switch state {
                    case .overdue: return "overdue"
                    case .dueSoon: return "dueSoon"
                    case .active: return event.todoHasDueDate ? "active" : "flexible"
                    case .flexible: return "flexible"
                    default: return "active"
                    }
                }() : nil
                return AgendaEvent(
                    eventId: event.id ?? UUID().uuidString,
                    title: event.title,
                    time: time,
                    memberColor: colorName,
                    isBill: event.isBill == true,
                    isTodo: event.isTodo == true,
                    todoUrgency: urgencyStr,
                    isCompleted: event.isCompleted == true
                )
            }
            return DayAgendaItem(
                date: dayStart,
                events: agendaEvents,
                isPast: dayStart < today
            )
        }

        briefing = WeeklyBriefing(
            weekStart: weekStart,
            headline: headline,
            summary: summary,
            highlights: highlights,
            otherEvents: otherEvents,
            bills: bills,
            todos: todos,
            agenda: agenda
        )
        saveBriefingCache()
        buildNextWeekBriefing()
    }

    private func buildNextWeekBriefing() {
        let nwEvents = eventsNextWeek()

        // Event counts per day
        var counts: [Date: Int] = [:]
        for day in nextWeekDays {
            let dayStart = calendar.startOfDay(for: day)
            counts[dayStart] = nwEvents.filter { $0.occursOn(dayStart) }.count
        }
        nextWeekEventCounts = counts

        guard !nwEvents.isEmpty else {
            nextWeekBriefing = nil
            return
        }

        let nonBillEvents = nwEvents.filter { $0.isBill != true }
        let funEvents = nonBillEvents.filter { isHighlightEvent($0) }
        let otherNonBillEvents = nonBillEvents.filter { !isHighlightEvent($0) }

        let highlights: [WeekHighlight] = funEvents
            .prefix(8)
            .map { event in
                WeekHighlight(
                    eventId: event.id ?? UUID().uuidString,
                    title: event.title,
                    date: event.startDate,
                    icon: iconForNextWeekEvent(event),
                    isPast: false
                )
            }

        let otherEvents: [WeekHighlight] = (otherNonBillEvents + nwEvents.filter { $0.isBill == true })
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                WeekHighlight(
                    eventId: event.id ?? UUID().uuidString,
                    title: event.title,
                    date: event.startDate,
                    icon: iconForNextWeekEvent(event),
                    isPast: false
                )
            }

        nextWeekBriefing = WeeklyBriefing(
            weekStart: nextWeekStart,
            headline: nextWeekHeadline,
            summary: nextWeekSummary,
            highlights: highlights,
            otherEvents: otherEvents,
            bills: [],
            agenda: []
        )
    }

    /// Icon for next week events — uses next week's AI icons, falls back to keyword matching.
    private func iconForNextWeekEvent(_ event: FamilyEvent) -> String {
        if event.isBill == true { return "💰" }
        if let aiIcon = nextWeekAiEventIcons[event.title], !aiIcon.isEmpty {
            return aiIcon
        }
        return iconForEvent(event)
    }

    // MARK: - Event helpers

    private func eventsThisWeek() -> [FamilyEvent] {
        let start = weekStart
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return firestoreService.events.filter { event in
            event.startDate >= start && event.startDate < end
                || event.occursOn(start)
                || weekDays.contains(where: { event.occursOn($0) })
        }
        .sorted { $0.startDate < $1.startDate }
    }

    private func eventsNextWeek() -> [FamilyEvent] {
        let start = nextWeekStart
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return firestoreService.events.filter { event in
            event.startDate >= start && event.startDate < end
                || event.occursOn(start)
                || nextWeekDays.contains(where: { event.occursOn($0) })
        }
        .sorted { $0.startDate < $1.startDate }
    }

    private func formatEventDate(_ event: FamilyEvent) -> String {
        if event.isAllDay == true {
            return Self.dayFormatter.string(from: event.startDate) + " (all day)"
        }
        return Self.dayFormatter.string(from: event.startDate) + " at " + Self.timeFormatter.string(from: event.startDate)
    }

    func iconForEvent(_ event: FamilyEvent) -> String {
        if event.isTodo == true { return event.todoEmoji ?? "✅" }
        if event.isBill == true { return "💰" }
        // Use AI-picked emoji if available
        if let aiIcon = aiEventIcons[event.title], !aiIcon.isEmpty {
            return aiIcon
        }
        let lower = event.title.lowercased()
        if lower.containsAny("birthday", "party") { return "🎉" }
        if lower.containsAny("doctor", "medical", "dentist", "health") { return "🏥" }
        if lower.containsAny("gym", "workout", "exercise") { return "💪" }
        if lower.containsAny("school", "class", "homework") { return "📚" }
        if lower.containsAny("lunch", "dinner", "food", "restaurant") { return "🍽️" }
        if lower.containsAny("meeting", "call", "zoom") { return "👥" }
        if lower.containsAny("swim", "pool") { return "🏊" }
        if lower.containsAny("soccer", "football", "sport") { return "⚽" }
        if lower.containsAny("travel", "flight", "airport") { return "✈️" }
        if lower.containsAny("shop", "groceries", "market") { return "🛒" }
        if lower.containsAny("coffee", "cafe", "café") { return "☕" }
        if lower.containsAny("movie", "cinema", "film") { return "🎬" }
        if lower.containsAny("music", "concert", "gig") { return "🎵" }
        if lower.containsAny("walk", "hike", "bush") { return "🚶" }
        if lower.containsAny("run", "jog", "parkrun") { return "🏃" }
        if lower.containsAny("beach", "surf") { return "🏖️" }
        if lower.containsAny("dance", "ballet") { return "💃" }
        if lower.containsAny("yoga", "pilates") { return "🧘" }
        if lower.containsAny("bike", "cycle") { return "🚴" }
        if lower.containsAny("dog", "cat", "pet", "vet") { return "🐾" }
        if lower.containsAny("haircut", "barber") { return "💇" }
        if lower.containsAny("clean", "tidy") { return "✨" }
        if lower.containsAny("garden", "plant", "mow") { return "🌿" }
        if lower.containsAny("car", "drive", "pick up", "drop off") { return "🚗" }
        if lower.containsAny("holiday", "vacation") { return "🧳" }
        return "📅"
    }

    /// Determines if an event is a "highlight" — fun, social, or outing-type events.
    /// Non-highlights (chores, routine tasks, admin) go to "Also this week".
    private func isHighlightEvent(_ event: FamilyEvent) -> Bool {
        if event.isBill == true { return false }
        if event.isTodo == true { return false }
        let lower = event.title.lowercased()

        // Fun / social / outings
        let funKeywords = [
            "dinner", "lunch", "brunch", "breakfast", "restaurant", "café", "cafe", "coffee",
            "birthday", "party", "celebration", "anniversary", "date",
            "movie", "cinema", "concert", "gig", "show", "theatre", "theater", "museum",
            "swim", "beach", "surf", "hike", "walk", "park", "playground", "picnic", "bbq",
            "travel", "flight", "holiday", "vacation", "trip",
            "game", "match", "soccer", "football", "cricket", "tennis", "basketball",
            "dance", "ballet", "yoga", "gym", "workout", "run", "parkrun",
            "playdate", "play date", "sleepover", "camping",
            "wedding", "engagement", "baby shower",
            "photo", "art", "craft", "paint",
            "spa", "massage"
        ]

        if funKeywords.contains(where: { lower.contains($0) }) { return true }

        // Chores / routine — these are NOT highlights
        let choreKeywords = [
            "clean", "tidy", "mow", "garden", "laundry", "ironing",
            "groceries", "shop", "errands", "pickup", "pick up", "drop off",
            "dentist", "doctor", "medical", "physio", "vet", "optometrist",
            "haircut", "barber",
            "meeting", "call", "zoom", "teams", "standup", "sprint",
            "school", "homework", "study", "exam", "test",
            "work", "office",
            "pay", "bill", "renewal", "insurance", "registration"
        ]

        if choreKeywords.contains(where: { lower.contains($0) }) { return false }

        // Default: if it has a location, it's probably an outing
        if let loc = event.location, !loc.isEmpty { return true }

        // Default: treat as a highlight (benefit of the doubt)
        return true
    }

    /// Sort order for todos: overdue (0) > dueSoon (1) > active (2) > flexible (3) > done (4)
    private func todoSortOrder(_ event: FamilyEvent) -> Int {
        switch event.urgencyState {
        case .overdue: 0
        case .dueSoon: 1
        case .active: event.todoHasDueDate ? 2 : 3
        case .flexible: 3
        case .done: 4
        case .notStarted: 5
        }
    }

    private func memberColorName(for event: FamilyEvent) -> String? {
        guard event.isBill != true else { return nil }
        guard let uids = event.attendeeUIDs, uids.count == 1 else { return nil }
        return uids.first
    }

    // MARK: - Cache

    private let briefingCacheKey = "WeeklyBriefing.cached"

    private func saveBriefingCache() {
        guard let briefing else { return }
        if let data = try? JSONEncoder().encode(briefing) {
            UserDefaults.standard.set(data, forKey: briefingCacheKey)
        }
    }

    private func loadCachedBriefing() {
        guard let data = UserDefaults.standard.data(forKey: briefingCacheKey),
              let cached = try? JSONDecoder().decode(WeeklyBriefing.self, from: data) else { return }
        // Only use cache if it's for the current week
        if calendar.isDate(cached.weekStart, equalTo: weekStart, toGranularity: .weekOfYear) {
            briefing = cached
            headline = cached.headline
            summary = cached.summary
        }
    }

    // MARK: - Formatters

    @ObservationIgnored
    private static let endDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    @ObservationIgnored
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    @ObservationIgnored
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()
}
