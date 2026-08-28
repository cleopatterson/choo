import Foundation
import WidgetKit

/// Expands events into dated occurrences over the next N days and writes
/// a compact snapshot to the shared App Group container for the widget.
enum WidgetDataWriter {
    static let lookaheadDays = 7
    static let maxItems = 12

    static func update(from events: [FamilyEvent]) {
        let snapshot = buildSnapshot(from: events)
        WidgetSharedStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedConstants.widgetKind)
    }

    static func buildSnapshot(from events: [FamilyEvent], now: Date = Date()) -> WidgetUpcomingSnapshot {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard let horizon = cal.date(byAdding: .day, value: lookaheadDays, to: today) else {
            return WidgetUpcomingSnapshot(generatedAt: now, items: [])
        }

        var items: [WidgetUpcomingItem] = []

        var dayCursor = today
        while dayCursor <= horizon {
            for event in events where event.occursOn(dayCursor) {
                if event.isBill == true, event.isPaidOn(dayCursor) { continue }
                if event.isTodo == true, event.isCompleted == true { continue }

                let occurrenceDate: Date
                if event.isAllDay == true || event.isTodo == true {
                    occurrenceDate = dayCursor
                } else {
                    // Shift the event's time to this occurrence's day
                    let timeComps = cal.dateComponents([.hour, .minute], from: event.startDate)
                    occurrenceDate = cal.date(
                        bySettingHour: timeComps.hour ?? 0,
                        minute: timeComps.minute ?? 0,
                        second: 0,
                        of: dayCursor
                    ) ?? dayCursor
                }

                // Only future-or-today items
                if occurrenceDate < now, !cal.isDate(occurrenceDate, inSameDayAs: now) { continue }

                let kind: WidgetUpcomingItem.Kind
                if event.isBill == true { kind = .bill }
                else if event.isTodo == true { kind = .todo }
                else { kind = .event }

                let uniqueId = "\(event.id ?? UUID().uuidString)-\(cal.startOfDay(for: dayCursor).timeIntervalSince1970)"
                items.append(WidgetUpcomingItem(
                    id: uniqueId,
                    title: event.title,
                    date: occurrenceDate,
                    isAllDay: event.isAllDay == true || event.isTodo == true,
                    kind: kind,
                    emoji: event.todoEmoji,
                    amount: event.amount,
                    location: event.location
                ))
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: dayCursor) else { break }
            dayCursor = next
        }

        items.sort { $0.date < $1.date }
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }

        return WidgetUpcomingSnapshot(generatedAt: now, items: items)
    }
}
