import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private static let idPrefix = "choo-"

    private init() {}

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func rescheduleAll(events: [FamilyEvent], currentUserUID: String) {
        Task {
            let pending = await center.pendingNotificationRequests()
            let chooIds = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: chooIds)

            let calendar = Calendar.current
            let now = Date()
            let fourWeeks = calendar.date(byAdding: .weekOfYear, value: 4, to: now) ?? now

            for event in events {
                guard let eventId = event.id else { continue }
                guard event.reminderEnabled == true else { continue }
                // Only remind if this user is an attendee (or no attendees specified)
                if let attendees = event.attendeeUIDs, !attendees.isEmpty {
                    guard attendees.contains(currentUserUID) else { continue }
                }

                if event.recurrence != nil {
                    scheduleRecurringNotifications(event: event, eventId: eventId, from: now, through: fourWeeks)
                } else {
                    scheduleNotification(for: event, eventId: eventId, on: event.startDate)
                }
            }
        }
    }

    func removeNotifications(for eventId: String) {
        Task {
            let pending = await center.pendingNotificationRequests()
            let matching = pending.map(\.identifier).filter { $0.hasPrefix("\(Self.idPrefix)\(eventId)_") }
            center.removePendingNotificationRequests(withIdentifiers: matching)
        }
    }

    // MARK: - Private

    private static let notifDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    private static let notifTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private func scheduleNotification(for event: FamilyEvent, eventId: String, on date: Date) {
        let now = Date()

        let triggerDate: Date
        if event.isAllDay == true {
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: date)
            comps.hour = 9
            comps.minute = 0
            triggerDate = cal.date(from: comps) ?? date
        } else if event.isBill == true || event.isTodo == true {
            // Bills and todos fire at the due time, not 15 min early
            triggerDate = date
        } else {
            triggerDate = date.addingTimeInterval(-15 * 60)
        }

        guard triggerDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title

        let dateString = Self.notifDateFormatter.string(from: date)
        if event.isBill == true {
            // Bills: "Due today" or "Due Wed 5 Mar" + amount
            let isToday = Calendar.current.isDateInToday(date)
            var body = isToday ? "Due today" : "Due \(dateString)"
            if let amount = event.amount, amount > 0 {
                body += " \u{00B7} $\(String(format: "%.0f", amount))"
            }
            content.body = body
        } else if event.isTodo == true {
            // Todos: "Due now" or "Due today" for all-day
            if event.isAllDay == true {
                content.body = "Due today \u{00B7} \(dateString)"
            } else {
                let timeString = Self.notifTimeFormatter.string(from: date)
                content.body = "Due now \u{00B7} \(dateString), \(timeString)"
            }
        } else if event.isAllDay == true {
            content.body = "All day \u{00B7} \(dateString)"
        } else {
            let timeString = Self.notifTimeFormatter.string(from: date)
            content.body = "\(dateString), \(timeString) \u{00B7} Starting in 15 minutes"
        }
        if let location = event.location, !location.isEmpty {
            content.body += " \u{00B7} \(location)"
        }
        content.sound = .default
        content.userInfo = ["eventDate": date.timeIntervalSince1970]

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let identifier = "\(Self.idPrefix)\(eventId)_\(Int(triggerDate.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func scheduleRecurringNotifications(event: FamilyEvent, eventId: String, from rangeStart: Date, through rangeEnd: Date) {
        guard let freq = event.recurrence else { return }
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: event.startDate)

        var current = anchor
        if current < rangeStart {
            switch freq {
            case .daily:
                current = calendar.startOfDay(for: rangeStart)
            case .weekly:
                let days = calendar.dateComponents([.day], from: anchor, to: rangeStart).day ?? 0
                current = calendar.date(byAdding: .day, value: (days / 7) * 7, to: anchor) ?? rangeStart
            case .fortnightly:
                let days = calendar.dateComponents([.day], from: anchor, to: rangeStart).day ?? 0
                current = calendar.date(byAdding: .day, value: (days / 14) * 14, to: anchor) ?? rangeStart
            case .monthly:
                let months = calendar.dateComponents([.month], from: anchor, to: rangeStart).month ?? 0
                current = calendar.date(byAdding: .month, value: max(0, months - 1), to: anchor) ?? rangeStart
            case .yearly:
                let years = calendar.dateComponents([.year], from: anchor, to: rangeStart).year ?? 0
                current = calendar.date(byAdding: .year, value: max(0, years - 1), to: anchor) ?? rangeStart
            }
        }

        var count = 0
        let maxPerEvent = 30
        while current <= rangeEnd && count < maxPerEvent {
            if current >= calendar.startOfDay(for: rangeStart) {
                let occurrenceDate: Date
                if event.isAllDay == true {
                    occurrenceDate = current
                } else {
                    let timeComps = calendar.dateComponents([.hour, .minute], from: event.startDate)
                    var dayComps = calendar.dateComponents([.year, .month, .day], from: current)
                    dayComps.hour = timeComps.hour
                    dayComps.minute = timeComps.minute
                    occurrenceDate = calendar.date(from: dayComps) ?? current
                }
                scheduleNotification(for: event, eventId: eventId, on: occurrenceDate)
                count += 1
            }

            if let recEnd = event.recurrenceEndDate, current > recEnd { break }

            switch freq {
            case .daily:
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? rangeEnd.addingTimeInterval(1)
            case .weekly:
                current = calendar.date(byAdding: .day, value: 7, to: current) ?? rangeEnd.addingTimeInterval(1)
            case .fortnightly:
                current = calendar.date(byAdding: .day, value: 14, to: current) ?? rangeEnd.addingTimeInterval(1)
            case .monthly:
                current = calendar.date(byAdding: .month, value: 1, to: current) ?? rangeEnd.addingTimeInterval(1)
            case .yearly:
                current = calendar.date(byAdding: .year, value: 1, to: current) ?? rangeEnd.addingTimeInterval(1)
            }
        }
    }
}
