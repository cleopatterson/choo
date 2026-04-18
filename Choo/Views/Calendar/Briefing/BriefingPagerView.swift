import SwiftUI

/// Wraps this-week and next-week briefing cards in a paged TabView.
/// Uses GeometryReader on visible cards to measure height, avoiding hidden duplicate renders.
struct BriefingPagerView: View {
    @Bindable var briefingViewModel: WeeklyBriefingViewModel
    var calendarViewModel: CalendarViewModel
    @Binding var selectedPage: Int

    @State private var thisWeekHeight: CGFloat = 500
    @State private var nextWeekHeight: CGFloat = 500

    private var pagerHeight: CGFloat {
        max(thisWeekHeight, nextWeekHeight, 200)
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                thisWeekCard
                    .readHeight { thisWeekHeight = $0 }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 4)
                    .tag(0)

                NextWeekPreviewView(viewModel: briefingViewModel, onEventTap: { eventId in
                    if let event = calendarViewModel.firestoreService.events.first(where: { $0.id == eventId }) {
                        calendarViewModel.selectedEvent = event
                    }
                })
                    .readHeight { nextWeekHeight = $0 }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 4)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: pagerHeight)

            // Custom page dots
            HStack(spacing: 6) {
                ForEach(0..<2) { i in
                    Circle()
                        .fill(.white.opacity(i == selectedPage ? 0.5 : 0.15))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 8)
        }
    }

    private var thisWeekCard: some View {
        WeeklyBriefingCardView(
            viewModel: briefingViewModel,
            onEventTap: { eventId in
                if let event = calendarViewModel.firestoreService.events.first(where: { $0.id == eventId }) {
                    calendarViewModel.selectedEvent = event
                }
            }
        )
    }
}

// MARK: - Height reader

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: HeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(HeightKey.self, perform: onChange)
    }
}
