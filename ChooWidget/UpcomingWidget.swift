import WidgetKit
import SwiftUI

// MARK: - Timeline

struct UpcomingEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetUpcomingSnapshot
}

struct UpcomingProvider: TimelineProvider {
    func placeholder(in context: Context) -> UpcomingEntry {
        UpcomingEntry(date: Date(), snapshot: Self.sampleSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (UpcomingEntry) -> Void) {
        let snap = WidgetSharedStore.load() ?? Self.sampleSnapshot()
        completion(UpcomingEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingEntry>) -> Void) {
        let snap = WidgetSharedStore.load() ?? WidgetUpcomingSnapshot(generatedAt: Date(), items: [])
        let entry = UpcomingEntry(date: Date(), snapshot: snap)
        // Refresh every 30 min; app also nudges reloadTimelines on data change.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    static func sampleSnapshot() -> WidgetUpcomingSnapshot {
        let cal = Calendar.current
        let now = Date()
        let items: [WidgetUpcomingItem] = [
            .init(id: "1", title: "Swimming", date: cal.date(byAdding: .hour, value: 2, to: now) ?? now,
                  isAllDay: false, kind: .event, emoji: nil, amount: nil, location: nil),
            .init(id: "2", title: "Electricity bill", date: cal.date(byAdding: .day, value: 1, to: now) ?? now,
                  isAllDay: true, kind: .bill, emoji: nil, amount: 142.50, location: nil),
            .init(id: "3", title: "School pickup", date: cal.date(byAdding: .day, value: 2, to: now) ?? now,
                  isAllDay: false, kind: .event, emoji: nil, amount: nil, location: nil)
        ]
        return WidgetUpcomingSnapshot(generatedAt: now, items: items)
    }
}

// MARK: - Widget

struct UpcomingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetSharedConstants.widgetKind,
            provider: UpcomingProvider()
        ) { entry in
            UpcomingWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.06, blue: 0.14),
                                 Color(red: 0.12, green: 0.08, blue: 0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Upcoming")
        .description("See what's coming up over the next few days.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - View

struct UpcomingWidgetView: View {
    var entry: UpcomingEntry
    @Environment(\.widgetFamily) private var family

    private var maxRows: Int {
        switch family {
        case .systemSmall: return 3
        case .systemLarge: return 7
        default: return 3
        }
    }

    var body: some View {
        let items = Array(entry.snapshot.items.prefix(maxRows))
        VStack(alignment: .leading, spacing: family == .systemSmall ? 5 : 6) {
            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                Text("UPCOMING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }

            if items.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("Nothing coming up")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: family == .systemSmall ? 6 : 5) {
                    ForEach(items) { item in
                        UpcomingRow(item: item, compact: family == .systemSmall)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct UpcomingRow: View {
    let item: WidgetUpcomingItem
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3, height: compact ? 18 : 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(compact ? .system(size: 11, weight: .semibold) : .caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(trailing)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            if !compact {
                Spacer(minLength: 4)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var accentColor: Color {
        switch item.kind {
        case .event: return Color(red: 0.55, green: 0.36, blue: 0.96) // chooPurple
        case .bill:  return Color(red: 0.98, green: 0.57, blue: 0.24) // chooAmber
        case .todo:  return Color(red: 0.78, green: 0.56, blue: 0.65) // chooRose
        }
    }

    private var subtitle: String {
        if let loc = item.location, !loc.isEmpty { return loc }
        switch item.kind {
        case .bill:
            if let amt = item.amount { return String(format: "$%.2f", amt) }
            return "Bill"
        case .todo: return "To-do"
        case .event: return "Event"
        }
    }

    private var trailing: String {
        let cal = Calendar.current
        let now = Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_AU")

        if cal.isDateInToday(item.date) {
            if item.isAllDay { return "Today" }
            df.dateFormat = "h:mma"
            return df.string(from: item.date).lowercased()
        }
        if cal.isDateInTomorrow(item.date) {
            if item.isAllDay { return "Tom" }
            df.dateFormat = "'Tom' h:mma"
            return df.string(from: item.date).replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
        }
        let daysOut = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: item.date)).day ?? 0
        if daysOut < 7 {
            df.dateFormat = item.isAllDay ? "EEE" : "EEE h:mma"
            return df.string(from: item.date).replacingOccurrences(of: "AM", with: "am").replacingOccurrences(of: "PM", with: "pm")
        }
        df.dateFormat = "d MMM"
        return df.string(from: item.date)
    }
}
