import SwiftUI

struct ChoresTabView: View {
    @Bindable var viewModel: ChoresViewModel
    @Binding var showingProfile: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ChoresBriefingView(
                        headline: viewModel.briefingHeadline,
                        summary: viewModel.briefingSummary,
                        isLoading: viewModel.isLoadingBriefing,
                        dateRange: viewModel.weekDateRange
                    )

                    ChoresHeroView(viewModel: viewModel)

                    ChoresWeekStripView(viewModel: viewModel)

                    if viewModel.choreCount > 0 {
                        ChoresStatsBar(
                            choreCount: viewModel.choreCount,
                            completedCount: viewModel.completedCount,
                            totalMinutes: viewModel.totalDurationMinutes
                        )
                    }

                    ChoresCategoriesView(viewModel: viewModel)
                }
                .padding()
            }
            .chooBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .opacity(0.6)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Chores")
                        .font(.system(.headline, design: .serif))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showingCategoryForm = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .sheet(item: Binding(
                get: { viewModel.selectedDayIndex.map { ChoresSheetIdentifier(id: $0) } },
                set: { viewModel.selectedDayIndex = $0?.id }
            )) { _ in
                ChoresAddSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.showingCategoryForm) {
                ChoresManageSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct ChoresSheetIdentifier: Identifiable {
    let id: Int
}

// MARK: - Briefing wrapper

private struct ChoresBriefingView: View {
    let headline: String
    let summary: String
    let isLoading: Bool
    var dateRange: String = ""

    var body: some View {
        BriefingCardView(
            badge: "This week",
            dateRange: dateRange,
            headline: headline,
            summary: summary,
            accent: .chores,
            isLoading: isLoading
        )
    }
}
