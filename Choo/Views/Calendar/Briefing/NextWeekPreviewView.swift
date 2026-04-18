import SwiftUI

struct NextWeekPreviewView: View {
    @Bindable var viewModel: WeeklyBriefingViewModel
    var onEventTap: ((String) -> Void)? = nil

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
        VStack(spacing: 12) {
            // Layer 1: Editorial header (separate card, matches this-week layout)
            BriefingCoverView(
                headline: viewModel.nextWeekHeadline,
                summary: viewModel.nextWeekSummary,
                weekLabel: weekLabel,
                badge: "Next week",
                isNextWeek: true
            )

            // Layer 2: Week timeline + highlights + weather (glass card)
            VStack(spacing: 0) {
                // Week timeline (read-only — no onDayTap)
                WeekTimelineView(
                    weekDays: viewModel.nextWeekDays,
                    eventCounts: viewModel.nextWeekEventCounts
                )

                // Unified events carousel — highlights + other events combined
                if let briefing = viewModel.nextWeekBriefing {
                    let allEvents = (briefing.highlights + briefing.otherEvents).sorted { $0.date < $1.date }
                    if !allEvents.isEmpty {
                        HighlightsCarouselView(
                            highlights: allEvents,
                            heading: "",
                            onEventTap: onEventTap
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
}
