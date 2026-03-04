import Foundation

struct WeeklyBriefing: Codable {
    var weekStart: Date
    var headline: String
    var summary: String
    var highlights: [WeekHighlight]
    var otherEvents: [WeekHighlight]
    var bills: [BriefingBill]
    var todos: [BriefingTodo]
    var agenda: [DayAgendaItem]

    init(weekStart: Date, headline: String, summary: String, highlights: [WeekHighlight], otherEvents: [WeekHighlight], bills: [BriefingBill], todos: [BriefingTodo] = [], agenda: [DayAgendaItem]) {
        self.weekStart = weekStart
        self.headline = headline
        self.summary = summary
        self.highlights = highlights
        self.otherEvents = otherEvents
        self.bills = bills
        self.todos = todos
        self.agenda = agenda
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weekStart = try container.decode(Date.self, forKey: .weekStart)
        headline = try container.decode(String.self, forKey: .headline)
        summary = try container.decode(String.self, forKey: .summary)
        highlights = try container.decode([WeekHighlight].self, forKey: .highlights)
        otherEvents = try container.decode([WeekHighlight].self, forKey: .otherEvents)
        bills = try container.decode([BriefingBill].self, forKey: .bills)
        todos = (try? container.decode([BriefingTodo].self, forKey: .todos)) ?? []
        agenda = try container.decode([DayAgendaItem].self, forKey: .agenda)
    }
}

struct DayForecast: Codable, Identifiable {
    var id: Date { date }
    var date: Date
    var maxTemp: Double
    var weatherCode: Int

    var sfSymbol: String {
        switch weatherCode {
        case 0:          return "sun.max.fill"
        case 1, 2:       return "cloud.sun.fill"
        case 3:          return "cloud.fill"
        case 45, 48:     return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57:     return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67:     return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77:         return "cloud.hail.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86:     return "cloud.snow.fill"
        case 95:         return "cloud.bolt.fill"
        case 96, 99:     return "cloud.bolt.rain.fill"
        default:         return "cloud.fill"
        }
    }

    var shortDescription: String {
        switch weatherCode {
        case 0:          return "Clear"
        case 1, 2:       return "Partly cloudy"
        case 3:          return "Overcast"
        case 45, 48:     return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Showers"
        case 95:         return "Thunderstorm"
        default:         return "Cloudy"
        }
    }
}

struct WeekHighlight: Codable, Identifiable {
    var id: String { eventId }
    var eventId: String
    var title: String
    var date: Date
    var icon: String
    var isPast: Bool
    var isTodo: Bool
    var todoUrgency: String?

    init(eventId: String, title: String, date: Date, icon: String, isPast: Bool, isTodo: Bool = false, todoUrgency: String? = nil) {
        self.eventId = eventId
        self.title = title
        self.date = date
        self.icon = icon
        self.isPast = isPast
        self.isTodo = isTodo
        self.todoUrgency = todoUrgency
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try container.decode(String.self, forKey: .eventId)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        icon = try container.decode(String.self, forKey: .icon)
        isPast = try container.decode(Bool.self, forKey: .isPast)
        isTodo = (try? container.decode(Bool.self, forKey: .isTodo)) ?? false
        todoUrgency = try? container.decode(String.self, forKey: .todoUrgency)
    }
}

struct BriefingBill: Codable, Identifiable {
    var id: String { eventId }
    var eventId: String
    var title: String
    var date: Date
    var amount: Double?
    var isPast: Bool
}

struct BriefingTodo: Codable, Identifiable {
    var id: String { eventId }
    var eventId: String
    var title: String
    var emoji: String
    var startDate: Date
    var dueDate: Date?
    var isCompleted: Bool
    var urgency: String  // "notStarted", "active", "dueSoon", "overdue", "done", "flexible"
    var daysOverdue: Int
}

struct DayAgendaItem: Codable, Identifiable {
    var id: Date { date }
    var date: Date
    var events: [AgendaEvent]
    var isPast: Bool
}

struct AgendaEvent: Codable, Identifiable {
    var id: String { eventId }
    var eventId: String
    var title: String
    var time: String?
    var memberColor: String?
    var isBill: Bool
    var isTodo: Bool
    var todoUrgency: String?  // "active", "dueSoon", "overdue", "flexible", "done"
    var isCompleted: Bool

    init(eventId: String, title: String, time: String? = nil, memberColor: String? = nil, isBill: Bool, isTodo: Bool = false, todoUrgency: String? = nil, isCompleted: Bool = false) {
        self.eventId = eventId
        self.title = title
        self.time = time
        self.memberColor = memberColor
        self.isBill = isBill
        self.isTodo = isTodo
        self.todoUrgency = todoUrgency
        self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try container.decode(String.self, forKey: .eventId)
        title = try container.decode(String.self, forKey: .title)
        time = try container.decodeIfPresent(String.self, forKey: .time)
        memberColor = try container.decodeIfPresent(String.self, forKey: .memberColor)
        isBill = try container.decode(Bool.self, forKey: .isBill)
        isTodo = (try? container.decode(Bool.self, forKey: .isTodo)) ?? false
        todoUrgency = try? container.decode(String.self, forKey: .todoUrgency)
        isCompleted = (try? container.decode(Bool.self, forKey: .isCompleted)) ?? false
    }
}
