import SwiftUI

struct WeeklyBriefingCardView: View {
    @Bindable var viewModel: WeeklyBriefingViewModel
    var onEventTap: ((String) -> Void)?

    @State private var highlightScrollDate: Date?

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
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

            // Layer 2: Week timeline + highlights + weather
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
}
