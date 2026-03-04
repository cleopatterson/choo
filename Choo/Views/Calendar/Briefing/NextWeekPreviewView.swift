import SwiftUI

struct NextWeekPreviewView: View {
    @Bindable var viewModel: WeeklyBriefingViewModel

    private static let weekRangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private var weekLabel: String {
        let start = Self.weekRangeFormatter.string(from: viewModel.nextWeekStart)
        let end = Self.weekRangeFormatter.string(from: viewModel.nextWeekEnd)
        return "\(start) – \(end)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // AI-powered editorial header (reuses BriefingCoverView)
            BriefingCoverView(
                headline: viewModel.nextWeekHeadline,
                summary: viewModel.nextWeekSummary,
                weekLabel: weekLabel,
                badge: "Next week",
                isNextWeek: true
            )

            // Week timeline (read-only — no onDayTap)
            WeekTimelineView(
                weekDays: viewModel.nextWeekDays,
                eventCounts: viewModel.nextWeekEventCounts
            )

            Divider()
                .overlay(.white.opacity(0.06))

            // Unified events carousel — highlights + other events combined
            if let briefing = viewModel.nextWeekBriefing {
                let allEvents = (briefing.highlights + briefing.otherEvents).sorted { $0.date < $1.date }
                if !allEvents.isEmpty {
                    HighlightsCarouselView(
                        highlights: allEvents,
                        heading: ""
                    )
                    .padding(.vertical, 12)
                }
            }

            // Weather strip
            if !viewModel.nextWeekForecasts.isEmpty {
                WeatherStripView(
                    forecasts: viewModel.nextWeekForecasts,
                    weekDays: viewModel.nextWeekDays,
                    showHeading: false
                )
                .padding(.vertical, 12)
            }

            // Empty state
            if viewModel.nextWeekBriefing == nil {
                Text("No events yet")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
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
