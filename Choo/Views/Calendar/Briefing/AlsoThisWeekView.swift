import SwiftUI

struct AlsoThisWeekView: View {
    let events: [WeekHighlight]
    var heading: String = "ALSO THIS WEEK"
    var onEventTap: ((String) -> Void)?

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1.5)
                .padding(.horizontal, 20)

            VStack(spacing: 2) {
                ForEach(events) { event in
                    Button {
                        onEventTap?(event.eventId)
                    } label: {
                        eventRow(event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func eventRow(_ event: WeekHighlight) -> some View {
        HStack(spacing: 8) {
            Text(event.icon)
                .font(.caption)
                .frame(width: 20)

            Text(event.title)
                .font(.caption)
                .foregroundStyle(event.isPast ? .white.opacity(0.35) : .white.opacity(0.8))
                .lineLimit(1)

            Spacer()

            Text(Self.shortDateFormatter.string(from: event.date))
                .font(.caption2)
                .foregroundStyle(event.isPast ? .white.opacity(0.2) : .white.opacity(0.4))
        }
        .padding(.vertical, 6)
        .opacity(event.isPast ? 0.7 : 1)
    }
}
