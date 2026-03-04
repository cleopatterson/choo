import SwiftUI

struct DayAgendaView: View {
    let agenda: [DayAgendaItem]

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    var body: some View {
        if agenda.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("THIS WEEK'S AGENDA")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1.5)
                    .padding(.horizontal, 20)

                VStack(spacing: 2) {
                    ForEach(agenda) { dayItem in
                        dayRow(dayItem)
                    }
                }
                .padding(.horizontal, 20)
            }
        )
    }

    private func dayRow(_ dayItem: DayAgendaItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Day label
            Text(Self.dayFormatter.string(from: dayItem.date).prefix(3).uppercased())
                .font(.caption2.bold())
                .foregroundStyle(dayItem.isPast ? .white.opacity(0.25) : .white.opacity(0.5))
                .frame(width: 30, alignment: .leading)

            // Events
            VStack(alignment: .leading, spacing: 3) {
                ForEach(dayItem.events) { event in
                    eventLine(event, isPast: dayItem.isPast)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func eventLine(_ event: AgendaEvent, isPast: Bool) -> some View {
        HStack(spacing: 6) {
            // Coloured border for member
            RoundedRectangle(cornerRadius: 1.5)
                .fill(stripColor(event))
                .frame(width: 3, height: 16)
                .opacity((isPast || event.isCompleted) ? 0.35 : 1)

            if isPast || event.isCompleted {
                Text(event.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
                    .strikethrough(true, color: .white.opacity(0.2))
                    .lineLimit(1)
            } else {
                Text(event.title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            // Urgency badge for todos
            if event.isTodo, !event.isCompleted, let urgency = event.todoUrgency {
                todoUrgencyBadge(urgency)
            }

            if let time = event.time {
                Spacer()
                Text(time)
                    .font(.caption2)
                    .foregroundStyle(isPast ? .white.opacity(0.2) : .white.opacity(0.4))
            } else if event.isTodo {
                Spacer()
                // Checkbox indicator
                Image(systemName: event.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundStyle(event.isCompleted ? .green : .white.opacity(0.3))
            }
        }
    }

    @ViewBuilder
    private func todoUrgencyBadge(_ urgency: String) -> some View {
        let (label, color) = todoUrgencyStyle(urgency)
        Text(label)
            .font(.system(size: 8, weight: .bold))
            .textCase(.uppercase)
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func todoUrgencyStyle(_ urgency: String) -> (String, Color) {
        switch urgency {
        case "overdue": ("Overdue", .red)
        case "dueSoon": ("Due soon", .orange)
        case "active": ("Active", .cyan)
        case "flexible": ("Flexible", .white.opacity(0.4))
        default: ("", .clear)
        }
    }

    private func stripColor(_ event: AgendaEvent) -> Color {
        if event.isTodo {
            return event.todoUrgency == "overdue" ? .red : .cyan
        }
        if event.isBill { return .orange }
        if let uid = event.memberColor {
            return MemberAvatarView.color(for: uid)
        }
        return .chooPurple
    }
}
