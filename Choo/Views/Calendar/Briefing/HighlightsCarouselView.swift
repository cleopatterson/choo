import SwiftUI

struct HighlightsCarouselView: View {
    let highlights: [WeekHighlight]
    var heading: String = "THIS WEEK'S HIGHLIGHTS"
    var onEventTap: ((String) -> Void)?
    var scrollToDate: Date?

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        if highlights.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                if !heading.isEmpty {
                    Text(heading)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(1.5)
                        .padding(.horizontal, 20)
                }

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(highlights) { item in
                                Button {
                                    onEventTap?(item.eventId)
                                } label: {
                                    highlightCard(item)
                                }
                                .buttonStyle(.plain)
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onAppear {
                        if let firstUpcoming = highlights.first(where: { !$0.isPast }) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(firstUpcoming.id, anchor: .leading)
                                }
                            }
                        }
                    }
                    .onChange(of: scrollToDate) { _, newDate in
                        guard let targetDate = newDate,
                              let match = highlights.first(where: {
                                  Calendar.current.isDate($0.date, inSameDayAs: targetDate)
                              }) else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(match.id, anchor: .leading)
                        }
                    }
                }
            }
        )
    }

    private func highlightCard(_ item: WeekHighlight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.icon)
                    .font(.title3)
                Spacer()
                if item.isTodo {
                    todoBadge(item)
                } else if item.isPast {
                    Text("Done")
                        .font(.caption2.bold())
                        .foregroundStyle(.green.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.1), in: Capsule())
                }
            }

            Text(item.title)
                .font(.subheadline.bold())
                .foregroundStyle(item.isPast ? .white.opacity(0.35) : .white)
                .lineLimit(2, reservesSpace: true)
                .strikethrough(item.isTodo && item.isPast, color: .white.opacity(0.2))

            if item.isTodo {
                todoDueLabel(item)
            } else {
                Text(Self.shortDateFormatter.string(from: item.date))
                    .font(.caption)
                    .foregroundStyle(item.isPast ? .white.opacity(0.25) : .white.opacity(0.5))
            }
        }
        .frame(width: 120, alignment: .topLeading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(todoStrokeBorder(item), lineWidth: 1)
        )
        .saturation(item.isPast ? 0 : 1)
        .opacity(item.isPast ? 0.7 : 1)
    }

    @ViewBuilder
    private func todoBadge(_ item: WeekHighlight) -> some View {
        if item.isPast {
            // Completed
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            let (label, color) = todoUrgencyStyle(item.todoUrgency)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(color)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(color.opacity(0.15), in: Capsule())
        }
    }

    @ViewBuilder
    private func todoDueLabel(_ item: WeekHighlight) -> some View {
        if item.isPast {
            Text("Done")
                .font(.caption)
                .foregroundStyle(.green.opacity(0.5))
        } else if item.todoUrgency == "flexible" {
            Text("No due date")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
        } else {
            Text("Due \(Self.shortDateFormatter.string(from: item.date))")
                .font(.caption)
                .foregroundStyle(item.todoUrgency == "overdue" ? .red.opacity(0.7) : .white.opacity(0.5))
        }
    }

    private func todoStrokeBorder(_ item: WeekHighlight) -> Color {
        guard item.isTodo else { return .white.opacity(0.08) }
        if item.isPast { return .white.opacity(0.08) }
        switch item.todoUrgency {
        case "overdue": return .red.opacity(0.25)
        case "dueSoon": return .orange.opacity(0.2)
        default: return .cyan.opacity(0.15)
        }
    }

    private func todoUrgencyStyle(_ urgency: String?) -> (String, Color) {
        switch urgency {
        case "overdue": ("Overdue", .red)
        case "dueSoon": ("Due soon", .orange)
        case "active": ("To-Do", .cyan)
        case "flexible": ("Flexible", .white.opacity(0.4))
        default: ("To-Do", .cyan)
        }
    }
}
