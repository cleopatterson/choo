import SwiftUI

struct WeeklyBriefingCardView: View {
    @Bindable var viewModel: WeeklyBriefingViewModel
    var calendarViewModel: CalendarViewModel?
    var onEventTap: ((String) -> Void)?

    @State private var highlightScrollDate: Date?

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private var weekLabel: String {
        let start = Self.weekRangeFormatter.string(from: viewModel.weekStart)
        let end = Self.weekRangeFormatter.string(from: viewModel.weekEnd)
        return "\(start) – \(end)"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Layer 1: Editorial header with AI summary
            BriefingCoverView(
                headline: viewModel.headline,
                summary: viewModel.summary,
                weekLabel: weekLabel,
                isLoading: viewModel.isLoadingBriefing
            )

            // Layer 2: Hero card — next event today (this-week page only)
            if let calendarVM = calendarViewModel, let event = calendarVM.todayNextEvent {
                calendarHeroCard(event: event, calendarVM: calendarVM)
            }

            // Layer 3: Week timeline + highlights + weather
            VStack(spacing: 0) {
                WeekTimelineView(
                    weekDays: viewModel.weekDays,
                    eventCounts: viewModel.eventCounts,
                    onDayTap: { highlightScrollDate = $0 }
                )

                // Unified events carousel — highlights + other events + todos combined
                if let briefing = viewModel.briefing {
                    let todoHighlights: [WeekHighlight] = briefing.todos.map { todo in
                        WeekHighlight(
                            eventId: todo.eventId,
                            title: todo.title,
                            date: todo.dueDate ?? todo.startDate,
                            icon: todo.emoji,
                            isPast: todo.isCompleted,
                            isTodo: true,
                            todoUrgency: todo.urgency
                        )
                    }
                    let allEvents = (briefing.highlights + briefing.otherEvents + todoHighlights).sorted { $0.date < $1.date }
                    if !allEvents.isEmpty {
                        HighlightsCarouselView(highlights: allEvents, heading: "", onEventTap: onEventTap, scrollToDate: highlightScrollDate)
                            .padding(.vertical, 12)
                    }
                }

                // Weather strip
                if !viewModel.forecasts.isEmpty {
                    WeatherStripView(
                        forecasts: viewModel.forecasts,
                        weekDays: viewModel.weekDays,
                        showHeading: false
                    )
                    .padding(.vertical, 12)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - Calendar Hero Card

    @ViewBuilder
    private func calendarHeroCard(event: FamilyEvent, calendarVM: CalendarViewModel) -> some View {
        let icon = viewModel.iconForEvent(event)
        let subtitle: String = {
            if let loc = event.location, !loc.isEmpty {
                return loc
            }
            if event.isAllDay == true {
                return "All day"
            }
            return Self.shortTimeFormatter.string(from: event.startDate)
        }()

        HeroCardView(
            label: calendarVM.todayNextEventLabel,
            title: event.title,
            subtitle: subtitle,
            emoji: icon,
            accent: .calendar
        ) {
            if event.isAllDay != true {
                HeroCardView<EmptyView>.pillBadge(text: "🕐 \(Self.shortTimeFormatter.string(from: event.startDate))")
            }
            if let loc = event.location, !loc.isEmpty {
                HeroCardView<EmptyView>.pillBadge(text: "📍 \(loc)")
            }
            if calendarVM.todayEventCount > 1 {
                HeroCardView<EmptyView>.pillBadge(text: "+\(calendarVM.todayEventCount - 1) more today")
            }
        }
        .onTapGesture {
            calendarVM.selectedEvent = event
        }
    }
}
