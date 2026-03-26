import SwiftUI

struct HouseTabView: View {
    @Bindable var viewModel: HouseViewModel
    @Binding var showingProfile: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 16) {
                        HouseBriefingView(
                            headline: viewModel.briefingHeadline,
                            summary: viewModel.briefingSummary,
                            isLoading: viewModel.isLoadingBriefing,
                            dateRange: viewModel.weekDateRange
                        )

                        HouseHeroView(viewModel: viewModel)

                        HouseWeekStripView(viewModel: viewModel)

                        if viewModel.dueCount > 0 || viewModel.completedThisMonthCount > 0 {
                            HouseStatsBar(
                                dueCount: viewModel.dueCount,
                                completedCount: viewModel.completedThisMonthCount,
                                overdueCount: viewModel.overdueCount
                            )
                        }

                        HouseChoreListView(viewModel: viewModel, scrollProxy: scrollProxy)
                    }
                    .padding()
                }
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
                    Text("House")
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
            .sheet(isPresented: $viewModel.showingCategoryForm) {
                HouseManageSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $viewModel.selectedChoreForAction) { item in
                HouseChoreActionSheet(viewModel: viewModel, item: item)
                    .presentationDetents([.medium])
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $viewModel.selectedChoreForEdit) { item in
                HouseChoreEditSheet(viewModel: viewModel, item: item)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: Binding(
                get: { viewModel.selectedDayIndex.map { HouseDaySheetId(id: $0) } },
                set: { viewModel.selectedDayIndex = $0?.id }
            )) { day in
                HouseDayPlanSheet(viewModel: viewModel, dayIndex: day.id)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Briefing wrapper

private struct HouseBriefingView: View {
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
            accent: .house,
            isLoading: isLoading
        )
    }
}

private struct HouseDaySheetId: Identifiable {
    let id: Int
}
