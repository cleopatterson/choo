import Foundation

struct WeekSummaryResult {
    var headline: String
    var summary: String
    var eventIcons: [String: String] = [:]  // event title → emoji
}

@Observable
final class ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let cacheKeyPrefix = "ClaudeAPIService.weekSummary.v3"
    private let cacheWeekKeyPrefix = "ClaudeAPIService.weekStart.v3"
    @ObservationIgnored private var activeGenerationTasks: [String: Task<WeekSummaryResult, Error>] = [:]

    /// Generate an AI headline and summary for the week's events.
    func generateWeekSummary(events: [EventSummaryInput], weekStart: Date, weatherSummary: String? = nil, weekLabel: String = "this week") async -> WeekSummaryResult {
        // Check cache — keyed by week + day so it refreshes daily, not every app open
        let weekString = Self.weekFormatter.string(from: weekStart)
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheString = "\(weekString)_\(dayString)"
        if let cached = loadCachedSummary(for: cacheString, weekKey: weekString) {
            return cached
        }

        // Deduplicate concurrent requests — return existing in-flight task for this specific week
        if let existing = activeGenerationTasks[weekString] {
            return (try? await existing.value) ?? fallback(events: events)
        }

        let capturedEvents = events
        let capturedWeatherSummary = weatherSummary
        let capturedDayString = dayString
        let capturedCacheString = cacheString
        let capturedWeekLabel = weekLabel

        let task = Task<WeekSummaryResult, Error> { [weak self] in
            guard let self else { throw ClaudeAPIError.badResponse }

            let eventList = capturedEvents.map { "• \($0.title) — \($0.dateDescription)" }.joined(separator: "\n")
            let weatherContext = capturedWeatherSummary.map { "\n\nWeather forecast for \(capturedWeekLabel):\n\($0)" } ?? ""
            let isNextWeek = capturedWeekLabel != "this week"
            let timeContext = isNextWeek
                ? "You are summarising NEXT WEEK (not the current week). All events listed are next week."
                : "Today is \(capturedDayString). Only mention events from today onwards — never reference past days."

            let prompt = """
            You are a witty, warm family calendar assistant. Given \(capturedWeekLabel)'s events, write two things:

            1. HEADLINE: A short, punchy headline capturing the week's vibe. Poetic or playful. Use a line break (\\n) to split into two short lines. STRICT LIMIT: 3-4 words per line, 4-8 words total. No quotes.\(isNextWeek ? " Make it clear this is about next week." : "")
               Examples:
               - "Splash and dash —\\nwhat a week"
               - "Birthday week!\\ncelebrations ahead"
               - "A quiet one —\\njust for you"

            2. SUMMARY: One or two SHORT sentences about the most exciting events only — outings, dinners, parties, fun stuff. Skip chores, bills, and routine. If there are overdue or due-soon TO-DOs, mention them naturally (e.g. "that Amazon return is overdue" not "TO-DO: Amazon return (overdue)"). If weather data is provided, weave it in briefly. Keep it punchy and under 120 characters.
               Examples: "Dinner at Ormeggio on Friday — sunshine all week!" or "Swim Monday, birthday bash Saturday. Don't forget the car service!"

            3. ICONS: For each event, pick the single most fitting emoji. Be creative and specific. Use standard emoji characters like: 🍽️ 🏊 🎉 💪 📚 ✈️ 🛒 🏥 🏆 🎵 🎨 🎬 🏃 🚶 ❤️ ☕ 🚗 🐾 ✂️ 🛏️ 🎮 🎁 ⭐ ⚡ 🔧 🔨 🌿 🔥 💧 🌙 ☀️ 👥 📱 💻 💳 🏠 🚴 💃 🏖️ 📸 💼 🎓 🩺 🦷 👁️ 🧠 ✨ 🪄 🎭 🧘 🏄 🐶 💇 🧳 🎂 🏋️
               One line per event: "Event Title" = emoji

            Respond in exactly this format:
            HEADLINE: <headline>
            SUMMARY: <summary>
            ICONS:
            "Event Title" = emoji

            \(timeContext)

            Events for \(capturedWeekLabel):
            \(eventList.isEmpty ? "No events for \(capturedWeekLabel)." : eventList)\(weatherContext)
            """

            return try await self.callClaude(prompt: prompt)
        }

        activeGenerationTasks[weekString] = task
        isLoading = true
        defer {
            isLoading = false
            activeGenerationTasks.removeValue(forKey: weekString)
        }

        do {
            let result = try await task.value
            cacheSummary(result, cacheString: capturedCacheString, weekKey: weekString)
            errorMessage = nil
            return result
        } catch {
            errorMessage = error.localizedDescription
            return fallback(events: capturedEvents)
        }
    }

    /// Invalidate all cached summaries so the next calls fetch fresh.
    func invalidateCache() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(cacheKeyPrefix) || key.hasPrefix(cacheWeekKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - API call

    static let modelHaiku = "claude-haiku-4-5-20251001"
    static let modelSonnet = "claude-sonnet-4-5-20241022"

    /// Low-level call that returns the raw text from Claude's response.
    func callClaudeRaw(prompt: String, system: String? = nil, model: String = ClaudeAPIService.modelHaiku, maxTokens: Int = 400) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(Secrets.claudeAPIKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 30

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        if let system {
            body["system"] = system
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ClaudeAPIError.badResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let content = json?["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw ClaudeAPIError.unexpectedFormat
        }

        return text
    }

    /// Call Claude with a system prompt and user message, parsing the JSON response into a Decodable type.
    func callClaudeJSON<T: Decodable>(system: String, prompt: String, model: String = ClaudeAPIService.modelHaiku, maxTokens: Int = 800) async throws -> T {
        let text = try await callClaudeRaw(prompt: prompt, system: system, model: model, maxTokens: maxTokens)

        // Extract JSON from response — handle cases where the model wraps in ```json blocks
        let jsonString: String
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            jsonString = String(text[start.lowerBound...end.upperBound])
        } else {
            throw ClaudeAPIError.unexpectedFormat
        }

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeAPIError.unexpectedFormat
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: jsonData)
    }

    private func callClaude(prompt: String) async throws -> WeekSummaryResult {
        let text = try await callClaudeRaw(prompt: prompt)
        return parseResponse(text)
    }

    private func parseResponse(_ text: String) -> WeekSummaryResult {
        var headline = "Your week at a glance"
        var summary = ""
        var eventIcons: [String: String] = [:]

        enum Section { case none, summary, icons }
        var current: Section = .none

        let lines = text.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("HEADLINE:") {
                headline = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                headline = headline.replacingOccurrences(of: "\\n", with: "\n")
                current = .none
            } else if trimmed.hasPrefix("SUMMARY:") {
                summary = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                current = .summary
            } else if trimmed.hasPrefix("ICONS:") {
                current = .icons
            } else if current == .summary && !trimmed.isEmpty {
                summary += " " + trimmed
            } else if current == .icons && trimmed.contains("=") {
                // Parse "Event Title" = symbol.name
                let parts = trimmed.components(separatedBy: "=")
                if parts.count == 2 {
                    let title = parts[0].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    let icon = parts[1].trimmingCharacters(in: .whitespaces)
                    if !title.isEmpty && !icon.isEmpty {
                        eventIcons[title] = icon
                    }
                }
            }
        }

        return WeekSummaryResult(headline: headline, summary: summary, eventIcons: eventIcons)
    }

    // MARK: - Natural Language Event Parsing

    func parseEventFromNaturalLanguage(text: String, isBill: Bool, referenceDate: Date) async -> ParsedEventInput? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: referenceDate)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayOfWeek = dayFormatter.string(from: referenceDate)

        let prompt = """
        Parse this natural language event description into structured fields.

        Input: "\(text)"
        Is bill: \(isBill)
        Today is: \(todayString) (\(dayOfWeek))

        Rules:
        - If an explicit calendar date is given (e.g. "21 Mar", "March 21", "21/3"), ALWAYS use that exact date regardless of any day-of-week name also mentioned. For example "Thurs 21 Mar" → use 21 March, NOT next Thursday.
        - If ONLY a day name is given without a calendar date (e.g. "Friday", "next Tuesday"), use the NEXT occurrence of that day from today.
        - For multi-day events (e.g. "from 4-6 Sept", "4 to 6 March", "Mon-Wed"), set DATE to the first day, END_DATE to the last day, and IS_ALL_DAY to true.
        - Strip the date, time, location, and person names from the title (e.g. "Harriet's walk from 4-6 Sept" → title "Harriet's walk", date=4 Sept, end_date=6 Sept, attendee=Harriet)
        - Keep the venue/restaurant in the title if it's part of the event name (e.g. "Dinner at Ormeggio" keeps "at Ormeggio")
        - If a person's name is mentioned as the subject or possessor (e.g. "Harriet's walk", "Sarah's birthday", "dinner with Tom"), extract it as ATTENDEE. Only extract clear person names, not group words.
        - Round minutes to the nearest 15-minute interval (00, 15, 30, 45)
        - Detect monetary amounts like "$120" or "120 dollars"
        - If no time is specified, leave TIME empty
        - If no date is specified, use today's date
        - IS_ALL_DAY should be true if explicitly stated (e.g. "all day") OR if the event spans multiple days.

        Respond in EXACTLY this format (one field per line, no extra text):
        TITLE: <event title with location but without date/time>
        DATE: <YYYY-MM-DD>
        END_DATE: <YYYY-MM-DD if multi-day, or empty>
        TIME: <HH:MM in 24h format, or empty>
        LOCATION: <location if mentioned separately from title, or empty>
        IS_ALL_DAY: <true or false>
        IS_BILL: <true or false>
        AMOUNT: <numeric amount or empty>
        ATTENDEE: <person name if mentioned, or empty>
        """

        do {
            let response = try await callClaudeRaw(prompt: prompt, maxTokens: 200)
            return ParsedEventInput.parse(from: response, referenceDate: referenceDate)
        } catch {
            return nil
        }
    }

    // MARK: - Cache

    private struct CachedSummary: Codable {
        var headline: String
        var summary: String
        var eventIcons: [String: String]
    }

    private func cacheSummary(_ result: WeekSummaryResult, cacheString: String, weekKey: String) {
        let cached = CachedSummary(headline: result.headline, summary: result.summary, eventIcons: result.eventIcons)
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(data, forKey: "\(cacheKeyPrefix).\(weekKey)")
            UserDefaults.standard.set(cacheString, forKey: "\(cacheWeekKeyPrefix).\(weekKey)")
        }
    }

    private func loadCachedSummary(for cacheString: String, weekKey: String) -> WeekSummaryResult? {
        guard let cachedWeek = UserDefaults.standard.string(forKey: "\(cacheWeekKeyPrefix).\(weekKey)"),
              cachedWeek == cacheString,
              let data = UserDefaults.standard.data(forKey: "\(cacheKeyPrefix).\(weekKey)"),
              let cached = try? JSONDecoder().decode(CachedSummary.self, from: data) else {
            return nil
        }
        return WeekSummaryResult(headline: cached.headline, summary: cached.summary, eventIcons: cached.eventIcons)
    }

    private func fallback(events: [EventSummaryInput]) -> WeekSummaryResult {
        if events.isEmpty {
            return WeekSummaryResult(
                headline: "A blank canvas —\nthe week is yours",
                summary: "Nothing on the calendar yet. Perfect for spontaneous plans or a well-earned rest."
            )
        }
        let titles = events.prefix(4).map(\.title).joined(separator: ", ")
        let more = events.count > 4 ? " and more" : ""
        return WeekSummaryResult(
            headline: "Your week at a glance",
            summary: "\(titles)\(more) — \(events.count) event\(events.count == 1 ? "" : "s") lined up."
        )
    }

    @ObservationIgnored
    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-'W'ww"
        return f
    }()

    @ObservationIgnored
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// Lightweight input for the AI prompt — keeps the API service decoupled from FamilyEvent.
struct EventSummaryInput {
    let title: String
    let dateDescription: String
}

struct ParsedEventInput {
    var title: String
    var date: Date?
    var endDate: Date?   // For multi-day events
    var time: Date?      // Only the hour/minute components matter
    var location: String?
    var isAllDay: Bool
    var isBill: Bool
    var amount: Double?
    var attendeeName: String?

    static func parse(from text: String, referenceDate: Date) -> ParsedEventInput? {
        var title = ""
        var date: Date?
        var endDate: Date?
        var time: Date?
        var location: String?
        var isAllDay = false
        var isBill = false
        var amount: Double?
        var attendeeName: String?

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("TITLE:") {
                title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("END_DATE:") {
                let val = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { endDate = dateFormatter.date(from: val) }
            } else if trimmed.hasPrefix("DATE:") {
                let val = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                date = dateFormatter.date(from: val)
            } else if trimmed.hasPrefix("TIME:") {
                let val = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty {
                    time = timeFormatter.date(from: val)
                }
            } else if trimmed.hasPrefix("LOCATION:") {
                let val = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { location = val }
            } else if trimmed.hasPrefix("IS_ALL_DAY:") {
                isAllDay = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces).lowercased() == "true"
            } else if trimmed.hasPrefix("IS_BILL:") {
                isBill = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces).lowercased() == "true"
            } else if trimmed.hasPrefix("AMOUNT:") {
                let val = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                amount = Double(val)
            } else if trimmed.hasPrefix("ATTENDEE:") {
                let val = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                if !val.isEmpty { attendeeName = val }
            }
        }

        guard !title.isEmpty else { return nil }
        return ParsedEventInput(title: title, date: date, endDate: endDate, time: time, location: location, isAllDay: isAllDay, isBill: isBill, amount: amount, attendeeName: attendeeName)
    }
}

enum ClaudeAPIError: LocalizedError {
    case badResponse
    case unexpectedFormat

    var errorDescription: String? {
        switch self {
        case .badResponse:      return "Claude API returned an error"
        case .unexpectedFormat: return "Unexpected response format"
        }
    }
}
