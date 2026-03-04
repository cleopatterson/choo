import SwiftUI

struct ExerciseTabView: View {
    @Bindable var viewModel: ExerciseViewModel
    @Binding var showingProfile: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ExerciseBriefingView(
                        headline: viewModel.briefingHeadline,
                        summary: viewModel.briefingSummary,
                        isLoading: viewModel.isLoadingBriefing,
                        dateRange: viewModel.weekDateRange
                    )

                    ExerciseHeroView(viewModel: viewModel)

                    ExerciseWeekStripView(viewModel: viewModel)

                    if viewModel.sessionCount > 0 || viewModel.restDayCount > 0 {
                        ExerciseStatsBar(
                            sessionCount: viewModel.sessionCount,
                            categoryCount: viewModel.categoryCount,
                            restDayCount: viewModel.restDayCount
                        )
                    }

                    ExerciseCategoriesView(viewModel: viewModel)
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
                    Text("Exercise")
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
                get: { viewModel.selectedDayIndex.map { SheetIdentifier(id: $0) } },
                set: { viewModel.selectedDayIndex = $0?.id }
            )) { _ in
                ExerciseAddSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $viewModel.showingCategoryForm) {
                ExerciseManageSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

private struct SheetIdentifier: Identifiable {
    let id: Int
}
